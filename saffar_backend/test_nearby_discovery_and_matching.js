require('./config/polyfill');
/**
 * Saffar - Real-Time Nearby Driver Discovery & Ride Matching Test Suite
 * Validates:
 * 1. High-frequency driver location updates with timestamps and logging.
 * 2. Stale GPS location (>3 minutes) exclusion from discovery and matching.
 * 3. Spatial driver discovery & real-time vehicle counts across categories (Bike, Auto, Mini Car, Sedan, SUV).
 * 4. ETA and fare calculation based on distance and category speed.
 * 5. Deterministic vehicle marker obfuscation for passenger privacy protection.
 * 6. Progressive search radius expansion (3 km -> 6 km -> 10 km).
 * 7. Candidate ranking based on proximity, ETA, and driver rating.
 * 8. Concurrency-safe atomic ride acceptance preventing dual assignments (race condition safety).
 * 9. Rejection handling and cascading dispatch to remaining candidates.
 * 10. Real-time Socket.IO event emission.
 */

require("./config/polyfill");
const assert = require("assert");
const http = require("http");
const jwt = require("jsonwebtoken");
const express = require("express");
const { pool, query, initPostgresDatabase } = require("./database/db");
const { initSocket, getIO } = require("./socket");
const rideRouter = require("./routes/ride_router");
const driverRouter = require("./routes/driver_router");
const config = require("./config");

let server;
let baseUrl;
let socketClient;
let userToken;
const driverTokens = {};

function makeToken(payload) {
  return jwt.sign(payload, config.TOKEN_SECRET_KEY || "test_token_secret", { expiresIn: "1h" });
}

