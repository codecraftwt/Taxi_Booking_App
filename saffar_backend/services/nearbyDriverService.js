const { redisClient, connectRedis } = require("../config/redis");

async function findNearbyDrivers({
  latitude,
  longitude,
  radiusKm = 3,
  limit = 15,
}) {
  if (!redisClient.isOpen) {
    await connectRedis();
  }

  const result = await redisClient.sendCommand([
    "GEOSEARCH",
    "drivers:locations",
    "FROMLONLAT",
    String(longitude),
    String(latitude),
    "BYRADIUS",
    String(radiusKm),
    "km",
    "ASC",
    "COUNT",
    String(limit),
    "WITHDIST",
  ]);

  const drivers = [];

  for (const item of (result || [])) {
    const driverId = item[0].replace("driver:", "");
    const distanceKm = Number(item[1]);

    const driverKey = `driver:location:${driverId}`;

    const [location, status] = await Promise.all([
      redisClient.hGetAll(driverKey),
      redisClient.get(`driver:status:${driverId}`),
    ]);

    // Ignore missing or stale locations
    if (!location || !location.updatedAt) continue;

    const age = Date.now() - Number(location.updatedAt);
    if (age > 30000) continue;

    // Only select online drivers (support 'online' or 'ONLINE_AVAILABLE')
    const normalizedStatus = (status || "").toLowerCase();
    if (normalizedStatus !== "online" && !normalizedStatus.includes("available")) {
      continue;
    }

    drivers.push({
      driverId,
      latitude: Number(location.latitude),
      longitude: Number(location.longitude),
      distanceKm,
      accuracy: Number(location.accuracy || 0),
    });
  }

  return drivers;
}

module.exports = {
  findNearbyDrivers,
};
