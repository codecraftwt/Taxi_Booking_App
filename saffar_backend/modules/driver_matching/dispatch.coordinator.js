const { v4: uuidv4 } = require("uuid");
const { query } = require("../../database");
const redisService = require("../../services/redisService");
const settingsService = require("../../services/settingsService");
const {
  emitNewRideRequest,
  emitRideSearching,
  emitNoDriversFound,
  emitRideOfferExpired,
  emitRideOfferCancelled,
  emitRideOfferRejected,
  emitRideAccepted,
} = require("../../socket");
const {
  findAndRankEligibleDrivers,
  acceptRideOffer,
} = require("./matching.engine");

// In-memory active dispatch sessions: rideId -> DispatchSession
const activeDispatches = new Map();

/**
 * Starts intelligent sequential batch dispatch for a ride request
 */
async function startSequentialDispatch(rideId, rideData, pickupCoords) {
  // If already dispatching, avoid duplicate runs
  if (activeDispatches.has(rideId)) {
    return activeDispatches.get(rideId);
  }

  const config = await settingsService.getMatchingConfig();

  // Define progressive search & dispatch tiers
  const tiers = [
    {
      ring: 1,
      radiusKm: config.initialRadiusKm || 2, // 2 km
      batchSize: config.batch1Size || 2, // 2 drivers
      timeoutSeconds: config.initialOfferTimeoutSeconds || 12, // 12 seconds
      label: "ring_1",
    },
    {
      ring: 2,
      radiusKm: config.secondRadiusKm || 4, // 4 km
      batchSize: config.batch2Size || 3, // 3 drivers
      timeoutSeconds: config.subsequentOfferTimeoutSeconds || 15, // 15 seconds
      label: "ring_2",
    },
    {
      ring: 3,
      radiusKm: config.thirdRadiusKm || 6, // 6 km
      batchSize: config.batch3Size || 5, // 5 drivers
      timeoutSeconds: config.subsequentOfferTimeoutSeconds || 15, // 15 seconds
      label: "ring_3",
    },
    {
      ring: 4,
      radiusKm: config.maxRadiusKm || 10, // 10 km max
      batchSize: config.batch3Size || 5, // 5 drivers
      timeoutSeconds: config.subsequentOfferTimeoutSeconds || 15, // 15 seconds
      label: "ring_4",
    },
  ];

  const session = {
    rideId,
    userId: rideData.user_id,
    rideData,
    pickupCoords,
    tiers,
    currentTierIndex: 0,
    offeredDriverIds: new Set(),
    pendingOfferDriverIds: new Set(),
    batchTimer: null,
    isCancelled: false,
    isAssigned: false,
    startedAt: Date.now(),
  };

  activeDispatches.set(rideId, session);

  // Trigger initial tier and await candidate discovery & dispatch
  await _executeTier(session);

  return session;
}

/**
 * Internal loop executing progressive tiers sequentially
 */
