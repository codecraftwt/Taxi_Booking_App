const crypto = require("crypto");
const { v4: uuidv4 } = require("uuid");
const { pool, query } = require("../../database");
const fareService = require("../fare_calculation/fare.service");
const redisService = require("../../services/redisService");
const {
  emitDriverReachingPickup,
  emitDriverArrived,
  emitTripStarted,
  emitTripCompleted,
} = require("../../socket");

const OTP_SALT = process.env.OTP_SECRET || "saffar_otp_secure_salt_2026";

function computeOtpHash(otp, rideId) {
  return crypto.createHash("sha256").update(`${otp}:${rideId}:${OTP_SALT}`).digest("hex");
}

function generateRandomOtp() {
  return Math.floor(1000 + Math.random() * 9000).toString();
}

/**
 * Marks driver as en route to pickup location
 */
async function markReachingPickup(rideId, driverId) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    const rideRes = await client.query(
      `SELECT id, user_id, driver_id, status FROM rides WHERE id = $1 FOR UPDATE;`,
      [rideId]
    );
    if (rideRes.rows.length === 0) {
      await client.query("ROLLBACK;");
      throw new Error("Ride not found.");
    }
    const ride = rideRes.rows[0];
    if (ride.driver_id !== driverId) {
      await client.query("ROLLBACK;");
      throw new Error("Driver not assigned to this ride.");
    }

    await client.query(
      `UPDATE rides 
       SET status = 'reaching_pickup', reaching_pickup_at = (NOW() AT TIME ZONE 'UTC') 
       WHERE id = $1;`,
      [rideId]
    );

    await client.query(
      `INSERT INTO ride_status_history (id, ride_id, old_status, new_status, triggered_by_role, triggered_by_id)
       VALUES ($1, $2, $3, 'reaching_pickup', 'driver', $4);`,
      [`hist_${uuidv4().slice(0, 8)}`, rideId, ride.status, driverId]
    );

    await client.query("COMMIT;");

    emitDriverReachingPickup(rideId, ride.user_id, {
      ride_id: rideId,
      status: "reaching_pickup",
      timestamp: new Date().toISOString(),
    });

    return { success: true, status: "reaching_pickup" };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Marks driver as arrived at the customer pickup location
 */
async function markDriverArrived(rideId, driverId) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    const rideRes = await client.query(
      `SELECT id, user_id, driver_id, status FROM rides WHERE id = $1 FOR UPDATE;`,
      [rideId]
    );
    if (rideRes.rows.length === 0) {
      await client.query("ROLLBACK;");
      throw new Error("Ride not found.");
    }
    const ride = rideRes.rows[0];
    if (ride.driver_id !== driverId) {
      await client.query("ROLLBACK;");
      throw new Error("Driver not assigned to this ride.");
    }

    await client.query(
      `UPDATE rides 
       SET status = 'arrived', arrived_at = (NOW() AT TIME ZONE 'UTC') 
       WHERE id = $1;`,
      [rideId]
    );

    await client.query(
      `INSERT INTO ride_status_history (id, ride_id, old_status, new_status, triggered_by_role, triggered_by_id)
       VALUES ($1, $2, $3, 'arrived', 'driver', $4);`,
      [`hist_${uuidv4().slice(0, 8)}`, rideId, ride.status, driverId]
    );

    await client.query("COMMIT;");

    emitDriverArrived(rideId, ride.user_id, {
      ride_id: rideId,
      status: "arrived",
      timestamp: new Date().toISOString(),
    });

    return { success: true, status: "arrived" };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Validates 4-digit OTP using cryptographic salt-hash comparison with brute-force lockout
 */
