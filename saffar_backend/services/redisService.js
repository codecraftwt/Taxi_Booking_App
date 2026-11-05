const { createClient } = require("redis");

// In-memory fallback stores when Redis instance is unreachable
const memoryGeo = new Map(); // category -> Map(driverId, { lat, lon, heading, speed, updatedAt })
const memoryAvailability = new Map(); // driverId -> { state, currentRideId, updatedAt }
const memoryLocks = new Map(); // key -> { value, expiresAt }

let redisClient = null;
let isRedisConnected = false;

async function initRedis() {
  const redisUrl = process.env.REDIS_URL || (process.env.REDIS_HOST ? `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT || 6379}` : null);
  
  if (!redisUrl) {
    console.log("[REDIS] No REDIS_URL provided. Operating with in-memory fast ephemeral store.");
    return;
  }

  try {
    redisClient = createClient({ url: redisUrl });
    redisClient.on("error", (err) => {
      // Graceful error logging without crashing Node process
      if (isRedisConnected) {
        console.warn("[REDIS ERROR]", err.message);
      }
      isRedisConnected = false;
    });

    redisClient.on("ready", () => {
      console.log("[REDIS] Connected and ready.");
      isRedisConnected = true;
    });

    await redisClient.connect();
    isRedisConnected = true;
  } catch (err) {
    console.warn(`[REDIS] Connection failed (${err.message}). Falling back to in-memory ephemeral store.`);
    isRedisConnected = false;
  }
}

// Haversine formula for in-memory geospatial search fallback
function haversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Math.round(R * c * 10) / 10;
}

// ─── 1. Driver Location Management ──────────────────────────────────────────

async function setDriverLocation(driverId, category, lat, lon, telemetry = {}) {
  const normCat = (category || "Auto").toLowerCase();
  const heading = telemetry.heading || 0.0;
  const speed = telemetry.speed || 0.0;
  const now = Date.now();

  if (isRedisConnected && redisClient) {
    try {
      const geoKey = `drivers:geo:${normCat}`;
      const metaKey = `driver:${driverId}:location`;

      await redisClient.geoAdd(geoKey, {
        longitude: lon,
        latitude: lat,
        member: driverId,
      });

      await redisClient.hSet(metaKey, {
        lat: lat.toString(),
        lon: lon.toString(),
        heading: heading.toString(),
        speed: speed.toString(),
        updatedAt: now.toString(),
      });
      await redisClient.expire(metaKey, 180); // 3 minutes TTL
      return true;
    } catch (err) {
      console.warn("[REDIS setDriverLocation Error]", err.message);
    }
  }

  // In-memory fallback
  if (!memoryGeo.has(normCat)) {
    memoryGeo.set(normCat, new Map());
  }
  memoryGeo.get(normCat).set(driverId, {
    lat,
    lon,
    heading,
    speed,
    updatedAt: now,
  });
  return true;
}

async function removeDriverLocation(driverId, category) {
  const normCat = (category || "Auto").toLowerCase();

  if (isRedisConnected && redisClient) {
    try {
      await redisClient.zRem(`drivers:geo:${normCat}`, driverId);
      await redisClient.del(`driver:${driverId}:location`);
      return true;
    } catch (err) {
      console.warn("[REDIS removeDriverLocation Error]", err.message);
    }
  }

  if (memoryGeo.has(normCat)) {
    memoryGeo.get(normCat).delete(driverId);
  }
  return true;
}

