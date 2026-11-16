const { query } = require("../../database");
const redisService = require("../../services/redisService");

async function getDashboardStats(req, res) {
  try {
    // 1. Driver Statistics
    const driverStatsRes = await query(`
      SELECT 
        COUNT(*) as total_drivers,
        COUNT(*) FILTER (WHERE verification_status = 'approved' AND active = true) as approved_drivers,
        COUNT(*) FILTER (WHERE verification_status = 'pending') as pending_drivers,
        COUNT(*) FILTER (WHERE verification_status = 'rejected') as rejected_drivers,
        COUNT(*) FILTER (WHERE active = false) as suspended_drivers,
        COUNT(*) FILTER (WHERE is_online = true) as online_drivers,
        COUNT(*) FILTER (WHERE is_online = false OR is_online IS NULL) as offline_drivers
      FROM drivers;
    `);

    // 2. Rides Statistics
    const rideStatsRes = await query(`
      SELECT 
        COUNT(*) as total_rides,
        COUNT(*) FILTER (WHERE status = 'completed') as completed_rides,
        COUNT(*) FILTER (WHERE cancelled = true OR status = 'cancelled') as cancelled_rides,
        COUNT(*) FILTER (WHERE status IN ('driver_assigned', 'arrived', 'ongoing', 'trip_started')) as active_rides,
        COUNT(*) FILTER (WHERE status = 'searching') as searching_rides,
        COALESCE(SUM(price) FILTER (WHERE status = 'completed'), 0) as total_revenue,
        COALESCE(SUM(price) FILTER (WHERE status = 'completed' AND DATE(start_time) = CURRENT_DATE), 0) as today_revenue
      FROM rides;
    `);

    // 3. Customer Statistics
    const userStatsRes = await query(`
      SELECT 
        COUNT(*) as total_customers,
        COALESCE(SUM(wallet_balance), 0) as total_wallet_balance
      FROM users;
    `);

    // 4. Pending Document Count
    const docStatsRes = await query(`
      SELECT COUNT(*) as pending_documents FROM driver_documents WHERE verification_status = 'pending';
    `);

    // 5. Category Breakdown
    const categoryStatsRes = await query(`
      SELECT 
        COALESCE(category, 'Auto') as category,
        COUNT(*) as ride_count,
        COALESCE(SUM(price), 0) as revenue
      FROM rides r
      LEFT JOIN driver_vehicles dv ON r.driver_id = dv.driver_id
      GROUP BY category;
    `);

    // 6. Recent Drivers (5)
    const recentDriversRes = await query(`
      SELECT 
        d.id, d.name, d.phone, d.email, d.vehicle_name, d.vehicle_number, 
        d.verification_status, d.is_online, d.active, d.created_at,
        COALESCE(dv.category, 'Auto') as category
      FROM drivers d
      LEFT JOIN driver_vehicles dv ON d.id = dv.driver_id
      ORDER BY d.created_at DESC
      LIMIT 5;
    `);

    // 7. Recent Rides (5)
    const recentRidesRes = await query(`
      SELECT 
        r.id, r.status, r.price, r.start_time, r.cancelled,
        u.name as customer_name, u.phone as customer_phone,
        d.name as driver_name, d.vehicle_number,
        sa.place as pickup_place, da.place as drop_place
      FROM rides r
      LEFT JOIN users u ON r.user_id = u.id
      LEFT JOIN drivers d ON r.driver_id = d.id
      LEFT JOIN addresses sa ON r.source_address_id = sa.id
      LEFT JOIN addresses da ON r.destination_address_id = da.id
      ORDER BY r.start_time DESC
      LIMIT 5;
    `);

    const driverStats = driverStatsRes.rows[0];
    const rideStats = rideStatsRes.rows[0];
    const userStats = userStatsRes.rows[0];
    const totalRev = parseFloat(rideStats.total_revenue || 0);
    const todayRev = parseFloat(rideStats.today_revenue || 0);
    const commissionRate = 0.15; // 15% platform commission

    return res.status(200).json({
      success: true,
      data: {
        summary: {
          totalDrivers: parseInt(driverStats.total_drivers || 0),
          approvedDrivers: parseInt(driverStats.approved_drivers || 0),
          pendingDrivers: parseInt(driverStats.pending_drivers || 0),
          rejectedDrivers: parseInt(driverStats.rejected_drivers || 0),
          suspendedDrivers: parseInt(driverStats.suspended_drivers || 0),
          onlineDrivers: parseInt(driverStats.online_drivers || 0),
          offlineDrivers: parseInt(driverStats.offline_drivers || 0),
          totalCustomers: parseInt(userStats.total_customers || 0),
          totalRides: parseInt(rideStats.total_rides || 0),
          completedRides: parseInt(rideStats.completed_rides || 0),
          cancelledRides: parseInt(rideStats.cancelled_rides || 0),
          activeRides: parseInt(rideStats.active_rides || 0),
          totalRevenue: Math.round(totalRev),
          todayRevenue: Math.round(todayRev),
          platformCommission: Math.round(totalRev * commissionRate),
          pendingDocuments: parseInt(docStatsRes.rows[0]?.pending_documents || 0),
        },
        categoryBreakdown: categoryStatsRes.rows,
        recentDrivers: recentDriversRes.rows,
        recentRides: recentRidesRes.rows,
      },
    });
  } catch (err) {
    console.error("[DASHBOARD STATS ERROR]", err);
    return res.status(500).json({
      success: false,
      message: "Failed to aggregate dashboard metrics: " + err.message,
    });
  }
}

module.exports = {
  getDashboardStats,
};

