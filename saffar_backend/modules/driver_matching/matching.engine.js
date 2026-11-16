const { v4: uuidv4 } = require("uuid");
const { pool, query } = require("../../database");
const redisService = require("../../services/redisService");
const settingsService = require("../../services/settingsService");
const { emitNewRideRequest, emitRideAccepted } = require("../../socket");

// Helper: Normalize category string
function normalizeCategory(type) {
  if (!type) return "Auto";
  const lower = type.toLowerCase();
  if (lower.includes("bike")) return "Bike";
  if (lower.includes("auto")) return "Auto";
  if (lower.includes("sedan")) return "Sedan";
  if (lower.includes("suv")) return "SUV";
  if (lower.includes("car") || lower.includes("mini")) return "Car";
  return type;
}

// Category urban speed constants in km/h
function getCategorySpeedKmh(category) {
  switch (category) {
    case "Bike": return 25.0;
    case "Auto": return 20.0;
    case "Car":  return 22.0;
    default:     return 20.0;
  }
}

// Estimate road distance and ETA with urban tortuosity (1.25x straight-line)
function calculateRoadEta(distanceKm, category = "Auto") {
  const roadDistanceKm = Math.round(distanceKm * 1.25 * 10) / 10;
  const speed = getCategorySpeedKmh(category);
  const etaMinutes = Math.max(1, Math.round((roadDistanceKm / speed) * 60));
  return { roadDistanceKm, etaMinutes };
}

/**
 * Searches and ranks nearby eligible drivers for a ride request across expansion rings
 */
