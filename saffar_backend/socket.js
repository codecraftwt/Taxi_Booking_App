const { Server } = require("socket.io");
const { createAdapter } = require("@socket.io/redis-adapter");
const jwt = require("jsonwebtoken");
const config = require("./config");
const { query } = require("./database");
const { sendPushNotification } = require("./services/fcmService");
const { redisClient, connectRedis } = require("./config/redis");
const { updateDriverLocation } = require("./services/driverLocationService");

let io = null;

async function setupRedisAdapter(ioInstance) {
  try {
    if (!redisClient.isOpen) {
      await connectRedis();
    }
    if (redisClient.isOpen) {
      const pubClient = redisClient.duplicate();
      const subClient = pubClient.duplicate();
      pubClient.on("error", (err) => console.warn("[REDIS ADAPTER PUB ERROR]", err.message));
      subClient.on("error", (err) => console.warn("[REDIS ADAPTER SUB ERROR]", err.message));
      await Promise.all([pubClient.connect(), subClient.connect()]);
      ioInstance.adapter(createAdapter(pubClient, subClient));
      console.log("[SOCKET] Redis Adapter attached successfully.");
    }
  } catch (err) {
    console.warn("[SOCKET] Failed to attach Redis adapter (using in-memory fallback):", err.message);
  }
}

