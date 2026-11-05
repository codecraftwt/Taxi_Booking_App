const { query } = require("../../database");
const redisService = require("../../services/redisService");

const DRIVER_STATES = {
  OFFLINE: "OFFLINE",
  ONLINE_AVAILABLE: "ONLINE_AVAILABLE",
  OFFER_PENDING: "OFFER_PENDING",
  ON_TRIP: "ON_TRIP",
  TEMPORARILY_UNAVAILABLE: "TEMPORARILY_UNAVAILABLE",
};

/**
 * Validates whether driver can change to requested availability state
 */
async function setDriverAvailabilityState(driverId, targetState, options = {}) {
  const state = targetState.toUpperCase();
  if (!Object.values(DRIVER_STATES).includes(state)) {
    throw new Error(`Invalid driver state: ${targetState}. Must be one of: ${Object.values(DRIVER_STATES).join(", ")}`);
  }

  // 1. Fetch driver profile & verification status
  const driverRes = await query(
    `SELECT id, name, verification_status, active, is_online, current_lat, current_lng, last_location_updated_at 
     FROM drivers WHERE id = $1;`,
    [driverId]
  );
  if (driverRes.rows.length === 0) {
    throw new Error("Driver account not found.");
  }
  const driver = driverRes.rows[0];

  // 2. Fetch driver active vehicles
  const vehicleRes = await query(
    `SELECT id, category, model, registration_number, is_active, verification_status 
     FROM driver_vehicles 
     WHERE driver_id = $1 AND is_active = true;`,
    [driverId]
  );

  // 3. Check transition invariants
  if (state === DRIVER_STATES.ONLINE_AVAILABLE) {
    // Invariant 1: Must be approved
    const vStatus = (driver.verification_status || "").toLowerCase();
    if (vStatus !== "approved") {
      throw new Error("Cannot go online: Driver verification is pending approval.");
    }

    // Invariant 2: Must have an approved active vehicle
    if (vehicleRes.rows.length === 0) {
      throw new Error("Cannot go online: No active vehicle selected. Please register/activate a vehicle.");
    }
    const activeVehicle = vehicleRes.rows[0];
    const vehStatus = (activeVehicle.verification_status || "").toLowerCase();
    if (vehStatus !== "approved") {
      throw new Error(`Cannot go online: Active vehicle (${activeVehicle.model}) documents are pending verification.`);
    }

    // Invariant 3: Location coordinate validity
    const lat = options.latitude ?? driver.current_lat;
    const lng = options.longitude ?? driver.current_lng;
    if (lat === null || lat === undefined || lng === null || lng === undefined) {
      throw new Error("Cannot go online: Valid GPS location required.");
    }
  }

  // Safe offline transition: Check if driver is currently on an active trip
  if (state === DRIVER_STATES.OFFLINE) {
    const activeRideRes = await query(
      `SELECT id, status FROM rides 
       WHERE driver_id = $1 
         AND cancelled = false 
         AND status IN ('accepted', 'reaching_pickup', 'arrived', 'in_progress');`,
      [driverId]
    );
    if (activeRideRes.rows.length > 0) {
      throw new Error("Cannot go offline while on an active trip. Please finish or cancel the current trip first.");
    }
  }

  // 4. Update PostgreSQL
  const isOnlineBool = state === DRIVER_STATES.ONLINE_AVAILABLE || state === DRIVER_STATES.OFFER_PENDING || state === DRIVER_STATES.ON_TRIP;
  const client = await query(
    `INSERT INTO driver_availability (driver_id, state, current_ride_id, last_state_change, updated_at)
     VALUES ($1, $2, $3, (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
     ON CONFLICT (driver_id) DO UPDATE SET 
       state = EXCLUDED.state,
       current_ride_id = EXCLUDED.current_ride_id,
       last_state_change = (NOW() AT TIME ZONE 'UTC'),
       updated_at = (NOW() AT TIME ZONE 'UTC');`,
    [driverId, state, options.currentRideId || null]
  );

  // Sync drivers legacy is_online flag
  await query(
    `UPDATE drivers SET is_online = $1 WHERE id = $2;`,
    [isOnlineBool, driverId]
  );

  // 5. Update Redis ephemeral fast cache
  await redisService.setDriverAvailability(driverId, state, options.currentRideId);

  // If going offline, remove from Redis geospatial index
  if (state === DRIVER_STATES.OFFLINE && vehicleRes.rows.length > 0) {
    await redisService.removeDriverLocation(driverId, vehicleRes.rows[0].category);
  }

  return {
    driverId,
    state,
    isOnline: isOnlineBool,
    updatedAt: new Date().toISOString(),
  };
}

async function getDriverAvailabilityState(driverId) {
  // Query Redis first, fallback to DB
  const redisState = await redisService.getDriverAvailability(driverId);
  if (redisState && redisState.state) {
    return redisState;
  }

  const dbRes = await query(
    `SELECT state, current_ride_id, last_state_change FROM driver_availability WHERE driver_id = $1;`,
    [driverId]
  );
  if (dbRes.rows.length > 0) {
    return dbRes.rows[0];
  }
  return { state: DRIVER_STATES.OFFLINE, current_ride_id: null };
}

module.exports = {
  DRIVER_STATES,
  setDriverAvailabilityState,
  getDriverAvailabilityState,
};