async function _executeTier(session) {
  if (session.isCancelled || session.isAssigned) {
    activeDispatches.delete(session.rideId);
    return;
  }

  // Check if all tiers are exhausted
  if (session.currentTierIndex >= session.tiers.length) {
    _finalizeNoDriversFound(session);
    return;
  }

  const tier = session.tiers[session.currentTierIndex];
  const radiusKm = tier.radiusKm;
  const batchNumber = session.currentTierIndex + 1;

  // 1. Notify Customer of Progress State
  const searchMessage =
    session.currentTierIndex === 0
      ? `Finding nearby drivers within ${radiusKm} km...`
      : `Expanding search area to ${radiusKm} km...`;

  emitRideSearching(session.userId, {
    ride_id: session.rideId,
    status: "searching",
    radius_km: radiusKm,
    batch_number: batchNumber,
    message: searchMessage,
  });

  // 2. Query eligible candidates for current radius (excluding already offered drivers)
  let candidates = [];
  try {
    candidates = await findAndRankEligibleDrivers({
      pickupLat: session.pickupCoords.lat,
      pickupLon: session.pickupCoords.lon,
      vehicleType: session.rideData.vehicle_type,
      searchRing: tier.ring,
      customRadiusKm: radiusKm,
      excludeDriverIds: Array.from(session.offeredDriverIds),
      limit: tier.batchSize,
    });
  } catch (err) {
    console.error(`[DISPATCH ERROR] Finding candidates for ride ${session.rideId}:`, err);
  }

  // 3. If no drivers found in this radius, immediately expand to next tier
  if (!candidates || candidates.length === 0) {
    session.currentTierIndex++;
    return _executeTier(session);
  }

  // 4. Create offers for selected batch
  session.pendingOfferDriverIds = new Set();
  const expiresAt = new Date(Date.now() + tier.timeoutSeconds * 1000);
  const offeredBatch = [];

  for (const candidate of candidates) {
    const offerId = `off_${uuidv4().slice(0, 12)}`;

    try {
      // PostgreSQL record in ride_offers
      await query(
        `INSERT INTO ride_offers (
          id, ride_id, driver_id, batch_number, search_ring, 
          distance_km, eta_minutes, status, score, expires_at
        ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING', $8, $9)
        ON CONFLICT (ride_id, driver_id) DO UPDATE SET 
          status = 'PENDING',
          batch_number = EXCLUDED.batch_number,
          expires_at = EXCLUDED.expires_at;`,
        [
          offerId,
          session.rideId,
          candidate.driverId,
          batchNumber,
          tier.label,
          candidate.distanceKm,
          candidate.etaMinutes,
          candidate.score,
          expiresAt,
        ]
      );

      // Sync legacy ride_requests table for full backward compatibility
      await query(
        `INSERT INTO ride_requests (id, ride_id, driver_id, status, expires_at, distance_to_pickup_km)
         VALUES ($1, $2, $3, 'pending', $4, $5)
         ON CONFLICT (ride_id, driver_id) DO UPDATE SET 
           status = 'pending', expires_at = EXCLUDED.expires_at;`,
        [offerId, session.rideId, candidate.driverId, expiresAt, candidate.distanceKm]
      );

      // Set Redis ephemeral state
      await redisService.setDriverAvailability(candidate.driverId, "OFFER_PENDING", session.rideId);

      session.offeredDriverIds.add(candidate.driverId);
      session.pendingOfferDriverIds.add(candidate.driverId);
      offeredBatch.push(candidate);
    } catch (dbErr) {
      console.warn(`[DISPATCH DB WARN] Failed to insert offer for driver ${candidate.driverId}:`, dbErr.message);
    }
  }

  if (offeredBatch.length === 0) {
    session.currentTierIndex++;
    return _executeTier(session);
  }

  // 5. Send targeted offers ONLY to the selected drivers (Privacy Preserving: no user phone/PII)
  for (const candidate of offeredBatch) {
    const socketPayload = {
      offer_id: `off_${session.rideId}_${candidate.driverId}`,
      ride_id: session.rideId,
      vehicle_type: session.rideData.vehicle_type || "Auto",
      pickup_address: session.rideData.pickup_address || "Pickup Point",
      destination_address: session.rideData.destination_address || "Destination Point",
      distance_to_pickup: `${candidate.distanceKm} km away`,
      estimated_arrival_minutes: candidate.etaMinutes,
      trip_distance: session.rideData.distance_text || "8.4 km",
      fare: parseFloat(session.rideData.price || 135.0),
      expires_at: expiresAt.toISOString(),
      expires_in_seconds: tier.timeoutSeconds,
    };

    emitNewRideRequest([candidate.driverId], socketPayload);
  }

  // 6. Schedule batch timeout callback
  session.batchTimer = setTimeout(async () => {
    if (session.isCancelled || session.isAssigned) {
      activeDispatches.delete(session.rideId);
      return;
    }

    // Auto-expire pending offers in DB
    try {
      await query(
        `UPDATE ride_offers 
         SET status = 'EXPIRED', responded_at = (NOW() AT TIME ZONE 'UTC') 
         WHERE ride_id = $1 AND status = 'PENDING';`,
        [session.rideId]
      );

      await query(
        `UPDATE ride_requests 
         SET status = 'expired' 
         WHERE ride_id = $1 AND status = 'pending';`,
        [session.rideId]
      );
    } catch (_) {}

    // Emit offer_expired and release availability in Redis
    for (const driverId of session.pendingOfferDriverIds) {
      emitRideOfferExpired(driverId, {
        ride_id: session.rideId,
        reason: "Offer timed out",
      });
      await redisService.setDriverAvailability(driverId, "ONLINE_AVAILABLE", null);
    }

    session.pendingOfferDriverIds.clear();
    session.currentTierIndex++;
    _executeTier(session);
  }, tier.timeoutSeconds * 1000);
}

/**
 * Concurrency-Safe Atomic Acceptance via Coordinator
 * Uses Redis atomic lock (SET ride:lock:<id> driver:<id> NX EX 15) + PostgreSQL SELECT FOR UPDATE
 */
