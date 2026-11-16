require("../../config/polyfill");
const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");
const Err = require("../../config/error");
const { query } = require("../../database");
const { emitDriverLocationUpdate, emitTripCompleted, emitRideCancelled } = require("../../socket");

// Helper to save base64 avatar to disk
function saveBase64Avatar(base64Data, driverId, req) {
  if (!base64Data || typeof base64Data !== "string" || !base64Data.startsWith("data:image")) {
    return base64Data;
  }
  try {
    const matches = base64Data.match(/^data:image\/([a-zA-Z0-9]+);base64,(.+)$/);
    if (!matches) return base64Data;
    const ext = matches[1] === "jpeg" ? "jpg" : matches[1];
    const buffer = Buffer.from(matches[2], "base64");
    const uploadsDir = path.join(__dirname, "../uploads/avatars");
    if (!fs.existsSync(uploadsDir)) {
      fs.mkdirSync(uploadsDir, { recursive: true });
    }
    const filename = `driver_avatar_${driverId}_${Date.now()}.${ext}`;
    const filePath = path.join(uploadsDir, filename);
    fs.writeFileSync(filePath, buffer);

    const host = req.get("host") || "localhost:5000";
    const protocol = req.protocol || "http";
    return `${protocol}://${host}/uploads/avatars/${filename}`;
  } catch (err) {
    console.error("Error saving base64 driver avatar:", err);
    return base64Data;
  }
}

