const { redisClient, connectRedis } = require("../config/redis");
const { query } = require("../database");

const LOCATION_KEY = "drivers:locations";
const LAST_SEEN_KEY = "drivers:last_seen";
const STALE_THRESHOLD_MS = 30000; // 30 seconds

async function ensureRedis() {
  if (!redisClient.isOpen) {
    await connectRedis();
  }
}

/**
 * Validates GPS coordinates
 */
function validateCoordinates(latitude, longitude) {
  if (
    !Number.isFinite(latitude) ||
    !Number.isFinite(longitude) ||
    latitude < -90 ||
    latitude > 90 ||
    longitude < -180 ||
    longitude > 180
  ) {
    throw new Error("Invalid GPS coordinates");
  }
}

/**
 * Updates driver live location, GEO index, location hash with TTL, and last_seen score
 */
async function updateDriverLocation({
  driverId,
  latitude,
  longitude,
  accuracy,
  speed,
  heading,
}) {
  validateCoordinates(latitude, longitude);
  await ensureRedis();

  const now = Date.now();
  const driverKey = `driver:location:${driverId}`;

  // 1. Update GEO index (member format: driver:<id>)
  await redisClient.sendCommand([
    "GEOADD",
    LOCATION_KEY,
    String(longitude),
    String(latitude),
    `driver:${driverId}`,
  ]);

  // 2. Store latest GPS information hash
  await redisClient.hSet(driverKey, {
    driverId: String(driverId),
    latitude: String(latitude),
    longitude: String(longitude),
    accuracy: String(accuracy ?? 0),
    speed: String(speed ?? 0),
    heading: String(heading ?? 0),
    updatedAt: String(now),
  });

  // 3. Expire temporary location hash after 30 seconds
  await redisClient.expire(driverKey, 30);

  // 4. Maintain last-seen timestamp in sorted set
  await redisClient.zAdd(LAST_SEEN_KEY, {
    score: now,
    value: `driver:${driverId}`,
  });

  return {
    success: true,
    updatedAt: now,
  };
}

/**
 * Marks driver as ONLINE in Redis:
 * - SET driver:status:<id> online
 * - Optionally seeds GEO index & location hash if coordinates provided
 */
async function setDriverOnline(driverId, location = null) {
  await ensureRedis();

  const statusKey = `driver:status:${driverId}`;
  await redisClient.set(statusKey, "online");

  if (
    location &&
    location.latitude !== undefined &&
    location.longitude !== undefined &&
    !isNaN(location.latitude) &&
    !isNaN(location.longitude)
  ) {
    await updateDriverLocation({
      driverId,
      latitude: Number(location.latitude),
      longitude: Number(location.longitude),
      accuracy: Number(location.accuracy ?? 0),
      speed: Number(location.speed ?? 0),
      heading: Number(location.heading ?? 0),
    });
  }

  return {
    success: true,
    driverId,
    status: "online",
  };
}

/**
 * Marks driver as OFFLINE in Redis:
 * 1. SET driver:status:<id> offline
 * 2. ZREM drivers:locations driver:<id>
 * 3. DEL driver:location:<id>
 * 4. ZREM drivers:last_seen driver:<id>
 */
async function setDriverOffline(driverId) {
  await ensureRedis();

  const statusKey = `driver:status:${driverId}`;
  const driverKey = `driver:location:${driverId}`;
  const member = `driver:${driverId}`;

  await Promise.all([
    redisClient.set(statusKey, "offline"),
    redisClient.sendCommand(["ZREM", LOCATION_KEY, member]),
    redisClient.del(driverKey),
    redisClient.sendCommand(["ZREM", LAST_SEEN_KEY, member]),
  ]);

  return {
    success: true,
    driverId,
    status: "offline",
  };
}

/**
 * Gets the current Redis status for a driver ('online', 'offline', 'busy', etc.)
 */
async function getDriverStatus(driverId) {
  await ensureRedis();
  const statusKey = `driver:status:${driverId}`;
  const status = await redisClient.get(statusKey);
  return status || "offline";
}

/**
 * Checks whether a driver has an active ride in progress in PostgreSQL
 */
async function isDriverOnActiveTrip(driverId) {
  try {
    const activeCheck = await query(
      `SELECT id FROM rides 
       WHERE driver_id = $1 
         AND end_time IS NULL 
         AND cancelled = false 
         AND status IN ('accepted', 'reaching_pickup', 'arrived', 'in_progress', 'started')
       LIMIT 1;`,
      [driverId]
    );
    return activeCheck.rows.length > 0;
  } catch (err) {
    console.warn("[CHECK ACTIVE TRIP ERROR]", err.message);
    return false;
  }
}

