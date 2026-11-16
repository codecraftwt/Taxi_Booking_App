const axios = require("axios");
const bcrypt = require("bcrypt");
const crypto = require("crypto");
const { v4: uuidv4 } = require("uuid");
const Constant = require("../../config/constants");
const Err = require("../../config/error");
const { query } = require("../../database");
const Helper = require("../../utils/helper");
const {
  dispatchRideToEligibleDrivers,
  calculateHaversineDistance,
  normalizeCategory,
  calculateEtaMinutes,
} = require("./rideRequestController");
const { emitRideCancelled } = require("../../socket");
const routingService = require("../../modules/location/routing.service");

const getPreviousRidesOfUser = async (req, res) => {
  try {
    const userId = req.body?.user_id ?? req.query?.user_id ?? req.user?.id;

    if (!userId) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const ridesRes = await query(
      `SELECT 
        r.id,
        r.start_time,
        r.end_time,
        r.cancelled,
        r.price,
        r.discount_price,
        COALESCE(r.otp, '4829') as otp,
        COALESCE(r.vehicle_type, 'Saffar Auto') as vehicle_type,
        COALESCE(r.status, CASE WHEN r.cancelled THEN 'cancelled' ELSE 'completed' END) as status,
        COALESCE(r.payment_method, 'Paid via UPI') as payment_method,
        COALESCE(r.co2_saved, 1.2) as co2_saved,
        json_build_object(
          'id', u.id,
          'name', u.name,
          'phone', u.phone,
          'email', u.email,
          'imageUrl', u.image_url
        ) as user,
        CASE 
          WHEN d.id IS NOT NULL THEN
            json_build_object(
              'id', d.id,
              'name', COALESCE(d.name, 'Driver'),
              'phone', COALESCE(d.phone, ''),
              'vehicle_name', COALESCE(d.vehicle_name, r.vehicle_type, 'Saffar Vehicle'),
              'vehicle_number', COALESCE(d.vehicle_number, 'Pending'),
              'image_url', d.image_url,
              'active', COALESCE(d.active, true),
              'rating', 4.9,
              'total_trips', 3240,
              'verified', true
            )
          ELSE
            json_build_object(
              'id', 'driver_unassigned',
              'name', 'Driver Unassigned',
              'phone', '',
              'vehicle_name', COALESCE(r.vehicle_type, 'Saffar Vehicle'),
              'vehicle_number', 'Not Assigned',
              'image_url', null,
              'active', false,
              'rating', 5.0,
              'total_trips', 0,
              'verified', false
            )
        END as driver,
        json_build_object(
          'id', sa.id,
          'place', sa.place,
          'street', sa.street,
          'state', sa.state,
          'country', sa.country,
          'lat', sa.lat,
          'lon', sa.lon,
          'pincode', sa.pincode
        ) as source_address,
        json_build_object(
          'id', da.id,
          'place', da.place,
          'street', da.street,
          'state', da.state,
          'country', da.country,
          'lat', da.lat,
          'lon', da.lon,
          'pincode', da.pincode
        ) as destination_address
      FROM rides r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN drivers d ON r.driver_id = d.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      WHERE r.user_id = $1
      ORDER BY r.start_time DESC`,
      [userId]
    );

    return res.status(200).json({
      message: "All previous rides of the user fetched successfully.",
      co2_saved_kg: 3.8,
      previous_rides: ridesRes.rows,
    });
  } catch (error) {
    console.log(`Error in getPreviousRidesOfUser: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const addRideAndRideAddresses = async (req, res) => {
  try {
    const userId = req.body?.user_id ?? req.user?.id;
    if (!userId) {
      return res.status(400).json({ error: { code: Err.code.EMPTY_PARAM, message: "User ID is required." } });
    }
    const explicitDriverId = req.body?.driver_id;
    const sourceAddressRaw = req.body?.source_address;
    const destinationAddressRaw = req.body?.destination_address;
    if (!sourceAddressRaw || !destinationAddressRaw) {
      return res.status(400).json({ error: { code: Err.code.EMPTY_PARAM, message: "source_address and destination_address are required." } });
    }
    const price = parseFloat(req.body?.price ?? 0.0);
    const discountPrice = req.body?.discount_price ? parseFloat(req.body.discount_price) : 0.0;
    const vehicleType = req.body?.vehicle_type || req.body?.category || "Saffar Auto";
    const paymentMethod = req.body?.payment_method ?? "Paid via Cash";
    const customId = req.body?.id;
    const startTime = req.body?.start_time ? new Date(req.body.start_time) : new Date();

    const sourceAddress = typeof sourceAddressRaw === "string"
      ? { place: "Bengaluru", street: sourceAddressRaw, state: "Karnataka", country: "India", lat: 12.9350, lon: 77.6850, pincode: "560034" }
      : sourceAddressRaw;

    const destinationAddress = typeof destinationAddressRaw === "string"
      ? { place: "Bengaluru", street: destinationAddressRaw, state: "Karnataka", country: "India", lat: 12.9780, lon: 77.6350, pincode: "560037" }
      : destinationAddressRaw;

    const sourceAddressId = sourceAddress.id || uuidv4();
    await query(
      `INSERT INTO addresses (id, place, street, state, country, lat, lon, pincode)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET street = EXCLUDED.street`,
      [
        sourceAddressId,
        sourceAddress.place || "Bengaluru",
        sourceAddress.street,
        sourceAddress.state || "Karnataka",
        sourceAddress.country || "India",
        sourceAddress.lat || 12.9350,
        sourceAddress.lon || 77.6850,
        sourceAddress.pincode || "560034",
      ]
    );

    const destinationAddressId = destinationAddress.id || uuidv4();
    await query(
      `INSERT INTO addresses (id, place, street, state, country, lat, lon, pincode)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       ON CONFLICT (id) DO UPDATE SET street = EXCLUDED.street`,
      [
        destinationAddressId,
        destinationAddress.place || "Bengaluru",
        destinationAddress.street,
        destinationAddress.state || "Karnataka",
        destinationAddress.country || "India",
        destinationAddress.lat || 12.9780,
        destinationAddress.lon || 77.6350,
        destinationAddress.pincode || "560037",
      ]
    );

    const rideId = customId || uuidv4();
    const isDirectAssignment = Boolean(explicitDriverId);
    const initialStatus = isDirectAssignment ? "in_progress" : "requested";
    const driverId = isDirectAssignment ? explicitDriverId : null;

    // Secure Ride-specific OTP Generation (cryptographically secure 4-digit code)
    const OTP_SALT = process.env.OTP_SECRET || "saffar_otp_secure_salt_2026";
    const secureOtp = req.body?.otp ? req.body.otp.toString() : String(crypto.randomInt(1000, 10000));
    const otpHash = crypto.createHash("sha256").update(`${secureOtp}:${rideId}:${OTP_SALT}`).digest("hex");
    const otpExpiresAt = new Date(Date.now() + 60 * 60 * 1000); // 60 minutes validity

    await query(
      `INSERT INTO rides (
         id, user_id, driver_id, source_address_id, destination_address_id,
         start_time, cancelled, price, discount_price, otp, otp_hash, otp_expires_at,
         otp_attempts, max_otp_attempts, otp_verified, vehicle_type, status, payment_method
       )
       VALUES ($1, $2, $3, $4, $5, $6, false, $7, $8, $9, $10, $11, 0, 5, false, $12, $13, $14)
       ON CONFLICT (id) DO NOTHING`,
      [
        rideId,
        userId,
        driverId,
        sourceAddressId,
        destinationAddressId,
        startTime,
        price,
        discountPrice,
        secureOtp,
        otpHash,
        otpExpiresAt,
        vehicleType,
        initialStatus,
        paymentMethod,
      ]
    );

    // If paid via wallet, deduct price from users.wallet_balance in PostgreSQL
    if (paymentMethod && paymentMethod.toLowerCase().includes("wallet")) {
      try {
        await query(
          "UPDATE users SET wallet_balance = GREATEST(0.0, COALESCE(wallet_balance, 0.0) - $1) WHERE id = $2",
          [price, userId]
        );
      } catch (wErr) {
        console.warn("Could not deduct wallet balance:", wErr.message);
      }
    }

    // Fetch user details for ride dispatch
    const userRes = await query("SELECT name, phone FROM users WHERE id = $1", [userId]);
    const userName = userRes.rows[0]?.name || "Passenger";
    const userPhone = userRes.rows[0]?.phone || "";

    // Dispatch to eligible drivers via Sequential Coordinator
    let eligibleDrivers = [];
    if (!isDirectAssignment) {
      const dispatchCoordinator = require("../../modules/driver_matching/dispatch.coordinator");
      const session = await dispatchCoordinator.startSequentialDispatch(
        rideId,
        {
          user_id: userId,
          passenger_name: userName,
          passenger_phone: userPhone,
          pickup_address: [sourceAddress.street, sourceAddress.place].filter(Boolean).join(", "),
          destination_address: [destinationAddress.street, destinationAddress.place].filter(Boolean).join(", "),
          distance_text: req.body?.distance_text || "8.4 km",
          price: price,
          vehicle_type: vehicleType,
        },
        { lat: sourceAddress.lat, lon: sourceAddress.lon }
      );
      eligibleDrivers = session?.offeredDriverIds ? Array.from(session.offeredDriverIds) : [];
    }

    // If explicit driver was assigned, return driver details from database
    let driverData = null;
    if (isDirectAssignment) {
      const dRes = await query("SELECT id, name, phone, vehicle_name, vehicle_number, image_url FROM drivers WHERE id = $1 LIMIT 1", [driverId]);
      if (dRes.rows.length > 0) {
        const d = dRes.rows[0];
        driverData = {
          id: d.id,
          name: d.name,
          phone: d.phone,
          vehicle_name: d.vehicle_name || vehicleType,
          vehicle_number: d.vehicle_number || "",
          image_url: d.image_url,
          rating: 5.0,
          total_trips: "1 trip",
        };
      }
    }

    return res.status(201).json({
      message: isDirectAssignment ? "Ride booked successfully." : "Ride request created and dispatched to nearby drivers.",
      ride_id: rideId,
      otp: secureOtp,
      expires_at: otpExpiresAt,
      status: initialStatus,
      vehicle_type: vehicleType,
      price: price,
      driver: driverData,
      eligible_drivers_notified: eligibleDrivers.length,
      expires_in_seconds: 45,
    });
  } catch (error) {
    console.error(`Error in addRideAndRideAddresses: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || Err.message.SERVER_ERROR,
      },
    });
  }
};

