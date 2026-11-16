const { query } = require("../../database");
const redisService = require("../../services/redisService");

async function getLiveDrivers(req, res) {
  try {
    const { category = "All", status = "All" } = req.query;

    // Fetch all active drivers from PostgreSQL with current coordinates
    let sql = `
      SELECT 
        d.id, d.name, d.phone, d.vehicle_number, d.vehicle_name,
        d.is_online, d.current_lat, d.current_lng, d.heading, d.speed,
        d.last_location_updated_at,
        COALESCE(dv.category, 'Auto') as category,
        COALESCE(dv.model, d.vehicle_name) as vehicle_model,
        (SELECT r.id FROM rides r WHERE r.driver_id = d.id AND r.status IN ('driver_assigned', 'arrived', 'ongoing', 'trip_started') LIMIT 1) as current_ride_id
      FROM drivers d
      LEFT JOIN driver_vehicles dv ON d.id = dv.driver_id
      WHERE d.active = true
    `;

    const params = [];
    if (category && category !== "All") {
      sql += " AND dv.category = $1";
      params.push(category);
    }

    const dbRes = await query(sql, params);

    // Map through drivers, determining exact live coordinates & status
    const liveDrivers = dbRes.rows
      .map((d) => {
        const isOnTrip = !!d.current_ride_id;
        const isOnline = !!d.is_online;
        const driverStatus = isOnTrip ? "on_trip" : isOnline ? "available" : "offline";

        // Filter by status if requested
        if (status === "Online" && !isOnline) return null;
        if (status === "Available" && (isOnTrip || !isOnline)) return null;
        if (status === "On Trip" && !isOnTrip) return null;

        // Only track drivers who have authentic acquired GPS coordinates
        if (d.current_lat == null || d.current_lng == null) return null;
        const lat = parseFloat(d.current_lat);
        const lon = parseFloat(d.current_lng);

        return {
          id: d.id,
          name: d.name,
          phone: d.phone,
          vehicleName: d.vehicle_name,
          vehicleNumber: d.vehicle_number,
          vehicleModel: d.vehicle_model,
          category: d.category,
          isOnline: isOnline,
          status: driverStatus,
          lat: lat,
          lon: lon,
          heading: d.heading || 0.0,
          speed: d.speed || 0.0,
          lastUpdatedAt: d.last_location_updated_at || new Date().toISOString(),
          currentRideId: d.current_ride_id || null,
        };
      })
      .filter(Boolean);

    return res.status(200).json({
      success: true,
      data: {
        total: liveDrivers.length,
        drivers: liveDrivers,
      },
    });
  } catch (err) {
    console.error("[LIVE TRACKING ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getLiveDrivers,
};