async function verifyOtpAndStartTrip(rideId, driverId, submittedOtp) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    const rideRes = await client.query(
      `SELECT id, user_id, driver_id, status, otp, otp_hash, otp_attempts, max_otp_attempts, otp_verified 
       FROM rides WHERE id = $1 FOR UPDATE;`,
      [rideId]
    );
    if (rideRes.rows.length === 0) {
      await client.query("ROLLBACK;");
      throw new Error("Ride not found.");
    }
    const ride = rideRes.rows[0];

    if (ride.driver_id !== driverId) {
      await client.query("ROLLBACK;");
      throw new Error("Driver not assigned to this ride.");
    }

    const maxAttempts = ride.max_otp_attempts || 5;
    const currentAttempts = ride.otp_attempts || 0;

    // Check brute force threshold
    if (currentAttempts >= maxAttempts) {
      await client.query("ROLLBACK;");
      return {
        success: false,
        code: "OTP_MAX_ATTEMPTS_EXCEEDED",
        message: "Maximum OTP verification attempts exceeded. Ride is temporarily locked.",
      };
    }

    // Verify OTP: Check hash or fallback match
    const expectedHash = ride.otp_hash || computeOtpHash(ride.otp, rideId);
    const submittedHash = computeOtpHash(submittedOtp.toString().trim(), rideId);
    const isDirectMatch = submittedOtp.toString().trim() === (ride.otp || "").toString().trim();

    if (submittedHash !== expectedHash && !isDirectMatch) {
      const nextAttempts = currentAttempts + 1;
      await client.query(
        `UPDATE rides SET otp_attempts = $1 WHERE id = $2;`,
        [nextAttempts, rideId]
      );
      await client.query("COMMIT;");
      return {
        success: false,
        code: "INVALID_OTP",
        message: `Incorrect OTP. ${maxAttempts - nextAttempts} attempts remaining.`,
        remainingAttempts: maxAttempts - nextAttempts,
      };
    }

    // Valid OTP: Transition to in_progress
    await client.query(
      `UPDATE rides 
       SET status = 'in_progress', otp_verified = true, trip_started_at = (NOW() AT TIME ZONE 'UTC') 
       WHERE id = $1;`,
      [rideId]
    );

    await client.query(
      `INSERT INTO ride_status_history (id, ride_id, old_status, new_status, triggered_by_role, triggered_by_id)
       VALUES ($1, $2, $3, 'in_progress', 'driver', $4);`,
      [`hist_${uuidv4().slice(0, 8)}`, rideId, ride.status, driverId]
    );

    await client.query("COMMIT;");

    // Emit real-time trip start
    emitTripStarted(rideId, ride.user_id, {
      ride_id: rideId,
      status: "in_progress",
      started_at: new Date().toISOString(),
    });

    return {
      success: true,
      status: "in_progress",
      startedAt: new Date().toISOString(),
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Concludes active trip, calculates itemized fare in minor units, records driver earnings (15% commission)
 */
async function completeTrip(rideId, driverId, { distanceKm = 8.4, durationMinutes = 22 }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    const rideRes = await client.query(
      `SELECT r.id, r.user_id, r.driver_id, r.status, r.price, r.vehicle_type, r.payment_method,
              u.name as passenger_name, sa.street as pickup_street, da.street as dest_street
       FROM rides r
       LEFT JOIN users u ON r.user_id = u.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE r.id = $1 FOR UPDATE;`,
      [rideId]
    );
    if (rideRes.rows.length === 0) {
      await client.query("ROLLBACK;");
      throw new Error("Ride not found.");
    }
    const ride = rideRes.rows[0];

    if (ride.driver_id !== driverId) {
      await client.query("ROLLBACK;");
      throw new Error("Driver not assigned to this ride.");
    }

    if (ride.status === "completed") {
      await client.query("ROLLBACK;");
      return { success: true, message: "Ride is already completed.", rideId };
    }

    // 1. Calculate fare breakdown in integer minor units (Paise)
    const fareCalc = await fareService.calculateFareEstimate({
      distanceKm,
      durationMinutes,
      category: ride.vehicle_type || "Auto",
    });

    const finalFareAmount = fareCalc.display.totalFare;
    const grossFareMinor = fareCalc.minorUnits.grossFare;
    const platformCommissionMinor = fareCalc.minorUnits.platformCommission;
    const netEarningsMinor = fareCalc.minorUnits.driverNetEarnings;

    // 2. Mark ride completed in database
    await client.query(
      `UPDATE rides 
       SET status = 'completed', end_time = (NOW() AT TIME ZONE 'UTC'), price = $1 
       WHERE id = $2;`,
      [finalFareAmount, rideId]
    );

    // 3. Insert normalized fare_breakdowns record
    await client.query(`
      INSERT INTO fare_breakdowns (
        id, ride_id, currency, base_fare_minor, distance_fare_minor, 
        platform_fee_minor, total_fare_minor, driver_net_earnings_minor
      ) VALUES ($1, $2, 'INR', $3, $4, $5, $6, $7)
      ON CONFLICT (ride_id) DO NOTHING;
    `, [
      `fb_${uuidv4().slice(0, 8)}`, rideId,
      fareCalc.minorUnits.baseFare, fareCalc.minorUnits.distanceFare,
      platformCommissionMinor, grossFareMinor, netEarningsMinor
    ]);

    // 4. Record driver_earnings (15% platform commission)
    const earningsId = `earn_${uuidv4().slice(0, 8)}`;
    await client.query(`
      INSERT INTO driver_earnings (
        id, driver_id, ride_id, amount, gross_fare, commission_rate, 
        commission_amount, net_earnings, distance_km, duration_minutes, 
        payment_status, payment_method
      ) VALUES ($1, $2, $3, $4, $5, 0.15, $6, $7, $8, $9, 'Paid', $10)
      ON CONFLICT (ride_id) DO UPDATE SET 
        gross_fare = EXCLUDED.gross_fare,
        commission_amount = EXCLUDED.commission_amount,
        net_earnings = EXCLUDED.net_earnings;
    `, [
      earningsId, driverId, rideId,
      netEarningsMinor / 100, grossFareAmount(finalFareAmount),
      platformCommissionMinor / 100, netEarningsMinor / 100,
      distanceKm, durationMinutes, ride.payment_method || "Paid via UPI / Cash"
    ]);

    // 5. Update driver availability state to ONLINE_AVAILABLE
    await client.query(`
      UPDATE driver_availability 
      SET state = 'ONLINE_AVAILABLE', current_ride_id = NULL, last_state_change = (NOW() AT TIME ZONE 'UTC') 
      WHERE driver_id = $1;
    `, [driverId]);

    // 6. Increment completed trips on driver_profiles
    await client.query(`
      UPDATE driver_profiles SET total_trips = total_trips + 1 WHERE driver_id = $1;
    `, [driverId]);

    // 7. Audit log
    await client.query(
      `INSERT INTO ride_status_history (id, ride_id, old_status, new_status, triggered_by_role, triggered_by_id)
       VALUES ($1, $2, $3, 'completed', 'driver', $4);`,
      [`hist_${uuidv4().slice(0, 8)}`, rideId, ride.status, driverId]
    );

    await client.query("COMMIT;");

    // 8. Update Redis state
    await redisService.setDriverAvailability(driverId, "ONLINE_AVAILABLE", null);

    // 9. Emit real-time trip completion to rider
    emitTripCompleted(rideId, ride.user_id, {
      ride_id: rideId,
      status: "completed",
      final_fare: finalFareAmount,
      distance_km: distanceKm,
      duration_minutes: durationMinutes,
      passenger_name: ride.passenger_name || "Passenger",
      pickup_address: ride.pickup_street || "Pickup Point",
      destination_address: ride.dest_street || "Destination Point",
      payment_method: ride.payment_method || "Paid via UPI / Cash",
    });

    return {
      success: true,
      rideId,
      status: "completed",
      finalFare: finalFareAmount,
      driverNetEarnings: netEarningsMinor / 100,
      platformCommission: platformCommissionMinor / 100,
      distanceKm,
      durationMinutes,
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

function grossFareAmount(val) {
  return parseFloat(val) || 135.0;
}

module.exports = {
  computeOtpHash,
  generateRandomOtp,
  markReachingPickup,
  markDriverArrived,
  verifyOtpAndStartTrip,
  completeTrip,
};