async function handleDriverAcceptance(rideId, driverId) {
  const { acquireRideLock, releaseRideLock } = require("../../services/driverLocationService");

  // 1. Acquire Redis atomic distributed lock (fast pre-validation barrier)
  const hasLock = await acquireRideLock(rideId, driverId, 15);
  if (!hasLock) {
    return {
      success: false,
      code: "RIDE_ALREADY_ACCEPTED",
      message: "Another driver has already accepted this booking.",
    };
  }

  // 2. Delegate authoritative database transaction with SELECT ... FOR UPDATE
  const result = await acceptRideOffer(rideId, driverId);

  if (!result.success) {
    // Release the Redis lock if Postgres validation rejected (e.g., driver already has an active trip)
    await releaseRideLock(rideId);
    return result;
  }

  if (result.success) {
    const session = activeDispatches.get(rideId);
    if (session) {
      session.isAssigned = true;
      if (session.batchTimer) {
        clearTimeout(session.batchTimer);
        session.batchTimer = null;
      }

      // Notify other pending drivers that this ride is taken
      for (const otherDriverId of session.pendingOfferDriverIds) {
        if (otherDriverId !== driverId) {
          emitRideOfferCancelled(otherDriverId, {
            ride_id: rideId,
            reason: "Ride accepted by another driver.",
          });
          redisService.setDriverAvailability(otherDriverId, "ONLINE_AVAILABLE", null).catch(() => {});
        }
      }

      activeDispatches.delete(rideId);
    }
  }

  return result;
}

/**
 * Handles Driver Rejection and Accelerates Next Batch If All Batch Drivers Reject
 */
async function handleDriverRejection(rideId, driverId) {
  try {
    await query(
      `UPDATE ride_offers 
       SET status = 'REJECTED', responded_at = (NOW() AT TIME ZONE 'UTC') 
       WHERE ride_id = $1 AND driver_id = $2;`,
      [rideId, driverId]
    );

    await query(
      `UPDATE ride_requests 
       SET status = 'rejected' 
       WHERE ride_id = $1 AND driver_id = $2;`,
      [rideId, driverId]
    );

    await redisService.setDriverAvailability(driverId, "ONLINE_AVAILABLE", null);
    emitRideOfferRejected(driverId, { ride_id: rideId, driver_id: driverId });
  } catch (err) {
    console.warn(`[REJECT WARN] Failed to update rejection:`, err.message);
  }

  const session = activeDispatches.get(rideId);
  if (session && !session.isAssigned && !session.isCancelled) {
    session.pendingOfferDriverIds.delete(driverId);

    // If all drivers in current batch rejected, advance immediately without waiting for timer!
    if (session.pendingOfferDriverIds.size === 0) {
      if (session.batchTimer) {
        clearTimeout(session.batchTimer);
        session.batchTimer = null;
      }
      session.currentTierIndex++;
      _executeTier(session);
    }
  }

  return { success: true, message: "Ride offer rejected." };
}

/**
 * Handles Customer Cancellation during active dispatch
 */
async function handleCustomerCancellation(rideId, reason = "Customer cancelled ride") {
  // 1. Always cancel pending offers in database (works across nodes/restarts)
  try {
    await query(
      `UPDATE ride_offers 
       SET status = 'CANCELLED', responded_at = (NOW() AT TIME ZONE 'UTC') 
       WHERE ride_id = $1 AND status = 'PENDING';`,
      [rideId]
    );

    await query(
      `UPDATE ride_requests 
       SET status = 'cancelled' 
       WHERE ride_id = $1 AND status = 'pending';`,
      [rideId]
    );
  } catch (dbErr) {
    console.warn(`[DISPATCH DB WARN] Failed to cancel ride offers for ${rideId}:`, dbErr.message);
  }

  // 2. Clear in-memory session timers and state if present
  const session = activeDispatches.get(rideId);
  if (session) {
    session.isCancelled = true;
    if (session.batchTimer) {
      clearTimeout(session.batchTimer);
      session.batchTimer = null;
    }

    // Emit cancellation to all offered drivers and release availability
    for (const driverId of session.pendingOfferDriverIds) {
      emitRideOfferCancelled(driverId, {
        ride_id: rideId,
        reason: reason || "Customer cancelled ride request.",
      });
      redisService.setDriverAvailability(driverId, "ONLINE_AVAILABLE", null).catch(() => {});
    }

    activeDispatches.delete(rideId);
  }

  return { success: true };
}

/**
 * Handles expiration when all tiers fail to produce an accepted ride
 */
async function _finalizeNoDriversFound(session) {
  try {
    await query(
      `UPDATE rides 
       SET status = 'no_drivers_found' 
       WHERE id = $1 AND status = 'requested';`,
      [session.rideId]
    );
  } catch (_) {}

  emitNoDriversFound(session.userId, {
    ride_id: session.rideId,
    status: "no_drivers_found",
    message: "No nearby drivers available. Please try again.",
  });

  activeDispatches.delete(session.rideId);
}

function getActiveDispatch(rideId) {
  return activeDispatches.get(rideId) || null;
}

module.exports = {
  startSequentialDispatch,
  handleDriverAcceptance,
  handleDriverRejection,
  handleCustomerCancellation,
  getActiveDispatch,
};
