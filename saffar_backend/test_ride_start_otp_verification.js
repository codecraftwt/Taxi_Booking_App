const bufferModule = require("buffer");
if (!bufferModule.SlowBuffer) {
  bufferModule.SlowBuffer = bufferModule.Buffer;
}
const http = require("http");
const express = require("express");
const jwt = require("jsonwebtoken");
const crypto = require("crypto");
const config = require("./config");
const { initPostgresDatabase, query } = require("./database/db");
const driverRouter = require("./routes/driver_router");
const rideRouter = require("./routes/ride_router");
const { initSocket } = require("./socket");

const JWT_KEY = config.TOKEN_SECRET_KEY;
const OTP_SALT = process.env.OTP_SECRET || "saffar_otp_secure_salt_2026";

async function runTests() {
  console.log("=== STARTING RIDE-START OTP VERIFICATION TEST SUITE ===");
  await initPostgresDatabase();

  const app = express();
  app.use(express.json());
  app.use("/api/driver", driverRouter);
  app.use("/api/ride", rideRouter);

  const server = http.createServer(app);
  initSocket(server);

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  console.log(`Test server running on port ${port}`);

  function makeRequest(method, path, body = null, token = null) {
    return new Promise((resolve, reject) => {
      const payload = body ? JSON.stringify(body) : "";
      const headers = {
        "Content-Type": "application/json",
      };
      if (token) headers["Authorization"] = `Bearer ${token}`;
      if (payload) headers["Content-Length"] = Buffer.byteLength(payload);

      const req = http.request(
        {
          hostname: "127.0.0.1",
          port,
          path,
          method,
          headers,
        },
        (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => {
            try {
              resolve({
                status: res.statusCode,
                body: data ? JSON.parse(data) : {},
              });
            } catch (err) {
              resolve({ status: res.statusCode, raw: data });
            }
          });
        }
      );
      req.on("error", reject);
      if (payload) req.write(payload);
      req.end();
    });
  }

  try {
    // 1. Seed Passenger
    const user1Id = "usr_otp_test_01";
    const user2Id = "usr_otp_test_02";
    await query(`DELETE FROM users WHERE id IN ($1, $2) OR phone IN ('9111111111', '9222222222')`, [user1Id, user2Id]);
    await query(
      `INSERT INTO users (id, name, phone, password, email)
       VALUES ($1, 'Pooja Hegde', '9111111111', 'pass123', 'pooja@example.com')`,
      [user1Id]
    );
    await query(
      `INSERT INTO users (id, name, phone, password, email)
       VALUES ($1, 'Rohan Unauth', '9222222222', 'pass123', 'rohan@example.com')`,
      [user2Id]
    );

    const userToken1 = jwt.sign({ id: user1Id, phone: "9111111111", role: "user" }, JWT_KEY, { expiresIn: "1h" });
    const userToken2 = jwt.sign({ id: user2Id, phone: "9222222222", role: "user" }, JWT_KEY, { expiresIn: "1h" });

    // 2. Seed Drivers
    const driver1Id = "drv_otp_test_01";
    const driver2Id = "drv_otp_test_02";
    await query(`DELETE FROM driver_vehicles WHERE driver_id IN ($1, $2)`, [driver1Id, driver2Id]);
    await query(`DELETE FROM drivers WHERE id IN ($1, $2) OR phone IN ('9333333333', '9444444444')`, [driver1Id, driver2Id]);
    await query(
      `INSERT INTO drivers (id, name, phone, password, is_online, verification_status, vehicle_name, vehicle_number)
       VALUES ($1, 'Vikram Assigned', '9333333333', 'hashed123', true, 'Approved', 'Bajaj Auto', 'KA01EQ1111')`,
      [driver1Id]
    );
    await query(
      `INSERT INTO drivers (id, name, phone, password, is_online, verification_status, vehicle_name, vehicle_number)
       VALUES ($1, 'Deepak Intruder', '9444444444', 'hashed123', true, 'Approved', 'Bajaj Auto', 'KA01EQ2222')`,
      [driver2Id]
    );

    const driverToken1 = jwt.sign({ id: driver1Id, phone: "9333333333", role: "driver" }, JWT_KEY, { expiresIn: "1h" });
    const driverToken2 = jwt.sign({ id: driver2Id, phone: "9444444444", role: "driver" }, JWT_KEY, { expiresIn: "1h" });

    // 3. Seed Addresses
    const addr1Id = "addr_otp_test_01";
    const addr2Id = "addr_otp_test_02";
    await query(`DELETE FROM addresses WHERE id IN ($1, $2)`, [addr1Id, addr2Id]);
    await query(
      `INSERT INTO addresses (id, place, street, lat, lon)
       VALUES ($1, 'MG Road Metro', 'MG Road', 12.9750, 77.6090)`,
      [addr1Id]
    );
    await query(
      `INSERT INTO addresses (id, place, street, lat, lon)
       VALUES ($1, 'Whitefield Tech Park', 'ITPL Main Rd', 12.9850, 77.7300)`,
      [addr2Id]
    );

    // 4. Test 1: Ride creation with secure OTP generation
    console.log("\n--- TEST 1: Secure Ride-Specific OTP Generation ---");
    const testOtp = "7294";
    const testRideId = "ride_otp_test_101";
    const testHash = crypto.createHash("sha256").update(`${testOtp}:${testRideId}:${OTP_SALT}`).digest("hex");
    const testExpiresAt = new Date(Date.now() + 60 * 60 * 1000);

    await query(`DELETE FROM ride_requests WHERE ride_id = $1`, [testRideId]);
    await query(`DELETE FROM rides WHERE id = $1`, [testRideId]);
    await query(
      `INSERT INTO rides (
         id, user_id, driver_id, source_address_id, destination_address_id,
         start_time, price, status, otp, otp_hash, otp_expires_at,
         otp_attempts, max_otp_attempts, otp_verified, vehicle_type
       )
       VALUES ($1, $2, $3, $4, $5, NOW(), 160.0, 'arrived', $6, $7, $8, 0, 5, false, 'Saffar Auto')`,
      [testRideId, user1Id, driver1Id, addr1Id, addr2Id, testOtp, testHash, testExpiresAt]
    );
    console.log(`✓ Ride seeded with secure OTP: ${testOtp}, Hash: ${testHash.substring(0, 16)}...`);

    // Test 2: User OTP Retrieval (Only authenticated user who created ride)
    console.log("\n--- TEST 2: User OTP Retrieval Endpoint ---");
    const userOtpRes = await makeRequest("GET", `/api/ride/${testRideId}/otp`, null, userToken1);
    console.log(`Status: ${userOtpRes.status}, OTP: ${userOtpRes.body.otp}`);
    if (userOtpRes.status !== 200 || userOtpRes.body.otp !== testOtp) {
      throw new Error(`Failed to retrieve OTP for authorized user: ${JSON.stringify(userOtpRes.body)}`);
    }

    // Unauthorized user attempt
    const unauthUserOtpRes = await makeRequest("GET", `/api/ride/${testRideId}/otp`, null, userToken2);
    console.log(`Unauthorized user status: ${unauthUserOtpRes.status}`);
    if (unauthUserOtpRes.status !== 403) {
      throw new Error(`Expected 403 for unauthorized user viewing OTP, got ${unauthUserOtpRes.status}`);
    }
    console.log("✓ TEST 2 PASSED: Authenticated passenger sees OTP; unrelated users blocked with 403.");

    // Test 3: Driver APIs must NOT expose passenger OTP
    console.log("\n--- TEST 3: Driver APIs Must Not Expose OTP ---");
    const assignedRes = await makeRequest("GET", `/api/driver/rides/${testRideId}/assigned`, null, driverToken1);
    console.log(`Driver assigned endpoint otp field: ${assignedRes.body.ride?.otp}`);
    if (assignedRes.body.ride?.otp !== undefined) {
      throw new Error("SECURITY LEAK: Driver assigned details endpoint exposed the passenger OTP!");
    }
    console.log("✓ TEST 3 PASSED: Driver assigned booking details does NOT expose the passenger OTP.");

    // Test 4: Unauthorized Driver Attempt to Verify OTP
    console.log("\n--- TEST 4: Unauthorized Driver OTP Verification Prevention ---");
    const unauthDriverVerifyRes = await makeRequest(
      "POST",
      `/api/driver/rides/${testRideId}/verify_otp_start`,
      { otp: testOtp },
      driverToken2
    );
    console.log(`Unauthorized driver status: ${unauthDriverVerifyRes.status}, Code: ${unauthDriverVerifyRes.body.error?.code}`);
    if (unauthDriverVerifyRes.status !== 403) {
      throw new Error(`Expected 403 for unauthorized driver verifying OTP, got ${unauthDriverVerifyRes.status}`);
    }
    console.log("✓ TEST 4 PASSED: Intruding driver blocked from verifying another driver's booking.");

    // Test 5: Invalid OTP & Attempt Limits
    console.log("\n--- TEST 5: Invalid OTP & Attempt Tracking ---");
    const invalidRes1 = await makeRequest(
      "POST",
      `/api/driver/rides/${testRideId}/verify_otp_start`,
      { otp: "0000" },
      driverToken1
    );
    console.log(`Invalid OTP status: ${invalidRes1.status}, Remaining: ${invalidRes1.body.error?.remaining_attempts}`);
    if (invalidRes1.status !== 400 || invalidRes1.body.error?.remaining_attempts !== 4) {
      throw new Error(`Expected 4 remaining attempts, got: ${JSON.stringify(invalidRes1.body)}`);
    }

    const invalidRes2 = await makeRequest(
      "POST",
      `/api/driver/rides/${testRideId}/verify_otp_start`,
      { otp: "1111" },
      driverToken1
    );
    console.log(`Invalid OTP 2nd try status: ${invalidRes2.status}, Remaining: ${invalidRes2.body.error?.remaining_attempts}`);
    if (invalidRes2.body.error?.remaining_attempts !== 3) {
      throw new Error(`Expected 3 remaining attempts, got: ${JSON.stringify(invalidRes2.body)}`);
    }
    console.log("✓ TEST 5 PASSED: Invalid OTP rejected and attempt counter tracks correctly.");

    // Test 6: Successful OTP Verification & Trip Start
    console.log("\n--- TEST 6: Successful OTP Verification & Trip Start ---");
    const successRes = await makeRequest(
      "POST",
      `/api/driver/rides/${testRideId}/verify_otp_start`,
      { otp: testOtp },
      driverToken1
    );
    console.log(`Status: ${successRes.status}, Message: ${successRes.body.message}`);
    if (successRes.status !== 200 || successRes.body.status !== "started" || !successRes.body.trip_started_at) {
      throw new Error(`OTP verification failed: ${JSON.stringify(successRes.body)}`);
    }

    // Verify DB update
    const dbRide = await query(`SELECT status, otp_verified, trip_started_at FROM rides WHERE id = $1`, [testRideId]);
    if (dbRide.rows[0].status !== "started" || !dbRide.rows[0].otp_verified || !dbRide.rows[0].trip_started_at) {
      throw new Error("PostgreSQL ride row not updated to started/verified!");
    }
    console.log(`DB Timestamp for trip_started_at: ${dbRide.rows[0].trip_started_at}`);
    console.log("✓ TEST 6 PASSED: OTP verified, status updated to 'started', and trip_started_at saved.");

    // Test 7: Prevent Repeated OTP Usage / Replay
    console.log("\n--- TEST 7: Prevent Repeated OTP Replay ---");
    const replayRes = await makeRequest(
      "POST",
      `/api/driver/rides/${testRideId}/verify_otp_start`,
      { otp: testOtp },
      driverToken1
    );
    console.log(`Replay status: ${replayRes.status}, Code: ${replayRes.body.error?.code}`);
    if (replayRes.status !== 400 || replayRes.body.error?.code !== "TRIP_ALREADY_STARTED") {
      throw new Error(`Expected TRIP_ALREADY_STARTED for repeated OTP use, got ${JSON.stringify(replayRes.body)}`);
    }
    console.log("✓ TEST 7 PASSED: Single-use rule strictly enforced; repeated OTP usage blocked.");

    // Test 8: Expired OTP Scenario
    console.log("\n--- TEST 8: Expired OTP Scenario ---");
    const expiredRideId = "ride_otp_expired_102";
    const expiredOtp = "8899";
    const expiredHash = crypto.createHash("sha256").update(`${expiredOtp}:${expiredRideId}:${OTP_SALT}`).digest("hex");
    const pastExpiresAt = new Date(Date.now() - 10 * 60 * 1000); // 10 minutes ago

    await query(`DELETE FROM rides WHERE id = $1`, [expiredRideId]);
    await query(
      `INSERT INTO rides (
         id, user_id, driver_id, source_address_id, destination_address_id,
         start_time, price, status, otp, otp_hash, otp_expires_at,
         otp_attempts, max_otp_attempts, otp_verified, vehicle_type
       )
       VALUES ($1, $2, $3, $4, $5, NOW(), 120.0, 'arrived', $6, $7, $8, 0, 5, false, 'Saffar Auto')`,
      [expiredRideId, user1Id, driver1Id, addr1Id, addr2Id, expiredOtp, expiredHash, pastExpiresAt]
    );

    const expiredRes = await makeRequest(
      "POST",
      `/api/driver/rides/${expiredRideId}/verify_otp_start`,
      { otp: expiredOtp },
      driverToken1
    );
    console.log(`Expired OTP status: ${expiredRes.status}, Code: ${expiredRes.body.error?.code}`);
    if (expiredRes.status !== 400 || expiredRes.body.error?.code !== "OTP_EXPIRED") {
      throw new Error(`Expected OTP_EXPIRED, got ${JSON.stringify(expiredRes.body)}`);
    }
    console.log("✓ TEST 8 PASSED: Expired OTP correctly blocked.");

    // Clean up test data
    await query(`DELETE FROM rides WHERE id IN ($1, $2)`, [testRideId, expiredRideId]);
    await query(`DELETE FROM addresses WHERE id IN ($1, $2)`, [addr1Id, addr2Id]);
    await query(`DELETE FROM users WHERE id IN ($1, $2)`, [user1Id, user2Id]);
    await query(`DELETE FROM drivers WHERE id IN ($1, $2)`, [driver1Id, driver2Id]);

    console.log("\n=======================================================");
    console.log(" ALL 8 RIDE-START OTP VERIFICATION TESTS PASSED (100%)");
    console.log("=======================================================");
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});