const cancelRide = async (req, res) => {
  try {
    const { ride_id, reason = "Rider cancelled" } = req.body;
    if (!ride_id) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "ride_id is required",
        },
      });
    }

    const rideRes = await query("SELECT * FROM rides WHERE id = $1", [ride_id]);
    if (rideRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride booking not found." },
      });
    }

    const ride = rideRes.rows[0];
    if (ride.end_time || ride.status === "completed") {
      return res.status(400).json({
        error: { code: "RIDE_ALREADY_COMPLETED", message: "Cannot cancel a completed ride." },
      });
    }
    if (ride.cancelled || ride.status === "cancelled") {
      return res.status(400).json({
        error: { code: "RIDE_ALREADY_CANCELLED", message: "This ride is already cancelled." },
      });
    }

    await query(
      `UPDATE rides 
       SET cancelled = true, status = 'cancelled', cancelled_by = 'user', cancellation_reason = $1, cancelled_at = NOW() 
       WHERE id = $2`,
      [reason, ride_id]
    );

    await query(
      `UPDATE ride_requests SET status = 'cancelled' WHERE ride_id = $1`,
      [ride_id]
    );

    try {
      const dispatchCoordinator = require("../../modules/driver_matching/dispatch.coordinator");
      await dispatchCoordinator.handleCustomerCancellation(ride_id, reason);
    } catch (coordErr) {
      console.warn("Could not notify dispatch coordinator of cancellation:", coordErr.message);
    }

    const cancellationId = `cnc_${uuidv4().substring(0, 18)}`;
    await query(
      `INSERT INTO ride_cancellations 
         (id, ride_id, driver_id, user_id, cancelled_by, reason, ride_status_at_cancellation, created_at)
       VALUES ($1, $2, $3, $4, 'user', $5, $6, NOW())`,
      [cancellationId, ride_id, ride.driver_id, ride.user_id, reason, ride.status || "requested"]
    );

    emitRideCancelled(ride_id, ride.user_id, reason, {
      cancelled_by: "user",
      reason,
      status: "cancelled",
    });

    return res.status(200).json({
      message: "Ride has been cancelled successfully.",
      ride_id,
      status: "cancelled",
      cancelled_by: "user",
      reason,
    });
  } catch (error) {
    console.error("Error in cancelRide:", error);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to cancel ride",
      },
    });
  }
};