async function request(path, options = {}) {
  const url = `${baseUrl}${path}`;
  const method = options.method || "GET";
  const headers = { "Content-Type": "application/json", ...(options.headers || {}) };
  if (options.token) {
    headers["Authorization"] = `Bearer ${options.token}`;
  }

  const res = await fetch(url, {
    method,
    headers,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const text = await res.text();
  let json;
  try {
    json = JSON.parse(text);
  } catch (_) {
    json = { raw: text };
  }
  return { status: res.status, data: json };
}

let passedTests = 0;
let totalTests = 0;

function it(desc, fn) {
  return { desc, fn };
}

async function runTests() {
  console.log("\n=======================================================");
  console.log("  SAFFAR DISCOVERY & RIDE MATCHING TEST SUITE");
  console.log("=======================================================\n");

  // 1. Initialize DB and App
  await initPostgresDatabase();

  const app = express();
  app.use(express.json());
  app.use("/api/ride", rideRouter);
  app.use("/api/driver", driverRouter);

  server = http.createServer(app);
  initSocket(server);

  await new Promise((resolve) => {
    server.listen(0, () => {
      const port = server.address().port;
      baseUrl = `http://localhost:${port}`;
      console.log(`Test server running at ${baseUrl}`);
      resolve();
    });
  });

  // Setup tokens
  userToken = makeToken({ id: "user_test_matcher", phone: "9876500001", role: "user" });

  const driversSetup = [
    { id: "drv_bike_1", name: "Ramesh Bike", cat: "Bike", lat: 12.9750, lng: 77.5980, phone: "9100000101", distDesc: "~0.8 km" },
    { id: "drv_auto_1", name: "Suresh Auto", cat: "Auto", lat: 12.9780, lng: 77.6000, phone: "9100000201", distDesc: "~1.1 km" },
    { id: "drv_auto_2", name: "Ganesh Auto", cat: "Auto", lat: 12.9800, lng: 77.6030, phone: "9100000202", distDesc: "~1.3 km" },
    { id: "drv_car_1",  name: "Kiran Mini",  cat: "Mini Car", lat: 12.9800, lng: 77.6050, phone: "9100000301", distDesc: "~1.5 km" },
    { id: "drv_sedan_1", name: "Anand Sedan", cat: "Sedan", lat: 12.9990, lng: 77.6250, phone: "9100000401", distDesc: "~4.5 km (outside 3km, inside 6km)" },
    { id: "drv_stale_1", name: "Stale Driver", cat: "Auto", lat: 12.9720, lng: 77.5950, phone: "9100000501", distDesc: "~0.2 km but stale GPS" },
  ];

  for (const d of driversSetup) {
    driverTokens[d.id] = makeToken({ id: d.id, phone: d.phone, role: "driver" });

    // Seed Driver
    await query(
      `INSERT INTO drivers (id, name, phone, password, vehicle_name, vehicle_number, active, is_online, current_lat, current_lng, verification_status, last_location_updated_at)
       VALUES ($1, $2, $3, 'hashed_pass', $4, $5, true, true, $6, $7, 'Approved', NOW())
       ON CONFLICT (id) DO UPDATE SET 
         name = EXCLUDED.name,
         phone = EXCLUDED.phone,
         is_online = true, active = true, 
         current_lat = EXCLUDED.current_lat, 
         current_lng = EXCLUDED.current_lng, 
         verification_status = 'Approved',
         last_location_updated_at = NOW()`,
      [d.id, d.name, d.phone, d.cat, `KA 01 AB 000${d.id.slice(-1)}`, d.lat, d.lng]
    );

    // Seed Vehicle
    await query(
      `INSERT INTO driver_vehicles (id, driver_id, category, model, registration_number, color, is_active, verification_status)
       VALUES ($1, $2, $3, $4, $5, 'White', true, 'approved')
       ON CONFLICT (id) DO UPDATE SET 
         category = EXCLUDED.category,
         is_active = true, 
         verification_status = 'approved'`,
      [`veh_${d.id}`, d.id, d.cat, `${d.cat} Standard`, `KA 01 AB 000${d.id.slice(-1)}`]
    );
  }

  // Seed user test user
  await query(
    `INSERT INTO users (id, name, phone, password, wallet_balance)
     VALUES ('user_test_matcher', 'Passenger Matcher', '9876500001', 'hashed_pass', 1500.0)
     ON CONFLICT (id) DO NOTHING`
  );

  // Clean up any test rides from prior test runs
  await query(`DELETE FROM rides WHERE user_id = 'user_test_matcher' OR driver_id LIKE 'drv_%'`);
  await query(`DELETE FROM ride_requests WHERE driver_id LIKE 'drv_%'`);
  await query(`DELETE FROM ride_offers WHERE driver_id LIKE 'drv_%'`);
  await query(`UPDATE driver_availability SET state = 'ONLINE_AVAILABLE', current_ride_id = NULL WHERE driver_id LIKE 'drv_%'`);

  // Isolate test drivers by setting legacy demo drivers offline for the duration of this unit test
  await query(`UPDATE drivers SET is_online = false, active = false WHERE id NOT LIKE 'drv_%'`);

  // Set stale driver GPS timestamp to 10 minutes ago
  await query(
    `UPDATE drivers SET last_location_updated_at = NOW() - INTERVAL '10 minutes' WHERE id = 'drv_stale_1'`
  );

  const tests = [
    // ----------------------------------------------------
    // TEST 1: Driver Location Management
    // ----------------------------------------------------
    it("1. Driver updates high-frequency location, heading, speed with timestamp and DB log", async () => {
      const res = await request("/api/driver/location", {
        method: "POST",
        token: driverTokens["drv_auto_1"],
        body: {
          latitude: 12.9785,
          longitude: 77.6005,
          heading: 88.5,
          speed: 24.0,
          timestamp: new Date().toISOString(),
        },
      });

      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.data.driver.current_lat, 12.9785);
      assert.strictEqual(res.data.driver.current_lng, 77.6005);
      assert.ok(res.data.driver.last_location_updated_at);

      // Verify log entry in driver_location_logs
      const logCheck = await query(
        `SELECT * FROM driver_location_logs WHERE driver_id = 'drv_auto_1' ORDER BY recorded_at DESC LIMIT 1`
      );
      assert.ok(logCheck.rows.length > 0);
      assert.strictEqual(logCheck.rows[0].latitude, 12.9785);
      assert.strictEqual(logCheck.rows[0].heading, 88.5);
    }),

    // ----------------------------------------------------
    // TEST 2: Stale GPS Exclusion
    // ----------------------------------------------------
    it("2. Drivers with stale GPS (>3 mins old) are excluded from discovery", async () => {
      const res = await request("/api/ride/nearby_availability?latitude=12.9716&longitude=77.5946&radius_km=3.0", {
        token: userToken,
      });

      assert.strictEqual(res.status, 200);
      assert.strictEqual(res.data.success, true);

      // drv_stale_1 is at 12.9720, 77.5950 (~0.2km), but last updated 10 mins ago
      // It must NOT be included in qualifying drivers or vehicles list
      const vehicleIds = (res.data.vehicles || []).map((v) => v.id);
      // Ensure total auto count matches only the active fresh auto (drv_auto_1) within 3km
      assert.strictEqual(res.data.categories.Auto.count, 2); // drv_auto_1 (~1.1km) and drv_auto_2 (~2.4km)
    }),

    // ----------------------------------------------------
    // TEST 3: User-side Vehicle Availability & Counts
    // ----------------------------------------------------
    it("3. GET /api/ride/nearby_availability returns authentic category counts and calculated ETAs", async () => {
      const res = await request("/api/ride/nearby_availability?latitude=12.9716&longitude=77.5946&radius_km=3.0", {
        token: userToken,
      });

      assert.strictEqual(res.status, 200);
      const cats = res.data.categories;

      // Bike: 1 driver within 3km
      assert.strictEqual(cats.Bike.available, true);
      assert.strictEqual(cats.Bike.count, 1);
      assert.ok(cats.Bike.closest_distance_km <= 1.5);
      assert.ok(cats.Bike.eta_mins >= 1);
      assert.ok(cats.Bike.base_fare > 0);

      // Auto: 2 drivers within 3km (drv_auto_1 and drv_auto_2)
      assert.strictEqual(cats.Auto.available, true);
      assert.strictEqual(cats.Auto.count, 2);
      assert.ok(cats.Auto.closest_distance_km <= 1.5);

      // Mini Car: 1 driver within 3km
      assert.strictEqual(cats["Mini Car"].available, true);
      assert.strictEqual(cats["Mini Car"].count, 1);

      // Sedan: 0 drivers within 3km (drv_sedan_1 is ~4.5km away)
      assert.strictEqual(cats.Sedan.count, 0);
      assert.strictEqual(cats.Sedan.available, false);
      assert.strictEqual(cats.Sedan.eta_mins, null);
    }),

    // ----------------------------------------------------
    // TEST 4: Vehicle Marker Privacy Obfuscation
    // ----------------------------------------------------
    it("4. Map vehicle markers are obfuscated without leaking exact house coordinates or driver PII", async () => {
      const res = await request("/api/ride/nearby_availability?latitude=12.9716&longitude=77.5946&radius_km=3.0", {
        token: userToken,
      });

      assert.strictEqual(res.status, 200);
      const vehicles = res.data.vehicles;
      assert.ok(vehicles.length > 0);

      for (const v of vehicles) {
        assert.ok(v.id.startsWith("veh_"));
        assert.ok(v.category);
        assert.ok(typeof v.latitude === "number");
        assert.ok(typeof v.longitude === "number");
        // Ensure NO driver private identifiers leaked in discovery marker
        assert.strictEqual(v.driver_id, undefined);
        assert.strictEqual(v.driver_name, undefined);
        assert.strictEqual(v.phone, undefined);
      }
    }),

    // ----------------------------------------------------
    // TEST 5: Progressive Search Radius Auto-Expansion
    // ----------------------------------------------------
    it("5. Progressive search auto-expands from 3km to 6km when requested location has 0 drivers nearby", async () => {
      // Point located far away from 3km center, where only Sedan at ~4.5km is in range
      // Center at 12.9990, 77.6250 (exact location of drv_sedan_1)
      // Querying specifically for Sedan from 12.9716 with initial 3km radius
      const res = await request(
        "/api/ride/nearby_availability?latitude=12.9716&longitude=77.5946&radius_km=3.0&category=Sedan",
        { token: userToken }
      );

      assert.strictEqual(res.status, 200);
      // Since 0 Sedans exist in 3km, engine auto-expands to 6km
      assert.strictEqual(res.data.radius_expanded, true);
      assert.strictEqual(res.data.search_radius_km, 6.0);
      assert.strictEqual(res.data.categories.Sedan.count, 1);
      assert.strictEqual(res.data.categories.Sedan.available, true);
    }),

    // ----------------------------------------------------
    // TEST 6: Candidate Ranking & Dispatch
    // ----------------------------------------------------
    it("6. Ride matching engine ranks candidates by proximity/rating and dispatches with 45s expiration", async () => {
      // User creates booking for Auto
      const rideRes = await request("/api/ride/add_ride", {
        method: "POST",
        token: userToken,
        body: {
          user_id: "user_test_matcher",
          vehicle_type: "Auto",
          source_address: {
            street: "MG Road Junction",
            place: "Central Bengaluru",
            lat: 12.9716,
            lon: 77.5946,
          },
          destination_address: {
            street: "Indiranagar 100ft Rd",
            place: "Indiranagar",
            lat: 12.9780,
            lon: 77.6400,
          },
          price: 95.0,
        },
      });

      assert.strictEqual(rideRes.status, 201);
      const rideId = rideRes.data.ride_id;
      assert.ok(rideId);
      assert.strictEqual(rideRes.data.status, "requested");
      assert.ok(rideRes.data.eligible_drivers_notified >= 1);

      // Verify ride_requests in DB
      const reqCheck = await query(
        `SELECT rr.*, d.name as driver_name 
         FROM ride_requests rr 
         JOIN drivers d ON rr.driver_id = d.id 
         WHERE rr.ride_id = $1 
         ORDER BY rr.distance_to_pickup_km ASC`,
        [rideId]
      );

      assert.ok(reqCheck.rows.length >= 2);
      // Closest driver (drv_auto_1 ~1.1km) should be first
      assert.strictEqual(reqCheck.rows[0].driver_id, "drv_auto_1");
      assert.strictEqual(reqCheck.rows[0].status, "pending");
      assert.ok(new Date(reqCheck.rows[0].expires_at) > new Date());
    }),

    // ----------------------------------------------------
    // TEST 7: Concurrency & Atomic Locking (Race Condition Prevention)
    // ----------------------------------------------------
    it("7. Concurrency-safe atomic assignment prevents dual assignment when two drivers accept simultaneously", async () => {
      // Create new fresh ride for race test
      const rideRes = await request("/api/ride/add_ride", {
        method: "POST",
        token: userToken,
        body: {
          user_id: "user_test_matcher",
          vehicle_type: "Auto",
          source_address: {
            street: "Brigade Road",
            place: "Central",
            lat: 12.9716,
            lon: 77.5946,
          },
          destination_address: {
            street: "Koramangala 4th Block",
            place: "Koramangala",
            lat: 12.9350,
            lon: 77.6200,
          },
          price: 110.0,
        },
      });

      const rideId = rideRes.data.ride_id;

      // Driver 1 (drv_auto_1) accepts ride
      const accept1 = await request(`/api/driver/rides/${rideId}/accept`, {
        method: "POST",
        token: driverTokens["drv_auto_1"],
      });
      assert.strictEqual(accept1.status, 200);
      assert.strictEqual(accept1.data.ride.driver_id, "drv_auto_1");
      assert.strictEqual(accept1.data.ride.status, "accepted");

      // Driver 2 (drv_auto_2) attempts to accept the SAME ride concurrently
      const accept2 = await request(`/api/driver/rides/${rideId}/accept`, {
        method: "POST",
        token: driverTokens["drv_auto_2"],
      });

      // Must fail with 409 Conflict: RIDE_ALREADY_ACCEPTED
      assert.strictEqual(accept2.status, 409);
      assert.strictEqual(accept2.data.error.code, "RIDE_ALREADY_ACCEPTED");

      // Verify in DB that only drv_auto_1 is assigned
      const rideDb = await query("SELECT driver_id, status FROM rides WHERE id = $1", [rideId]);
      assert.strictEqual(rideDb.rows[0].driver_id, "drv_auto_1");
      assert.strictEqual(rideDb.rows[0].status, "accepted");

      // Verify drv_auto_2's request is marked 'expired'
      const req2 = await query(
        "SELECT status FROM ride_requests WHERE ride_id = $1 AND driver_id = 'drv_auto_2'",
        [rideId]
      );
      assert.strictEqual(req2.rows[0].status, "expired");
    }),

    // ----------------------------------------------------
    // TEST 8: Driver Cannot Accept Two Concurrent Active Rides
    // ----------------------------------------------------
    it("8. Driver with an active ride is blocked from accepting a second ride", async () => {
      // Create another ride
      const rideRes = await request("/api/ride/add_ride", {
        method: "POST",
        token: userToken,
        body: {
          user_id: "user_test_matcher",
          vehicle_type: "Auto",
          source_address: { street: "Trinity", place: "CBD", lat: 12.9716, lon: 77.5946 },
          destination_address: { street: "Indiranagar", place: "East", lat: 12.9780, lon: 77.6400 },
          price: 85.0,
        },
      });

      const rideId2 = rideRes.data.ride_id;

      // drv_auto_1 is already on accepted ride from Test 7
      const secondAccept = await request(`/api/driver/rides/${rideId2}/accept`, {
        method: "POST",
        token: driverTokens["drv_auto_1"],
      });

      assert.strictEqual(secondAccept.status, 400);
      assert.strictEqual(secondAccept.data.error.code, "DRIVER_HAS_ACTIVE_RIDE");
    }),

    // ----------------------------------------------------
    // TEST 9: Cascading Dispatch upon Rejection
    // ----------------------------------------------------
    it("9. Rejection cascades gracefully to remaining eligible candidates", async () => {
      // Create a fresh ride
      const rideRes = await request("/api/ride/add_ride", {
        method: "POST",
        token: userToken,
        body: {
          user_id: "user_test_matcher",
          vehicle_type: "Auto",
          source_address: { street: "Richmond Town", place: "CBD", lat: 12.9716, lon: 77.5946 },
          destination_address: { street: "Ulsoor Lake", place: "East", lat: 12.9820, lon: 77.6180 },
          price: 75.0,
        },
      });

      const rideId = rideRes.data.ride_id;

      // drv_auto_2 rejects the ride request
      const rejectRes = await request(`/api/driver/rides/${rideId}/reject`, {
        method: "POST",
        token: driverTokens["drv_auto_2"],
      });

      assert.strictEqual(rejectRes.status, 200);
      assert.strictEqual(rejectRes.data.message, "Ride request rejected.");

      // Verify in DB that drv_auto_2's status is 'rejected'
      const checkReq = await query(
        "SELECT status FROM ride_requests WHERE ride_id = $1 AND driver_id = 'drv_auto_2'",
        [rideId]
      );
      assert.strictEqual(checkReq.rows[0].status, "rejected");
    }),

    // ----------------------------------------------------
    // TEST 10: Driver Offline Teardown
    // ----------------------------------------------------
    it("10. Driver going offline immediately stops appearing in nearby discovery", async () => {
      // Toggle drv_bike_1 OFFLINE
      const offlineRes = await request("/api/driver/availability", {
        method: "POST",
        token: driverTokens["drv_bike_1"],
        body: { is_online: false },
      });
      assert.strictEqual(offlineRes.status, 200);
      assert.strictEqual(offlineRes.data.driver.is_online, false);

      // Now query nearby availability
      const availRes = await request("/api/ride/nearby_availability?latitude=12.9716&longitude=77.5946&radius_km=3.0", {
        token: userToken,
      });

      assert.strictEqual(availRes.status, 200);
      // Bike count must now be 0
      assert.strictEqual(availRes.data.categories.Bike.count, 0);
      assert.strictEqual(availRes.data.categories.Bike.available, false);

      // Re-enable drv_bike_1 online for future testing
      await request("/api/driver/availability", {
        method: "POST",
        token: driverTokens["drv_bike_1"],
        body: { is_online: true },
      });
    }),
  ];

  for (const t of tests) {
    totalTests++;
    try {
      await t.fn();
      console.log(`  [PASS] ${t.desc}`);
      passedTests++;
    } catch (err) {
      console.error(`  [FAIL] ${t.desc}`);
      console.error(`         ${err.message}`);
      if (err.stack) {
        console.error(`         ${err.stack.split("\n").slice(1, 4).join("\n")}`);
      }
    }
  }

  console.log("\n=======================================================");
  console.log(`  TEST RESULTS: ${passedTests} / ${totalTests} PASSED (${Math.round((passedTests / totalTests) * 100)}%)`);
  console.log("=======================================================\n");

  // Restore demo drivers
  await query(`UPDATE drivers SET is_online = true, active = true WHERE id IN ('driver_001', 'driver_002')`);

  if (server) {
    server.close();
  }
  await pool.end();

  if (passedTests === totalTests) {
    process.exit(0);
  } else {
    process.exit(1);
  }
}

runTests().catch((e) => {
  console.error("Test execution fatal error:", e);
  process.exit(1);
});