// GET driver profile by token
const getDriverProfile = async (req, res) => {
  try {
    const driverId = req.user.id;
    const driverRes = await query(
      `SELECT id, name, phone, email, age, gender, address, 
              vehicle_name, vehicle_model, vehicle_number, image_url, active, 
              COALESCE(is_online, active) as is_online,
              current_lat, current_lng, heading, speed, last_location_updated_at,
              COALESCE(verification_status, 'pending') as verification_status, created_at 
       FROM drivers WHERE id = $1`,
      [driverId]
    );
    if (driverRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "No driver found with this ID." },
      });
    }
    return res.status(200).json({ driver: driverRes.rows[0] });
  } catch (error) {
    console.log(`Error in getDriverProfile: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// PATCH update driver profile
const updateDriverProfile = async (req, res) => {
  try {
    const driverId = req.user.id;
    const {
      name,
      email,
      phone,
      age,
      gender,
      address,
      vehicle_name,
      vehicle_model,
      model,
      vehicle_number,
      image_url,
    } = req.body;
    
    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (name !== undefined) {
      fields.push(`name = $${paramIndex++}`);
      values.push(name.trim());
    }
    if (email !== undefined) {
      fields.push(`email = $${paramIndex++}`);
      values.push(email && typeof email === "string" && email.trim().length > 0 ? email.trim() : null);
    }
    if (phone !== undefined) {
      const cleanPhone = phone.trim();
      const existing = await query("SELECT id FROM drivers WHERE phone = $1 AND id != $2", [cleanPhone, driverId]);
      if (existing.rows.length > 0) {
        return res.status(409).json({
          error: { code: Err.code.PHONE_ALREADY_EXISTS, message: "Phone number is already registered by another driver." },
        });
      }
      fields.push(`phone = $${paramIndex++}`);
      values.push(cleanPhone);
    }
    if (age !== undefined) {
      fields.push(`age = $${paramIndex++}`);
      const parsedAge = age !== null && age !== "" ? parseInt(age, 10) : null;
      values.push(isNaN(parsedAge) ? null : parsedAge);
    }
    if (gender !== undefined) {
      fields.push(`gender = $${paramIndex++}`);
      values.push(gender && typeof gender === "string" && gender.trim().length > 0 ? gender.trim() : null);
    }
    if (address !== undefined) {
      fields.push(`address = $${paramIndex++}`);
      values.push(address && typeof address === "string" && address.trim().length > 0 ? address.trim() : null);
    }
    if (vehicle_name !== undefined) {
      fields.push(`vehicle_name = $${paramIndex++}`);
      values.push(vehicle_name.trim());
    }
    const resolvedModel = vehicle_model !== undefined ? vehicle_model : model;
    if (resolvedModel !== undefined) {
      fields.push(`vehicle_model = $${paramIndex++}`);
      values.push(resolvedModel && typeof resolvedModel === "string" && resolvedModel.trim().length > 0 ? resolvedModel.trim() : null);
    }
    if (vehicle_number !== undefined) {
      fields.push(`vehicle_number = $${paramIndex++}`);
      values.push(vehicle_number.trim());
    }
    if (image_url !== undefined) {
      const savedImageUrl = saveBase64Avatar(image_url, driverId, req);
      fields.push(`image_url = $${paramIndex++}`);
      values.push(savedImageUrl);
    }

    if (fields.length === 0) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "No fields to update." },
      });
    }

    values.push(driverId);
    const result = await query(
      `UPDATE drivers 
       SET ${fields.join(", ")} 
       WHERE id = $${paramIndex} 
       RETURNING id, name, phone, email, age, gender, address, vehicle_name, vehicle_model, vehicle_number, image_url, active, COALESCE(verification_status, 'Approved') as verification_status, created_at`,
      values
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "No driver found with this ID." },
      });
    }

    return res.status(200).json({ message: "Profile updated successfully.", driver: result.rows[0] });
  } catch (error) {
    console.log(`Error in updateDriverProfile: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// POST upload driver profile photo
const uploadDriverPhoto = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { image_url, photo } = req.body;
    const rawPhoto = image_url || photo;

    if (!rawPhoto) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "No photo data provided." },
      });
    }

    const finalUrl = saveBase64Avatar(rawPhoto, driverId, req);

    const result = await query(
      `UPDATE drivers SET image_url = $1 WHERE id = $2 
       RETURNING id, name, phone, email, age, gender, address, vehicle_name, vehicle_model, vehicle_number, image_url, active, COALESCE(verification_status, 'Approved') as verification_status`,
      [finalUrl, driverId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "Driver not found." },
      });
    }

    return res.status(200).json({
      message: "Driver profile photo updated successfully.",
      image_url: finalUrl,
      driver: result.rows[0],
    });
  } catch (error) {
    console.error(`Error in uploadDriverPhoto: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || "Failed to upload photo." },
    });
  }
};

// POST toggle driver availability (online/offline)
const toggleAvailability = async (req, res) => {
  try {
    const driverId = req.user.id;
    let isOnline = req.body.is_online !== undefined ? req.body.is_online : req.body.active;

    if (isOnline === undefined) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing 'active' or 'is_online' field." },
      });
    }

    isOnline = Boolean(isOnline);

    // 1. Check driver account verification status
    const driverCheck = await query(
      "SELECT id, active, verification_status FROM drivers WHERE id = $1",
      [driverId]
    );
    if (driverCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "No driver found with this ID." },
      });
    }
    const driverRow = driverCheck.rows[0];

    // If going ONLINE:
    if (isOnline) {
      // Verify driver account verification status - Super Admin approval required
      const driverStatus = (driverRow.verification_status || "pending").toLowerCase();
      if (driverStatus !== "approved") {
        return res.status(403).json({
          error: {
            code: "DRIVER_ACCOUNT_PENDING_APPROVAL",
            message: `Cannot go online. Your driver account is ${driverRow.verification_status || "Pending Approval"} by Super Admin. You will be able to go online once approved.`,
          },
        });
      }

      if (!driverRow.active) {
        return res.status(403).json({
          error: {
            code: "DRIVER_ACCOUNT_INACTIVE",
            message: "Cannot go online. Your driver account is currently inactive or suspended by Super Admin.",
          },
        });
      }

      // Verify vehicle and document eligibility
      // Driver must have an active vehicle that is 'approved'
      const vehicleCheck = await query(
        `SELECT id, model, registration_number, category, verification_status 
         FROM driver_vehicles 
         WHERE driver_id = $1 AND is_active = true`,
        [driverId]
      );

      if (vehicleCheck.rows.length === 0) {
        return res.status(400).json({
          error: {
            code: "NO_ACTIVE_VEHICLE",
            message: "Cannot go online: No active vehicle found. Please add or select an active vehicle in Vehicle Management.",
          },
        });
      }

      const activeVehicle = vehicleCheck.rows[0];
      const vehStatus = (activeVehicle.verification_status || "").toLowerCase();
      if (vehStatus !== "approved") {
        return res.status(400).json({
          error: {
            code: "VEHICLE_NOT_VERIFIED",
            message: `Cannot go online: Your active vehicle (${activeVehicle.model} - ${activeVehicle.registration_number}) has ${activeVehicle.verification_status} verification status. Only approved vehicles can receive ride bookings.`,
          },
        });
      }
    } else {
      // If going OFFLINE:
      // Verify no active trips (rides with end_time IS NULL and not cancelled and status in active trip states)
      const activeRides = await query(
        `SELECT id, status FROM rides 
         WHERE driver_id = $1 AND end_time IS NULL AND cancelled = false 
           AND (status IS NULL OR status IN ('requested', 'accepted', 'arrived', 'in_progress', 'started'))`,
        [driverId]
      );
      if (activeRides.rows.length > 0) {
        return res.status(400).json({
          error: {
            code: "ACTIVE_RIDE_EXISTS",
            message: "Cannot go offline while you have an active ride in progress. Please complete or cancel your trip first.",
          },
        });
      }
    }

    // Optional initial location passed in body
    const { latitude, longitude, heading, speed } = req.body;
    let locUpdateSql = "";
    const params = [isOnline, isOnline, driverId];
    if (latitude !== undefined && longitude !== undefined) {
      params.push(parseFloat(latitude), parseFloat(longitude));
      locUpdateSql = `, current_lat = $4, current_lng = $5, last_location_updated_at = NOW()`;
      if (heading !== undefined) {
        params.push(parseFloat(heading));
        locUpdateSql += `, heading = $${params.length}`;
      }
      if (speed !== undefined) {
        params.push(parseFloat(speed));
        locUpdateSql += `, speed = $${params.length}`;
      }
    }

    const result = await query(
      `UPDATE drivers 
       SET active = $1, is_online = $2 ${locUpdateSql} 
       WHERE id = $3 
       RETURNING id, name, phone, email, vehicle_name, vehicle_model, vehicle_number, 
                 image_url, active, is_online, current_lat, current_lng, heading, speed, 
                 last_location_updated_at, COALESCE(verification_status, 'Approved') as verification_status`,
      params
    );

    // Sync normalized driver_availability state
    try {
      const targetState = isOnline ? "ONLINE_AVAILABLE" : "OFFLINE";
      await query(
        `INSERT INTO driver_availability (driver_id, state, last_state_change, updated_at)
         VALUES ($1, $2, (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
         ON CONFLICT (driver_id) DO UPDATE SET 
           state = EXCLUDED.state,
           last_state_change = (NOW() AT TIME ZONE 'UTC'),
           updated_at = (NOW() AT TIME ZONE 'UTC');`,
        [driverId, targetState]
      );
    } catch (availErr) {
      console.warn("Driver availability state update warning:", availErr.message);
    }

    // Sync Redis status & GEO index
    try {
      const { setDriverOnline, setDriverOffline } = require("../../services/driverLocationService");
      if (isOnline) {
        await setDriverOnline(driverId, {
          latitude: latitude !== undefined ? parseFloat(latitude) : undefined,
          longitude: longitude !== undefined ? parseFloat(longitude) : undefined,
          heading: heading !== undefined ? parseFloat(heading) : 0,
          speed: speed !== undefined ? parseFloat(speed) : 0,
        });
      } else {
        await setDriverOffline(driverId);
      }
    } catch (redisErr) {
      console.warn("[REDIS AVAILABILITY SYNC ERROR]", redisErr.message);
    }

    return res.status(200).json({
      message: isOnline ? "Driver is now online and available for rides." : "Driver is now offline.",
      driver: result.rows[0],
    });
  } catch (error) {
    console.log(`Error in toggleAvailability: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// POST update driver live location
const updateDriverLocation = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { latitude, longitude, heading = 0.0, speed = 0.0, timestamp } = req.body;

    if (latitude === undefined || longitude === undefined) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing latitude or longitude." },
      });
    }

    const lat = parseFloat(latitude);
    const lng = parseFloat(longitude);

    if (isNaN(lat) || lat < -90 || lat > 90) {
      return res.status(400).json({
        error: { code: "INVALID_LATITUDE", message: "Latitude must be a valid number between -90 and 90." },
      });
    }
    if (isNaN(lng) || lng < -180 || lng > 180) {
      return res.status(400).json({
        error: { code: "INVALID_LONGITUDE", message: "Longitude must be a valid number between -180 and 180." },
      });
    }

    const head = parseFloat(heading) || 0.0;
    const spd = parseFloat(speed) || 0.0;
    const recordedAt = timestamp ? new Date(timestamp) : new Date();

    // Update driver's current position and timestamp
    const updateResult = await query(
      `UPDATE drivers 
       SET current_lat = $1, current_lng = $2, heading = $3, speed = $4, last_location_updated_at = $5 
       WHERE id = $6 
       RETURNING id, name, active, COALESCE(is_online, active) as is_online, current_lat, current_lng, heading, speed, last_location_updated_at`,
      [lat, lng, head, spd, recordedAt, driverId]
    );

    if (updateResult.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "Driver not found." },
      });
    }

    // Insert into driver_location_logs
    const logId = `loc_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`;
    await query(
      `INSERT INTO driver_location_logs (id, driver_id, latitude, longitude, heading, speed, recorded_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [logId, driverId, lat, lng, head, spd, recordedAt]
    );

    // Sync live location in Redis (GEO index, location hash, last_seen)
    try {
      const { updateDriverLocation: updateRedisLocation } = require("../../services/driverLocationService");
      await updateRedisLocation({
        driverId,
        latitude: lat,
        longitude: lng,
        heading: head,
        speed: spd,
      });
    } catch (redisLocErr) {
      console.warn("[REDIS LIVE LOCATION SYNC ERROR]", redisLocErr.message);
    }

    // Broadcast live driver location to User Panel if driver is currently on an active trip
    try {
      const activeRideRes = await query(
        `SELECT id, user_id FROM rides 
         WHERE driver_id = $1 AND end_time IS NULL AND cancelled = false 
           AND status IN ('accepted', 'reaching_pickup', 'arrived', 'started', 'in_progress')
         LIMIT 1`,
        [driverId]
      );

      if (activeRideRes.rows.length > 0) {
        const activeRide = activeRideRes.rows[0];
        emitDriverLocationUpdate(activeRide.id, activeRide.user_id, {
          driver_id: driverId,
          ride_id: activeRide.id,
          latitude: lat,
          longitude: lng,
          heading: head,
          speed: spd,
          timestamp: recordedAt.toISOString(),
        });
      }
    } catch (locBroadcastErr) {
      console.warn("Could not broadcast active trip location update:", locBroadcastErr.message);
    }

    return res.status(200).json({
      message: "Location updated successfully.",
      location: {
        latitude: lat,
        longitude: lng,
        heading: head,
        speed: spd,
        timestamp: recordedAt.toISOString(),
      },
      driver: updateResult.rows[0],
    });
  } catch (error) {
    console.error(`Error in updateDriverLocation: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET driver current availability and live location status
const getDriverStatus = async (req, res) => {
  try {
    const driverId = req.user.id;
    const driverRes = await query(
      `SELECT id, name, active, COALESCE(is_online, active) as is_online, 
              current_lat, current_lng, heading, speed, last_location_updated_at,
              COALESCE(verification_status, 'pending') as verification_status
       FROM drivers WHERE id = $1`,
      [driverId]
    );
    if (driverRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "Driver not found." },
      });
    }

    // Check active trip
    const activeRideRes = await query(
      `SELECT r.id, r.user_id, r.price, r.status, r.start_time,
              sa.place as pickup_place, sa.street as pickup_street,
              da.place as destination_place, da.street as destination_street
       FROM rides r
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE r.driver_id = $1 AND r.end_time IS NULL AND r.cancelled = false
       LIMIT 1`,
      [driverId]
    );

    return res.status(200).json({
      driver: driverRes.rows[0],
      active_ride: activeRideRes.rows.length > 0 ? activeRideRes.rows[0] : null,
    });
  } catch (error) {
    console.error(`Error in getDriverStatus: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET driver ride history with category, date filtering, and accounting metrics
const getDriverRideHistory = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { page = 1, limit = 20, status, period, from_date, to_date } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let whereClause = "WHERE r.driver_id = $1";
    const params = [driverId];
    let paramIdx = 2;

    const normStatus = (status || "").toLowerCase().trim();

    if (normStatus === "assigned" || normStatus === "upcoming") {
      whereClause += ` AND r.cancelled = false AND r.end_time IS NULL AND (r.status IN ('accepted', 'reaching_pickup') OR r.status IS NULL)`;
    } else if (normStatus === "ongoing" || normStatus === "in_progress") {
      whereClause += ` AND r.cancelled = false AND r.end_time IS NULL AND r.status IN ('arrived', 'started', 'in_progress')`;
    } else if (normStatus === "completed") {
      whereClause += ` AND r.cancelled = false AND (r.end_time IS NOT NULL OR r.status = 'completed')`;
    } else if (normStatus === "cancelled") {
      whereClause += ` AND (r.cancelled = true OR r.status = 'cancelled')`;
    } else if (normStatus === "active") {
      whereClause += ` AND r.cancelled = false AND r.end_time IS NULL`;
    }

    // Date filtering
    if (period === "today" || period === "daily") {
      whereClause += ` AND r.start_time >= CURRENT_DATE`;
    } else if (period === "this_week" || period === "weekly") {
      whereClause += ` AND r.start_time >= DATE_TRUNC('week', CURRENT_DATE)`;
    } else if (period === "this_month" || period === "monthly") {
      whereClause += ` AND r.start_time >= DATE_TRUNC('month', CURRENT_DATE)`;
    } else if (from_date || to_date) {
      if (from_date) {
        whereClause += ` AND r.start_time >= $${paramIdx++}::timestamp`;
        params.push(new Date(from_date).toISOString());
      }
      if (to_date) {
        const endD = new Date(to_date);
        if (to_date.length <= 10) endD.setHours(23, 59, 59, 999);
        whereClause += ` AND r.start_time <= $${paramIdx++}::timestamp`;
        params.push(endD.toISOString());
      }
    }

    const limitIdx = paramIdx++;
    const offsetIdx = paramIdx++;
    params.push(parseInt(limit), offset);

    const ridesRes = await query(
      `SELECT 
        r.id, r.id as booking_id, r.user_id, r.driver_id, r.vehicle_type, r.status,
        r.cancelled, r.cancelled_by, r.cancellation_reason, r.cancellation_notes, r.cancelled_at,
        r.start_time, r.trip_started_at, r.arrived_at, r.reaching_pickup_at, r.end_time, r.created_at,
        r.price as original_price, r.discount_price,
        COALESCE(de.gross_fare, r.price) as gross_fare,
        COALESCE(de.commission_amount, ROUND((r.price * 0.15)::numeric, 2)) as platform_commission,
        COALESCE(de.commission_rate, 0.15) as commission_rate,
        COALESCE(de.other_deductions, 0.0) as other_deductions,
        COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2)) as net_earnings,
        COALESCE(de.distance_km, 0.0) as distance_km,
        COALESCE(de.duration_minutes, 0) as duration_minutes,
        COALESCE(de.payment_status, 'Paid') as payment_status,
        COALESCE(de.payment_method, r.payment_method, 'Paid via UPI') as payment_method,
        json_build_object('id', u.id, 'name', u.name, 'phone', u.phone, 'image_url', u.image_url) as passenger,
        json_build_object('id', sa.id, 'place', sa.place, 'street', sa.street, 'state', sa.state, 'lat', sa.lat, 'lon', sa.lon) as source_address,
        json_build_object('id', da.id, 'place', da.place, 'street', da.street, 'state', da.state, 'lat', da.lat, 'lon', da.lon) as destination_address
      FROM rides r
      LEFT JOIN driver_earnings de ON r.id = de.ride_id
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      ${whereClause}
      ORDER BY r.start_time DESC
      LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
      params
    );

    // Get total count
    const countParams = params.slice(0, limitIdx - 1);
    const countRes = await query(
      `SELECT COUNT(*) as total FROM rides r ${whereClause}`,
      countParams
    );

    // Get counts per category for tab badges
    const categoryCountsRes = await query(
      `SELECT 
         COUNT(r.id) as total_all,
         COUNT(CASE WHEN r.cancelled = false AND r.end_time IS NULL AND (r.status IN ('accepted', 'reaching_pickup') OR r.status IS NULL) THEN 1 END) as total_assigned,
         COUNT(CASE WHEN r.cancelled = false AND r.end_time IS NULL AND r.status IN ('arrived', 'started', 'in_progress') THEN 1 END) as total_ongoing,
         COUNT(CASE WHEN r.cancelled = false AND (r.end_time IS NOT NULL OR r.status = 'completed') THEN 1 END) as total_completed,
         COUNT(CASE WHEN r.cancelled = true OR r.status = 'cancelled' THEN 1 END) as total_cancelled
       FROM rides r
       WHERE r.driver_id = $1`,
      [driverId]
    );

    const counts = categoryCountsRes.rows[0];

    return res.status(200).json({
      message: "Ride history fetched successfully.",
      rides: ridesRes.rows.map((row) => ({
        ...row,
        gross_fare: parseFloat(row.gross_fare),
        platform_commission: parseFloat(row.platform_commission),
        net_earnings: parseFloat(row.net_earnings),
        distance_km: parseFloat(row.distance_km),
        duration_minutes: parseInt(row.duration_minutes),
      })),
      category_counts: {
        all: parseInt(counts.total_all),
        assigned: parseInt(counts.total_assigned),
        ongoing: parseInt(counts.total_ongoing),
        completed: parseInt(counts.total_completed),
        cancelled: parseInt(counts.total_cancelled),
      },
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countRes.rows[0].total),
      },
    });
  } catch (error) {
    console.error(`Error in getDriverRideHistory: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET single trip full details for Driver My Trips
const getDriverTripDetails = async (req, res) => {
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
        r.id, r.id as booking_id, r.user_id, r.driver_id, r.vehicle_type, r.status,
        r.cancelled, r.cancelled_by, r.cancellation_reason, r.cancellation_notes, r.cancelled_at,
        r.start_time, r.trip_started_at, r.arrived_at, r.reaching_pickup_at, r.end_time, r.created_at,
        r.price as original_price, r.discount_price,
        COALESCE(de.gross_fare, r.price) as gross_fare,
        COALESCE(de.commission_amount, ROUND((r.price * 0.15)::numeric, 2)) as platform_commission,
        COALESCE(de.commission_rate, 0.15) as commission_rate,
        COALESCE(de.other_deductions, 0.0) as other_deductions,
        COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2)) as net_earnings,
        COALESCE(de.distance_km, 0.0) as distance_km,
        COALESCE(de.duration_minutes, 0) as duration_minutes,
        COALESCE(de.payment_status, 'Paid') as payment_status,
        COALESCE(de.payment_method, r.payment_method, 'Paid via UPI') as payment_method,
        json_build_object('id', u.id, 'name', u.name, 'phone', u.phone, 'image_url', u.image_url) as passenger,
        json_build_object('id', sa.id, 'place', sa.place, 'street', sa.street, 'state', sa.state, 'lat', sa.lat, 'lon', sa.lon) as source_address,
        json_build_object('id', da.id, 'place', da.place, 'street', da.street, 'state', da.state, 'lat', da.lat, 'lon', da.lon) as destination_address
      FROM rides r
      LEFT JOIN driver_earnings de ON r.id = de.ride_id
      LEFT JOIN users u ON r.user_id = u.id
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

    // Authorization check: Only assigned driver can view trip details
    if (row.driver_id !== driverId) {
      return res.status(403).json({
        error: { code: "UNAUTHORIZED_DRIVER", message: "You are not authorized to view this trip's details." },
      });
    }

    return res.status(200).json({
      message: "Trip details fetched successfully.",
      trip: {
        ...row,
        gross_fare: parseFloat(row.gross_fare),
        platform_commission: parseFloat(row.platform_commission),
        commission_rate: parseFloat(row.commission_rate),
        other_deductions: parseFloat(row.other_deductions),
        net_earnings: parseFloat(row.net_earnings),
        distance_km: parseFloat(row.distance_km),
        duration_minutes: parseInt(row.duration_minutes),
      },
    });
  } catch (error) {
    console.error(`Error in getDriverTripDetails: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// Helper to build date range filter for driver earnings queries
function buildEarningsDateFilter(period, fromDate, toDate, paramOffset = 2) {
  let filterSql = "";
  const params = [];
  let currentIdx = paramOffset;

  if (!period || period === "all" || period === "all_time") {
    if (fromDate) {
      filterSql += ` AND r.end_time >= $${currentIdx++}::timestamp`;
      params.push(new Date(fromDate).toISOString());
    }
    if (toDate) {
      const endD = new Date(toDate);
      if (toDate.length <= 10) {
        endD.setHours(23, 59, 59, 999);
      }
      filterSql += ` AND r.end_time <= $${currentIdx++}::timestamp`;
      params.push(endD.toISOString());
    }
    return { filterSql, params };
  }

  const normalized = period.toLowerCase();

  if (normalized === "today" || normalized === "daily") {
    filterSql = " AND r.end_time >= CURRENT_DATE";
  } else if (normalized === "weekly" || normalized === "this_week") {
    filterSql = " AND r.end_time >= DATE_TRUNC('week', CURRENT_DATE)";
  } else if (normalized === "monthly" || normalized === "this_month") {
    filterSql = " AND r.end_time >= DATE_TRUNC('month', CURRENT_DATE)";
  } else if (normalized === "custom") {
    if (fromDate) {
      filterSql += ` AND r.end_time >= $${currentIdx++}::timestamp`;
      params.push(new Date(fromDate).toISOString());
    }
    if (toDate) {
      // Include the entire end date up to end of day if no time specified
      const endD = new Date(toDate);
      if (toDate.length <= 10) {
        endD.setHours(23, 59, 59, 999);
      }
      filterSql += ` AND r.end_time <= $${currentIdx++}::timestamp`;
      params.push(endD.toISOString());
    }
  }
  return { filterSql, params };
}

// GET driver earnings summary with period and custom date filtering
const getDriverEarningsSummary = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { period = "today", from_date, to_date } = req.query;

    const { filterSql, params: dateParams } = buildEarningsDateFilter(period, from_date, to_date, 2);

    // 1. Period-specific aggregated metrics
    const periodQuery = `
      SELECT 
        COALESCE(SUM(COALESCE(de.gross_fare, r.price)), 0) as gross_earnings,
        COALESCE(SUM(COALESCE(de.commission_amount, ROUND((r.price * 0.15)::numeric, 2))), 0) as platform_commission,
        COALESCE(SUM(COALESCE(de.other_deductions, 0.0)), 0) as other_deductions,
        COALESCE(SUM(COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2))), 0) as net_earnings,
        COALESCE(SUM(COALESCE(de.distance_km, 0.0)), 0) as total_distance_km,
        COALESCE(SUM(COALESCE(de.duration_minutes, 0)), 0) as total_duration_minutes,
        COUNT(r.id) as completed_rides,
        COUNT(CASE WHEN r.cancelled = true THEN 1 END) as cancelled_rides
      FROM rides r
      LEFT JOIN driver_earnings de ON r.id = de.ride_id
      WHERE r.driver_id = $1 AND r.end_time IS NOT NULL AND r.cancelled = false ${filterSql}
    `;

    const earningsRes = await query(periodQuery, [driverId, ...dateParams]);
    const periodRow = earningsRes.rows[0];

    // 2. High-level dashboard aggregate cards (Today, Weekly, Monthly, All-time)
    const aggregateRes = await query(
      `SELECT 
        COALESCE(SUM(CASE WHEN r.end_time >= CURRENT_DATE THEN COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2)) ELSE 0 END), 0) as today_earnings,
        COALESCE(SUM(CASE WHEN r.end_time >= DATE_TRUNC('week', CURRENT_DATE) THEN COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2)) ELSE 0 END), 0) as weekly_earnings,
        COALESCE(SUM(CASE WHEN r.end_time >= DATE_TRUNC('month', CURRENT_DATE) THEN COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2)) ELSE 0 END), 0) as monthly_earnings,
        COALESCE(SUM(COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2))), 0) as total_earnings,
        COALESCE(SUM(COALESCE(de.gross_fare, r.price)), 0) as all_time_gross_earnings,
        COALESCE(SUM(COALESCE(de.commission_amount, ROUND((r.price * 0.15)::numeric, 2))), 0) as all_time_commission,
        COUNT(CASE WHEN r.end_time >= CURRENT_DATE THEN 1 END) as today_completed_rides,
        COUNT(CASE WHEN r.end_time >= DATE_TRUNC('week', CURRENT_DATE) THEN 1 END) as weekly_completed_rides,
        COUNT(CASE WHEN r.end_time >= DATE_TRUNC('month', CURRENT_DATE) THEN 1 END) as monthly_completed_rides,
        COUNT(r.id) as total_completed_rides
      FROM rides r
      LEFT JOIN driver_earnings de ON r.id = de.ride_id
      WHERE r.driver_id = $1 AND r.end_time IS NOT NULL AND r.cancelled = false`,
      [driverId]
    );

    const aggRow = aggregateRes.rows[0];

    return res.status(200).json({
      message: "Earnings summary fetched successfully.",
      earnings: {
        period: period,
        from_date: from_date || null,
        to_date: to_date || null,
        gross_earnings: parseFloat(periodRow.gross_earnings),
        platform_commission: parseFloat(periodRow.platform_commission),
        other_deductions: parseFloat(periodRow.other_deductions),
        net_earnings: parseFloat(periodRow.net_earnings),
        total_earnings: parseFloat(periodRow.net_earnings),
        total_distance_km: parseFloat(periodRow.total_distance_km),
        total_duration_minutes: parseInt(periodRow.total_duration_minutes),
        completed_rides: parseInt(periodRow.completed_rides),
        cancelled_rides: parseInt(periodRow.cancelled_rides),
        // High-level aggregates for card displays
        today_earnings: parseFloat(aggRow.today_earnings),
        weekly_earnings: parseFloat(aggRow.weekly_earnings),
        monthly_earnings: parseFloat(aggRow.monthly_earnings),
        all_time_earnings: parseFloat(aggRow.total_earnings),
        today_rides: parseInt(aggRow.today_completed_rides),
        weekly_rides: parseInt(aggRow.weekly_completed_rides),
        monthly_rides: parseInt(aggRow.monthly_completed_rides),
        total_completed_rides: parseInt(aggRow.total_completed_rides),
        all_time_gross_earnings: parseFloat(aggRow.all_time_gross_earnings),
        all_time_commission: parseFloat(aggRow.all_time_commission),
      },
    });
  } catch (error) {
    console.error(`Error in getDriverEarningsSummary: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET driver earnings history (individual rides with detailed financial breakdown)
const getDriverEarningsHistory = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { page = 1, limit = 20, period, from_date, to_date } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { filterSql, params: dateParams } = buildEarningsDateFilter(period, from_date, to_date, 2);

    const queryParams = [driverId, ...dateParams];
    const limitIdx = queryParams.length + 1;
    const offsetIdx = queryParams.length + 2;
    queryParams.push(parseInt(limit), offset);

    const ridesRes = await query(
      `SELECT 
        r.id, r.id as booking_id, r.start_time, r.end_time, r.price as original_price, r.vehicle_type, r.status,
        COALESCE(de.gross_fare, r.price) as gross_fare,
        COALESCE(de.commission_amount, ROUND((r.price * 0.15)::numeric, 2)) as platform_commission,
        COALESCE(de.commission_rate, 0.15) as commission_rate,
        COALESCE(de.other_deductions, 0.0) as other_deductions,
        COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2)) as net_earnings,
        COALESCE(de.distance_km, 0.0) as distance_km,
        COALESCE(de.duration_minutes, 0) as duration_minutes,
        COALESCE(de.payment_status, 'Paid') as payment_status,
        COALESCE(de.payment_method, r.payment_method, 'Paid via UPI') as payment_method,
        json_build_object('name', u.name, 'phone', u.phone) as passenger,
        json_build_object('place', sa.place, 'street', sa.street) as source_address,
        json_build_object('place', da.place, 'street', da.street) as destination_address
      FROM rides r
      LEFT JOIN driver_earnings de ON r.id = de.ride_id
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      WHERE r.driver_id = $1 AND r.end_time IS NOT NULL AND r.cancelled = false ${filterSql}
      ORDER BY r.end_time DESC
      LIMIT $${limitIdx} OFFSET $${offsetIdx}`,
      queryParams
    );

    const countRes = await query(
      `SELECT COUNT(r.id) as total 
       FROM rides r 
       WHERE r.driver_id = $1 AND r.end_time IS NOT NULL AND r.cancelled = false ${filterSql}`,
      [driverId, ...dateParams]
    );

    return res.status(200).json({
      message: "Earnings history fetched successfully.",
      rides: ridesRes.rows.map((row) => ({
        id: row.id,
        booking_id: row.booking_id,
        start_time: row.start_time,
        end_time: row.end_time,
        trip_date: row.end_time,
        vehicle_type: row.vehicle_type,
        status: row.status,
        gross_fare: parseFloat(row.gross_fare),
        platform_commission: parseFloat(row.platform_commission),
        commission_rate: parseFloat(row.commission_rate),
        other_deductions: parseFloat(row.other_deductions),
        net_earnings: parseFloat(row.net_earnings),
        distance_km: parseFloat(row.distance_km),
        duration_minutes: parseInt(row.duration_minutes),
        payment_status: row.payment_status,
        payment_method: row.payment_method,
        passenger: row.passenger,
        source_address: row.source_address,
        destination_address: row.destination_address,
      })),
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countRes.rows[0].total),
      },
    });
  } catch (error) {
    console.error(`Error in getDriverEarningsHistory: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET detailed individual trip earnings breakdown
const getDriverTripEarningDetails = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    const result = await query(
      `SELECT 
        r.id, r.id as booking_id, r.start_time, r.end_time, r.price, r.vehicle_type, r.status,
        COALESCE(de.gross_fare, r.price) as gross_fare,
        COALESCE(de.commission_amount, ROUND((r.price * 0.15)::numeric, 2)) as platform_commission,
        COALESCE(de.commission_rate, 0.15) as commission_rate,
        COALESCE(de.other_deductions, 0.0) as other_deductions,
        COALESCE(de.net_earnings, ROUND((r.price * 0.85)::numeric, 2)) as net_earnings,
        COALESCE(de.distance_km, 0.0) as distance_km,
        COALESCE(de.duration_minutes, 0) as duration_minutes,
        COALESCE(de.payment_status, 'Paid') as payment_status,
        COALESCE(de.payment_method, r.payment_method, 'Paid via UPI') as payment_method,
        json_build_object('id', u.id, 'name', u.name, 'phone', u.phone) as passenger,
        json_build_object('place', sa.place, 'street', sa.street, 'lat', sa.lat, 'lon', sa.lon) as source_address,
        json_build_object('place', da.place, 'street', da.street, 'lat', da.lat, 'lon', da.lon) as destination_address
      FROM rides r
      LEFT JOIN driver_earnings de ON r.id = de.ride_id
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      WHERE r.id = $1`,
      [rideId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride booking not found." },
      });
    }

    const row = result.rows[0];

    // Ownership check
    const rideDriverCheck = await query("SELECT driver_id FROM rides WHERE id = $1", [rideId]);
    if (rideDriverCheck.rows[0].driver_id !== driverId) {
      return res.status(403).json({
        error: { code: "UNAUTHORIZED_DRIVER", message: "You are not authorized to view this trip's earnings." },
      });
    }

    return res.status(200).json({
      message: "Trip earning details fetched successfully.",
      trip_earnings: {
        booking_id: row.booking_id,
        ride_id: row.id,
        trip_date: row.end_time || row.start_time,
        status: row.status,
        vehicle_type: row.vehicle_type,
        pickup_address: [row.source_address?.street, row.source_address?.place].filter(Boolean).join(", "),
        destination_address: [row.destination_address?.street, row.destination_address?.place].filter(Boolean).join(", "),
        passenger: row.passenger,
        gross_fare: parseFloat(row.gross_fare),
        platform_commission: parseFloat(row.platform_commission),
        commission_rate: parseFloat(row.commission_rate),
        other_deductions: parseFloat(row.other_deductions),
        net_earnings: parseFloat(row.net_earnings),
        distance_km: parseFloat(row.distance_km),
        duration_minutes: parseInt(row.duration_minutes),
        payment_status: row.payment_status,
        payment_method: row.payment_method,
      },
    });
  } catch (error) {
    console.error(`Error in getDriverTripEarningDetails: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// POST complete a ride
const completeRide = async (req, res) => {
  try {
    const driverId = req.user.id;
    const rideId = req.params.rideId;
    const { actual_distance_km, final_fare } = req.body || {};

    // 1. Verify ride exists and fetch full ride & address details
    const rideRes = await query(
      `SELECT r.*, sa.lat as pickup_lat, sa.lon as pickup_lon, da.lat as dest_lat, da.lon as dest_lon
       FROM rides r
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

    const ride = rideRes.rows[0];

    // 2. Validate assigned driver
    if (ride.driver_id !== driverId) {
      return res.status(403).json({
        error: { code: "UNAUTHORIZED_DRIVER", message: "Only the assigned driver can complete this trip." },
      });
    }

    // 3. Prevent duplicate completion
    if (ride.end_time || ride.status === "completed") {
      return res.status(400).json({
        error: { code: "RIDE_ALREADY_COMPLETED", message: "This ride is already completed." },
      });
    }

    // 4. Prevent completing cancelled ride
    if (ride.cancelled) {
      return res.status(400).json({
        error: { code: "RIDE_CANCELLED", message: "Cannot complete a cancelled ride." },
      });
    }

    // 5. Must be started or arrived
    if (!["started", "in_progress", "arrived"].includes(ride.status)) {
      return res.status(400).json({
        error: {
          code: "TRIP_NOT_STARTED",
          message: "Cannot complete a trip that has not been started with passenger OTP verification.",
        },
      });
    }

    // 6. Calculate & validate final fare using pricing rules
    const priceConfigRes = await query("SELECT base_price, price_per_km FROM prices LIMIT 1");
    let basePrice = 50.0;
    let pricePerKm = 15.0;
    if (priceConfigRes.rows.length > 0) {
      basePrice = parseFloat(priceConfigRes.rows[0].base_price);
      pricePerKm = parseFloat(priceConfigRes.rows[0].price_per_km);
    }

    let distanceKm = 8.4;
    if (actual_distance_km !== undefined && !isNaN(parseFloat(actual_distance_km))) {
      distanceKm = parseFloat(actual_distance_km);
    } else if (ride.pickup_lat && ride.dest_lat) {
      const R = 6371;
      const dLat = ((ride.dest_lat - ride.pickup_lat) * Math.PI) / 180;
      const dLon = ((ride.dest_lon - ride.pickup_lon) * Math.PI) / 180;
      const a =
        Math.sin(dLat / 2) * Math.sin(dLat / 2) +
        Math.cos((ride.pickup_lat * Math.PI) / 180) *
          Math.cos((ride.dest_lat * Math.PI) / 180) *
          Math.sin(dLon / 2) *
          Math.sin(dLon / 2);
      const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
      distanceKm = Math.round(R * c * 10) / 10;
    }

    // Backend validates calculated fare
    let validatedFare = basePrice + (distanceKm * pricePerKm);
    if (final_fare !== undefined && !isNaN(parseFloat(final_fare))) {
      validatedFare = Math.max(basePrice, parseFloat(final_fare));
    } else if (ride.price) {
      validatedFare = Math.max(basePrice, parseFloat(ride.price));
    }
    validatedFare = Math.round(validatedFare * 100) / 100;

    // Calculate trip duration
    const startTimeMs = new Date(ride.trip_started_at || ride.start_time).getTime();
    const durationMinutes = Math.max(1, Math.round((Date.now() - startTimeMs) / 60000));

    // 7. Atomic conditional completion in PostgreSQL
    const result = await query(
      `UPDATE rides 
       SET status = 'completed', 
           end_time = NOW(), 
           price = $1, 
           cancelled = false 
       WHERE id = $2 AND driver_id = $3 AND end_time IS NULL AND status IN ('started', 'in_progress', 'arrived')
       RETURNING *`,
      [validatedFare, rideId, driverId]
    );

    if (result.rows.length === 0) {
      return res.status(409).json({
        error: { code: "COMPLETION_CONFLICT", message: "Trip completion conflict or already completed." },
      });
    }

    const completedRide = result.rows[0];

    // 8. Prevent duplicate earnings record with UNIQUE(ride_id)
    const grossFare = validatedFare;
    const commissionRate = 0.15;
    const commissionAmount = Math.round(grossFare * commissionRate * 100) / 100;
    const otherDeductions = 0.0;
    const netEarnings = Math.round((grossFare - commissionAmount - otherDeductions) * 100) / 100;
    const earningId = `earn_${uuidv4().substring(0, 16)}`;

    await query(
      `INSERT INTO driver_earnings 
         (id, driver_id, ride_id, amount, gross_fare, commission_rate, commission_amount, other_deductions, net_earnings, distance_km, duration_minutes, payment_status, payment_method, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'Paid', $12, NOW())
       ON CONFLICT (ride_id) DO UPDATE SET
         amount = EXCLUDED.amount,
         gross_fare = EXCLUDED.gross_fare,
         commission_amount = EXCLUDED.commission_amount,
         net_earnings = EXCLUDED.net_earnings`,
      [
        earningId,
        driverId,
        rideId,
        netEarnings,
        grossFare,
        commissionRate,
        commissionAmount,
        otherDeductions,
        netEarnings,
        distanceKm,
        durationMinutes,
        ride.payment_method || "Paid via UPI",
      ]
    );

    // 8b. Update normalized driver_availability and fare_breakdowns (integer minor units)
    try {
      const grossMinor = Math.round(grossFare * 100);
      const commissionMinor = Math.round(commissionAmount * 100);
      const netMinor = Math.round(netEarnings * 100);

      await query(
        `INSERT INTO fare_breakdowns (
          id, ride_id, currency, base_fare_minor, distance_fare_minor, platform_fee_minor, total_fare_minor, driver_net_earnings_minor
        ) VALUES ($1, $2, 'INR', $3, $4, $5, $6, $7)
        ON CONFLICT (ride_id) DO NOTHING;`,
        [`fb_${rideId}`, rideId, Math.round(basePrice * 100), Math.round(distanceKm * pricePerKm * 100), commissionMinor, grossMinor, netMinor]
      );

      await query(
        `UPDATE driver_availability SET state = 'ONLINE_AVAILABLE', current_ride_id = NULL, last_state_change = (NOW() AT TIME ZONE 'UTC') WHERE driver_id = $1;`,
        [driverId]
      );

      await query(
        `INSERT INTO ride_status_history (id, ride_id, old_status, new_status, triggered_by_role, triggered_by_id)
         VALUES ($1, $2, 'in_progress', 'completed', 'driver', $3);`,
        [`hist_${Date.now()}_${rideId.slice(0, 8)}`, rideId, driverId]
      );
    } catch (normErr) {
      console.warn("Normalized tables update warning:", normErr.message);
    }

    // 9. Real-time notification to User Panel
    emitTripCompleted(rideId, ride.user_id, {
      ride_id: rideId,
      driver_id: driverId,
      status: "completed",
      final_fare: validatedFare,
      distance_km: distanceKm,
      duration_minutes: durationMinutes,
      end_time: completedRide.end_time,
    });

    return res.status(200).json({
      message: "Ride completed successfully.",
      ride: {
        id: completedRide.id,
        status: completedRide.status,
        final_fare: parseFloat(completedRide.price),
        distance_km: distanceKm,
        duration_minutes: durationMinutes,
        start_time: completedRide.start_time,
        end_time: completedRide.end_time,
      },
      earnings: {
        gross_fare: grossFare,
        platform_commission: commissionAmount,
        commission_rate: commissionRate,
        other_deductions: otherDeductions,
        net_earnings: netEarnings,
        amount: netEarnings,
      },
    });
  } catch (error) {
    console.error(`Error in completeRide: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

// GET driver dashboard stats
const getDriverDashboardStats = async (req, res) => {
  try {
    const driverId = req.user.id;

    // Today's stats
    const todayRes = await query(
      `SELECT 
        COALESCE(SUM(r.price), 0) as today_earnings,
        COUNT(r.id) as today_rides
      FROM rides r
      WHERE r.driver_id = $1 AND r.end_time IS NOT NULL AND r.cancelled = false 
        AND r.start_time >= CURRENT_DATE`,
      [driverId]
    );

    // Active ride
    const activeRideRes = await query(
      `SELECT r.id, r.start_time, r.price,
        json_build_object('id', u.id, 'name', u.name, 'phone', u.phone) as passenger,
        json_build_object('place', sa.place, 'street', sa.street, 'lat', sa.lat, 'lon', sa.lon) as source_address,
        json_build_object('place', da.place, 'street', da.street, 'lat', da.lat, 'lon', da.lon) as destination_address
      FROM rides r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      WHERE r.driver_id = $1 AND r.end_time IS NULL AND r.cancelled = false
      ORDER BY r.start_time DESC LIMIT 1`,
      [driverId]
    );

    // Total completed rides
    const totalRes = await query(
      `SELECT COUNT(r.id) as total_rides FROM rides r 
       WHERE r.driver_id = $1 AND r.end_time IS NOT NULL AND r.cancelled = false`,
      [driverId]
    );

    // Driver online status
    const driverRes = await query(
      "SELECT active FROM drivers WHERE id = $1",
      [driverId]
    );

    return res.status(200).json({
      message: "Dashboard stats fetched successfully.",
      stats: {
        today_earnings: parseFloat(todayRes.rows[0].today_earnings),
        today_rides: parseInt(todayRes.rows[0].today_rides),
        total_rides: parseInt(totalRes.rows[0].total_rides),
        is_online: driverRes.rows.length > 0 ? driverRes.rows[0].active : false,
        active_ride: activeRideRes.rows.length > 0 ? activeRideRes.rows[0] : null,
      },
    });
  } catch (error) {
    console.log(`Error in getDriverDashboardStats: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// POST cancel an assigned ride by driver
const cancelDriverRide = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { rideId } = req.params;
    const { reason, notes } = req.body || {};

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    if (!reason || typeof reason !== "string" || !reason.trim()) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Cancellation reason is required." },
      });
    }

    const trimmedReason = reason.trim();
    const optionalNotes = notes && typeof notes === "string" && notes.trim() ? notes.trim() : null;

    // 1. Fetch ride details
    const rideRes = await query(
      `SELECT r.*, 
              u.id as passenger_id, u.name as passenger_name, u.phone as passenger_phone,
              sa.street as pickup_street, sa.place as pickup_place,
              da.street as destination_street, da.place as destination_place
       FROM rides r
       LEFT JOIN users u ON r.user_id = u.id
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

    const ride = rideRes.rows[0];

    // 2. Validate driver ownership
    if (ride.driver_id !== driverId) {
      return res.status(403).json({
        error: {
          code: "UNAUTHORIZED_DRIVER",
          message: "Only the assigned driver can cancel this ride booking.",
        },
      });
    }

    // 3. Prevent cancellation after trip completion
    if (ride.end_time || ride.status === "completed") {
      return res.status(400).json({
        error: {
          code: "RIDE_ALREADY_COMPLETED",
          message: "Cannot cancel a ride that has already been completed.",
        },
      });
    }

    // 4. Prevent duplicate cancellation
    if (ride.cancelled || ride.status === "cancelled") {
      return res.status(400).json({
        error: {
          code: "RIDE_ALREADY_CANCELLED",
          message: "This ride is already cancelled.",
        },
      });
    }

    const statusAtCancellation = ride.status || "accepted";

    // 5. Concurrency-safe atomic cancellation in PostgreSQL
    const cancelRes = await query(
      `UPDATE rides 
       SET cancelled = true,
           status = 'cancelled',
           cancelled_by = 'driver',
           cancellation_reason = $1,
           cancellation_notes = $2,
           cancelled_at = NOW()
       WHERE id = $3 AND cancelled = false AND end_time IS NULL
       RETURNING *`,
      [trimmedReason, optionalNotes, rideId]
    );

    if (cancelRes.rows.length === 0) {
      return res.status(400).json({
        error: {
          code: "CANCELLATION_FAILED",
          message: "Could not cancel ride. It may have already been cancelled or completed.",
        },
      });
    }

    const cancelledRide = cancelRes.rows[0];

    // 6. Update any dispatch requests
    await query(
      `UPDATE ride_requests SET status = 'cancelled' WHERE ride_id = $1`,
      [rideId]
    );

    // 7. Insert audit record in ride_cancellations table
    const cancellationId = `cnc_${uuidv4().substring(0, 18)}`;
    await query(
      `INSERT INTO ride_cancellations 
         (id, ride_id, driver_id, user_id, cancelled_by, reason, notes, ride_status_at_cancellation, created_at)
       VALUES ($1, $2, $3, $4, 'driver', $5, $6, $7, NOW())`,
      [
        cancellationId,
        rideId,
        driverId,
        ride.user_id,
        trimmedReason,
        optionalNotes,
        statusAtCancellation,
      ]
    );

    // 8. Make the driver eligible for another ride
    // By updating rides.cancelled = true, the driver has no active uncompleted rides.
    // Ensure driver availability/online status is preserved and ready
    await query(
      `UPDATE drivers SET active = true, is_online = true WHERE id = $1 AND (active = true OR is_online = true)`,
      [driverId]
    );

    // 9. Real-time notification to User Panel & Ride room
    emitRideCancelled(rideId, ride.user_id, trimmedReason, {
      cancelled_by: "driver",
      reason: trimmedReason,
      notes: optionalNotes,
      status: "cancelled",
      cancelled_at: cancelledRide.cancelled_at,
    });

    return res.status(200).json({
      message: "Ride cancelled successfully.",
      cancellation: {
        id: cancellationId,
        ride_id: rideId,
        status: "cancelled",
        cancelled_by: "driver",
        reason: trimmedReason,
        notes: optionalNotes,
        cancelled_at: cancelledRide.cancelled_at,
        ride_status_at_cancellation: statusAtCancellation,
      },
    });
  } catch (error) {
    console.error("Error in cancelDriverRide:", error);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || "Failed to cancel ride." },
    });
  }
};

// GET driver cancellation history
const getDriverCancellationHistory = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const result = await query(
      `SELECT 
         c.id, c.ride_id, c.cancelled_by, c.reason, c.notes, c.ride_status_at_cancellation, c.created_at as cancelled_at,
         r.price, r.vehicle_type,
         json_build_object('id', u.id, 'name', u.name, 'phone', u.phone) as passenger,
         json_build_object('place', sa.place, 'street', sa.street) as pickup,
         json_build_object('place', da.place, 'street', da.street) as destination
       FROM ride_cancellations c
       JOIN rides r ON c.ride_id = r.id
       LEFT JOIN users u ON c.user_id = u.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE c.driver_id = $1
       ORDER BY c.created_at DESC
       LIMIT $2 OFFSET $3`,
      [driverId, parseInt(limit), offset]
    );

    const countRes = await query(
      `SELECT COUNT(*) as total FROM ride_cancellations WHERE driver_id = $1`,
      [driverId]
    );

    return res.status(200).json({
      message: "Driver cancellation history fetched successfully.",
      cancellations: result.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countRes.rows[0].total),
      },
    });
  } catch (error) {
    console.error("Error in getDriverCancellationHistory:", error);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || "Failed to fetch cancellation history." },
    });
  }
};

const getActiveTripForDriver = async (req, res) => {
  try {
    const driverId = req.user?.id || req.query?.driver_id;
    if (!driverId) {
      return res.status(400).json({ error: { code: "EMPTY_PARAM", message: "Driver ID required." } });
    }

    const activeRes = await query(
      `SELECT 
        r.id as ride_id, r.user_id, r.driver_id, r.status, r.otp, r.price, r.vehicle_type,
        r.start_time, r.reaching_pickup_at, r.arrived_at, r.trip_started_at,
        sa.street as pickup_address, sa.lat as pickup_lat, sa.lon as pickup_lon,
        da.street as destination_address, da.lat as dest_lat, da.lon as dest_lon,
        u.name as passenger_name, u.phone as passenger_phone, u.image_url as passenger_image
       FROM rides r
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       LEFT JOIN users u ON r.user_id = u.id
       WHERE r.driver_id = $1 
         AND r.cancelled = false 
         AND r.status IN ('accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started')
       ORDER BY r.start_time DESC
       LIMIT 1`,
      [driverId]
    );

    if (activeRes.rows.length === 0) {
      return res.status(200).json({ active_trip: null });
    }

    return res.status(200).json({ active_trip: activeRes.rows[0] });
  } catch (err) {
    console.error("Error in getActiveTripForDriver:", err);
    return res.status(500).json({ error: { code: "SERVER_ERROR", message: err.message } });
  }
};

module.exports = {
  getDriverProfile,
  updateDriverProfile,
  uploadDriverPhoto,
  toggleAvailability,
  updateDriverLocation,
  getDriverStatus,
  getDriverRideHistory,
  getDriverEarningsSummary,
  getDriverEarningsHistory,
  getDriverTripEarningDetails,
  completeRide,
  cancelDriverRide,
  getDriverCancellationHistory,
  getDriverDashboardStats,
  getDriverTripDetails,
  getActiveTripForDriver,
};