const getPriceInfoAndCalculateRidePrice = async (req, res) => {
  try {
    const rideDistanceInKm = req.body?.distance_in_km ?? req.query?.distance_in_km;

    if (!rideDistanceInKm) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const category = req.query.category || req.body?.category || "Auto";
    const fareRes = await query(
      "SELECT base_fare, per_km, per_minute, minimum_fare FROM fare_configs WHERE LOWER(category) = LOWER($1) OR LOWER(category) LIKE LOWER($2) ORDER BY base_fare ASC LIMIT 1",
      [category, `%${category.toLowerCase()}%`]
    );

    let basePrice = 50.0;
    let pricePerKm = 15.0;
    let minFare = 50.0;

    if (fareRes.rows.length > 0) {
      basePrice = parseFloat(fareRes.rows[0].base_fare);
      pricePerKm = parseFloat(fareRes.rows[0].per_km);
      minFare = parseFloat(fareRes.rows[0].minimum_fare);
    } else {
      const priceRes = await query("SELECT * FROM prices LIMIT 1");
      if (priceRes.rows.length > 0) {
        basePrice = parseFloat(priceRes.rows[0].base_price);
        pricePerKm = parseFloat(priceRes.rows[0].price_per_km);
      }
    }

    const dist = parseFloat(rideDistanceInKm);
    const totalPrice = Math.max(minFare, Math.round(basePrice + dist * pricePerKm));

    return res.json({
      total_price: totalPrice,
      base_price: basePrice,
      price_per_km: pricePerKm,
      minimum_fare: minFare,
    });
  } catch (error) {
    console.log(`Error in getPriceInfoAndCalculateRidePrice: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const findRideDriver = async (req, res) => {
  try {
    const latitude = parseFloat(req.body?.latitude ?? req.query?.latitude);
    const longitude = parseFloat(req.body?.longitude ?? req.query?.longitude);
    const mapApiKey = req.body?.map_api_key ?? req.query?.map_api_key;

    if (isNaN(latitude) || isNaN(longitude)) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const changeLatitude = Math.random() <= 0.5;
    const sign = Math.random() <= 0.5 ? 1 : -1;
    const pointLatitude = latitude + (changeLatitude ? sign * 0.018 : 0);
    const pointLongitude = longitude + (!changeLatitude ? sign * 0.018 : 0);

    let driverSourceLatitude = pointLatitude;
    let driverSourceLongitude = pointLongitude;
    let driverDestinationLatitude = latitude;
    let driverDestinationLongitude = longitude;

    if (mapApiKey && mapApiKey !== "dummy_tomtom_api_key") {
      try {
        const response = await axios.get(
          `https://api.tomtom.com/routing/1/calculateRoute/${pointLatitude},${pointLongitude}:${latitude},${longitude}/json?key=${mapApiKey}`
        );
        const points = response.data["routes"][0]["legs"][0]["points"];
        driverSourceLatitude = Number.parseFloat(points[0]["latitude"]);
        driverSourceLongitude = Number.parseFloat(points[0]["longitude"]);
        driverDestinationLatitude = Number.parseFloat(points[points.length - 1]["latitude"]);
        driverDestinationLongitude = Number.parseFloat(points[points.length - 1]["longitude"]);
      } catch (tomtomErr) {
        console.log("TomTom routing fallback used (direct coordinates)");
      }
    }

    const driverRes = await query("SELECT * FROM drivers WHERE active = true OR is_online = true LIMIT 1");
    let driver = driverRes.rows[0];

    if (!driver) {
      return res.status(404).json({
        error: {
          code: "NO_DRIVERS_AVAILABLE",
          message: "No active drivers currently available in this area.",
        },
      });
    }

    const secureOtp = String(crypto.randomInt(1000, 10000));

    return res.json({
      otp: secureOtp,
      eta_mins: 4,
      distance_away: "Nearby",
      status_message: "Approaching pickup location",
      pickup_spot: "Pickup Location",
      driver: {
        id: driver.id,
        name: driver.name,
        phone: driver.phone,
        email: driver.email,
        vehicle_name: driver.vehicle_name || "Auto",
        vehicle_number: driver.vehicle_number || "",
        image_url: driver.image_url,
        active: driver.active,
        rating: 5.0,
        total_trips: 0,
        verified: true,
      },
      ride_info: {
        category: driver.vehicle_name || "Auto",
        payment_mode: "Pay via UPI / Cash",
        fare: 78.50,
        fare_text: "Standard fare",
      },
      source_position: {
        latitude: driverSourceLatitude,
        longitude: driverSourceLongitude,
      },
      destination_position: {
        latitude: driverDestinationLatitude,
        longitude: driverDestinationLongitude,
      },
    });
  } catch (error) {
    console.log(`Error in findRideDriver: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const getRideOptions = async (req, res) => {
  try {
    const distanceKm = parseFloat(req.query?.distance ?? req.body?.distance ?? 8.4);
    const durationMins = Math.max(5, Math.round(distanceKm * 2.6));
    const promoCode = (req.query?.promo ?? req.body?.promo ?? 'SAVE30').toUpperCase();

    // Saffar Bike
    const bikeRaw = Math.round(25 + distanceKm * 8.5);
    const bikeDiscounted = Math.round(bikeRaw * 0.9); // ₹85 vs ₹95

    // Saffar Auto (POPULAR - Default)
    const autoRaw = Math.round(40 + distanceKm * 14.5);
    const autoDiscounted = promoCode === 'SAVE30' ? Math.max(autoRaw - 30, 50) : autoRaw; // ₹135

    // Mini Cab
    const miniRaw = Math.round(60 + distanceKm * 18); // ₹210

    // Prime Sedan
    const sedanRaw = Math.round(80 + distanceKm * 24); // ₹280

    // Rentals
    const rentalsRaw = 280;

    const options = [
      {
        id: "bike",
        name: "Saffar Bike",
        tag: "FASTEST",
        tag_color: "0xFFFF6B00",
        capacity: 1,
        eta_mins: 2,
        drop_time: "09:45 AM",
        price: bikeDiscounted,
        original_price: bikeRaw,
        description: "1 • Drop 09:45 AM • 2 min",
        icon: "bike",
      },
      {
        id: "auto",
        name: "Saffar Auto",
        tag: "POPULAR",
        tag_color: "0xFFFF6B00",
        sub_tag: "Eco Save",
        sub_tag_color: "0xFF20A46B",
        capacity: 3,
        eta_mins: 3,
        description: "3 • Eco-friendly • 3 min",
        price: autoDiscounted,
        original_price: autoRaw,
        selected: true,
        icon: "auto",
      },
      {
        id: "mini",
        name: "Mini Cab",
        tag: "Standard",
        capacity: 4,
        eta_mins: 4,
        description: "4 • AC Compact • 4 min",
        price: miniRaw,
        original_price: miniRaw,
        icon: "mini",
      },
      {
        id: "sedan",
        name: "Prime Sedan",
        tag: "Comfort",
        capacity: 4,
        eta_mins: 6,
        description: "4 • Spacious Sedan • 6 min",
        price: sedanRaw,
        original_price: sedanRaw,
        icon: "sedan",
      },
      {
        id: "rentals",
        name: "Rentals",
        tag: "Hourly",
        capacity: 4,
        eta_mins: 5,
        description: "Hourly flexible multi-stop",
        price: rentalsRaw,
        original_price: rentalsRaw,
        icon: "rentals",
      },
    ];

    return res.status(200).json({
      distance_km: distanceKm,
      duration_mins: durationMins,
      promo_code: promoCode,
      promo_applied: promoCode === 'SAVE30' ? 'SAVE30 applied' : null,
      options,
    });
  } catch (error) {
    console.error("Error in getRideOptions:", error);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message,
      },
    });
  }
};

const rebookRide = async (req, res) => {
  try {
    const { ride_id, user_id } = req.body;
    if (!ride_id) {
      return res.status(400).json({ error: { message: "ride_id is required" } });
    }

    const previousRideRes = await query("SELECT * FROM rides WHERE id = $1 LIMIT 1", [ride_id]);
    if (previousRideRes.rows.length === 0) {
      return res.status(404).json({ error: { message: "Ride not found" } });
    }

    const oldRide = previousRideRes.rows[0];
    const newRideId = uuidv4();
    const newOtp = "4829";

    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, cancelled, price, discount_price, otp, vehicle_type, status, payment_method)
       VALUES ($1, $2, $3, $4, $5, NOW(), false, $6, $7, $8, $9, 'in_progress', $10)`,
      [
        newRideId,
        user_id || oldRide.user_id,
        oldRide.driver_id,
        oldRide.source_address_id,
        oldRide.destination_address_id,
        oldRide.price,
        oldRide.discount_price || 0,
        newOtp,
        oldRide.vehicle_type || 'Saffar Auto',
        oldRide.payment_method || 'Paid via UPI',
      ]
    );

    return res.status(201).json({
      message: "Ride rebooked successfully",
      ride_id: newRideId,
      otp: newOtp,
    });
  } catch (error) {
    console.error("Error in rebookRide:", error);
    return res.status(500).json({ error: { message: error.message } });
  }
};

