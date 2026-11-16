const { query } = require("../../database");

async function getFinancialOverview(req, res) {
  try {
    const revRes = await query(`
      SELECT 
        COALESCE(SUM(price), 0.0) as gross_revenue,
        COUNT(*) as total_completed_rides,
        COALESCE(SUM(tip_amount), 0.0) as total_tips
      FROM rides 
      WHERE status = 'completed';
    `);

    const gross = parseFloat(revRes.rows[0]?.gross_revenue || 0);
    const commission = Math.round(gross * 0.15);
    const driverPayouts = Math.round(gross - commission);

    // Recent 10 completed financial transactions
    const txRes = await query(`
      SELECT 
        r.id as ride_id,
        r.price as amount,
        ROUND((r.price * 0.15)::numeric, 2) as commission,
        ROUND((r.price * 0.85)::numeric, 2) as driver_share,
        r.payment_method,
        r.end_time as completed_at,
        u.name as customer_name,
        d.name as driver_name,
        d.vehicle_number
      FROM rides r
      JOIN users u ON r.user_id = u.id
      JOIN drivers d ON r.driver_id = d.id
      WHERE r.status = 'completed'
      ORDER BY r.end_time DESC
      LIMIT 15;
    `);

    return res.status(200).json({
      success: true,
      data: {
        grossRevenue: gross,
        platformCommission: commission,
        driverPayouts: driverPayouts,
        totalCompletedRides: parseInt(revRes.rows[0]?.total_completed_rides || 0),
        transactions: txRes.rows,
      },
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function getDriverSettlements(req, res) {
  try {
    const settlementsRes = await query(`
      SELECT 
        s.*,
        d.name as driver_name,
        d.phone as driver_phone,
        d.vehicle_number
      FROM driver_settlements s
      JOIN drivers d ON s.driver_id = d.id
      ORDER BY s.created_at DESC;
    `);

    return res.status(200).json({
      success: true,
      data: settlementsRes.rows,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getFinancialOverview,
  getDriverSettlements,
};