async function findAndRankEligibleDrivers({
  pickupLat,
  pickupLon,
  vehicleType,
  searchRing = 1,
  customRadiusKm = null,
  excludeDriverIds = [],
  limit = null,
}) {
  const config = await settingsService.getMatchingConfig();
  const category = normalizeCategory(vehicleType);

  // Determine radius based on custom override or current ring
  let radiusKm = customRadiusKm || config.initialRadiusKm; // Ring 1 default: 2km
  let ringLabel = `ring_${searchRing}`;
  if (!customRadiusKm) {
    if (searchRing === 2) {
      radiusKm = config.secondRadiusKm; // Ring 2: 4km
      ringLabel = "ring_2";
    } else if (searchRing === 3) {
      radiusKm = config.thirdRadiusKm; // Ring 3: 6km
      ringLabel = "ring_3";
    } else if (searchRing >= 4) {
      radiusKm = config.maxRadiusKm; // Ring 4: 10km
      ringLabel = "ring_4";
    }
  }

  // 1. Fast Redis Proximity Query
  const nearbyFromRedis = await redisService.getNearbyDrivers(
    category,
    pickupLat,
    pickupLon,
    radiusKm,
    50
  );

  // 2. Hydrate & Enforce Strict Database Invariants
  const sql = `
    SELECT 
      d.id, d.name, d.phone, d.image_url, d.current_lat, d.current_lng,
      d.heading, d.speed, d.last_location_updated_at,
      COALESCE(d.verification_status, 'approved') as verification_status,
      COALESCE(da.state, 'OFFLINE') as availability_state,
      dv.category, dv.model as vehicle_model, dv.registration_number,
      COALESCE(dp.rating, 5.0) as rating,
      COALESCE(dp.acceptance_rate, 1.0) as acceptance_rate,
      COALESCE(dp.cancellation_rate, 0.0) as cancellation_rate
    FROM drivers d
    JOIN driver_vehicles dv ON d.id = dv.driver_id AND dv.is_active = true
    LEFT JOIN driver_availability da ON d.id = da.driver_id
    LEFT JOIN driver_profiles dp ON d.id = dp.driver_id
    WHERE (d.is_online = true OR da.state = 'ONLINE_AVAILABLE')
      AND COALESCE(da.state, 'ONLINE_AVAILABLE') NOT IN ('OFFLINE', 'ON_TRIP', 'TEMPORARILY_UNAVAILABLE')
      AND COALESCE(d.verification_status, 'approved') ILIKE 'approved'
      AND dv.verification_status ILIKE 'approved'
      AND (
        dv.category ILIKE $1 
        OR dv.category ILIKE $2 
        OR (dv.category ILIKE '%Car%' AND $2 IN ('Sedan', 'SUV', 'Car', 'Mini Car'))
        OR ($2 = 'Car' AND dv.category IN ('Sedan', 'SUV', 'Mini Car', 'Car'))
      )
      AND (d.last_location_updated_at IS NOT NULL AND d.last_location_updated_at >= NOW() - ($3 || ' seconds')::INTERVAL)
      AND NOT EXISTS (
        SELECT 1 FROM rides r 
        WHERE r.driver_id = d.id 
          AND r.cancelled = false 
          AND r.status IN ('accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started')
      );
  `;

  const dbRes = await query(sql, [`%${category}%`, category, config.staleTimeoutSeconds]);
  const eligibleMap = new Map();
  for (const driver of dbRes.rows) {
    if (!excludeDriverIds.includes(driver.id)) {
      eligibleMap.set(driver.id, driver);
    }
  }

  // 3. Compute Distance, ETA, and Multi-Factor Composite Score
  const candidates = [];
  const now = Date.now();

  for (const [driverId, driver] of eligibleMap.entries()) {
    let distanceKm = 1.0;
    if (driver.current_lat != null && driver.current_lng != null && pickupLat != null && pickupLon != null) {
      distanceKm = redisService.haversineDistanceKm(
        Number(pickupLat),
        Number(pickupLon),
        Number(driver.current_lat),
        Number(driver.current_lng)
      );
    } else {
      const redisMatch = nearbyFromRedis.find((r) => r.driverId === driverId);
      if (redisMatch) distanceKm = redisMatch.distanceKm;
      else continue; // No reliable coordinates available
    }

    if (distanceKm > radiusKm) continue;

    const { roadDistanceKm, etaMinutes } = calculateRoadEta(distanceKm, category);

    // Composite scoring formula
    const distanceScore = Math.max(0, 1 - (roadDistanceKm / radiusKm)); // 0.0 to 1.0
    const ratingScore = Math.min(1.0, driver.rating / 5.0); // 0.0 to 1.0
    const acceptanceScore = Math.min(1.0, driver.acceptance_rate); // 0.0 to 1.0
    const freshnessScore = driver.last_location_updated_at 
      ? Math.max(0, 1 - ((now - new Date(driver.last_location_updated_at).getTime()) / (config.staleTimeoutSeconds * 1000)))
      : 0.8;

    const compositeScore = Math.round(
      ((0.45 * distanceScore) + (0.25 * ratingScore) + (0.15 * acceptanceScore) + (0.15 * freshnessScore)) * 100
    ) / 100;

    candidates.push({
      driverId: driver.id,
      name: driver.name,
      phone: driver.phone,
      imageUrl: driver.image_url,
      vehicleCategory: category,
      vehicleModel: driver.vehicle_model,
      registrationNumber: driver.registration_number,
      rating: driver.rating,
      distanceKm: roadDistanceKm,
      etaMinutes,
      score: compositeScore,
      searchRing: ringLabel,
    });
  }

  // Rank by composite score descending, then ETA ascending
  candidates.sort((a, b) => b.score - a.score || a.etaMinutes - b.etaMinutes);
  const finalLimit = limit || config.maxCandidatesPerBatch;
  return candidates.slice(0, finalLimit);
}

/**
 * Dispatches ride offers to ranked candidates and tracks acceptance timeout
 */
