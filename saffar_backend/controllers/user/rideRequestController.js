require("../../config/polyfill");
const crypto = require("crypto");
const { v4: uuidv4 } = require("uuid");
const Err = require("../../config/error");
const { query } = require("../../database");
const {
  emitNewRideRequest,
  emitRideAccepted,
  emitRideCancelled,
  emitDriverReachingPickup,
  emitDriverArrived,
  emitTripStarted,
} = require("../../socket");

const OTP_SALT = process.env.OTP_SECRET || "saffar_otp_secure_salt_2026";

function computeOtpHash(otp, rideId) {
  return crypto.createHash("sha256").update(`${otp}:${rideId}:${OTP_SALT}`).digest("hex");
}

// Helper: Haversine distance in km
function calculateHaversineDistance(lat1, lon1, lat2, lon2) {
  const R = 6371; // Earth's radius in km
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
}

// Helper: Normalize category string
function normalizeCategory(type) {
  if (!type) return "Auto";
  const lower = type.toLowerCase();
  if (lower.includes("bike")) return "Bike";
  if (lower.includes("auto")) return "Auto";
  if (lower.includes("mini")) return "Mini Car";
  if (lower.includes("sedan") || lower.includes("prime")) return "Sedan";
  if (lower.includes("suv")) return "SUV";
  return type;
}

// Helper: Calculate average vehicle speed in km/h
function getCategorySpeedKmh(category) {
  const norm = normalizeCategory(category);
  switch (norm) {
    case "Bike": return 25;
    case "Auto": return 20;
    case "Mini Car": return 22;
    case "Sedan": return 22;
    case "SUV": return 20;
    default: return 20;
  }
}

// Helper: Calculate ETA in minutes
function calculateEtaMinutes(distanceKm, category = "Auto") {
  const speed = getCategorySpeedKmh(category);
  return Math.max(1, Math.round((distanceKm / speed) * 60));
}

// Find all eligible drivers for a ride with progressive radius expansion & candidate scoring
async function findEligibleDrivers({ pickupLat, pickupLon, vehicleType, maxRadiusKm = 15 }) {
  const category = normalizeCategory(vehicleType);

  const sql = `
    SELECT 
      d.id, d.name, d.phone, d.image_url, d.current_lat, d.current_lng,
      d.heading, d.speed, d.last_location_updated_at,
      d.active, COALESCE(d.is_online, d.active) as is_online,
      dv.category, dv.model as vehicle_model, dv.registration_number,
      COALESCE((SELECT AVG(rating) FROM ride_reviews WHERE driver_id = d.id), 4.9)::float as rating
    FROM drivers d
    JOIN driver_vehicles dv ON d.id = dv.driver_id AND dv.is_active = true
    WHERE (d.is_online = true OR d.active = true)
      AND COALESCE(d.verification_status, 'Approved') ILIKE 'approved'
      AND dv.verification_status ILIKE 'approved'
      AND (dv.category ILIKE $1 OR dv.category = $2)
      AND (d.last_location_updated_at IS NULL OR d.last_location_updated_at >= NOW() - INTERVAL '3 minutes')
      AND NOT EXISTS (
        SELECT 1 FROM rides r 
        WHERE r.driver_id = d.id 
          AND r.end_time IS NULL 
          AND r.cancelled = false 
          AND r.status IN ('requested', 'accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started')
      )
  `;

  const result = await query(sql, [`%${category}%`, category]);
  const allCandidates = [];

  for (const driver of result.rows) {
    let distance = 1.2; // default fallback if GPS is not yet acquired
    if (driver.current_lat && driver.current_lng && pickupLat && pickupLon) {
      distance = calculateHaversineDistance(
        pickupLat,
        pickupLon,
        driver.current_lat,
        driver.current_lng
      );
    }

    const etaMins = calculateEtaMinutes(distance, driver.category);
    const rating = parseFloat(driver.rating) || 4.9;
    // Composite Rank Score: lower is better (0.6 * ETA + 0.4 * (5.0 - rating))
    const rankScore = (etaMins * 0.6) + ((5.0 - rating) * 0.4);

    allCandidates.push({
      ...driver,
      distance_to_pickup_km: distance,
      eta_mins: etaMins,
      rating: rating,
      rank_score: Math.round(rankScore * 100) / 100,
    });
  }

  // Progressive radius expansion: try 3 km, then 6 km, then 10 km, then maxRadiusKm
  const expansionTiers = [3.0, 6.0, 10.0, maxRadiusKm].filter(
    (r, i, arr) => arr.indexOf(r) === i && r <= maxRadiusKm
  );

  let selectedDrivers = [];
  let appliedRadius = expansionTiers[0] || 3.0;

  for (const tier of expansionTiers) {
    const inTier = allCandidates.filter((d) => d.distance_to_pickup_km <= tier);
    if (inTier.length > 0) {
      selectedDrivers = inTier;
      appliedRadius = tier;
      break;
    }
  }

  // If none matched tiers but maxRadiusKm matches
  if (selectedDrivers.length === 0 && allCandidates.length > 0) {
    selectedDrivers = allCandidates.filter((d) => d.distance_to_pickup_km <= maxRadiusKm);
    appliedRadius = maxRadiusKm;
  }

  // Sort by composite ranking score (lowest/best first)
  selectedDrivers.sort((a, b) => a.rank_score - b.rank_score);
  return selectedDrivers;
}