const rateRideDriver = async (req, res) => {
  try {
    const {
      ride_id,
      driver_id = "driver_001",
      rating = 5.0,
      tags = [],
      tip_amount = 0.0,
      note = "",
    } = req.body;

    const userId = req.user?.id || req.body?.user_id;
    const reviewId = uuidv4();

    // 1. Insert into ride_reviews table
    await query(
      `INSERT INTO ride_reviews (id, ride_id, user_id, driver_id, rating, tags, tip_amount, note)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)`,
      [
        reviewId,
        ride_id || null,
        userId || null,
        driver_id,
        parseFloat(rating),
        Array.isArray(tags) ? tags : [],
        parseFloat(tip_amount),
        note || null,
      ]
    );

    // 2. Update ride record if ride_id provided
    if (ride_id) {
      await query(
        `UPDATE rides SET rating = $1, tip_amount = $2 WHERE id = $3`,
        [parseFloat(rating), parseFloat(tip_amount), ride_id]
      );

      // Sync into normalized ratings table
      if (userId) {
        try {
          await query(
            `INSERT INTO ratings (id, ride_id, reviewer_type, reviewer_id, reviewee_id, rating_score, tags, comments, tip_amount_minor)
             VALUES ($1, $2, 'USER', $3, $4, $5, $6, $7, $8)
             ON CONFLICT (ride_id, reviewer_type) DO UPDATE SET
               rating_score = EXCLUDED.rating_score,
               tags = EXCLUDED.tags,
               comments = EXCLUDED.comments,
               tip_amount_minor = EXCLUDED.tip_amount_minor`,
            [
              uuidv4(),
              ride_id,
              userId,
              driver_id,
              parseFloat(rating),
              Array.isArray(tags) ? tags : [],
              note || null,
              Math.round(parseFloat(tip_amount || 0) * 100),
            ]
          );
        } catch (rErr) {
          console.warn("Could not sync to normalized ratings table:", rErr.message);
        }
      }
    }

    // 3. Fetch driver name
    let driverName = "Rajesh Kumar";
    const driverRes = await query("SELECT name FROM drivers WHERE id = $1 LIMIT 1", [driver_id]);
    if (driverRes.rows.length > 0) {
      driverName = driverRes.rows[0].name;
    }

    return res.status(200).json({
      message: `Rating of ${rating}★ and ₹${tip_amount} tip submitted for ${driverName}!`,
      review_id: reviewId,
      rating: parseFloat(rating),
      tip_amount: parseFloat(tip_amount),
      tags: tags,
      driver_name: driverName,
    });
  } catch (error) {
    console.error("Error in rateRideDriver:", error);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to submit rating",
      },
    });
  }
};

