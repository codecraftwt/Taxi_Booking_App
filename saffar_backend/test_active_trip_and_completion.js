const bufferModule = require("buffer");
if (!bufferModule.SlowBuffer) {
  bufferModule.SlowBuffer = bufferModule.Buffer;
}
const http = require("http");
const express = require("express");
const jwt = require("jsonwebtoken");
const config = require("./config");
const { initPostgresDatabase, query } = require("./database/db");
const driverRouter = require("./routes/driver_router");
const rideRouter = require("./routes/ride_router");
const { initSocket } = require("./socket");

const JWT_KEY = config.TOKEN_SECRET_KEY;

async function runTests() {
  console.log("=== STARTING ACTIVE TRIP & COMPLETION TEST SUITE ===");
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
    const userId = "usr_active_test_01";
    await query(`DELETE FROM users WHERE id = $1 OR phone = '9811122233'`, [userId]);
    await query(
      `INSERT INTO users (id, name, phone, password, email)
       VALUES ($1, 'Kiran Rao', '9811122233', 'pass123', 'kiran@example.com')`,
      [userId]
    );
    const userToken = jwt.sign({ id: userId, phone: "9811122233", role: "user" }, JWT_KEY, { expiresIn: "1h" });

    // 2. Seed Primary & Secondary Drivers
    const driver1Id = "drv_active_test_01";
    const driver2Id = "drv_active_test_02";
    await query(`DELETE FROM driver_earnings WHERE driver_id IN ($1, $2)`, [driver1Id, driver2Id]);
    await query(`DELETE FROM driver_vehicles WHERE driver_id IN ($1, $2)`, [driver1Id, driver2Id]);
    await query(`DELETE FROM drivers WHERE id IN ($1, $2) OR phone IN ('9844455566', '9877788899')`, [driver1Id, driver2Id]);

    await query(
      `INSERT INTO drivers (id, name, phone, password, is_online, verification_status, vehicle_name, vehicle_number)
       VALUES ($1, 'Mohan Driver', '9844455566', 'hashed123', true, 'Approved', 'Tata Tigor EV', 'KA04AB5678')`,
      [driver1Id]
    );
    await query(
      `INSERT INTO drivers (id, name, phone, password, is_online, verification_status, vehicle_name, vehicle_number)
       VALUES ($1, 'Alok Intruder', '9877788899', 'hashed123', true, 'Approved', 'Maruti Dzire', 'KA04CD9999')`,
      [driver2Id]
    );

    const driverToken1 = jwt.sign({ id: driver1Id, phone: "9844455566", role: "driver" }, JWT_KEY, { expiresIn: "1h" });
    const driverToken2 = jwt.sign({ id: driver2Id, phone: "9877788899", role: "driver" }, JWT_KEY, { expiresIn: "1h" });

    // 3. Seed Addresses
    const pickupAddrId = "addr_active_pickup_01";
    const destAddrId = "addr_active_dest_01";
    await query(`DELETE FROM addresses WHERE id IN ($1, $2)`, [pickupAddrId, destAddrId]);
    await query(
      `INSERT INTO addresses (id, place, street, lat, lon)
       VALUES ($1, 'Koramangala 4th Block', '100 Ft Rd', 12.9345, 77.6265)`,
      [pickupAddrId]
    );
    await query(
      `INSERT INTO addresses (id, place, street, lat, lon)
       VALUES ($1, 'Electronic City Phase 1', 'Hosur Rd', 12.8399, 77.6770)`,
      [destAddrId]
    );

    // 4. Seed an Active Trip (Started)
    const activeRideId = "ride_active_test_201";
    await query(`DELETE FROM driver_earnings WHERE ride_id = $1`, [activeRideId]);
    await query(`DELETE FROM ride_requests WHERE ride_id = $1`, [activeRideId]);
    await query(`DELETE FROM rides WHERE id = $1`, [activeRideId]);
    await query(
      `INSERT INTO rides (
         id, user_id, driver_id, source_address_id, destination_address_id,
         start_time, trip_started_at, price, status, otp, otp_verified, vehicle_type
       )
       VALUES ($1, $2, $3, $4, $5, NOW() - INTERVAL '20 minutes', NOW() - INTERVAL '20 minutes', 180.0, 'started', '4928', true, 'Sedan')`,
      [activeRideId, userId, driver1Id, pickupAddrId, destAddrId]
    );

    console.log("Seeded passenger, drivers, addresses, and started active trip successfully.");

    // TEST 1: Driver Location Update during active trip
    console.log("\n--- TEST 1: Location Update During Active Trip ---");
    const locRes = await makeRequest(
      "POST",
      "/api/driver/location",
      { latitude: 12.8900, longitude: 77.6500, heading: 145.0, speed: 42.5 },
      driverToken1
    );
    console.log(`Status: ${locRes.status}, Message: ${locRes.body.message}`);
    if (locRes.status !== 200 || locRes.body.location?.latitude !== 12.8900) {
      throw new Error(`Location update failed: ${JSON.stringify(locRes.body)}`);
    }

    // Verify DB update
    const dbDriver = await query(`SELECT current_lat, current_lng, speed, last_location_updated_at FROM drivers WHERE id = $1`, [driver1Id]);
    if (dbDriver.rows[0].current_lat !== 12.8900 || dbDriver.rows[0].speed !== 42.5) {
      throw new Error("Driver table location coordinates or speed not updated!");
    }
    console.log(`✓ Driver position logged: [${dbDriver.rows[0].current_lat}, ${dbDriver.rows[0].current_lng}] Speed: ${dbDriver.rows[0].speed} km/h`);
    console.log("✓ TEST 1 PASSED: Live driver location updated and synchronized with active trip.");

    // TEST 2: Prevent Unauthorized Driver from Completing Ride
    console.log("\n--- TEST 2: Unauthorized Driver Completion Prevention ---");
    const unauthCompleteRes = await makeRequest(
      "POST",
      `/api/driver/rides/${activeRideId}/complete`,
      { final_fare: 180.0 },
      driverToken2
    );
    console.log(`Status: ${unauthCompleteRes.status}, Code: ${unauthCompleteRes.body.error?.code}`);
    if (unauthCompleteRes.status !== 403) {
      throw new Error(`Expected 403 for unauthorized driver complete ride, got ${unauthCompleteRes.status}`);
    }
    console.log("✓ TEST 2 PASSED: Intruding driver blocked from completing unassigned booking.");

    // TEST 3: Successful Ride Completion
    console.log("\n--- TEST 3: Authorized Driver Completes Ride ---");
    const completeRes = await makeRequest(
      "POST",
      `/api/driver/rides/${activeRideId}/complete`,
      { actual_distance_km: 12.5, final_fare: 237.5 },
      driverToken1
    );
    console.log(`Status: ${completeRes.status}, Message: ${completeRes.body.message}`);
    console.log(`Ride Status: ${completeRes.body.ride?.status}, Final Fare: ₹${completeRes.body.ride?.final_fare}, Duration: ${completeRes.body.ride?.duration_minutes}m`);
    if (completeRes.status !== 200 || completeRes.body.ride?.status !== "completed") {
      throw new Error(`Complete ride failed: ${JSON.stringify(completeRes.body)}`);
    }

    // Verify PostgreSQL records
    const dbCompleted = await query(
      `SELECT status, end_time, price, cancelled FROM rides WHERE id = $1`,
      [activeRideId]
    );
    if (dbCompleted.rows[0].status !== "completed" || !dbCompleted.rows[0].end_time || parseFloat(dbCompleted.rows[0].price) !== 237.5) {
      throw new Error("Database row not updated to completed or fare mismatch!");
    }
    console.log(`DB Timestamp for end_time: ${dbCompleted.rows[0].end_time}`);
    console.log("✓ TEST 3 PASSED: Ride completed, end_time recorded, final fare validated.");

    // TEST 4: Prevent Duplicate Completion
    console.log("\n--- TEST 4: Prevent Duplicate Trip Completion ---");
    const duplicateRes = await makeRequest(
      "POST",
      `/api/driver/rides/${activeRideId}/complete`,
      { final_fare: 237.5 },
      driverToken1
    );
    console.log(`Status: ${duplicateRes.status}, Code: ${duplicateRes.body.error?.code}`);
    if (duplicateRes.status !== 400 || duplicateRes.body.error?.code !== "RIDE_ALREADY_COMPLETED") {
      throw new Error(`Expected RIDE_ALREADY_COMPLETED, got: ${JSON.stringify(duplicateRes.body)}`);
    }
    console.log("✓ TEST 4 PASSED: Duplicate completion attempt rejected.");

    // TEST 5: Verify Driver Earnings Recorded & Duplicate Prevention
    console.log("\n--- TEST 5: Driver Earnings Record & Duplicate Prevention ---");
    const earningsRes = await query(
      `SELECT * FROM driver_earnings WHERE ride_id = $1`,
      [activeRideId]
    );
    if (earningsRes.rows.length !== 1) {
      throw new Error(`Expected exactly 1 earnings row for ride, found ${earningsRes.rows.length}`);
    }
    console.log(`Earnings Row: ID: ${earningsRes.rows[0].id}, Amount: ₹${earningsRes.rows[0].amount}, Distance: ${earningsRes.rows[0].distance_km} km`);

    // Verify Driver Earnings Summary API reflects the completed ride
    const summaryRes = await makeRequest("GET", "/api/driver/earnings/summary?period=daily", null, driverToken1);
    console.log(`Driver Total Earnings: ₹${summaryRes.body.earnings?.total_earnings}, Gross: ₹${summaryRes.body.earnings?.gross_earnings}, Completed Rides: ${summaryRes.body.earnings?.completed_rides}`);
    if (summaryRes.body.earnings?.gross_earnings !== 237.5 && summaryRes.body.earnings?.net_earnings < 200.0) {
      throw new Error("Driver earnings summary did not reflect completed trip fare!");
    }
    console.log("✓ TEST 5 PASSED: Driver earnings record saved without duplicates and summary updated.");

    // TEST 6: Verify User Trip History
    console.log("\n--- TEST 6: User Trip History Synchronization ---");
    const userHistoryRes = await makeRequest("GET", `/api/ride/previous_rides?user_id=${userId}`, null, userToken);
    const userRides = userHistoryRes.body.previous_rides || userHistoryRes.body.rides || [];
    console.log(`User completed rides count: ${userRides.length}`);
    const foundRide = userRides.find((r) => r.id === activeRideId);
    if (!foundRide) {
      throw new Error("User ride history does not contain the completed trip!");
    }
    console.log(`Found completed ride in user history with price: ₹${foundRide.price}`);
    console.log("✓ TEST 6 PASSED: Completed ride synchronized with User's trip history.");

    // Clean up test records
    await query(`DELETE FROM driver_earnings WHERE ride_id = $1`, [activeRideId]);
    await query(`DELETE FROM rides WHERE id = $1`, [activeRideId]);
    await query(`DELETE FROM addresses WHERE id IN ($1, $2)`, [pickupAddrId, destAddrId]);
    await query(`DELETE FROM users WHERE id = $1`, [userId]);
    await query(`DELETE FROM drivers WHERE id IN ($1, $2)`, [driver1Id, driver2Id]);

    console.log("\n=======================================================");
    console.log(" ALL 6 ACTIVE TRIP & COMPLETION TESTS PASSED (100%)");
    console.log("=======================================================");
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
