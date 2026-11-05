const { query } = require("../database");

// Sliding window memory rate limiter
const rateLimitStore = new Map();

function createRateLimiter({ windowMs = 60 * 1000, max = 200, message = "Too many requests. Please try again later." }) {
  return (req, res, next) => {
    const key = req.ip || req.connection.remoteAddress || "global_client";
    const now = Date.now();

    let record = rateLimitStore.get(key);
    if (!record || now - record.startTime > windowMs) {
      record = { count: 1, startTime: now };
      rateLimitStore.set(key, record);
    } else {
      record.count += 1;
    }

    if (record.count > max) {
      const retryAfter = Math.ceil((record.startTime + windowMs - now) / 1000);
      res.setHeader("Retry-After", retryAfter);
      return res.status(429).json({
        error: {
          code: "RATE_LIMIT_EXCEEDED",
          message,
          retry_after_seconds: retryAfter,
        },
      });
    }

    next();
  };
}

// Strict rate limiter for Authentication & Sign-in (max 5 requests per 15 minutes)
const authRateLimiter = createRateLimiter({
  windowMs: 15 * 60 * 1000,
  max: 10, // 10 attempts per 15 mins
  message: "Too many authentication attempts. Please wait 15 minutes before trying again.",
});

// General API rate limiter (max 200 requests per minute)
const apiRateLimiter = createRateLimiter({
  windowMs: 60 * 1000,
  max: 200,
  message: "Rate limit exceeded. Maximum 200 requests per minute allowed.",
});

// Brute-force Login Attempt Protection
const failedLoginTracker = new Map();
const MAX_FAILED_ATTEMPTS = 5;
const LOCKOUT_DURATION_MS = 15 * 60 * 1000; // 15 mins

function checkLoginLockout(req, res, next) {
  const identifier = req.body?.phone || req.ip;
  const now = Date.now();

  const record = failedLoginTracker.get(identifier);
  if (record && record.lockedUntil && now < record.lockedUntil) {
    const remainingMins = Math.ceil((record.lockedUntil - now) / 60000);
    return res.status(423).json({
      error: {
        code: "ACCOUNT_TEMPORARILY_LOCKED",
        message: `Account is temporarily locked due to multiple failed login attempts. Try again in ${remainingMins} minute(s).`,
      },
    });
  }

  next();
}

function recordFailedLogin(identifier) {
  const now = Date.now();
  let record = failedLoginTracker.get(identifier) || { count: 0 };
  record.count += 1;

  if (record.count >= MAX_FAILED_ATTEMPTS) {
    record.lockedUntil = now + LOCKOUT_DURATION_MS;
    console.warn(`[SECURITY LOCKOUT] Identifier ${identifier} locked for 15 minutes due to ${record.count} consecutive failed login attempts.`);
  }

  failedLoginTracker.set(identifier, record);
}

function resetFailedLogin(identifier) {
  failedLoginTracker.delete(identifier);
}

// Resource Ownership Verification Middleware
async function authorizeRideAccess(req, res, next) {
  const rideId = req.params?.rideId || req.body?.ride_id || req.query?.ride_id;
  const callerId = req.user?.id;
  const role = req.user?.role;

  if (!rideId) return next();

  try {
    const rideRes = await query("SELECT user_id, driver_id FROM rides WHERE id = $1 LIMIT 1;", [rideId]);
    if (rideRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "RIDE_NOT_FOUND", message: "Ride does not exist." },
      });
    }

    const ride = rideRes.rows[0];

    // If rider, must match user_id
    if (role === "user" && ride.user_id !== callerId) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN_RESOURCE_ACCESS",
          message: "Access denied. You do not own this ride record.",
        },
      });
    }

    // If driver, must match assigned driver_id (unless ride is unassigned requested dispatch)
    if (role === "driver" && ride.driver_id && ride.driver_id !== callerId) {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN_RESOURCE_ACCESS",
          message: "Access denied. This ride is assigned to another driver.",
        },
      });
    }

    next();
  } catch (err) {
    return res.status(500).json({
      error: { code: "AUTHORIZATION_CHECK_ERROR", message: err.message },
    });
  }
}

// Sensitive-Data Redaction for Audit Logging
const SENSITIVE_KEYS = new Set([
  "password", "token", "jwt", "otp", "otp_hash",
  "secret", "key_secret", "signature", "raw_token",
  "authorization", "cookie"
]);

function maskSensitiveData(obj) {
  if (!obj || typeof obj !== "object") return obj;

  if (Array.isArray(obj)) {
    return obj.map(maskSensitiveData);
  }

  const masked = {};
  for (const [key, value] of Object.entries(obj)) {
    if (SENSITIVE_KEYS.has(key.toLowerCase())) {
      masked[key] = "[REDACTED]";
    } else if (typeof value === "object" && value !== null) {
      masked[key] = maskSensitiveData(value);
    } else {
      masked[key] = value;
    }
  }
  return masked;
}

module.exports = {
  authRateLimiter,
  apiRateLimiter,
  checkLoginLockout,
  recordFailedLogin,
  resetFailedLogin,
  authorizeRideAccess,
  maskSensitiveData,
};

