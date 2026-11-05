require('./config/polyfill');
require("./config/polyfill");
const http = require("http");
const app = require("./app");
const { query, initPostgresDatabase } = require("./database");

const TEST_PORT = 5097;

function makeRequest(method, path, data = null, token = null) {
  return new Promise((resolve, reject) => {
    const postData = data ? JSON.stringify(data) : null;
    const headers = { "Content-Type": "application/json" };
    if (token) headers["Authorization"] = `Bearer ${token}`;
    if (postData) headers["Content-Length"] = Buffer.byteLength(postData);

    const fullPath = path.startsWith("/api") ? path : `/api${path}`;

    const req = http.request(
      {
        hostname: "127.0.0.1",
        port: TEST_PORT,
        path: fullPath,
        method,
        headers,
      },
      (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => {
          try {
            resolve({ status: res.statusCode, data: JSON.parse(body) });
          } catch (_) {
            resolve({ status: res.statusCode, raw: body });
          }
        });
      }
    );
    req.on("error", reject);
    if (postData) req.write(postData);
    req.end();
  });
}

async function runTests() {
  console.log("==================================================");
  console.log("   SAFFAR DRIVER AVAILABILITY & LOCATION TESTS    ");
  console.log("==================================================");

  await initPostgresDatabase();

  const server = http.createServer(app);
  await new Promise((res) => server.listen(TEST_PORT, res));
  console.log(`Test server running on port ${TEST_PORT}\n`);

  try {
    // 1. Authenticate as Driver
    console.log("[TEST 1] Authenticating as Driver...");
    const authRes = await makeRequest("POST", "/auth/driver_sign_in", {
      phone: "9988776655",
      password: "password123",
    });
    if (authRes.status !== 200 || !authRes.data.token) {
      throw new Error(`Auth failed: ${JSON.stringify(authRes.data)}`);
    }
    const token = authRes.data.token;
    const driverId = authRes.data.driver.id;
    console.log(`✅ Authenticated! Driver ID: ${driverId}`);

    // Ensure any stale test rides are marked completed so test state is clean
    await query(
      `UPDATE rides SET status = 'completed', end_time = NOW() 
       WHERE driver_id = $1 AND end_time IS NULL`,
      [driverId]
    );

    // Ensure driver has an approved active vehicle
    await query(
      `UPDATE driver_vehicles SET is_active = true, verification_status = 'approved'
       WHERE driver_id = $1 AND id = (SELECT id FROM driver_vehicles WHERE driver_id = $1 LIMIT 1)`,
      [driverId]
    );

    // 2. Test Going Online (POST /driver/availability)
    console.log("\n[TEST 2] Toggling Online with Initial Coordinates...");
    const onlineRes = await makeRequest("POST", "/driver/availability", {
      is_online: true,
      latitude: 12.9716,
      longitude: 77.5946,
      heading: 90.0,
      speed: 15.5,
    }, token);
    if (onlineRes.status !== 200) {
      throw new Error(`Failed to go online: ${JSON.stringify(onlineRes.data)}`);
    }
    if (!onlineRes.data.driver.is_online || !onlineRes.data.driver.active) {
      throw new Error(`Driver is_online flag was not set to true!`);
    }
    console.log(`✅ Driver is now ONLINE! Lat: ${onlineRes.data.driver.current_lat}, Lng: ${onlineRes.data.driver.current_lng}`);

    // 3. Test Location Updates (POST /driver/location)
    console.log("\n[TEST 3] Updating Driver Live Location...");
    const newLat = 12.9780;
    const newLng = 77.6400;
    const locRes = await makeRequest("POST", "/driver/location", {
      latitude: newLat,
      longitude: newLng,
      heading: 180.0,
      speed: 25.0,
      timestamp: new Date().toISOString(),
    }, token);
    if (locRes.status !== 200) {
      throw new Error(`Failed to update location: ${JSON.stringify(locRes.data)}`);
    }
    console.log(`✅ Location updated! Driver Lat: ${locRes.data.location.latitude}, Lng: ${locRes.data.location.longitude}, Heading: ${locRes.data.location.heading}°`);

    // Verify in database and log table
    const dbLoc = await query("SELECT current_lat, current_lng, last_location_updated_at FROM drivers WHERE id = $1", [driverId]);
    if (Math.abs(dbLoc.rows[0].current_lat - newLat) > 0.0001) {
      throw new Error("Latitude in database does not match updated location!");
    }
    const logCount = await query("SELECT COUNT(*) FROM driver_location_logs WHERE driver_id = $1", [driverId]);
    console.log(`✅ Verified in DB: current_lat=${dbLoc.rows[0].current_lat}, logs recorded=${logCount.rows[0].count}`);

    // 4. Test Invalid Coordinates (validation check)
    console.log("\n[TEST 4] Testing Invalid Latitude/Longitude validation...");
    const invalidLocRes = await makeRequest("POST", "/driver/location", {
      latitude: 195.0, // Invalid latitude
      longitude: 77.0,
    }, token);
    if (invalidLocRes.status !== 400 || invalidLocRes.data.error.code !== "INVALID_LATITUDE") {
      throw new Error(`Validation check failed: expected 400 INVALID_LATITUDE, got ${JSON.stringify(invalidLocRes)}`);
    }
    console.log(`✅ Validation correctly rejected invalid latitude: ${invalidLocRes.data.error.message}`);

    // 5. Test Driver Status Endpoint (GET /driver/status)
    console.log("\n[TEST 5] Fetching Driver Status (GET /driver/status)...");
    const statusRes = await makeRequest("GET", "/driver/status", null, token);
    if (statusRes.status !== 200) {
      throw new Error(`Failed to get status: ${JSON.stringify(statusRes.data)}`);
    }
    console.log(`✅ Status retrieved: is_online=${statusRes.data.driver.is_online}, lat=${statusRes.data.driver.current_lat}, lng=${statusRes.data.driver.current_lng}`);

    // 6. Test Vehicle Eligibility Check when Going Online
    console.log("\n[TEST 6] Testing Vehicle Eligibility Check (No active verified vehicle)...");
    // Temporarily mark vehicle inactive
    await query("UPDATE driver_vehicles SET is_active = false WHERE driver_id = $1", [driverId]);
    const blockedOnlineRes = await makeRequest("POST", "/driver/availability", {
      is_online: true,
    }, token);
    if (blockedOnlineRes.status !== 400 || blockedOnlineRes.data.error.code !== "NO_ACTIVE_VEHICLE") {
      throw new Error(`Expected NO_ACTIVE_VEHICLE error, got ${JSON.stringify(blockedOnlineRes)}`);
    }
    console.log(`✅ Correctly blocked online toggle without active vehicle: ${blockedOnlineRes.data.error.message}`);

    // Restore active vehicle
    await query("UPDATE driver_vehicles SET is_active = true, verification_status = 'approved' WHERE driver_id = $1", [driverId]);

    // 7. Test Active Ride Protection when Going Offline
    console.log("\n[TEST 7] Testing Active Ride Protection when Going Offline...");
    // Insert dummy in-progress ride
    const dummyRideId = `ride_test_${Date.now()}`;
    await query(
      `INSERT INTO rides (id, user_id, driver_id, start_time, price, status, cancelled)
       VALUES ($1, 'user_001', $2, NOW(), 120.0, 'in_progress', false)`,
      [dummyRideId, driverId]
    );

    const blockedOfflineRes = await makeRequest("POST", "/driver/availability", {
      is_online: false,
    }, token);
    if (blockedOfflineRes.status !== 400 || blockedOfflineRes.data.error.code !== "ACTIVE_RIDE_EXISTS") {
      throw new Error(`Expected ACTIVE_RIDE_EXISTS error, got ${JSON.stringify(blockedOfflineRes)}`);
    }
    console.log(`✅ Correctly blocked offline toggle during active trip: ${blockedOfflineRes.data.error.message}`);

    // Complete the test ride
    await query("UPDATE rides SET status = 'completed', end_time = NOW() WHERE id = $1", [dummyRideId]);

    // 8. Test Going Offline (POST /driver/availability)
    console.log("\n[TEST 8] Toggling Driver OFFLINE...");
    const offlineRes = await makeRequest("POST", "/driver/availability", {
      is_online: false,
    }, token);
    if (offlineRes.status !== 200) {
      throw new Error(`Failed to go offline: ${JSON.stringify(offlineRes.data)}`);
    }
    if (offlineRes.data.driver.is_online || offlineRes.data.driver.active) {
      throw new Error(`Driver is_online flag was not set to false!`);
    }
    console.log(`✅ Driver is now successfully OFFLINE!`);

    console.log("\n==================================================");
    console.log("   🎉 ALL AVAILABILITY & LOCATION TESTS PASSED!   ");
    console.log("==================================================");
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
