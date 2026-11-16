const { query } = require("../../database");

async function getDrivers(req, res) {
  try {
    const { status = "all", category, search, page = 1, limit = 15 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let whereClauses = [];
    let params = [];
    let paramIndex = 1;

    // Status filter
    if (status === "approved") {
      whereClauses.push("LOWER(COALESCE(d.verification_status, '')) = 'approved' AND d.active = true");
    } else if (status === "pending") {
      whereClauses.push("LOWER(COALESCE(d.verification_status, '')) = 'pending'");
    } else if (status === "rejected") {
      whereClauses.push("LOWER(COALESCE(d.verification_status, '')) = 'rejected'");
    } else if (status === "suspended") {
      whereClauses.push("d.active = false");
    } else if (status === "online") {
      whereClauses.push("d.is_online = true");
    } else if (status === "offline") {
      whereClauses.push("(d.is_online = false OR d.is_online IS NULL)");
    } else if (status === "on_trip") {
      whereClauses.push("d.id IN (SELECT driver_id FROM rides WHERE status IN ('driver_assigned', 'arrived', 'ongoing', 'trip_started'))");
    }

    // Category filter
    if (category && category !== "All") {
      whereClauses.push(`dv.category = $${paramIndex}`);
      params.push(category);
      paramIndex++;
    }

    // Search query
    if (search && search.trim() !== "") {
      const q = `%${search.trim().toLowerCase()}%`;
      whereClauses.push(`(LOWER(d.name) LIKE $${paramIndex} OR LOWER(d.phone) LIKE $${paramIndex} OR LOWER(d.vehicle_number) LIKE $${paramIndex} OR LOWER(COALESCE(d.email, '')) LIKE $${paramIndex})`);
      params.push(q);
      paramIndex++;
    }

    const whereSql = whereClauses.length > 0 ? "WHERE " + whereClauses.join(" AND ") : "";

    // Count total
    const countSql = `
      SELECT COUNT(DISTINCT d.id) as total
      FROM drivers d
      LEFT JOIN driver_vehicles dv ON d.id = dv.driver_id
      ${whereSql};
    `;
    const countRes = await query(countSql, params);
    const totalRecords = parseInt(countRes.rows[0]?.total || 0);

    // Fetch records
    const listSql = `
      SELECT 
        d.id, d.name, d.phone, d.email, d.image_url,
        d.vehicle_name, d.vehicle_number, d.verification_status,
        d.active, d.is_online, d.current_lat, d.current_lng,
        d.heading, d.speed, d.last_location_updated_at, d.created_at,
        COALESCE(dv.category, 'Auto') as category,
        COALESCE(dv.model, d.vehicle_name) as vehicle_model,
        COALESCE(dv.color, 'Standard') as vehicle_color,
        (SELECT COUNT(*) FROM rides r WHERE r.driver_id = d.id AND r.status = 'completed') as completed_rides,
        (SELECT COALESCE(AVG(rating), 5.0) FROM rides r WHERE r.driver_id = d.id AND r.rating IS NOT NULL) as rating,
        (SELECT COALESCE(SUM(price), 0.0) FROM rides r WHERE r.driver_id = d.id AND r.status = 'completed') as total_earnings
      FROM drivers d
      LEFT JOIN driver_vehicles dv ON d.id = dv.driver_id
      ${whereSql}
      ORDER BY d.created_at DESC
      LIMIT $${paramIndex} OFFSET $${paramIndex + 1};
    `;
    params.push(parseInt(limit), offset);

    const listRes = await query(listSql, params);

    return res.status(200).json({
      success: true,
      data: {
        drivers: listRes.rows,
        pagination: {
          total: totalRecords,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: Math.ceil(totalRecords / parseInt(limit)) || 1,
        },
      },
    });
  } catch (err) {
    console.error("[GET DRIVERS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function getDriverDetails(req, res) {
  try {
    const { driverId } = req.params;

    // 1. Basic driver info
    const driverRes = await query(
      `SELECT d.*, 
        (SELECT COUNT(*) FROM rides r WHERE r.driver_id = d.id AND r.status = 'completed') as total_rides_count,
        (SELECT COUNT(*) FROM rides r WHERE r.driver_id = d.id AND (r.status = 'cancelled' OR r.cancelled = true)) as cancelled_rides_count,
        (SELECT COALESCE(AVG(rating), 5.0) FROM rides r WHERE r.driver_id = d.id AND r.rating IS NOT NULL) as avg_rating,
        (SELECT COALESCE(SUM(price), 0.0) FROM rides r WHERE r.driver_id = d.id AND r.status = 'completed') as total_gross_earnings
       FROM drivers d WHERE d.id = $1`,
      [driverId]
    );

    if (driverRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Driver not found." });
    }

    const driver = driverRes.rows[0];

    // 2. Vehicle Info
    const vehicleRes = await query(
      `SELECT * FROM driver_vehicles WHERE driver_id = $1 LIMIT 1`,
      [driverId]
    );

    // 3. Documents
    const docsRes = await query(
      `SELECT * FROM driver_documents WHERE driver_id = $1 ORDER BY created_at DESC`,
      [driverId]
    );

    // 4. Recent Rides (10)
    const ridesRes = await query(
      `SELECT r.id, r.status, r.price, r.start_time, r.rating, r.cancelled,
              u.name as customer_name, u.phone as customer_phone,
              sa.place as pickup_place, da.place as drop_place
       FROM rides r
       LEFT JOIN users u ON r.user_id = u.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE r.driver_id = $1
       ORDER BY r.start_time DESC
       LIMIT 10`,
      [driverId]
    );

    const grossEarnings = parseFloat(driver.total_gross_earnings || 0);
    const platformCommission = Math.round(grossEarnings * 0.15);
    const netEarnings = Math.round(grossEarnings - platformCommission);

    return res.status(200).json({
      success: true,
      data: {
        driver: {
          ...driver,
          password: undefined, // Never send password hash
        },
        vehicle: vehicleRes.rows[0] || null,
        documents: docsRes.rows,
        recentRides: ridesRes.rows,
        financialSummary: {
          grossEarnings,
          platformCommission,
          netEarnings,
        },
      },
    });
  } catch (err) {
    console.error("[GET DRIVER DETAILS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function updateDriverStatus(req, res) {
  try {
    const { driverId } = req.params;
    const { action, reason } = req.body;
    // action: 'approve', 'reject', 'suspend', 'activate'

    if (!["approve", "reject", "suspend", "activate"].includes(action)) {
      return res.status(400).json({
        success: false,
        message: "Invalid action. Must be approve, reject, suspend, or activate.",
      });
    }

    let updateFields = "";
    let params = [driverId];

    if (action === "approve") {
      updateFields = "verification_status = 'approved', active = true";
    } else if (action === "reject") {
      if (!reason || reason.trim().length < 5) {
        return res.status(400).json({
          success: false,
          message: "A specific rejection reason of at least 5 characters is required.",
        });
      }
      updateFields = "verification_status = 'rejected', active = false";
    } else if (action === "suspend") {
      if (!reason || reason.trim().length < 5) {
        return res.status(400).json({
          success: false,
          message: "A specific suspension reason of at least 5 characters is required.",
        });
      }
      updateFields = "active = false, is_online = false";
    } else if (action === "activate") {
      updateFields = "active = true";
    }

    await query(`UPDATE drivers SET ${updateFields} WHERE id = $1`, params);

    // Also update driver_vehicles and driver_documents status if approving/rejecting
    if (action === "approve") {
      await query("UPDATE driver_vehicles SET verification_status = 'approved', is_active = true WHERE driver_id = $1", [driverId]);
      await query("UPDATE driver_documents SET verification_status = 'approved', verified_at = NOW() WHERE driver_id = $1", [driverId]);
    } else if (action === "reject") {
      await query("UPDATE driver_vehicles SET verification_status = 'rejected', rejection_reason = $1 WHERE driver_id = $2", [reason, driverId]);
      await query("UPDATE driver_documents SET verification_status = 'rejected', rejection_reason = $1 WHERE driver_id = $2", [reason, driverId]);
    }

    // Write audit log
    await query(
      `INSERT INTO admin_audit_logs (id, admin_id, admin_name, action, target_type, target_id, details, ip_address)
       VALUES ('log_' || substr(md5(random()::text), 1, 16), $1, $2, $3, 'driver', $4, $5, $6)`,
      [
        req.admin.id,
        req.admin.name,
        action.toUpperCase() + "_DRIVER",
        driverId,
        `Driver status set to ${action}. Reason: ${reason || "Admin standard action"}`,
        req.ip || "127.0.0.1",
      ]
    );

    // Real-time WebSocket event broadcast to driver's app
    try {
      const { emitDriverStatusUpdated } = require("../../socket");
      const normalizedStatus = action === "approve" ? "approved" : (action === "reject" ? "rejected" : (action === "suspend" ? "suspended" : "approved"));
      emitDriverStatusUpdated(driverId, {
        driver_id: driverId,
        verification_status: normalizedStatus,
        active: action === "approve" || action === "activate",
        action: action,
        reason: reason || null,
      });
    } catch (sockErr) {
      console.warn("[SOCKET NOTIFY ERROR] Could not emit driver status update:", sockErr.message);
    }

    return res.status(200).json({
      success: true,
      message: `Driver has been successfully ${action}d.`,
    });
  } catch (err) {
    console.error("[UPDATE DRIVER STATUS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function updateDriverDetails(req, res) {
  try {
    const { driverId } = req.params;
    const { name, phone, email, address, vehicleName, vehicleNumber, vehicleCategory } = req.body;

    await query(
      `UPDATE drivers 
       SET name = COALESCE($1, name),
           phone = COALESCE($2, phone),
           email = COALESCE($3, email),
           address = COALESCE($4, address),
           vehicle_name = COALESCE($5, vehicle_name),
           vehicle_number = COALESCE($6, vehicle_number)
       WHERE id = $7`,
      [name, phone, email, address, vehicleName, vehicleNumber, driverId]
    );

    if (vehicleCategory) {
      await query(
        `UPDATE driver_vehicles 
         SET category = $1, 
             registration_number = COALESCE($2, registration_number),
             model = COALESCE($3, model)
         WHERE driver_id = $4`,
        [vehicleCategory, vehicleNumber, vehicleName, driverId]
      );
    }

    return res.status(200).json({
      success: true,
      message: "Driver profile updated successfully.",
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function deleteDriver(req, res) {
  try {
    const { driverId } = req.params;
    await query(`DELETE FROM driver_documents WHERE driver_id = $1`, [driverId]);
    await query(`DELETE FROM driver_settlements WHERE driver_id = $1`, [driverId]);
    await query(`DELETE FROM driver_availability WHERE driver_id = $1`, [driverId]);
    await query(`DELETE FROM driver_vehicles WHERE driver_id = $1`, [driverId]);
    await query(`DELETE FROM vehicles WHERE driver_id = $1`, [driverId]);
    await query(`DELETE FROM driver_profiles WHERE driver_id = $1`, [driverId]);
    await query(`UPDATE rides SET driver_id = NULL WHERE driver_id = $1`, [driverId]);
    const delRes = await query(`DELETE FROM drivers WHERE id = $1`, [driverId]);

    await logAdminAction({
      adminId: req.admin?.id,
      adminName: req.admin?.name || "Super Admin",
      action: "DELETE_DRIVER",
      targetType: "driver",
      targetId: driverId,
      details: `Permanently deleted driver #${driverId}`,
      ipAddress: req.ip,
    });

    return res.status(200).json({
      success: true,
      message: `Driver #${driverId} permanently deleted.`,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function deleteAllDrivers(req, res) {
  try {
    await query(`DELETE FROM driver_documents;`);
    await query(`DELETE FROM driver_settlements;`);
    await query(`DELETE FROM driver_availability;`);
    await query(`DELETE FROM driver_vehicles;`);
    await query(`DELETE FROM vehicles;`);
    await query(`DELETE FROM driver_profiles;`);
    await query(`DELETE FROM ride_cancellations WHERE driver_id IS NOT NULL;`);
    await query(`DELETE FROM ratings WHERE reviewer_type = 'DRIVER';`);
    await query(`UPDATE rides SET driver_id = NULL WHERE driver_id IS NOT NULL;`);
    const delRes = await query(`DELETE FROM drivers;`);

    await logAdminAction({
      adminId: req.admin?.id,
      adminName: req.admin?.name || "Super Admin",
      action: "DELETE_ALL_DRIVERS",
      targetType: "driver",
      targetId: "ALL",
      details: `Purged all drivers from database (${delRes.rowCount} deleted)`,
      ipAddress: req.ip,
    });

    return res.status(200).json({
      success: true,
      message: `All ${delRes.rowCount} drivers have been permanently deleted.`,
      count: delRes.rowCount,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getDrivers,
  getDriverDetails,
  updateDriverStatus,
  updateDriverDetails,
  deleteDriver,
  deleteAllDrivers,
};