const getRideReviewDetails = async (req, res) => {
  try {
    const rideId = req.query?.ride_id || req.body?.ride_id;
    let rideData = null;

    if (rideId) {
      const resRide = await query(
        `SELECT r.*, d.name as driver_name, d.phone as driver_phone, d.image_url as driver_image,
                d.vehicle_name, d.vehicle_number,
                sa.street as pickup_street, da.street as drop_street
         FROM rides r
         LEFT JOIN drivers d ON r.driver_id = d.id
         LEFT JOIN addresses sa ON r.source_address_id = sa.id
         LEFT JOIN addresses da ON r.destination_address_id = da.id
         WHERE r.id = $1 LIMIT 1`,
        [rideId]
      );
      if (resRide.rows.length > 0) {
        rideData = resRide.rows[0];
      }
    }

    if (!rideData) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride details not found." },
      });
    }

    return res.status(200).json({
      ride_id: rideData.id,
      status: rideData.status?.toUpperCase() || "COMPLETED",
      vehicle_type: rideData.vehicle_type,
      vehicle_number: rideData.vehicle_number || "",
      distance_km: rideData.distance_km || "",
      duration_mins: rideData.duration_mins || "",
      pickup_address: rideData.pickup_street || "",
      drop_address: rideData.drop_street || "",
      fare_paid: parseFloat(rideData.price || 0),
      payment_method: rideData.payment_method || "Paid",
      driver: {
        id: rideData.driver_id,
        name: rideData.driver_name || "Driver",
        vehicle_model: rideData.vehicle_name || "",
        rating: 5.0,
        total_trips: "",
        image_url: rideData.driver_image,
        verified: true,
      },
    });
  } catch (error) {
    console.error("Error in getRideReviewDetails:", error);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message,
      },
    });
  }
};

const DEFAULT_POPULAR_PLACES = [
  {
    id: "pop_001",
    place: "Kempegowda Int'l Airport (BLR)",
    street: "Airport Terminal 1 & 2, Devanahalli",
    type: "airport",
    distance_km: "28.5 km",
    duration_mins: 45,
    lat: 13.1986,
    lon: 77.7066,
  },
  {
    id: "pop_002",
    place: "Manyata Tech Park",
    street: "Outer Ring Rd, Nagavara, Bengaluru",
    type: "work",
    distance_km: "8.4 km",
    duration_mins: 22,
    lat: 13.0475,
    lon: 77.6215,
  },
  {
    id: "pop_003",
    place: "MG Road Metro Station",
    street: "MG Road, Trinity Circle Gate 2",
    type: "metro",
    distance_km: "3.2 km",
    duration_mins: 10,
    lat: 12.9756,
    lon: 77.6066,
  },
  {
    id: "pop_004",
    place: "Phoenix Marketcity Mall",
    street: "Whitefield Main Rd, Mahadevapura",
    type: "mall",
    distance_km: "12.0 km",
    duration_mins: 28,
    lat: 12.9959,
    lon: 77.6964,
  },
  {
    id: "pop_005",
    place: "City Railway Station",
    street: "Majestic Platform 1, Gubbi Thotadappa Rd",
    type: "train",
    distance_km: "4.8 km",
    duration_mins: 15,
    lat: 12.9784,
    lon: 77.5696,
  },
  {
    id: "pop_006",
    place: "Indiranagar 100ft Road",
    street: "100 Feet Rd, HAL 2nd Stage, Indiranagar",
    type: "popular",
    distance_km: "5.6 km",
    duration_mins: 16,
    lat: 12.9719,
    lon: 77.6412,
  },
  {
    id: "pop_007",
    place: "Apollo Hospital",
    street: "Bannerghatta Main Rd, Krishnaraju Layout",
    type: "hospital",
    distance_km: "7.1 km",
    duration_mins: 20,
    lat: 12.8943,
    lon: 77.5990,
  },
];

const searchPlaces = async (req, res) => {
  try {
    const rawQuery = (req.query?.query || "").trim();
    const userLat = req.query?.latitude ? parseFloat(req.query.latitude) : null;
    const userLon = req.query?.longitude ? parseFloat(req.query.longitude) : null;

    if (!rawQuery) {
      // If query is empty, return recent / saved places from database
      let initialPlaces = [];
      try {
        const resDb = await query(
          "SELECT id, place, street, lat, lon FROM addresses ORDER BY id DESC LIMIT 8"
        );
        initialPlaces = resDb.rows.map((r, i) => {
          const lat = parseFloat(r.lat);
          const lon = parseFloat(r.lon);
          let distText = `${(2.0 + i * 1.5).toFixed(1)} km`;
          let durMins = Math.round(5 + i * 4);
          if (userLat != null && userLon != null && !isNaN(lat) && !isNaN(lon)) {
            const directMeters = calculateHaversineDistance(userLat, userLon, lat, lon);
            const roadKm = (directMeters * 1.25) / 1000.0;
            distText = roadKm < 1.0 ? `${Math.round(roadKm * 1000)} m` : `${roadKm.toFixed(1)} km`;
            durMins = Math.max(3, Math.round(roadKm * 2.5));
          }
          return {
            id: r.id || `addr_${i}`,
            place: r.place || r.street.split(",")[0],
            street: r.street,
            type: "recent",
            distance_km: distText,
            duration_mins: durMins,
            lat: lat,
            lon: lon,
          };
        });
      } catch (_) {}
      return res.json({ places: initialPlaces });
    }

    // 1. Query PostgreSQL addresses table for local matches
    let dbPlaces = [];
    try {
      const resDb = await query(
        "SELECT id, place, street, lat, lon FROM addresses WHERE LOWER(place) LIKE $1 OR LOWER(street) LIKE $1 LIMIT 6",
        [`%${rawQuery.toLowerCase()}%`]
      );
      dbPlaces = resDb.rows.map((r, i) => {
        const lat = parseFloat(r.lat);
        const lon = parseFloat(r.lon);
        let distText = `${(2.0 + i * 1.2).toFixed(1)} km`;
        let durMins = Math.round(5 + i * 3);
        if (userLat != null && userLon != null && !isNaN(lat) && !isNaN(lon)) {
          const directMeters = calculateHaversineDistance(userLat, userLon, lat, lon);
          const roadKm = (directMeters * 1.25) / 1000.0;
          distText = roadKm < 1.0 ? `${Math.round(roadKm * 1000)} m` : `${roadKm.toFixed(1)} km`;
          durMins = Math.max(3, Math.round(roadKm * 2.5));
        }
        return {
          id: r.id || `addr_${i}`,
          place: r.place || r.street.split(",")[0],
          street: r.street,
          type: "recent",
          distance_km: distText,
          duration_mins: durMins,
          lat: lat,
          lon: lon,
        };
      });
    } catch (dbErr) {
      console.warn("Could not query addresses table:", dbErr.message);
    }

    // 2. Query live forward geocoder (Photon OSM with location bias and real-distance calculation)
    let geoPlaces = [];
    try {
      geoPlaces = await routingService.forwardGeocode(rawQuery, 8, userLat, userLon);
    } catch (geoErr) {
      console.warn("Live forward geocode warning:", geoErr.message);
    }

    // 3. Asynchronously cache geocoded results in database
    for (const p of geoPlaces) {
      if (p.lat && p.lon) {
        query(
          `INSERT INTO addresses (id, place, street, lat, lon, country)
           VALUES ($1, $2, $3, $4, $5, 'India')
           ON CONFLICT (id) DO NOTHING`,
          [p.id, p.place, p.street, p.lat, p.lon]
        ).catch(() => {});
      }
    }

    // Merge: Database cached matches + Live geocoded matches
    const combined = [...dbPlaces, ...geoPlaces];
    const seen = new Set();
    const finalPlaces = [];
    for (const item of combined) {
      const key = `${(item.place || item.street).toLowerCase()}_${Number(item.lat || 0).toFixed(2)}_${Number(item.lon || 0).toFixed(2)}`;
      if (!seen.has(key)) {
        seen.add(key);
        finalPlaces.push(item);
      }
    }

    return res.json({ places: finalPlaces });
  } catch (error) {
    console.error("Error in searchPlaces:", error);
    return res.status(500).json({ error: { message: error.message } });
  }
};