// Dispatch ride to eligible drivers
async function dispatchRideToEligibleDrivers(rideId, rideData, pickupCoords) {
  try {
    const dispatchCoordinator = require("../../modules/driver_matching/dispatch.coordinator");
    const session = await dispatchCoordinator.startSequentialDispatch(rideId, rideData, pickupCoords);
    return session ? [session] : [];
  } catch (err) {
    console.error("Error dispatching ride to drivers:", err);
    return [];
  }
}

// GET /api/driver/rides/pending_requests
const getPendingRequestsForDriver = async (req, res) => {
  try {
    const driverId = req.user.id;

    // First auto-expire old requests in DB
    await query(
      `UPDATE ride_requests SET status = 'expired' 
       WHERE expires_at < NOW() AND status = 'pending'`
    );

    const requestsRes = await query(
      `SELECT 
         rr.id as request_id, rr.ride_id, rr.status as request_status,
         rr.expires_at, rr.distance_to_pickup_km,
         r.price, r.vehicle_type, r.otp, r.status as ride_status,
         u.id as user_id, u.name as passenger_name, u.phone as passenger_phone, u.image_url as passenger_image,
         sa.place as pickup_place, sa.street as pickup_street, sa.lat as pickup_lat, sa.lon as pickup_lon,
         da.place as destination_place, da.street as destination_street, da.lat as destination_lat, da.lon as destination_lon
       FROM ride_requests rr
       JOIN rides r ON rr.ride_id = r.id
       JOIN users u ON r.user_id = u.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE rr.driver_id = $1 
         AND rr.status = 'pending' 
         AND r.status = 'requested'
         AND rr.expires_at > NOW()
       ORDER BY rr.created_at DESC`,
      [driverId]
    );

    const formatted = requestsRes.rows.map((row) => {
      const secondsLeft = Math.max(0, Math.floor((new Date(row.expires_at) - new Date()) / 1000));
      return {
        request_id: row.request_id,
        ride_id: row.ride_id,
        passenger_name: row.passenger_name,
        passenger_phone: row.passenger_phone,
        passenger_image: row.passenger_image,
        pickup_address: [row.pickup_street, row.pickup_place].filter(Boolean).join(", "),
        destination_address: [row.destination_street, row.destination_place].filter(Boolean).join(", "),
        pickup_lat: row.pickup_lat,
        pickup_lon: row.pickup_lon,
        destination_lat: row.destination_lat,
        destination_lon: row.destination_lon,
        distance_to_pickup: `${row.distance_to_pickup_km ?? 1.2} km away`,
        estimated_distance: "8.4 km",
        fare: parseFloat(row.price),
        vehicle_type: row.vehicle_type,
        expires_at: row.expires_at,
        seconds_left: secondsLeft,
      };
    });

    return res.status(200).json({
      count: formatted.length,
      requests: formatted,
    });
  } catch (err) {
    console.error("Error in getPendingRequestsForDriver:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// POST /api/driver/rides/:rideId/accept
const acceptRideRequest = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    // 1. Verify driver is online & exists
    const driverCheck = await query(
      `SELECT d.id, d.name, d.phone, d.image_url, d.active, COALESCE(d.is_online, d.active) as is_online,
              dv.category, dv.model as vehicle_model, dv.registration_number
       FROM drivers d
       LEFT JOIN driver_vehicles dv ON d.id = dv.driver_id AND dv.is_active = true
       WHERE d.id = $1`,
      [driverId]
    );

    if (driverCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "Driver not found." },
      });
    }

    const driver = driverCheck.rows[0];
    if (!driver.is_online) {
      return res.status(400).json({
        error: { code: "DRIVER_OFFLINE", message: "You must be online to accept rides." },
      });
    }

    // Delegate atomic row-lock acceptance to Dispatch Coordinator
    const dispatchCoordinator = require("../../modules/driver_matching/dispatch.coordinator");
    const acceptResult = await dispatchCoordinator.handleDriverAcceptance(rideId, driverId);

    if (!acceptResult.success) {
      const statusCode = acceptResult.code === "RIDE_NOT_FOUND" ? 404 :
                         acceptResult.code === "RIDE_ALREADY_ACCEPTED" ? 409 : 400;
      return res.status(statusCode).json({
        error: {
          code: acceptResult.code || "ACCEPT_FAILED",
          message: acceptResult.message || "Could not accept ride.",
        },
      });
    }

    // Fetch full ride, passenger, and address info for client response
    const fullInfo = await query(
      `SELECT 
         r.id, r.user_id, r.driver_id, r.price, r.discount_price, r.otp, r.vehicle_type, r.status,
         u.name as passenger_name, u.phone as passenger_phone, u.image_url as passenger_image,
         sa.place as pickup_place, sa.street as pickup_street, sa.lat as pickup_lat, sa.lon as pickup_lon,
         da.place as destination_place, da.street as destination_street, da.lat as destination_lat, da.lon as destination_lon
       FROM rides r
       JOIN users u ON r.user_id = u.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE r.id = $1`,
      [rideId]
    );

    const rideDetail = fullInfo.rows[0];

    return res.status(200).json({
      message: "Ride accepted successfully!",
      ride: {
        id: rideDetail.id,
        driver_id: rideDetail.driver_id,
        status: rideDetail.status,
        price: parseFloat(rideDetail.price),
        pickup_address: [rideDetail.pickup_street, rideDetail.pickup_place].filter(Boolean).join(", "),
        destination_address: [rideDetail.destination_street, rideDetail.destination_place].filter(Boolean).join(", "),
        pickup_lat: rideDetail.pickup_lat,
        pickup_lon: rideDetail.pickup_lon,
        destination_lat: rideDetail.destination_lat,
        destination_lon: rideDetail.destination_lon,
        passenger: {
          id: rideDetail.user_id,
          name: rideDetail.passenger_name,
          phone: rideDetail.passenger_phone,
          image_url: rideDetail.passenger_image,
        },
      },
    });
  } catch (err) {
    console.error("Error in acceptRideRequest:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// POST /api/driver/rides/:rideId/reject
const rejectRideRequest = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    const dispatchCoordinator = require("../../modules/driver_matching/dispatch.coordinator");
    const result = await dispatchCoordinator.handleDriverRejection(rideId, driverId);

    return res.status(200).json({
      message: "Ride request rejected.",
      ride_id: rideId,
      driver_id: driverId,
    });
  } catch (err) {
    console.error("Error in rejectRideRequest:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// GET /api/driver/rides/:rideId/assigned
const getAssignedBookingDetails = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    const rideRes = await query(
      `SELECT 
         r.id, r.user_id, r.driver_id, r.price, r.discount_price, r.otp, r.vehicle_type, r.status,
         r.arrived_at, r.reaching_pickup_at, r.created_at,
         u.id as passenger_id, u.name as passenger_name, u.phone as passenger_phone, u.image_url as passenger_image,
         sa.id as source_address_id, sa.place as pickup_place, sa.street as pickup_street, sa.lat as pickup_lat, sa.lon as pickup_lon,
         da.id as destination_address_id, da.place as destination_place, da.street as destination_street, da.lat as destination_lat, da.lon as destination_lon,
         d.name as driver_name, d.phone as driver_phone, d.current_lat as driver_lat, d.current_lng as driver_lng, d.last_location_updated_at
       FROM rides r
       LEFT JOIN users u ON r.user_id = u.id
       LEFT JOIN drivers d ON r.driver_id = d.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE r.id = $1`,
      [rideId]
    );

    if (rideRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride booking not found." },
      });
    }

    const row = rideRes.rows[0];

    // Validate driver ownership
    if (row.driver_id !== driverId) {
      return res.status(403).json({
        error: {
          code: "UNAUTHORIZED_DRIVER",
          message: "You are not authorized to view this booking. It is assigned to another driver.",
        },
      });
    }

    // Distance and ETA calculation
    let distanceKm = 1.2;
    let etaMinutes = 4;
    if (row.driver_lat && row.driver_lng && row.pickup_lat && row.pickup_lon) {
      distanceKm = calculateHaversineDistance(
        row.driver_lat,
        row.driver_lng,
        row.pickup_lat,
        row.pickup_lon
      );
      etaMinutes = Math.max(1, Math.round(distanceKm / 0.4));
    }

    const pickupAddress = [row.pickup_street, row.pickup_place].filter(Boolean).join(", ");
    const destinationAddress = [row.destination_street, row.destination_place].filter(Boolean).join(", ");

    return res.status(200).json({
      ride: {
        id: row.id,
        status: row.status,
        price: parseFloat(row.price),
        discount_price: row.discount_price ? parseFloat(row.discount_price) : null,
        vehicle_type: row.vehicle_type,
        arrived_at: row.arrived_at,
        reaching_pickup_at: row.reaching_pickup_at,
        distance_to_pickup_km: distanceKm,
        eta_minutes: etaMinutes,
        passenger: {
          id: row.passenger_id,
          name: row.passenger_name || "Passenger",
          phone: row.passenger_phone || "",
          image_url: row.passenger_image || "",
          rating: 4.9,
        },
        pickup: {
          address: pickupAddress,
          place: row.pickup_place,
          street: row.pickup_street,
          lat: row.pickup_lat,
          lon: row.pickup_lon,
        },
        destination: {
          address: destinationAddress,
          place: row.destination_place,
          street: row.destination_street,
          lat: row.destination_lat,
          lon: row.destination_lon,
        },
        driver_location: {
          lat: row.driver_lat,
          lng: row.driver_lng,
          last_updated: row.last_location_updated_at,
        },
      },
    });
  } catch (err) {
    console.error("Error in getAssignedBookingDetails:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// POST /api/driver/rides/:rideId/reaching
const markReachingPickup = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    // 1. Check current ride status and ownership
    const currentCheck = await query(
      `SELECT r.*, u.id as user_id, u.name as passenger_name, u.phone as passenger_phone
       FROM rides r
       JOIN users u ON r.user_id = u.id
       WHERE r.id = $1`,
      [rideId]
    );

    if (currentCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride booking not found." },
      });
    }

    const currentRide = currentCheck.rows[0];

    if (currentRide.driver_id !== driverId) {
      return res.status(403).json({
        error: {
          code: "UNAUTHORIZED_DRIVER",
          message: "You are not assigned to this ride booking.",
        },
      });
    }

    if (currentRide.cancelled) {
      return res.status(400).json({
        error: { code: "RIDE_CANCELLED", message: "This ride has been cancelled." },
      });
    }

    if (["arrived", "started", "in_progress", "completed"].includes(currentRide.status)) {
      return res.status(200).json({
        message: "Ride is already beyond reaching pickup.",
        status: currentRide.status,
      });
    }

    // 2. Update status to 'reaching_pickup'
    const updateRes = await query(
      `UPDATE rides 
       SET status = 'reaching_pickup', reaching_pickup_at = COALESCE(reaching_pickup_at, NOW())
       WHERE id = $1 AND driver_id = $2
       RETURNING *`,
      [rideId, driverId]
    );

    const updated = updateRes.rows[0];

    // 3. Socket broadcast to User and Ride room
    emitDriverReachingPickup(rideId, currentRide.user_id, {
      ride_id: rideId,
      driver_id: driverId,
      status: "reaching_pickup",
      reaching_pickup_at: updated.reaching_pickup_at,
    });

    return res.status(200).json({
      message: "Status updated to reaching pickup.",
      status: "reaching_pickup",
      reaching_pickup_at: updated.reaching_pickup_at,
    });
  } catch (err) {
    console.error("Error in markReachingPickup:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// POST /api/driver/rides/:rideId/arrive
const markDriverArrived = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    // 1. Check current ride status and ownership
    const currentCheck = await query(
      `SELECT r.*, u.id as user_id, u.name as passenger_name, u.phone as passenger_phone
       FROM rides r
       JOIN users u ON r.user_id = u.id
       WHERE r.id = $1`,
      [rideId]
    );

    if (currentCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride booking not found." },
      });
    }

    const currentRide = currentCheck.rows[0];

    if (currentRide.driver_id !== driverId) {
      return res.status(403).json({
        error: {
          code: "UNAUTHORIZED_DRIVER",
          message: "You are not assigned to this ride booking.",
        },
      });
    }

    if (currentRide.cancelled) {
      return res.status(400).json({
        error: { code: "RIDE_CANCELLED", message: "This ride has been cancelled." },
      });
    }

    // 2. Concurrency-safe atomic arrival update
    const updateRes = await query(
      `UPDATE rides 
       SET status = 'arrived', arrived_at = COALESCE(arrived_at, NOW())
       WHERE id = $1 AND driver_id = $2
       RETURNING *`,
      [rideId, driverId]
    );

    const updated = updateRes.rows[0];

    // 3. Socket broadcast to User and Ride room
    emitDriverArrived(rideId, currentRide.user_id, {
      ride_id: rideId,
      driver_id: driverId,
      status: "arrived",
      arrived_at: updated.arrived_at,
      otp: updated.otp,
    });

    return res.status(200).json({
      message: "Driver arrived at pickup location.",
      status: "arrived",
      arrived_at: updated.arrived_at,
    });
  } catch (err) {
    console.error("Error in markDriverArrived:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// POST /api/driver/rides/:rideId/verify_otp_start
const verifyRideStartOtp = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;
    const { otp } = req.body;

    if (!rideId || !otp) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "Both rideId and OTP are required.",
        },
      });
    }

    const trimmedOtp = otp.toString().trim();

    // 1. Fetch current ride status and OTP info
    const rideRes = await query(
      `SELECT id, user_id, driver_id, otp, otp_hash, otp_expires_at, 
              otp_attempts, max_otp_attempts, otp_verified, status, cancelled
       FROM rides
       WHERE id = $1`,
      [rideId]
    );

    if (rideRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride booking not found." },
      });
    }

    const ride = rideRes.rows[0];

    // 2. Validate assigned driver and booking ownership
    if (!ride.driver_id || ride.driver_id !== driverId) {
      return res.status(403).json({
        error: {
          code: "UNAUTHORIZED_DRIVER",
          message: "You are not the assigned driver for this ride booking.",
        },
      });
    }

    // 3. Prevent starting an already cancelled trip
    if (ride.cancelled) {
      return res.status(400).json({
        error: { code: "RIDE_CANCELLED", message: "This booking has been cancelled." },
      });
    }

    // 4. Prevent starting an already completed trip
    if (ride.status === "completed") {
      return res.status(400).json({
        error: { code: "TRIP_ALREADY_COMPLETED", message: "This trip has already ended." },
      });
    }

    // 5. Prevent repeated OTP usage / already started trip
    if (ride.otp_verified || ["started", "in_progress"].includes(ride.status)) {
      return res.status(400).json({
        error: {
          code: "TRIP_ALREADY_STARTED",
          message: "This trip has already been started. OTP cannot be reused.",
        },
      });
    }

    // 6. Check attempt limit
    const currentAttempts = ride.otp_attempts || 0;
    const maxAttempts = ride.max_otp_attempts || 5;

    if (currentAttempts >= maxAttempts) {
      return res.status(429).json({
        error: {
          code: "OTP_MAX_ATTEMPTS_EXCEEDED",
          message: "Maximum OTP verification attempts exceeded. Ride locked for security.",
        },
      });
    }

    // 7. Check OTP expiration
    if (ride.otp_expires_at && new Date() > new Date(ride.otp_expires_at)) {
      return res.status(400).json({
        error: {
          code: "OTP_EXPIRED",
          message: "Passenger OTP has expired. Please ask passenger to refresh OTP.",
        },
      });
    }

    // 8. Secure verification
    const expectedHash = ride.otp_hash;
    const candidateHash = computeOtpHash(trimmedOtp, rideId);

    let isValid = false;
    if (expectedHash) {
      isValid = (candidateHash === expectedHash);
    } else if (ride.otp) {
      isValid = (trimmedOtp === ride.otp.trim());
    }

    if (!isValid) {
      const newAttempts = currentAttempts + 1;
      await query(
        `UPDATE rides SET otp_attempts = $1 WHERE id = $2`,
        [newAttempts, rideId]
      );

      const remainingAttempts = Math.max(0, maxAttempts - newAttempts);
      return res.status(400).json({
        error: {
          code: "INVALID_OTP",
          message: remainingAttempts > 0 
            ? `Invalid OTP. You have ${remainingAttempts} attempts remaining.`
            : "Invalid OTP. Maximum attempts reached. Ride locked.",
          remaining_attempts: remainingAttempts,
        },
      });
    }

    // 9. Concurrency-Safe Conditional Single-Use Start Trip Update:
    const updateRes = await query(
      `UPDATE rides 
       SET status = 'started',
           otp_verified = true,
           trip_started_at = NOW(),
           start_time = COALESCE(trip_started_at, NOW())
       WHERE id = $1 AND driver_id = $2 AND otp_verified = false AND status != 'started'
       RETURNING *`,
      [rideId, driverId]
    );

    if (updateRes.rows.length === 0) {
      return res.status(409).json({
        error: {
          code: "CONCURRENT_CONFLICT",
          message: "Trip has already been started or verification conflict.",
        },
      });
    }

    const updatedRide = updateRes.rows[0];

    // 10. Real-time Notification via Socket.IO
    emitTripStarted(rideId, ride.user_id, {
      ride_id: rideId,
      driver_id: driverId,
      status: "started",
      trip_started_at: updatedRide.trip_started_at,
    });

    return res.status(200).json({
      message: "OTP verified successfully. Trip started!",
      status: "started",
      trip_started_at: updatedRide.trip_started_at,
      ride_id: rideId,
    });
  } catch (err) {
    console.error("Error in verifyRideStartOtp:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

module.exports = {
  findEligibleDrivers,
  dispatchRideToEligibleDrivers,
  getPendingRequestsForDriver,
  acceptRideRequest,
  rejectRideRequest,
  getAssignedBookingDetails,
  markReachingPickup,
  markDriverArrived,
  verifyRideStartOtp,
  calculateHaversineDistance,
  normalizeCategory,
  calculateEtaMinutes,
  getCategorySpeedKmh,
};