async function getNearbyDrivers(category, lat, lon, radiusKm = 5, limit = 10) {
  const normCat = (category || "Auto").toLowerCase();

  if (isRedisConnected && redisClient) {
    try {
      const geoKey = `drivers:geo:${normCat}`;
      // Use GEOSEARCH with radius in km
      const results = await redisClient.geoSearchWith(
        geoKey,
        { latitude: lat, longitude: lon },
        { radius: radiusKm, unit: "km" },
        ["WITHDIST", "WITHCOORD"],
        { SORT: "ASC", COUNT: limit }
      );

      return results.map((r) => ({
        driverId: r.member,
        distanceKm: parseFloat(r.distance),
        latitude: r.coordinates.latitude,
        longitude: r.coordinates.longitude,
      }));
    } catch (err) {
      console.warn("[REDIS getNearbyDrivers Error, using memory]", err.message);
    }
  }

  // In-memory fallback
  const catMap = memoryGeo.get(normCat);
  if (!catMap || catMap.size === 0) return [];

  const candidates = [];
  const now = Date.now();
  const maxStaleMs = 180 * 1000; // 3 minutes

  for (const [driverId, data] of catMap.entries()) {
    if (now - data.updatedAt > maxStaleMs) continue; // skip stale
    const dist = haversineDistanceKm(lat, lon, data.lat, data.lon);
    if (dist <= radiusKm) {
      candidates.push({
        driverId,
        distanceKm: dist,
        latitude: data.lat,
        longitude: data.lon,
        heading: data.heading,
        speed: data.speed,
      });
    }
  }

  candidates.sort((a, b) => a.distanceKm - b.distanceKm);
  return candidates.slice(0, limit);
}

// ─── 2. Driver Availability Management ──────────────────────────────────────

async function setDriverAvailability(driverId, state, currentRideId = null) {
  // Valid states: 'OFFLINE', 'ONLINE_AVAILABLE', 'OFFER_PENDING', 'ON_TRIP', 'TEMPORARILY_UNAVAILABLE'
  const now = Date.now();

  if (isRedisConnected && redisClient) {
    try {
      const key = `driver:${driverId}:avail`;
      await redisClient.hSet(key, {
        state,
        currentRideId: currentRideId || "",
        updatedAt: now.toString(),
      });
      return true;
    } catch (err) {
      console.warn("[REDIS setDriverAvailability Error]", err.message);
    }
  }

  memoryAvailability.set(driverId, {
    state,
    currentRideId,
    updatedAt: now,
  });
  return true;
}

async function getDriverAvailability(driverId) {
  if (isRedisConnected && redisClient) {
    try {
      const key = `driver:${driverId}:avail`;
      const data = await redisClient.hGetAll(key);
      if (data && data.state) {
        return {
          state: data.state,
          currentRideId: data.currentRideId || null,
          updatedAt: parseInt(data.updatedAt, 10),
        };
      }
    } catch (err) {
      console.warn("[REDIS getDriverAvailability Error]", err.message);
    }
  }

  return memoryAvailability.get(driverId) || {
    state: "OFFLINE",
    currentRideId: null,
    updatedAt: Date.now(),
  };
}

// ─── 3. Concurrency Lock for Ride Offers ────────────────────────────────────

async function acquireOfferLock(rideId, driverId, ttlSeconds = 15) {
  const key = `lock:offer:${rideId}`;
  const now = Date.now();

  if (isRedisConnected && redisClient) {
    try {
      // SET key value NX EX ttl
      const result = await redisClient.set(key, driverId, {
        NX: true,
        EX: ttlSeconds,
      });
      return result === "OK";
    } catch (err) {
      console.warn("[REDIS acquireOfferLock Error]", err.message);
    }
  }

  // Memory fallback
  const existing = memoryLocks.get(key);
  if (existing && existing.expiresAt > now) {
    return false; // lock held
  }
  memoryLocks.set(key, {
    value: driverId,
    expiresAt: now + ttlSeconds * 1000,
  });
  return true;
}

async function releaseOfferLock(rideId) {
  const key = `lock:offer:${rideId}`;
  if (isRedisConnected && redisClient) {
    try {
      await redisClient.del(key);
      return true;
    } catch (err) {
      console.warn("[REDIS releaseOfferLock Error]", err.message);
    }
  }
  memoryLocks.delete(key);
  return true;
}

module.exports = {
  initRedis,
  setDriverLocation,
  updateDriverLocation: setDriverLocation,
  removeDriverLocation,
  getNearbyDrivers,
  setDriverAvailability,
  getDriverAvailability,
  acquireOfferLock,
  releaseOfferLock,
  haversineDistanceKm,
};