/**
 * Periodic cleanup of stale drivers who disconnected without sending offline event:
 * - Identifies drivers whose last_seen timestamp > maxAgeMs
 * - CRITICAL: Checks if driver has an active trip. If yes, DO NOT mark available or cancel trip.
 * - If driver has no active trip, safely cleans up GEO index, Redis status, and PostgreSQL availability.
 */
async function cleanupStaleDrivers(maxAgeMs = STALE_THRESHOLD_MS) {
  if (!redisClient.isOpen) return [];
  try {
    const cutoff = Date.now() - maxAgeMs;

    // Find all driver members whose last_seen score <= cutoff
    const staleMembers = await redisClient.sendCommand([
      "ZRANGEBYSCORE",
      LAST_SEEN_KEY,
      "-inf",
      String(cutoff),
    ]);

    if (!staleMembers || staleMembers.length === 0) {
      return [];
    }

    const cleanedDrivers = [];

    for (const member of staleMembers) {
      const driverId = member.replace("driver:", "");

      // 1. Check if driver is on an active trip
      const onTrip = await isDriverOnActiveTrip(driverId);
      if (onTrip) {
        // Driver is currently driving a passenger!
        // Do NOT make available for new rides, remove only from GEO dispatch search pool
        await redisClient.sendCommand(["ZREM", LOCATION_KEY, member]);
        continue;
      }

      // 2. Driver has no active trip and is stale -> mark offline
      await setDriverOffline(driverId);

      // 3. Update PostgreSQL availability state to OFFLINE
      try {
        await query(
          `UPDATE driver_availability 
           SET state = 'OFFLINE', last_state_change = (NOW() AT TIME ZONE 'UTC'), updated_at = (NOW() AT TIME ZONE 'UTC')
           WHERE driver_id = $1 AND state = 'ONLINE_AVAILABLE';`,
          [driverId]
        );
        await query(
          `UPDATE drivers SET active = false, is_online = false WHERE id = $1;`,
          [driverId]
        );
      } catch (dbErr) {
        console.warn("[STALE CLEANUP DB SYNC ERROR]", dbErr.message);
      }

      cleanedDrivers.push(driverId);
    }

    if (cleanedDrivers.length > 0) {
      console.log(`[REDIS CLEANUP] Cleaned up ${cleanedDrivers.length} stale drivers:`, cleanedDrivers);
    }

    return cleanedDrivers;
  } catch (err) {
    console.warn("[CLEANUP STALE DRIVERS ERROR]", err.message);
    return [];
  }
}

/**
 * Starts a background interval worker to automatically clean up stale drivers
 */
let cleanupIntervalTimer = null;
function startStaleDriverCleanupWorker(intervalMs = 15000, maxAgeMs = STALE_THRESHOLD_MS) {
  if (cleanupIntervalTimer) return;
  cleanupIntervalTimer = setInterval(async () => {
    try {
      await cleanupStaleDrivers(maxAgeMs);
    } catch (err) {
      console.warn("[STALE WORKER TICK ERROR]", err.message);
    }
  }, intervalMs);
  if (cleanupIntervalTimer.unref) cleanupIntervalTimer.unref();
  console.log(`[REDIS WORKER] Stale driver cleanup worker started (interval: ${intervalMs}ms, threshold: ${maxAgeMs}ms)`);
}

/**
 * Concurrency Lock: Prevents two drivers from accepting the same ride simultaneously.
 * SET ride:lock:<rideId> driver:<driverId> NX EX <ttlSeconds>
 */
async function acquireRideLock(rideId, driverId, ttlSeconds = 15) {
  await ensureRedis();
  const lockKey = `ride:lock:${rideId}`;
  const lockVal = `driver:${driverId}`;
  try {
    const res = await redisClient.set(lockKey, lockVal, {
      NX: true,
      EX: ttlSeconds,
    });
    return res === "OK";
  } catch (err) {
    console.warn("[REDIS LOCK ERROR]", err.message);
    // If Redis is temporarily offline, allow DB transactional lock (SELECT FOR UPDATE) to guard
    return true;
  }
}

async function releaseRideLock(rideId) {
  await ensureRedis();
  const lockKey = `ride:lock:${rideId}`;
  try {
    await redisClient.del(lockKey);
  } catch (err) {
    console.warn("[REDIS UNLOCK ERROR]", err.message);
  }
}

module.exports = {
  updateDriverLocation,
  setDriverOnline,
  setDriverOffline,
  getDriverStatus,
  cleanupStaleDrivers,
  startStaleDriverCleanupWorker,
  isDriverOnActiveTrip,
  acquireRideLock,
  releaseRideLock,
  LOCATION_KEY,
  LAST_SEEN_KEY,
};