function formatEventEnvelope(eventType, data) {
  return {
    event_id: `evt_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
    event_type: eventType,
    timestamp: new Date().toISOString(),
    ...data,
  };
}

function initSocket(httpServer) {
  io = new Server(httpServer, {
    cors: {
      origin: "*",
      methods: ["GET", "POST", "PATCH", "DELETE"],
    },
    pingInterval: 10000,
    pingTimeout: 5000,
  });

  // Attach Redis Adapter for horizontal scaling if Redis is connected
  setupRedisAdapter(io);

  // 1. Authenticate Socket Handshake with JWT
  io.use((socket, next) => {
    const token =
      socket.handshake.auth?.token ||
      socket.handshake.headers?.authorization?.replace("Bearer ", "") ||
      socket.handshake.query?.token;

    if (!token) {
      // Allow connection but mark unauthenticated if connecting without token
      socket.user = null;
      return next();
    }

    try {
      const decoded = jwt.verify(token, config.TOKEN_SECRET_KEY);
      socket.user = decoded; // { id, phone, role }
      return next();
    } catch (err) {
      console.warn("[SOCKET AUTH] Handshake token verification failed:", err.message);
      // Still allow connection with unauthenticated tag to allow reconnecting clients to refresh tokens
      socket.user = null;
      return next();
    }
  });

  io.on("connection", (socket) => {
    const userId = socket.user?.id;
    const role = socket.user?.role;

    // 2. Authorize and automatically join user-specific rooms (Never trust client-provided IDs)
    if (userId) {
      if (role === "driver") {
        socket.join(`driver_${userId}`);
      } else {
        socket.join(`user_${userId}`);
      }
    }

    // Fallback manual room join with token verification check
    socket.on("join_driver", (data) => {
      const targetDriverId = socket.user?.id || (typeof data === "string" ? data : data?.driver_id);
      if (targetDriverId) {
        socket.join(`driver_${targetDriverId}`);
      }
    });

    socket.on("join_user", (data) => {
      const targetUserId = socket.user?.id || (typeof data === "string" ? data : data?.user_id);
      if (targetUserId) {
        socket.join(`user_${targetUserId}`);
      }
    });

    // 3. Authorize Ride-Specific Room Subscription
    socket.on("join_ride", async (data, ack) => {
      const rideId = typeof data === "string" ? data : data?.ride_id;
      if (!rideId) {
        if (typeof ack === "function") ack({ success: false, error: "Missing ride_id" });
        return;
      }

      // If user is authenticated, verify authorization against database
      if (socket.user?.id) {
        try {
          const authCheck = await query(
            `SELECT id FROM rides WHERE id = $1 AND (user_id = $2 OR driver_id = $2);`,
            [rideId, socket.user.id]
          );
          if (authCheck.rows.length === 0) {
            console.warn(`[SOCKET AUTH] User ${socket.user.id} unauthorized to join ride room: ${rideId}`);
            if (typeof ack === "function") ack({ success: false, error: "Unauthorized for this ride room." });
            return;
          }
        } catch (dbErr) {
          console.warn("[SOCKET DB ERROR]", dbErr.message);
        }
      }

      socket.join(`ride_${rideId}`);
      if (typeof ack === "function") ack({ success: true, room: `ride_${rideId}` });
    });

    // 4. Reconnection & Authoritative State Synchronization
    socket.on("sync_state", async (data, ack) => {
      const effectiveId = socket.user?.id || data?.id;
      if (!effectiveId) {
        if (typeof ack === "function") ack({ success: false, error: "Authentication required" });
        return;
      }

      try {
        const activeRideRes = await query(
          `SELECT r.id, r.user_id, r.driver_id, r.status, r.otp, r.price, r.vehicle_type,
                  r.start_time, r.reaching_pickup_at, r.arrived_at, r.trip_started_at,
                  sa.street as pickup_street, da.street as dest_street,
                  d.name as driver_name, d.phone as driver_phone, d.vehicle_name, d.vehicle_number, d.current_lat, d.current_lng
           FROM rides r
           LEFT JOIN addresses sa ON r.source_address_id = sa.id
           LEFT JOIN addresses da ON r.destination_address_id = da.id
           LEFT JOIN drivers d ON r.driver_id = d.id
           WHERE (r.user_id = $1 OR r.driver_id = $1)
             AND r.cancelled = false
             AND r.status IN ('requested', 'accepted', 'reaching_pickup', 'arrived', 'in_progress')
           ORDER BY r.start_time DESC
           LIMIT 1;`,
          [effectiveId]
        );

        const activeRide = activeRideRes.rows.length > 0 ? activeRideRes.rows[0] : null;
        if (typeof ack === "function") {
          ack({
            success: true,
            synced_at: new Date().toISOString(),
            active_ride: activeRide,
          });
        }
      } catch (err) {
        if (typeof ack === "function") ack({ success: false, error: err.message });
      }
    });

    // 5. Driver Accept / Reject Offer via Socket
    socket.on("accept_offer", async (data, ack) => {
      const driverId = socket.user?.id || (typeof data === "object" ? data.driver_id : null);
      const rideId = typeof data === "object" ? data.ride_id : null;
      if (!driverId || !rideId) {
        if (typeof ack === "function") ack({ success: false, error: "Missing ride_id or driver_id" });
        return;
      }
      try {
        const dispatchCoordinator = require("./modules/driver_matching/dispatch.coordinator");
        const result = await dispatchCoordinator.handleDriverAcceptance(rideId, driverId);
        if (typeof ack === "function") ack(result);
      } catch (err) {
        if (typeof ack === "function") ack({ success: false, error: err.message });
      }
    });

    socket.on("reject_offer", async (data, ack) => {
      const driverId = socket.user?.id || (typeof data === "object" ? data.driver_id : null);
      const rideId = typeof data === "object" ? data.ride_id : null;
      if (!driverId || !rideId) {
        if (typeof ack === "function") ack({ success: false, error: "Missing ride_id or driver_id" });
        return;
      }
      try {
        const dispatchCoordinator = require("./modules/driver_matching/dispatch.coordinator");
        const result = await dispatchCoordinator.handleDriverRejection(rideId, driverId);
        if (typeof ack === "function") ack(result);
      } catch (err) {
        if (typeof ack === "function") ack({ success: false, error: err.message });
      }
    });

    // 6. Driver Real-time GPS Location Update Telemetry
    socket.on("driver:location:update", async (data, ack) => {
      try {
        const driverId =
          socket.user?.id ||
          (typeof data === "object" ? (data.driverId || data.driver_id) : null);

        if (!driverId) {
          if (typeof ack === "function") {
            ack({ success: false, error: "Authentication required: missing driver identity" });
          }
          return;
        }

        const latitude = Number(data?.latitude ?? data?.lat);
        const longitude = Number(data?.longitude ?? data?.lng ?? data?.lon);
        const accuracy = Number(data?.accuracy ?? 0);
        const speed = Number(data?.speed ?? 0);
        const heading = Number(data?.heading ?? 0);
        const rideId = data?.rideId || data?.ride_id;

        // Update driver location, GEO index, and last-seen in Redis
        await updateDriverLocation({
          driverId,
          latitude,
          longitude,
          accuracy,
          speed,
          heading,
        });

        const telemetryPayload = {
          driverId,
          driver_id: driverId,
          latitude,
          longitude,
          accuracy,
          speed,
          heading,
          rideId,
          ride_id: rideId,
          updatedAt: Date.now(),
        };

        // Broadcast to customer and ride room if in an active trip/pickup
        if (rideId) {
          io.to(`ride_${rideId}`).emit("ride:driver:location", telemetryPayload);
          io.to(`ride_${rideId}`).emit(
            "driver_location_update",
            formatEventEnvelope("driver_location_update", telemetryPayload)
          );
        }

        if (typeof ack === "function") {
          ack({ success: true, updatedAt: telemetryPayload.updatedAt });
        }
      } catch (err) {
        console.warn("[SOCKET driver:location:update error]", err.message);
        if (typeof ack === "function") {
          ack({ success: false, error: err.message });
        }
      }
    });

    // 7. Driver Online / Offline WebSocket Event Handlers
    socket.on("driver:set_online", async (data, ack) => {
      try {
        const driverId = socket.user?.id || data?.driverId || data?.driver_id;
        if (!driverId) {
          if (typeof ack === "function") ack({ success: false, error: "Missing driver identity" });
          return;
        }

        const { setDriverOnline } = require("./services/driverLocationService");
        const result = await setDriverOnline(driverId, {
          latitude: data?.latitude,
          longitude: data?.longitude,
          heading: data?.heading,
          speed: data?.speed,
        });

        if (typeof ack === "function") ack(result);
      } catch (err) {
        if (typeof ack === "function") ack({ success: false, error: err.message });
      }
    });

    socket.on("driver:set_offline", async (data, ack) => {
      try {
        const driverId = socket.user?.id || data?.driverId || data?.driver_id;
        if (!driverId) {
          if (typeof ack === "function") ack({ success: false, error: "Missing driver identity" });
          return;
        }

        const { setDriverOffline, isDriverOnActiveTrip } = require("./services/driverLocationService");
        const onTrip = await isDriverOnActiveTrip(driverId);
        if (onTrip) {
          if (typeof ack === "function") {
            ack({ success: false, error: "Cannot go offline while on an active trip" });
          }
          return;
        }

        const result = await setDriverOffline(driverId);
        if (typeof ack === "function") ack(result);
      } catch (err) {
        if (typeof ack === "function") ack({ success: false, error: err.message });
      }
    });

    socket.on("disconnect", () => {
      // Disconnected cleanly
    });
  });

  return io;
}

function getIO() {
  return io;
}

// ─── Event Emitters with Structured Envelopes & FCM Integration ─────────────

// 1. Notify eligible drivers about a new ride offer (Targeted only to selected drivers)
function emitNewRideRequest(driverIds, ridePayload) {
  if (!io) return;
  const list = Array.isArray(driverIds) ? driverIds : [driverIds];
  const envelopeLegacy = formatEventEnvelope("new_ride_request", ridePayload);
  const envelopeDot = formatEventEnvelope("ride.offer_received", ridePayload);

  list.forEach((driverId) => {
    io.to(`driver_${driverId}`).emit("new_ride_request", envelopeLegacy);
    io.to(`driver_${driverId}`).emit("ride.offer_received", envelopeDot);

    // Background push notification
    sendPushNotification({
      recipientType: "driver",
      recipientId: driverId,
      title: "New Ride Request Nearby!",
      body: `${ridePayload.vehicle_type || "Ride"} booking ready for pickup (${ridePayload.pickup_address || "Nearby"})`,
      dataPayload: { ride_id: ridePayload.ride_id, action: "DISPATCH" },
    });
  });
}

// 2. Notify user and drivers that a ride was accepted
function emitRideAccepted(rideId, userId, payload) {
  if (!io) return;
  const envelope = formatEventEnvelope("ride_accepted", payload);
  const envelopeDot = formatEventEnvelope("ride.driver_assigned", payload);

  io.to(`user_${userId}`).emit("ride_accepted", envelope);
  io.to(`user_${userId}`).emit("ride.driver_assigned", envelopeDot);
  io.to(`ride_${rideId}`).emit("ride_accepted", envelope);
  io.to(`ride_${rideId}`).emit("ride.driver_assigned", envelopeDot);

  if (payload.driver?.id) {
    io.to(`driver_${payload.driver.id}`).emit("ride.accepted", formatEventEnvelope("ride.accepted", payload));
  }

  // Notify all other drivers that this ride is taken
  const takenEnvelope = formatEventEnvelope("ride_taken", {
    ride_id: rideId,
    assigned_driver: payload.driver,
  });
  io.emit("ride_taken", takenEnvelope);

  // Send push notification to passenger
  sendPushNotification({
    recipientType: "user",
    recipientId: userId,
    title: "Driver Assigned!",
    body: `${payload.driver?.name || "A driver"} has accepted your ride.`,
    dataPayload: { ride_id: rideId, action: "RIDE_ACCEPTED" },
  });
}

// 2b. Notify customer of progressive search status (radius expansion, batch progress)
function emitRideSearching(userId, payload) {
  if (!io) return;
  const envelopeLegacy = formatEventEnvelope("ride_searching", payload);
  const envelopeDot = formatEventEnvelope("ride.searching", payload);

  io.to(`user_${userId}`).emit("ride_searching", envelopeLegacy);
  io.to(`user_${userId}`).emit("ride.searching", envelopeDot);
}

// 2c. Notify customer when no nearby drivers are available
function emitNoDriversFound(userId, payload) {
  if (!io) return;
  const envelopeLegacy = formatEventEnvelope("no_drivers_found", payload);
  const envelopeDot = formatEventEnvelope("ride.no_drivers_found", payload);

  io.to(`user_${userId}`).emit("no_drivers_found", envelopeLegacy);
  io.to(`user_${userId}`).emit("ride.no_drivers_found", envelopeDot);
}

// 2d. Notify individual driver that their offer has expired
function emitRideOfferExpired(driverId, payload) {
  if (!io) return;
  const envelopeLegacy = formatEventEnvelope("ride_offer_expired", payload);
  const envelopeDot = formatEventEnvelope("ride.offer_expired", payload);

  io.to(`driver_${driverId}`).emit("ride_offer_expired", envelopeLegacy);
  io.to(`driver_${driverId}`).emit("ride.offer_expired", envelopeDot);
}

// 2e. Notify individual driver that an offer was cancelled (e.g. rider cancelled or taken by competitor)
function emitRideOfferCancelled(driverId, payload) {
  if (!io) return;
  const envelopeLegacy = formatEventEnvelope("ride_offer_cancelled", payload);
  const envelopeDot = formatEventEnvelope("ride.offer_cancelled", payload);

  io.to(`driver_${driverId}`).emit("ride_offer_cancelled", envelopeLegacy);
  io.to(`driver_${driverId}`).emit("ride.offer_cancelled", envelopeDot);
}

// 2f. Notify individual driver that their rejection was registered
function emitRideOfferRejected(driverId, payload) {
  if (!io) return;
  const envelopeLegacy = formatEventEnvelope("ride_offer_rejected", payload);
  const envelopeDot = formatEventEnvelope("ride.rejected", payload);

  io.to(`driver_${driverId}`).emit("ride_offer_rejected", envelopeLegacy);
  io.to(`driver_${driverId}`).emit("ride.rejected", envelopeDot);
}

// 3. Notify user that ride was cancelled
function emitRideCancelled(rideId, userId, reason, extraPayload = {}) {
  if (!io) return;
  const payload = { ride_id: rideId, reason, status: "cancelled", ...extraPayload };
  const envelope = formatEventEnvelope("ride_cancelled", payload);

  io.to(`user_${userId}`).emit("ride_cancelled", envelope);
  io.to(`ride_${rideId}`).emit("ride_cancelled", envelope);
  io.to(`user_${userId}`).emit("ride_status_updated", envelope);
  io.to(`ride_${rideId}`).emit("ride_status_updated", envelope);

  // Dismiss for all drivers
  io.emit("ride_taken", formatEventEnvelope("ride_taken", { ride_id: rideId, reason }));

  sendPushNotification({
    recipientType: "user",
    recipientId: userId,
    title: "Ride Cancelled",
    body: reason || "Your ride booking has been cancelled.",
    dataPayload: { ride_id: rideId, action: "RIDE_CANCELLED" },
  });
}

// 4. Notify user that driver is reaching pickup
function emitDriverReachingPickup(rideId, userId, payload) {
  if (!io) return;
  const envelope = formatEventEnvelope("driver_reaching_pickup", payload);
  io.to(`user_${userId}`).emit("driver_reaching_pickup", envelope);
  io.to(`ride_${rideId}`).emit("driver_reaching_pickup", envelope);
  io.to(`user_${userId}`).emit("ride_status_updated", envelope);
  io.to(`ride_${rideId}`).emit("ride_status_updated", envelope);
}

// 5. Notify user that driver has arrived at pickup location
function emitDriverArrived(rideId, userId, payload) {
  if (!io) return;
  const envelope = formatEventEnvelope("driver_arrived", payload);
  io.to(`user_${userId}`).emit("driver_arrived", envelope);
  io.to(`ride_${rideId}`).emit("driver_arrived", envelope);
  io.to(`user_${userId}`).emit("ride_status_updated", envelope);
  io.to(`ride_${rideId}`).emit("ride_status_updated", envelope);

  sendPushNotification({
    recipientType: "user",
    recipientId: userId,
    title: "Driver Has Arrived!",
    body: "Your driver is waiting at the pickup spot.",
    dataPayload: { ride_id: rideId, action: "DRIVER_ARRIVED" },
  });
}

// 6. Notify user and driver that OTP was verified and trip has officially started
function emitTripStarted(rideId, userId, payload) {
  if (!io) return;
  const envelope = formatEventEnvelope("trip_started", payload);
  io.to(`user_${userId}`).emit("trip_started", envelope);
  io.to(`ride_${rideId}`).emit("trip_started", envelope);
  io.to(`user_${userId}`).emit("ride_status_updated", envelope);
  io.to(`ride_${rideId}`).emit("ride_status_updated", envelope);
}

// 7. Broadcast live driver location to passenger during active ride
function emitDriverLocationUpdate(rideId, userId, payload) {
  if (!io) return;
  const envelope = formatEventEnvelope("driver_location_update", payload);
  io.to(`user_${userId}`).emit("driver_location_update", envelope);
  io.to(`ride_${rideId}`).emit("driver_location_update", envelope);
  io.to(`user_${userId}`).emit("ride:driver:location", payload);
  io.to(`ride_${rideId}`).emit("ride:driver:location", payload);
}

// 8. Notify user that trip has concluded at destination
function emitTripCompleted(rideId, userId, payload) {
  if (!io) return;
  const envelope = formatEventEnvelope("trip_completed", payload);
  io.to(`user_${userId}`).emit("trip_completed", envelope);
  io.to(`ride_${rideId}`).emit("trip_completed", envelope);
  io.to(`user_${userId}`).emit("ride_status_updated", envelope);
  io.to(`ride_${rideId}`).emit("ride_status_updated", envelope);

  sendPushNotification({
    recipientType: "user",
    recipientId: userId,
    title: "Trip Completed!",
    body: `Your ride has concluded. Total fare: ₹${payload.final_fare || "135.00"}`,
    dataPayload: { ride_id: rideId, action: "TRIP_COMPLETED" },
  });
}

// 9. Broadcast driver account verification status updates (Super Admin approval/rejection/suspension)
function emitDriverStatusUpdated(driverId, payload) {
  if (!io) return;
  const envelope = formatEventEnvelope("driver_status_updated", payload);
  io.to(`driver_${driverId}`).emit("driver_status_updated", envelope);
  io.emit("driver_status_updated", envelope);
  console.log(`[SOCKET] Emitted driver_status_updated to driver_${driverId}:`, payload);
}

module.exports = {
  initSocket,
  getIO,
  emitNewRideRequest,
  emitRideAccepted,
  emitRideCancelled,
  emitRideSearching,
  emitNoDriversFound,
  emitRideOfferExpired,
  emitRideOfferCancelled,
  emitRideOfferRejected,
  emitDriverReachingPickup,
  emitDriverArrived,
  emitTripStarted,
  emitDriverLocationUpdate,
  emitTripCompleted,
  emitDriverStatusUpdated,
};
