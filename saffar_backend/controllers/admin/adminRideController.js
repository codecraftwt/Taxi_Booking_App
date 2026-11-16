const { query } = require("../../database");

async function getRides(req, res) {
  try {
    const { status = "all", search, page = 1, limit = 15 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = [];
    let params = [];
    let pIdx = 1;

    if (status && status !== "all") {
      if (status === "active") {
        where.push("r.status IN ('driver_assigned', 'arrived', 'ongoing', 'trip_started')");
      } else if (status === "cancelled") {
        where.push("(r.status = 'cancelled' OR r.cancelled = true)");
      } else {
        where.push(`r.status = $${pIdx}`);
        params.push(status);
        pIdx++;
      }
    }

    if (search && search.trim() !== "") {
      const q = `%${search.trim().toLowerCase()}%`;
      where.push(`(LOWER(r.id) LIKE $${pIdx} OR LOWER(u.name) LIKE $${pIdx} OR LOWER(d.name) LIKE $${pIdx} OR LOWER(sa.place) LIKE $${pIdx} OR LOWER(da.place) LIKE $${pIdx})`);
      params.push(q);
      pIdx++;
    }

    const whereStr = where.length > 0 ? "WHERE " + where.join(" AND ") : "";

    const countRes = await query(
      `SELECT COUNT(*) as total 
       FROM rides r
       LEFT JOIN users u ON r.user_id = u.id
       LEFT JOIN drivers d ON r.driver_id = d.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       ${whereStr};`,
      params
    );
    const total = parseInt(countRes.rows[0]?.total || 0);

    const listSql = `
      SELECT 
        r.id, r.status, r.price, r.discount_price, r.payment_method,
        r.start_time, r.end_time, r.cancelled, r.cancellation_reason,
        r.cancelled_by, r.rating, r.otp, r.vehicle_type,
        u.id as user_id, u.name as customer_name, u.phone as customer_phone,
        d.id as driver_id, d.name as driver_name, d.phone as driver_phone,
        d.vehicle_number,
        sa.place as pickup_place, sa.street as pickup_street, sa.lat as pickup_lat, sa.lon as pickup_lon,
        da.place as drop_place, da.street as drop_street, da.lat as drop_lat, da.lon as drop_lon
      FROM rides r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN drivers d ON r.driver_id = d.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      ${whereStr}
      ORDER BY r.start_time DESC
      LIMIT $${pIdx} OFFSET $${pIdx + 1};
    `;
    params.push(parseInt(limit), offset);

    const listRes = await query(listSql, params);

    return res.status(200).json({
      success: true,
      data: {
        rides: listRes.rows,
        pagination: {
          total,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: Math.ceil(total / parseInt(limit)) || 1,
        },
      },
    });
  } catch (err) {
    console.error("[ADMIN GET RIDES ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function getRideDetails(req, res) {
  try {
    const { rideId } = req.params;

    const rideRes = await query(
      `SELECT 
        r.*,
        u.name as customer_name, u.phone as customer_phone, u.email as customer_email,
        d.name as driver_name, d.phone as driver_phone, d.vehicle_name, d.vehicle_number,
        sa.place as pickup_place, sa.street as pickup_street, sa.lat as pickup_lat, sa.lon as pickup_lon,
        da.place as drop_place, da.street as drop_street, da.lat as drop_lat, da.lon as drop_lon
       FROM rides r
       LEFT JOIN users u ON r.user_id = u.id
       LEFT JOIN drivers d ON r.driver_id = d.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE r.id = $1`,
      [rideId]
    );

    if (rideRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Ride not found." });
    }

    return res.status(200).json({
      success: true,
      data: rideRes.rows[0],
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function cancelRideByAdmin(req, res) {
  try {
    const { rideId } = req.params;
    const { reason } = req.body;

    if (!reason || reason.trim().length < 5) {
      return res.status(400).json({
        success: false,
        message: "A cancellation reason of at least 5 characters is required.",
      });
    }

    const updateRes = await query(
      `UPDATE rides 
       SET status = 'cancelled', 
           cancelled = true, 
           cancelled_by = 'admin', 
           cancellation_reason = $1, 
           cancelled_at = NOW()
       WHERE id = $2 
       RETURNING *;`,
      [reason, rideId]
    );

    if (updateRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Ride not found." });
    }

    // Write audit log
    await query(
      `INSERT INTO admin_audit_logs (id, admin_id, admin_name, action, target_type, target_id, details, ip_address)
       VALUES ('log_' || substr(md5(random()::text), 1, 16), $1, $2, 'CANCEL_RIDE', 'ride', $3, $4, $5)`,
      [
        req.admin.id,
        req.admin.name,
        rideId,
        `Ride cancelled by administrator. Reason: ${reason}`,
        req.ip || "127.0.0.1",
      ]
    );

    return res.status(200).json({
      success: true,
      message: "Ride cancelled successfully.",
      data: updateRes.rows[0],
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getRides,
  getRideDetails,
  cancelRideByAdmin,
};