async function dispatchRideOffers(rideId, candidates, options = {}) {
  const config = await settingsService.getMatchingConfig();
  const expirySeconds = config.offerExpirySeconds; // 15 seconds
  const expiresAt = new Date(Date.now() + expirySeconds * 1000);

  const offeredDriverIds = [];

  for (const candidate of candidates) {
    const offerId = `off_${uuidv4().slice(0, 8)}`;
    
    // Insert into ride_offers
    await query(`
      INSERT INTO ride_offers (
        id, ride_id, driver_id, batch_number, search_ring, 
        distance_km, eta_minutes, status, score, expires_at
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, 'PENDING', $8, $9)
      ON CONFLICT (ride_id, driver_id) DO UPDATE SET 
        status = 'PENDING',
        expires_at = EXCLUDED.expires_at;
    `, [
      offerId, rideId, candidate.driverId, options.batchNumber || 1, 
      candidate.searchRing || "ring_1", candidate.distanceKm, candidate.etaMinutes, 
      candidate.score, expiresAt
    ]);

    // Sync to legacy ride_requests table for existing test suite compatibility
    await query(`
      INSERT INTO ride_requests (id, ride_id, driver_id, status, expires_at, distance_to_pickup_km)
      VALUES ($1, $2, $3, 'pending', $4, $5)
      ON CONFLICT (ride_id, driver_id) DO UPDATE SET 
        status = 'pending', expires_at = EXCLUDED.expires_at;
    `, [offerId, rideId, candidate.driverId, expiresAt, candidate.distanceKm]);

    // Mark driver state OFFER_PENDING in Redis
    await redisService.setDriverAvailability(candidate.driverId, "OFFER_PENDING", rideId);
    offeredDriverIds.push(candidate.driverId);
  }

  // Broadcast WebSocket notification to drivers
  const socketPayload = {
    ride_id: rideId,
    vehicle_type: options.vehicleType || "Auto",
    pickup_address: options.pickupAddress || "Pickup Point",
    destination_address: options.destinationAddress || "Destination Point",
    estimated_fare: options.price || 135.0,
    expires_at: expiresAt.toISOString(),
    expires_in_seconds: expirySeconds,
  };

  emitNewRideRequest(offeredDriverIds, socketPayload);

  return {
    rideId,
    dispatchedCount: offeredDriverIds.length,
    expiresAt: expiresAt.toISOString(),
    candidates,
  };
}

/**
 * Concurrency-Safe Atomic Ride Offer Acceptance using PostgreSQL Transaction and Row Lock
 */