const getSavedAndRecentPlaces = async (req, res) => {
  try {
    const userId = req.user?.id || req.query?.user_id;
    let savedHome = null;
    let savedOffice = null;
    let recentPlaces = [];

    if (userId) {
      try {
        const placesRes = await query("SELECT id, title, address, type, lat, lon FROM saved_places WHERE user_id = $1", [userId]);
        for (const row of placesRes.rows) {
          const item = {
            id: row.id,
            place: row.title,
            street: row.address,
            type: row.type,
            lat: row.lat,
            lon: row.lon,
          };
          if (row.type === "home") savedHome = item;
          else if (row.type === "work") savedOffice = item;
        }

        const recentRes = await query(
          `SELECT DISTINCT ON (da.street) r.id, da.place, da.street, da.lat, da.lon, r.start_time
           FROM rides r
           JOIN addresses da ON r.destination_address_id = da.id
           WHERE r.user_id = $1
           ORDER BY da.street, r.start_time DESC
           LIMIT 5;`,
          [userId]
        );
        recentPlaces = recentRes.rows.map(r => ({
          id: `rec_${r.id}`,
          place: r.place || r.street,
          street: r.street,
          type: "recent",
          lat: r.lat,
          lon: r.lon,
        }));
      } catch (_) {}
    }

    return res.json({
      home: savedHome,
      office: savedOffice,
      recent: recentPlaces,
      popular_categories: [
        { label: "Airport", icon: "flight", query: "Airport" },
        { label: "Metro", icon: "train", query: "Metro" },
        { label: "Tech Parks", icon: "business", query: "Tech Park" },
        { label: "Malls", icon: "shopping_bag", query: "Mall" },
      ],
    });
  } catch (error) {
    console.error("Error in getSavedAndRecentPlaces:", error);
    return res.status(500).json({ error: { message: error.message } });
  }
};

