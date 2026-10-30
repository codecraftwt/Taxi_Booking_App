require("../config/polyfill");
const Err = require("../config/error");
const { query } = require("../database");

// GET driver profile by token
const getDriverProfile = async (req, res) => {
  try {
    const driverId = req.user.id;
    const driverRes = await query(
      "SELECT id, name, phone, email, vehicle_name, vehicle_number, image_url, active, created_at FROM drivers WHERE id = $1",
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
    const { name, email, vehicle_name, vehicle_number, image_url } = req.body;
    
    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (name !== undefined) { fields.push(`name = $${paramIndex++}`); values.push(name); }
    if (email !== undefined) { fields.push(`email = $${paramIndex++}`); values.push(email); }
    if (vehicle_name !== undefined) { fields.push(`vehicle_name = $${paramIndex++}`); values.push(vehicle_name); }
    if (vehicle_number !== undefined) { fields.push(`vehicle_number = $${paramIndex++}`); values.push(vehicle_number); }
    if (image_url !== undefined) { fields.push(`image_url = $${paramIndex++}`); values.push(image_url); }

    if (fields.length === 0) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "No fields to update." },
      });
    }

    values.push(driverId);
    const result = await query(
      `UPDATE drivers SET ${fields.join(", ")} WHERE id = $${paramIndex} RETURNING id, name, phone, email, vehicle_name, vehicle_number, image_url, active, created_at`,
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

// POST toggle driver availability (online/offline)
const toggleAvailability = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { active } = req.body;

    if (active === undefined) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Missing 'active' field." },
      });
    }

    // If going offline, check for active rides (rides with no end_time and not cancelled)
    if (active === false) {
      const activeRides = await query(
        "SELECT id FROM rides WHERE driver_id = $1 AND end_time IS NULL AND cancelled = false",
        [driverId]
      );
      if (activeRides.rows.length > 0) {
        return res.status(400).json({
          error: { code: "ACTIVE_RIDE_EXISTS", message: "Cannot go offline while you have an active ride." },
        });
      }
    }

    const result = await query(
      "UPDATE drivers SET active = $1 WHERE id = $2 RETURNING id, name, phone, email, vehicle_name, vehicle_number, image_url, active",
      [active, driverId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: "NO_DRIVER_WITH_ID", message: "No driver found with this ID." },
      });
    }

    return res.status(200).json({
      message: active ? "Driver is now online." : "Driver is now offline.",
      driver: result.rows[0],
    });
  } catch (error) {
    console.log(`Error in toggleAvailability: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET driver ride history
const getDriverRideHistory = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { page = 1, limit = 20, status } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let whereClause = "WHERE r.driver_id = $1";
    const params = [driverId];
    let paramIdx = 2;

    if (status === "completed") {
      whereClause += ` AND r.end_time IS NOT NULL AND r.cancelled = false`;
    } else if (status === "cancelled") {
      whereClause += ` AND r.cancelled = true`;
    } else if (status === "active") {
      whereClause += ` AND r.end_time IS NULL AND r.cancelled = false`;
    }

    params.push(parseInt(limit), offset);

    const ridesRes = await query(
      `SELECT 
        r.id, r.start_time, r.end_time, r.cancelled, r.price, r.discount_price, r.created_at,
        json_build_object('id', u.id, 'name', u.name, 'phone', u.phone) as passenger,
        json_build_object('id', sa.id, 'place', sa.place, 'street', sa.street, 'state', sa.state, 'lat', sa.lat, 'lon', sa.lon) as source_address,
        json_build_object('id', da.id, 'place', da.place, 'street', da.street, 'state', da.state, 'lat', da.lat, 'lon', da.lon) as destination_address
      FROM rides r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      ${whereClause}
      ORDER BY r.start_time DESC
      LIMIT $${paramIdx++} OFFSET $${paramIdx}`,
      params
    );

    // Get total count
    const countRes = await query(
      `SELECT COUNT(*) as total FROM rides r ${whereClause}`,
      [driverId]
    );

    return res.status(200).json({
      message: "Ride history fetched successfully.",
      rides: ridesRes.rows,
      pagination: {
        page: parseInt(page),
        limit: parseInt(limit),
        total: parseInt(countRes.rows[0].total),
      },
    });
  } catch (error) {
    console.log(`Error in getDriverRideHistory: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET driver earnings summary
const getDriverEarningsSummary = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { period = "daily" } = req.query;

    let dateFilter = "";
    if (period === "daily") {
      dateFilter = "AND r.start_time >= CURRENT_DATE";
    } else if (period === "weekly") {
      dateFilter = "AND r.start_time >= CURRENT_DATE - INTERVAL '7 days'";
    } else if (period === "monthly") {
      dateFilter = "AND r.start_time >= CURRENT_DATE - INTERVAL '30 days'";
    }

    const earningsRes = await query(
      `SELECT 
        COALESCE(SUM(r.price), 0) as total_earnings,
        COALESCE(SUM(COALESCE(r.discount_price, 0)), 0) as total_discounts,
        COUNT(r.id) as total_rides,
        COUNT(CASE WHEN r.cancelled = true THEN 1 END) as cancelled_rides,
        COUNT(CASE WHEN r.end_time IS NOT NULL AND r.cancelled = false THEN 1 END) as completed_rides
      FROM rides r
      WHERE r.driver_id = $1 AND r.cancelled = false AND r.end_time IS NOT NULL ${dateFilter}`,
      [driverId]
    );

    const row = earningsRes.rows[0];

    return res.status(200).json({
      message: "Earnings summary fetched successfully.",
      earnings: {
        period: period,
        total_earnings: parseFloat(row.total_earnings),
        total_discounts: parseFloat(row.total_discounts),
        net_earnings: parseFloat(row.total_earnings) - parseFloat(row.total_discounts),
        total_rides: parseInt(row.total_rides),
        completed_rides: parseInt(row.completed_rides),
        cancelled_rides: parseInt(row.cancelled_rides),
      },
    });
  } catch (error) {
    console.log(`Error in getDriverEarningsSummary: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

// GET driver earnings history (individual rides with earnings)
const getDriverEarningsHistory = async (req, res) => {
  try {
    const driverId = req.user.id;
    const { page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    const ridesRes = await query(
      `SELECT 
        r.id, r.start_time, r.end_time, r.price, r.discount_price,
        json_build_object('place', sa.place, 'street', sa.street) as source_address,
        json_build_object('place', da.place, 'street', da.street) as destination_address
      FROM rides r
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      WHERE r.driver_id = $1 AND r.end_time IS NOT NULL AND r.cancelled = false
      ORDER BY r.end_time DESC
      LIMIT $2 OFFSET $3`,
      [driverId, parseInt(limit), offset]
    );

    return res.status(200).json({
      message: "Earnings history fetched successfully.",
      rides: ridesRes.rows,
    });
  } catch (error) {
    console.log(`Error in getDriverEarningsHistory: ${error}`);
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

    // Verify ride belongs to this driver and is not already completed
    const rideRes = await query(
      "SELECT id, end_time, cancelled FROM rides WHERE id = $1 AND driver_id = $2",
      [rideId, driverId]
    );

    if (rideRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride not found or does not belong to this driver." },
      });
    }

    if (rideRes.rows[0].end_time) {
      return res.status(400).json({
        error: { code: "RIDE_ALREADY_COMPLETED", message: "This ride is already completed." },
      });
    }

    if (rideRes.rows[0].cancelled) {
      return res.status(400).json({
        error: { code: "RIDE_CANCELLED", message: "Cannot complete a cancelled ride." },
      });
    }

    const result = await query(
      "UPDATE rides SET end_time = NOW() WHERE id = $1 RETURNING *",
      [rideId]
    );

    return res.status(200).json({
      message: "Ride completed successfully.",
      ride: result.rows[0],
    });
  } catch (error) {
    console.log(`Error in completeRide: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
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

module.exports = {
  getDriverProfile,
  updateDriverProfile,
  toggleAvailability,
  getDriverRideHistory,
  getDriverEarningsSummary,
  getDriverEarningsHistory,
  completeRide,
  getDriverDashboardStats,
};
