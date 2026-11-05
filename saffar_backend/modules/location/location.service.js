const { query } = require("../../database");
const redisService = require("../../services/redisService");
const { emitDriverLocationUpdate } = require("../../socket");

/**
 * Ingest driver location ping with Redis caching and throttle-optimized DB logging
 */
async function recordDriverLocation(driverId, { latitude, longitude, heading = 0.0, speed = 0.0, rideId = null }) {
  const lat = parseFloat(latitude);
  const lon = parseFloat(longitude);
  if (isNaN(lat) || isNaN(lon)) {
    throw new Error("Invalid GPS coordinates.");
  }

  // 1. Fetch driver active vehicle category
  const vehRes = await query(
    `SELECT category FROM driver_vehicles WHERE driver_id = $1 AND is_active = true LIMIT 1;`,
    [driverId]
  );
  const category = vehRes.rows.length > 0 ? vehRes.rows[0].category : "Auto";

  // 2. Fast Ephemeral Cache Update (Redis GEO & Hash)
  await redisService.setDriverLocation(driverId, category, lat, lon, { heading, speed });

  // 3. PostgreSQL latest snapshot update
  await query(
    `INSERT INTO driver_locations (driver_id, latitude, longitude, heading, speed, recorded_at, updated_at)
     VALUES ($1, $2, $3, $4, $5, (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
     ON CONFLICT (driver_id) DO UPDATE SET 
       latitude = EXCLUDED.latitude,
       longitude = EXCLUDED.longitude,
       heading = EXCLUDED.heading,
       speed = EXCLUDED.speed,
       is_stale = false,
       recorded_at = (NOW() AT TIME ZONE 'UTC'),
       updated_at = (NOW() AT TIME ZONE 'UTC');`,
    [driverId, lat, lon, heading, speed]
  );

  await query(
    `UPDATE drivers 
     SET current_lat = $1, current_lng = $2, heading = $3, speed = $4, 
         last_location_updated_at = (NOW() AT TIME ZONE 'UTC') 
     WHERE id = $5;`,
    [lat, lon, heading, speed, driverId]
  );

  // 4. If on an active ride, log permanently for trip trail audit and broadcast live to rider
  if (rideId) {
    // Audit log during active trip
    await query(
      `INSERT INTO driver_location_logs (id, driver_id, latitude, longitude, heading, speed, recorded_at)
       VALUES ($1, $2, $3, $4, $5, $6, (NOW() AT TIME ZONE 'UTC'));`,
      [`loc_${Date.now()}_${driverId.slice(0, 8)}`, driverId, lat, lon, heading, speed]
    );

    // Look up rider to emit real-time event
    const rideRes = await query(`SELECT user_id, status FROM rides WHERE id = $1;`, [rideId]);
    if (rideRes.rows.length > 0) {
      const { user_id, status } = rideRes.rows[0];
      emitDriverLocationUpdate(rideId, user_id, {
        ride_id: rideId,
        driver_id: driverId,
        latitude: lat,
        longitude: lon,
        heading,
        speed,
        status,
        timestamp: new Date().toISOString(),
      });
    }
  }

  return {
    driverId,
    latitude: lat,
    longitude: lon,
    heading,
    speed,
    recordedAt: new Date().toISOString(),
  };
}

module.exports = {
  recordDriverLocation,
};