// GET /api/ride/:rideId/otp (Authenticated Passenger only)
const getUserRideOtp = async (req, res) => {
  try {
    const userId = req.user.id;
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    const rideRes = await query(
      `SELECT id, user_id, driver_id, otp, otp_expires_at, otp_verified, status, cancelled
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

    // Ownership: Only the authenticated passenger who booked the ride can view the OTP
    if (ride.user_id !== userId) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN",
          message: "You are not authorized to view this booking's OTP.",
        },
      });
    }

    if (ride.cancelled) {
      return res.status(400).json({
        error: { code: "RIDE_CANCELLED", message: "This ride booking has been cancelled." },
      });
    }

    const isExpired = ride.otp_expires_at && new Date() > new Date(ride.otp_expires_at);

    return res.status(200).json({
      ride_id: ride.id,
      otp: ride.otp,
      otp_verified: ride.otp_verified,
      expires_at: ride.otp_expires_at,
      is_expired: isExpired,
      status: ride.status,
    });
  } catch (err) {
    console.error("Error in getUserRideOtp:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// GET /api/ride/:rideId/status
const getRideStatus = async (req, res) => {
  try {
    const { rideId } = req.params;

    if (!rideId) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing rideId parameter." },
      });
    }

    const rideRes = await query(
      `SELECT id, user_id, driver_id, status, cancelled, cancelled_by, cancellation_reason, cancellation_notes, cancelled_at,
              arrived_at, trip_started_at, end_time, price, discount_price, vehicle_type
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

    let driverInfo = null;
    if (ride.driver_id) {
      const dRes = await query(
        `SELECT d.id, d.name, d.phone, d.image_url, d.current_lat, d.current_lng,
                COALESCE(dv.registration_number, d.vehicle_number) as vehicle_number,
                COALESCE(dv.model, d.vehicle_model) as vehicle_model,
                COALESCE(dv.category, d.vehicle_name) as vehicle_name
         FROM drivers d
         LEFT JOIN driver_vehicles dv ON d.id = dv.driver_id AND dv.is_active = true
         WHERE d.id = $1 LIMIT 1`,
        [ride.driver_id]
      );
      if (dRes.rows.length > 0) {
        driverInfo = dRes.rows[0];
      }
    }

    return res.status(200).json({
      ride_id: ride.id,
      status: ride.status,
      cancelled: ride.cancelled,
      cancelled_by: ride.cancelled_by,
      cancellation_reason: ride.cancellation_reason,
      cancellation_notes: ride.cancellation_notes,
      cancelled_at: ride.cancelled_at,
      driver_id: ride.driver_id,
      driver: driverInfo,
      arrived_at: ride.arrived_at,
      trip_started_at: ride.trip_started_at,
      end_time: ride.end_time,
      price: ride.price,
      vehicle_type: ride.vehicle_type,
    });
  } catch (err) {
    console.error("Error in getRideStatus:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

// GET /api/ride/nearby_availability
// Query: latitude, longitude, radius_km (default 3.0), category (optional)
const getNearbyVehicleAvailability = async (req, res) => {
  try {
    const lat = parseFloat(req.query.latitude ?? req.query.lat ?? req.body?.latitude);
    const lon = parseFloat(req.query.longitude ?? req.query.lng ?? req.query.lon ?? req.body?.longitude);
    const requestedRadius = parseFloat(req.query.radius_km ?? req.query.radius ?? 3.0);
    const specificCategory = req.query.category ? normalizeCategory(req.query.category) : null;

    if (isNaN(lat) || isNaN(lon) || lat < -90 || lat > 90 || lon < -180 || lon > 180) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "Valid latitude and longitude coordinates are required.",
        },
      });
    }

    // Query all online, verified drivers with active verified vehicle, fresh GPS, and no active rides
    const sql = `
      SELECT 
        d.id, d.name, d.current_lat, d.current_lng, d.heading, d.speed,
        d.last_location_updated_at,
        dv.category, dv.model as vehicle_model,
        COALESCE((SELECT AVG(rating) FROM ride_reviews WHERE driver_id = d.id), 4.9)::float as rating
      FROM drivers d
      JOIN driver_vehicles dv ON d.id = dv.driver_id AND dv.is_active = true
      WHERE (d.is_online = true OR d.active = true)
        AND COALESCE(d.verification_status, 'Approved') ILIKE 'approved'
        AND dv.verification_status ILIKE 'approved'
        AND d.current_lat IS NOT NULL 
        AND d.current_lng IS NOT NULL
        AND (d.last_location_updated_at IS NULL OR d.last_location_updated_at >= NOW() - INTERVAL '3 minutes')
        AND NOT EXISTS (
          SELECT 1 FROM rides r 
          WHERE r.driver_id = d.id 
            AND r.end_time IS NULL 
            AND r.cancelled = false 
            AND r.status IN ('requested', 'accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started')
        )
    `;

    const result = await query(sql);

    // Compute distance for all matching drivers
    const driversWithDist = [];
    for (const d of result.rows) {
      const distance = calculateHaversineDistance(lat, lon, d.current_lat, d.current_lng);
      const normalizedCat = normalizeCategory(d.category);
      if (!specificCategory || normalizedCat.toLowerCase() === specificCategory.toLowerCase()) {
        driversWithDist.push({
          ...d,
          category: normalizedCat,
          distance_km: distance,
        });
      }
    }

    // Progressive radius search: try requestedRadius, then 6km, then 10km if 0 drivers found
    const expansionTiers = [requestedRadius, 6.0, 10.0, 15.0].filter(
      (r, i, arr) => arr.indexOf(r) === i && r >= requestedRadius
    );

    let effectiveRadius = requestedRadius;
    let qualifyingDrivers = [];

    for (const tier of expansionTiers) {
      const inTier = driversWithDist.filter((d) => d.distance_km <= tier);
      if (inTier.length > 0) {
        effectiveRadius = tier;
        qualifyingDrivers = inTier;
        break;
      }
    }

    if (qualifyingDrivers.length === 0) {
      qualifyingDrivers = driversWithDist.filter((d) => d.distance_km <= requestedRadius);
    }

    // Standard vehicle categories with live dynamic Super Admin rates from fare_configs
    const standardCategories = ["Bike", "Auto", "Mini Car", "Sedan", "SUV"];
    const dynamicBaseFares = {
      "Bike": 20.0,
      "Auto": 30.0,
      "Mini Car": 50.0,
      "Sedan": 70.0,
      "SUV": 90.0,
    };
    const dynamicPerKmFares = {
      "Bike": 8.0,
      "Auto": 12.0,
      "Mini Car": 15.0,
      "Sedan": 18.0,
      "SUV": 22.0,
    };

    try {
      const fareConfigsRes = await query("SELECT category, base_fare, per_km, minimum_fare FROM fare_configs WHERE is_active = true");
      for (const f of fareConfigsRes.rows) {
        const c = (f.category || "").toLowerCase();
        const bf = parseFloat(f.base_fare);
        const pk = parseFloat(f.per_km);
        if (c === "bike") { dynamicBaseFares["Bike"] = bf; dynamicPerKmFares["Bike"] = pk; }
        else if (c === "auto") { dynamicBaseFares["Auto"] = bf; dynamicPerKmFares["Auto"] = pk; }
        else if (c === "car" || c === "mini" || c === "mini car") { dynamicBaseFares["Mini Car"] = bf; dynamicPerKmFares["Mini Car"] = pk; }
        else if (c.includes("sedan")) { dynamicBaseFares["Sedan"] = bf; dynamicPerKmFares["Sedan"] = pk; }
        else if (c.includes("suv")) { dynamicBaseFares["SUV"] = bf; dynamicPerKmFares["SUV"] = pk; }
      }
    } catch (_) {}

    const categoryDetails = {};
    for (const cat of standardCategories) {
      const catDrivers = qualifyingDrivers.filter(
        (d) => d.category.toLowerCase() === cat.toLowerCase()
      );
      catDrivers.sort((a, b) => a.distance_km - b.distance_km);

      if (catDrivers.length > 0) {
        const closestDist = catDrivers[0].distance_km;
        const etaMins = calculateEtaMinutes(closestDist, cat);
        categoryDetails[cat] = {
          available: true,
          count: catDrivers.length,
          closest_distance_km: closestDist,
          eta_mins: etaMins,
          eta_text: `${etaMins} mins`,
          base_fare: dynamicBaseFares[cat] || 50.0,
          per_km: dynamicPerKmFares[cat] || 15.0,
        };
      } else {
        categoryDetails[cat] = {
          available: false,
          count: 0,
          closest_distance_km: null,
          eta_mins: null,
          eta_text: "No drivers",
          base_fare: dynamicBaseFares[cat] || 50.0,
          per_km: dynamicPerKmFares[cat] || 15.0,
        };
      }
    }

    // Obfuscated vehicle positions for map display (Privacy: No driver ID, name, or exact residential address)
    const vehicleMarkers = qualifyingDrivers.slice(0, 30).map((d, index) => {
      // Deterministic small noise based on driver ID string hash (~30-60m jitter)
      const hash = d.id.split("").reduce((acc, c) => acc + c.charCodeAt(0), 0);
      const latOffset = ((hash % 7) - 3) * 0.00015;
      const lngOffset = (((hash >> 2) % 7) - 3) * 0.00015;
      const obfuscatedLat = Math.round((d.current_lat + latOffset) * 10000) / 10000;
      const obfuscatedLng = Math.round((d.current_lng + lngOffset) * 10000) / 10000;

      return {
        id: `veh_${index + 1}`,
        category: d.category,
        latitude: obfuscatedLat,
        longitude: obfuscatedLng,
        heading: d.heading || 0.0,
        distance_km: d.distance_km,
      };
    });

    return res.status(200).json({
      success: true,
      search_center: { latitude: lat, longitude: lon },
      search_radius_km: effectiveRadius,
      radius_expanded: effectiveRadius > requestedRadius,
      total_nearby_drivers: qualifyingDrivers.length,
      categories: categoryDetails,
      vehicles: vehicleMarkers,
    });
  } catch (err) {
    console.error("Error in getNearbyVehicleAvailability:", err);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: err.message },
    });
  }
};

