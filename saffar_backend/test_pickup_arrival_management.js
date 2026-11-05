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
const { initSocket } = require("./socket");

const JWT_KEY = config.TOKEN_SECRET_KEY;

async function runTests() {
  console.log("=== STARTING PICKUP & ARRIVAL MANAGEMENT BACKEND TESTS ===");
  await initPostgresDatabase();

  const app = express();
  app.use(express.json());
  app.use("/api/driver", driverRouter);

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
    // 1. Seed primary test driver
    const driver1Id = "drv_test_nav_01";
    const phone1 = "9988776655";
    await query(`DELETE FROM driver_vehicles WHERE driver_id IN (SELECT id FROM drivers WHERE phone = $1)`, [phone1]);
    await query(`DELETE FROM drivers WHERE id = $1 OR phone = $2`, [driver1Id, phone1]);
    await query(
      `INSERT INTO drivers (id, name, phone, password, is_online, verification_status, current_lat, current_lng, vehicle_name, vehicle_number)
       VALUES ($1, 'Ramesh Pilot', $2, 'hashed123', true, 'Approved', 12.9716, 77.5946, 'Bajaj Auto', 'KA01AB1234')`,
      [driver1Id, phone1]
    );

    // 2. Seed unauthorized secondary driver
    const driver2Id = "drv_test_nav_02";
    const phone2 = "9988776656";
    await query(`DELETE FROM driver_vehicles WHERE driver_id IN (SELECT id FROM drivers WHERE phone = $1)`, [phone2]);
    await query(`DELETE FROM drivers WHERE id = $1 OR phone = $2`, [driver2Id, phone2]);
    await query(
      `INSERT INTO drivers (id, name, phone, password, is_online, verification_status, current_lat, current_lng, vehicle_name, vehicle_number)
       VALUES ($1, 'Suresh Unauth', $2, 'hashed123', true, 'Approved', 12.9800, 77.6000, 'TVS King', 'KA01AB9999')`,
      [driver2Id, phone2]
    );

    const token1 = jwt.sign({ id: driver1Id, phone: phone1, role: "driver" }, JWT_KEY, { expiresIn: "1h" });
    const token2 = jwt.sign({ id: driver2Id, phone: phone2, role: "driver" }, JWT_KEY, { expiresIn: "1h" });

    // 3. Seed user, addresses, and accepted test ride
    const userId = "usr_test_nav_01";
    await query(`DELETE FROM users WHERE id = $1`, [userId]);
    await query(
      `INSERT INTO users (id, name, phone, password, email)
       VALUES ($1, 'Anita Sharma', '9123456780', 'userpass123', 'anita@example.com')`,
      [userId]
    );

    const pickupAddrId = "addr_test_pickup_01";
    await query(`DELETE FROM addresses WHERE id = $1`, [pickupAddrId]);
    await query(
      `INSERT INTO addresses (id, place, street, lat, lon)
       VALUES ($1, 'Indiranagar Metro', '100 Feet Rd', 12.9784, 77.6408)`,
      [pickupAddrId]
    );

    const destAddrId = "addr_test_dest_01";
    await query(`DELETE FROM addresses WHERE id = $1`, [destAddrId]);
    await query(
      `INSERT INTO addresses (id, place, street, lat, lon)
       VALUES ($1, 'Koramangala Sony World', '80 Feet Rd', 12.9352, 77.6245)`,
      [destAddrId]
    );

    const testRideId = "ride_test_nav_101";
    await query(`DELETE FROM ride_requests WHERE ride_id = $1`, [testRideId]);
    await query(`DELETE FROM rides WHERE id = $1`, [testRideId]);
    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, price, status, otp, vehicle_type)
       VALUES ($1, $2, $3, $4, $5, NOW(), 125.0, 'accepted', '7391', 'Saffar Auto')`,
      [testRideId, userId, driver1Id, pickupAddrId, destAddrId]
    );

    console.log("Seeded test drivers, rider, addresses, and ride booking successfully.");

    // TEST 1: Retrieve assigned booking details (Driver 1 - authorized)
    console.log("\n--- TEST 1: Get Assigned Booking Details ---");
    const getRes = await makeRequest("GET", `/api/driver/rides/${testRideId}/assigned`, null, token1);
    console.log(`Status: ${getRes.status}`);
    if (getRes.status !== 200 || !getRes.body.ride) {
      throw new Error(`Failed to get assigned booking: ${JSON.stringify(getRes.body)}`);
    }
    const ride = getRes.body.ride;
    console.log(`Passenger: ${ride.passenger.name} (${ride.passenger.phone})`);
    console.log(`Pickup Address: ${ride.pickup.address} [${ride.pickup.lat}, ${ride.pickup.lon}]`);
    console.log(`Destination Address: ${ride.destination.address} [${ride.destination.lat}, ${ride.destination.lon}]`);
    console.log(`Calculated Distance to Pickup: ${ride.distance_to_pickup_km} km`);
    console.log(`Estimated Arrival Time (ETA): ${ride.eta_minutes} mins`);
    console.log(`Status: ${ride.status}`);
    if (ride.passenger.name !== "Anita Sharma" || ride.pickup.lat !== 12.9784) {
      throw new Error("Assigned booking details mismatch!");
    }
    if (ride.otp !== undefined) {
      throw new Error("Security leak: Driver assigned booking details exposed the passenger OTP!");
    }
    console.log("✓ TEST 1 PASSED: Booking details returned with accurate coordinates and passenger info.");

    // TEST 2: Prevent unauthorized driver from accessing booking
    console.log("\n--- TEST 2: Unauthorized Driver Access Prevention ---");
    const unauthGetRes = await makeRequest("GET", `/api/driver/rides/${testRideId}/assigned`, null, token2);
    console.log(`Status: ${unauthGetRes.status}, Code: ${unauthGetRes.body.error?.code}`);
    if (unauthGetRes.status !== 403) {
      throw new Error(`Expected 403 Forbidden for unauthorized driver, got ${unauthGetRes.status}`);
    }
    console.log("✓ TEST 2 PASSED: Unauthorized driver correctly blocked with 403 Forbidden.");

    // TEST 3: Driver Reaching Pickup Status Update
    console.log("\n--- TEST 3: Driver Reaching Pickup (En Route) ---");
    const reachingRes = await makeRequest("POST", `/api/driver/rides/${testRideId}/reaching`, {}, token1);
    console.log(`Status: ${reachingRes.status}, Result: ${reachingRes.body.status}`);
    if (reachingRes.status !== 200 || reachingRes.body.status !== "reaching_pickup") {
      throw new Error(`Failed to update to reaching_pickup: ${JSON.stringify(reachingRes.body)}`);
    }

    // Verify DB update
    const dbReaching = await query(`SELECT status, reaching_pickup_at FROM rides WHERE id = $1`, [testRideId]);
    if (dbReaching.rows[0].status !== "reaching_pickup" || !dbReaching.rows[0].reaching_pickup_at) {
      throw new Error("Database reaching_pickup status or timestamp not updated!");
    }
    console.log(`DB Timestamp for reaching_pickup_at: ${dbReaching.rows[0].reaching_pickup_at}`);
    console.log("✓ TEST 3 PASSED: Status updated to 'reaching_pickup' and timestamp saved.");

    // TEST 4: Prevent unauthorized driver from updating status
    console.log("\n--- TEST 4: Unauthorized Driver Status Update Prevention ---");
    const unauthArriveRes = await makeRequest("POST", `/api/driver/rides/${testRideId}/arrive`, {}, token2);
    console.log(`Status: ${unauthArriveRes.status}, Code: ${unauthArriveRes.body.error?.code}`);
    if (unauthArriveRes.status !== 403) {
      throw new Error(`Expected 403 Forbidden for unauthorized arrive attempt, got ${unauthArriveRes.status}`);
    }
    console.log("✓ TEST 4 PASSED: Unauthorized arrival attempt blocked with 403 Forbidden.");

    // TEST 5: Driver Arrived at Pickup
    console.log("\n--- TEST 5: Driver Arrived at Pickup ---");
    const arriveRes = await makeRequest("POST", `/api/driver/rides/${testRideId}/arrive`, {}, token1);
    console.log(`Status: ${arriveRes.status}, Result: ${arriveRes.body.status}, OTP: ${arriveRes.body.otp}`);
    if (arriveRes.status !== 200 || arriveRes.body.status !== "arrived" || !arriveRes.body.arrived_at) {
      throw new Error(`Failed to mark arrived: ${JSON.stringify(arriveRes.body)}`);
    }

    // Verify DB arrival timestamp
    const dbArrived = await query(`SELECT status, arrived_at, otp FROM rides WHERE id = $1`, [testRideId]);
    if (dbArrived.rows[0].status !== "arrived" || !dbArrived.rows[0].arrived_at) {
      throw new Error("Database arrived_at timestamp or status not updated!");
    }
    console.log(`DB Timestamp for arrived_at: ${dbArrived.rows[0].arrived_at}`);
    console.log("✓ TEST 5 PASSED: Driver arrived status confirmed and arrived_at timestamp recorded in PostgreSQL.");

    // Clean up test records
    await query(`DELETE FROM rides WHERE id = $1`, [testRideId]);
    await query(`DELETE FROM addresses WHERE id IN ($1, $2)`, [pickupAddrId, destAddrId]);
    await query(`DELETE FROM users WHERE id = $1`, [userId]);
    await query(`DELETE FROM drivers WHERE id IN ($1, $2)`, [driver1Id, driver2Id]);

    console.log("\n=======================================================");
    console.log(" ALL 5 BACKEND PICKUP & ARRIVAL TESTS PASSED (100%)");
    console.log("=======================================================");
  } finally {
    server.close();
  }
}

runTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});