async function acceptRideOffer(rideId, driverId) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    // 1. Acquire exclusive row lock on the ride
    const rideRes = await client.query(
      `SELECT id, user_id, driver_id, status, price, otp 
       FROM rides 
       WHERE id = $1 
       FOR UPDATE;`,
      [rideId]
    );

    if (rideRes.rows.length === 0) {
      await client.query("ROLLBACK;");
      return { success: false, code: "RIDE_NOT_FOUND", message: "Ride booking does not exist." };
    }

    const ride = rideRes.rows[0];

    // 2. Check if already assigned
    if (ride.driver_id !== null || (ride.status !== "requested" && ride.status !== "offered")) {
      await client.query("ROLLBACK;");

      // Mark this driver's offer expired
      await query(
        `UPDATE ride_offers SET status = 'EXPIRED', responded_at = (NOW() AT TIME ZONE 'UTC') 
         WHERE ride_id = $1 AND driver_id = $2;`,
        [rideId, driverId]
      );
      await redisService.setDriverAvailability(driverId, "ONLINE_AVAILABLE", null);

      return {
        success: false,
        code: "RIDE_ALREADY_ACCEPTED",
        message: "Another driver has already accepted this booking.",
      };
    }

    // 2a. Check if the specific driver's offer or request has already expired
    const offerCheck = await client.query(
      `SELECT status, expires_at FROM ride_offers 
       WHERE ride_id = $1 AND driver_id = $2
       UNION ALL
       SELECT status, expires_at FROM ride_requests
       WHERE ride_id = $1 AND driver_id = $2
       LIMIT 1;`,
      [rideId, driverId]
    );

    if (offerCheck.rows.length > 0) {
      const offer = offerCheck.rows[0];
      const isExpired =
        (offer.expires_at && new Date(offer.expires_at).getTime() < Date.now()) ||
        (offer.status || "").toUpperCase() === "EXPIRED";
      if (isExpired) {
        await client.query("ROLLBACK;");
        return {
          success: false,
          code: "REQUEST_EXPIRED",
          message: "This ride offer has expired.",
        };
      }
    }

    // 2b. Ensure the driver has no conflicting active ride
    const activeDriverRide = await client.query(
      `SELECT id FROM rides 
       WHERE driver_id = $1 
         AND cancelled = false 
         AND status IN ('accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started') 
         AND id != $2 
       LIMIT 1;`,
      [driverId, rideId]
    );

    if (activeDriverRide.rows.length > 0) {
      await client.query("ROLLBACK;");
      return {
        success: false,
        code: "DRIVER_HAS_ACTIVE_RIDE",
        message: "Driver already has an active ongoing trip.",
      };
    }

    // 3. Bind driver to ride atomically
    await client.query(
      `UPDATE rides 
       SET driver_id = $1, status = 'accepted' 
       WHERE id = $2;`,
      [driverId, rideId]
    );

    // 4. Update ride_offers: accept current driver, expire competing candidates
    await client.query(
      `UPDATE ride_offers 
       SET status = 'ACCEPTED', responded_at = (NOW() AT TIME ZONE 'UTC') 
       WHERE ride_id = $1 AND driver_id = $2;`,
      [rideId, driverId]
    );

    await client.query(
      `UPDATE ride_offers 
       SET status = 'EXPIRED', responded_at = (NOW() AT TIME ZONE 'UTC') 
       WHERE ride_id = $1 AND driver_id != $2;`,
      [rideId, driverId]
    );

    // Sync legacy ride_requests
    await client.query(
      `UPDATE ride_requests SET status = 'accepted' WHERE ride_id = $1 AND driver_id = $2;`,
      [rideId, driverId]
    );
    await client.query(
      `UPDATE ride_requests SET status = 'expired' WHERE ride_id = $1 AND driver_id != $2;`,
      [rideId, driverId]
    );

    // 5. Update driver availability state to ON_TRIP
    await client.query(
      `INSERT INTO driver_availability (driver_id, state, current_ride_id, last_state_change, updated_at)
       VALUES ($1, 'ON_TRIP', $2, (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
       ON CONFLICT (driver_id) DO UPDATE SET 
         state = 'ON_TRIP', 
         current_ride_id = $2, 
         last_state_change = (NOW() AT TIME ZONE 'UTC');`,
      [driverId, rideId]
    );

    // 6. Record status history audit
    await client.query(
      `INSERT INTO ride_status_history (id, ride_id, old_status, new_status, triggered_by_role, triggered_by_id)
       VALUES ($1, $2, 'requested', 'accepted', 'driver', $3);`,
      [`hist_${uuidv4().slice(0, 8)}`, rideId, driverId]
    );

    await client.query("COMMIT;");

    // 7. Update Redis availability & locks
    await redisService.setDriverAvailability(driverId, "ON_TRIP", rideId);
    await redisService.releaseOfferLock(rideId);

    // 8. Fetch driver details for socket dispatch
    const dRes = await query(
      `SELECT d.id, d.name, d.phone, d.image_url, d.vehicle_name, d.vehicle_number,
              COALESCE(dp.rating, 4.9) as rating, COALESCE(dp.total_trips, 3240) as total_trips
       FROM drivers d
       LEFT JOIN driver_profiles dp ON d.id = dp.driver_id
       WHERE d.id = $1;`,
      [driverId]
    );
    const driver = dRes.rows[0];

    // Emit socket events: notify passenger that driver accepted, notify all drivers that ride is taken
    emitRideAccepted(rideId, ride.user_id, {
      ride_id: rideId,
      status: "accepted",
      otp: ride.otp,
      driver: {
        id: driver.id,
        name: driver.name,
        phone: driver.phone,
        imageUrl: driver.image_url,
        vehicleName: driver.vehicle_name,
        vehicleNumber: driver.vehicle_number,
        rating: driver.rating,
        totalTrips: driver.total_trips,
      },
    });

    return {
      success: true,
      rideId,
      driverId,
      status: "accepted",
      driver,
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

module.exports = {
  findAndRankEligibleDrivers,
  dispatchRideOffers,
  acceptRideOffer,
  calculateRoadEta,
  normalizeCategory,
};

