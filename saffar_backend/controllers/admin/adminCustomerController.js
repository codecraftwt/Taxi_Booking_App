const { query } = require("../../database");

async function getCustomers(req, res) {
  try {
    const { search, page = 1, limit = 15 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = [];
    let params = [];
    let pIdx = 1;

    if (search && search.trim() !== "") {
      const q = `%${search.trim().toLowerCase()}%`;
      where.push(`(LOWER(name) LIKE $${pIdx} OR LOWER(phone) LIKE $${pIdx} OR LOWER(COALESCE(email, '')) LIKE $${pIdx})`);
      params.push(q);
      pIdx++;
    }

    const whereStr = where.length > 0 ? "WHERE " + where.join(" AND ") : "";

    const countRes = await query(`SELECT COUNT(*) as total FROM users ${whereStr};`, params);
    const total = parseInt(countRes.rows[0]?.total || 0);

    const listSql = `
      SELECT 
        u.id, u.name, u.phone, u.email, u.image_url, u.address,
        u.wallet_balance, u.created_at,
        (SELECT COUNT(*) FROM rides r WHERE r.user_id = u.id) as total_rides,
        (SELECT COUNT(*) FROM rides r WHERE r.user_id = u.id AND r.status = 'completed') as completed_rides,
        (SELECT COUNT(*) FROM rides r WHERE r.user_id = u.id AND (r.status = 'cancelled' OR r.cancelled = true)) as cancelled_rides
      FROM users u
      ${whereStr}
      ORDER BY u.created_at DESC
      LIMIT $${pIdx} OFFSET $${pIdx + 1};
    `;
    params.push(parseInt(limit), offset);

    const listRes = await query(listSql, params);

    return res.status(200).json({
      success: true,
      data: {
        customers: listRes.rows,
        pagination: {
          total,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: Math.ceil(total / parseInt(limit)) || 1,
        },
      },
    });
  } catch (err) {
    console.error("[ADMIN GET CUSTOMERS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function getCustomerDetails(req, res) {
  try {
    const { customerId } = req.params;

    const userRes = await query(
      `SELECT u.*,
        (SELECT COUNT(*) FROM rides r WHERE r.user_id = u.id) as total_rides,
        (SELECT COUNT(*) FROM rides r WHERE r.user_id = u.id AND r.status = 'completed') as completed_rides,
        (SELECT COALESCE(SUM(price), 0.0) FROM rides r WHERE r.user_id = u.id AND r.status = 'completed') as total_spend
       FROM users u WHERE u.id = $1`,
      [customerId]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Customer not found." });
    }

    const user = userRes.rows[0];

    const ridesRes = await query(
      `SELECT r.id, r.status, r.price, r.start_time, d.name as driver_name,
              sa.place as pickup_place, da.place as drop_place
       FROM rides r
       LEFT JOIN drivers d ON r.driver_id = d.id
       LEFT JOIN addresses sa ON r.source_address_id = sa.id
       LEFT JOIN addresses da ON r.destination_address_id = da.id
       WHERE r.user_id = $1
       ORDER BY r.start_time DESC
       LIMIT 10`,
      [customerId]
    );

    return res.status(200).json({
      success: true,
      data: {
        customer: { ...user, password: undefined },
        recentRides: ridesRes.rows,
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getCustomers,
  getCustomerDetails,
};

