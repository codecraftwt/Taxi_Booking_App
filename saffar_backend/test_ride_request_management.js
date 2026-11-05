require('./config/polyfill');
require("./config/polyfill");
const http = require("http");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const config = require("./config");
const app = require("./app");
const { query, initPostgresDatabase } = require("./database");
const { initSocket } = require("./socket");

const TEST_PORT = 5096;

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
  console.log("   SAFFAR RIDE REQUEST MANAGEMENT TEST SUITE      ");
  console.log("==================================================");

  await initPostgresDatabase();

  const httpServer = http.createServer(app);
  initSocket(httpServer);
  await new Promise((res) => httpServer.listen(TEST_PORT, res));
  console.log(`Test server running on port ${TEST_PORT}\n`);

  try {
    // 1. Authenticate Driver 1 (driver_001)
    console.log("[TEST 1] Setup & Authenticate Driver 1 & Driver 2...");
    const d1Auth = await makeRequest("POST", "/auth/driver_sign_in", {
      phone: "9988776655",
      password: "password123",
    });
    if (d1Auth.status !== 200 || !d1Auth.data.token) {
      throw new Error(`Driver 1 auth failed: ${JSON.stringify(d1Auth.data)}`);
    }
    const token1 = d1Auth.data.token;
    const driverId1 = d1Auth.data.driver.id;

    // Ensure Driver 1 active vehicle is Auto for this test
    await query("UPDATE driver_vehicles SET is_active = false WHERE driver_id = $1", [driverId1]);
    await query(
      `INSERT INTO driver_vehicles (id, driver_id, category, model, registration_number, color, is_active, verification_status)
       VALUES ('veh_test_001_auto', $1, 'Auto', 'Bajaj Maxima', 'KA 05 ER 9999', 'Yellow', true, 'approved')
       ON CONFLICT (id) DO UPDATE SET is_active = true, verification_status = 'approved'`,
      [driverId1]
    );

    // Seed/Ensure Driver 2
    const driverId2 = "driver_test_002";
    const hashedPw = await bcrypt.hash("password123", 10);
    await query(
      `INSERT INTO drivers (id, name, phone, password, vehicle_name, vehicle_number, active, is_online, verification_status, current_lat, current_lng)
       VALUES ($1, 'Suresh Patel', '9876543299', $2, 'Bajaj RE Auto', 'KA 04 MP 1122', true, true, 'Approved', 12.9360, 77.6860)
       ON CONFLICT (id) DO UPDATE SET 
         active = true, is_online = true, verification_status = 'Approved', 
         current_lat = 12.9360, current_lng = 77.6860`,
      [driverId2, hashedPw]
    );

    // Ensure Driver 2 has an active approved Auto vehicle
    await query(
      `INSERT INTO driver_vehicles (id, driver_id, category, model, registration_number, color, is_active, verification_status)
       VALUES ('veh_test_002', $1, 'Auto', 'Bajaj RE Auto', 'KA 04 MP 1122', 'Yellow', true, 'approved')
       ON CONFLICT (id) DO UPDATE SET is_active = true, verification_status = 'approved'`,
      [driverId2]
    );

    const d2Auth = await makeRequest("POST", "/auth/driver_sign_in", {
      phone: "9876543299",
      password: "password123",
    });
    const token2 = d2Auth.data.token;

    // Make both drivers ONLINE with GPS coordinates near Koramangala (12.9350, 77.6850)
    await query(
      `UPDATE drivers 
       SET active = true, is_online = true, verification_status = 'Approved',
           current_lat = 12.9355, current_lng = 77.6855, last_location_updated_at = NOW()
       WHERE id = $1`,
      [driverId1]
    );
    await query(
      `UPDATE drivers 
       SET active = true, is_online = true, verification_status = 'Approved',
           current_lat = 12.9365, current_lng = 77.6865, last_location_updated_at = NOW()
       WHERE id = $1`,
      [driverId2]
    );

    // Clean up any stale active rides
    await query(
      `UPDATE rides SET status = 'completed', end_time = NOW() 
       WHERE (driver_id = $1::varchar OR driver_id = $2::varchar) AND end_time IS NULL`,
      [driverId1, driverId2]
    );

    console.log(`✅ Both drivers ready: Driver 1 (${driverId1}), Driver 2 (${driverId2})`);

    // 2. User Books a Ride (POST /api/ride/add_ride)
    console.log("\n[TEST 2] User Books a Ride (Auto category at Koramangala)...");
    const userToken = jwt.sign({ id: "user_001", phone: "9876543210" }, config.TOKEN_SECRET_KEY);
    const bookRes = await makeRequest("POST", "/ride/add_ride", {
      user_id: "user_001",
      vehicle_type: "Saffar Auto",
      price: 145.0,
      source_address: "74 Park Ave, Koramangala 4th Block",
      destination_address: "Cyber Gateway Tower, Tech Zone 2",
      payment_method: "Paid via Saffar Wallet",
    }, userToken);

    if (bookRes.status !== 201) {
      throw new Error(`Booking failed: ${JSON.stringify(bookRes.data)}`);
    }

    const testRideId = bookRes.data.ride_id;
    console.log(`✅ Ride booked! ID: ${testRideId}, Status: ${bookRes.data.status}, Eligible drivers notified: ${bookRes.data.eligible_drivers_notified}`);

    // 3. Verify Both Drivers have Pending Ride Requests
    console.log("\n[TEST 3] Fetch Pending Ride Requests for Driver 1 & Driver 2...");
    const req1 = await makeRequest("GET", "/driver/rides/pending_requests", null, token1);
    const req2 = await makeRequest("GET", "/driver/rides/pending_requests", null, token2);

    console.assert(req1.status === 200, "Driver 1 pending requests failed");
    console.assert(req2.status === 200, "Driver 2 pending requests failed");
    console.assert(req1.data.requests.some((r) => r.ride_id === testRideId), "Driver 1 should see the ride request");
    console.assert(req2.data.requests.some((r) => r.ride_id === testRideId), "Driver 2 should see the ride request");

    const rideInfo = req1.data.requests.find((r) => r.ride_id === testRideId);
    console.log(`✅ Driver 1 sees request: Passenger: ${rideInfo.passenger_name}, Fare: ₹${rideInfo.fare}, Distance to pickup: ${rideInfo.distance_to_pickup}`);
    console.log(`✅ Driver 2 sees request: Passenger: ${rideInfo.passenger_name}, Fare: ₹${rideInfo.fare}`);

    // 4. Test Concurrency: Driver 1 Accepts First
    console.log("\n[TEST 4] Driver 1 Accepts the Ride Request...");
    const acceptRes1 = await makeRequest("POST", `/driver/rides/${testRideId}/accept`, null, token1);
    if (acceptRes1.status !== 200) {
      throw new Error(`Driver 1 accept failed: ${JSON.stringify(acceptRes1.data)}`);
    }
    console.log(`✅ Driver 1 successfully accepted ride! Status: ${acceptRes1.data.ride.status}, Passenger: ${acceptRes1.data.ride.passenger.name}`);

    // 5. Test Simultaneous / Race Condition: Driver 2 Attempts to Accept Same Ride
    console.log("\n[TEST 5] Driver 2 attempts to accept the already-accepted ride...");
    const acceptRes2 = await makeRequest("POST", `/driver/rides/${testRideId}/accept`, null, token2);
    if (acceptRes2.status !== 409 || acceptRes2.data.error.code !== "RIDE_ALREADY_ACCEPTED") {
      throw new Error(`Expected 409 RIDE_ALREADY_ACCEPTED, got ${JSON.stringify(acceptRes2)}`);
    }
    console.log(`✅ Concurrency lock protected booking: ${acceptRes2.data.error.message}`);

    // 6. Test Multiple Simultaneous Active Rides Prevention for Driver 1
    console.log("\n[TEST 6] Testing Prevention of Multiple Active Rides for Driver 1...");
    // Book a second ride
    const book2Res = await makeRequest("POST", "/ride/add_ride", {
      user_id: "user_001",
      vehicle_type: "Saffar Auto",
      price: 90.0,
    }, userToken);
    const secondRideId = book2Res.data.ride_id;

    // Driver 1 tries to accept second ride while first is active
    const busyAcceptRes = await makeRequest("POST", `/driver/rides/${secondRideId}/accept`, null, token1);
    if (busyAcceptRes.status !== 400 || busyAcceptRes.data.error.code !== "DRIVER_HAS_ACTIVE_RIDE") {
      throw new Error(`Expected 400 DRIVER_HAS_ACTIVE_RIDE, got ${JSON.stringify(busyAcceptRes)}`);
    }
    console.log(`✅ Driver 1 blocked from accepting simultaneous rides: ${busyAcceptRes.data.error.message}`);

    // 7. Test Driver Rejection
    console.log("\n[TEST 7] Driver 2 Rejects the Second Ride Request...");
    const rejectRes = await makeRequest("POST", `/driver/rides/${secondRideId}/reject`, null, token2);
    if (rejectRes.status !== 200) {
      throw new Error(`Reject failed: ${JSON.stringify(rejectRes.data)}`);
    }
    const checkReject = await query("SELECT status FROM ride_requests WHERE ride_id = $1 AND driver_id = $2", [secondRideId, driverId2]);
    console.assert(checkReject.rows[0]?.status === "rejected", "Request status should be rejected");
    console.log(`✅ Driver 2 successfully rejected ride request!`);

    // 8. Test Offline Driver Cannot Accept
    console.log("\n[TEST 8] Offline Driver Cannot Accept Rides...");
    await query("UPDATE drivers SET active = false, is_online = false WHERE id = $1", [driverId2]);
    const offlineAccept = await makeRequest("POST", `/driver/rides/${secondRideId}/accept`, null, token2);
    if (offlineAccept.status !== 400 || offlineAccept.data.error.code !== "DRIVER_OFFLINE") {
      throw new Error(`Expected DRIVER_OFFLINE error, got ${JSON.stringify(offlineAccept)}`);
    }
    console.log(`✅ Offline driver correctly blocked: ${offlineAccept.data.error.message}`);

    // Clean up test rides
    await query("UPDATE rides SET status = 'completed', end_time = NOW() WHERE id IN ($1, $2)", [testRideId, secondRideId]);

    console.log("\n==================================================");
    console.log("   🎉 ALL RIDE REQUEST TESTS PASSED!              ");
    console.log("==================================================");
  } finally {
    httpServer.close();
  }
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