const getActiveRideForUser = async (req, res) => {
  try {
    const userId = req.user?.id || req.query?.user_id;
    if (!userId) {
      return res.status(400).json({ error: { code: "EMPTY_PARAM", message: "User ID required." } });
    }

    // Auto-expire stale requested rides older than 5 minutes
    await query(
      `UPDATE rides 
       SET status = 'cancelled', cancelled = true 
       WHERE user_id = $1 AND status = 'requested' AND start_time < NOW() - INTERVAL '5 minutes'`,
      [userId]
    ).catch(() => {});

    const activeRes = await query(
      `SELECT 
        r.id as ride_id, r.user_id, r.driver_id, r.status, r.otp, r.price, r.vehicle_type,
        r.start_time, r.reaching_pickup_at, r.arrived_at, r.trip_started_at,
        sa.street as pickup_address, sa.lat as pickup_lat, sa.lon as pickup_lon,
        da.street as destination_address, da.lat as dest_lat, da.lon as dest_lon,
        d.name as driver_name, d.phone as driver_phone, d.image_url as driver_image_url,
        d.vehicle_name, d.vehicle_number, d.current_lat, d.current_lng, d.heading,
        COALESCE(dp.rating, 4.9)::text as driver_rating,
        COALESCE(dp.total_trips, 3240)::text as driver_trips
       FROM rides r
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       LEFT JOIN drivers d ON r.driver_id = d.id
       LEFT JOIN driver_profiles dp ON d.id = dp.driver_id
       WHERE r.user_id = $1 
         AND r.cancelled = false 
         AND r.status IN ('accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started')
         AND r.driver_id IS NOT NULL
         AND r.start_time > NOW() - INTERVAL '3 hours'
       ORDER BY r.start_time DESC
       LIMIT 1`,
      [userId]
    );

    if (activeRes.rows.length === 0) {
      return res.status(200).json({ active_ride: null });
    }

    return res.status(200).json({ active_ride: activeRes.rows[0] });
  } catch (err) {
    console.error("Error in getActiveRideForUser:", err);
    return res.status(500).json({ error: { code: "SERVER_ERROR", message: err.message } });
  }
};

/**
 * GET /api/ride/route
 * Proxy route calculation between two GPS coordinates
 */
const getRouteBetweenPoints = async (req, res) => {
  try {
    const originLat = req.query?.origin_lat || req.body?.origin_lat;
    const originLon = req.query?.origin_lon || req.body?.origin_lon;
    const destLat = req.query?.dest_lat || req.body?.dest_lat;
    const destLon = req.query?.dest_lon || req.body?.dest_lon;
    const vehicleType = req.query?.vehicle_type || req.body?.vehicle_type || "Auto";

    if (!originLat || !originLon || !destLat || !destLon) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "origin_lat, origin_lon, dest_lat, and dest_lon are required parameters.",
        },
      });
    }

    const route = await routingService.calculateRoute(originLat, originLon, destLat, destLon, vehicleType);
    return res.status(200).json(route);
  } catch (error) {
    console.error("Error in getRouteBetweenPoints:", error);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to calculate route.",
      },
    });
  }
};

/**
 * GET /api/ride/geocode/reverse
 * Proxy reverse geocoding from GPS coordinates to human-readable address
 */
const reverseGeocodeLocation = async (req, res) => {
  try {
    const lat = req.query?.lat || req.query?.latitude || req.body?.lat || req.body?.latitude;
    const lon = req.query?.lon || req.query?.longitude || req.body?.lon || req.body?.longitude;

    if (!lat || !lon) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "lat and lon parameters are required.",
        },
      });
    }

    const geocoded = await routingService.reverseGeocode(lat, lon);
    return res.status(200).json(geocoded);
  } catch (error) {
    console.error("Error in reverseGeocodeLocation:", error);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to reverse geocode location.",
      },
    });
  }
};

module.exports = {
  getPreviousRidesOfUser,
  addRideAndRideAddresses,
  cancelRide,
  getPriceInfoAndCalculateRidePrice,
  findRideDriver,
  getRideOptions,
  rebookRide,
  rateRideDriver,
  getRideReviewDetails,
  searchPlaces,
  getSavedAndRecentPlaces,
  getUserRideOtp,
  getRideStatus,
  getNearbyVehicleAvailability,
  getActiveRideForUser,
  getRouteBetweenPoints,
  reverseGeocodeLocation,
};

