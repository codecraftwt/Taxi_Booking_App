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

async function runCancellationTests() {
  console.log("=== STARTING DRIVER RIDE CANCELLATION TEST SUITE ===");
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
      const headers = { "Content-Type": "application/json" };
      if (token) headers["Authorization"] = `Bearer ${token}`;
      if (payload) headers["Content-Length"] = Buffer.byteLength(payload);

      const req = http.request(
        { hostname: "127.0.0.1", port, path, method, headers },
        (res) => {
          let data = "";
          res.on("data", (chunk) => (data += chunk));
          res.on("end", () => {
            try {
              resolve({ status: res.statusCode, body: data ? JSON.parse(data) : {} });
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

  // --- SEED TEST DATA ---
  const driverAId = "drv_cancel_001";
  const driverBId = "drv_cancel_002";
  const riderId = "usr_cancel_001";

  // Clean previous test runs
  await query("DELETE FROM ride_cancellations WHERE driver_id IN ($1, $2)", [driverAId, driverBId]);
  await query("DELETE FROM driver_earnings WHERE driver_id IN ($1, $2)", [driverAId, driverBId]);
  await query("DELETE FROM ride_requests WHERE driver_id IN ($1, $2)", [driverAId, driverBId]);
  await query("DELETE FROM rides WHERE driver_id IN ($1, $2)", [driverAId, driverBId]);
  await query("DELETE FROM driver_vehicles WHERE driver_id IN ($1, $2)", [driverAId, driverBId]);
  await query("DELETE FROM drivers WHERE id IN ($1, $2) OR phone IN ('9800000001', '9800000002')", [driverAId, driverBId]);
  await query("DELETE FROM users WHERE id = $1 OR phone = '9800000003'", [riderId]);

  // Seed Driver A (Assigned Driver)
  await query(
    `INSERT INTO drivers (id, name, phone, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
     VALUES ($1, 'Ramesh Babu', '9800000001', 'hash123', true, true, 'Approved', 'Saffar Auto', 'Bajaj Compact RE', 'KA 01 CA 1111')`,
    [driverAId]
  );
  await query(
    `INSERT INTO driver_vehicles (id, driver_id, category, model, registration_number, color, is_active, verification_status)
     VALUES ('veh_cancel_001', $1, 'Auto', 'Bajaj Compact RE', 'KA 01 CA 1111', 'Yellow', true, 'approved')`,
    [driverAId]
  );

  // Seed Driver B (Unauthorized Driver)
  await query(
    `INSERT INTO drivers (id, name, phone, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
     VALUES ($1, 'Suresh Patel', '9800000002', 'hash123', true, true, 'Approved', 'Saffar Sedan', 'Dzire', 'KA 02 CA 2222')`,
    [driverBId]
  );

  // Seed Passenger
  await query(
    `INSERT INTO users (id, name, phone, email, password, wallet_balance)
     VALUES ($1, 'Meera Nair', '9800000003', 'meera@example.com', 'hash123', 800.0)`,
    [riderId]
  );

  // Seed Addresses
  const pickupAddrId = "addr_cancel_pick";
  const destAddrId = "addr_cancel_dest";
  await query(
    `INSERT INTO addresses (id, place, street, state, country, lat, lon)
     VALUES ($1, 'Indiranagar', '100ft Road', 'Karnataka', 'India', 12.9784, 77.6408)
     ON CONFLICT (id) DO UPDATE SET street = EXCLUDED.street`,
    [pickupAddrId]
  );
  await query(
    `INSERT INTO addresses (id, place, street, state, country, lat, lon)
     VALUES ($1, 'MG Road', 'Trinity Circle', 'Karnataka', 'India', 12.9740, 77.6180)
     ON CONFLICT (id) DO UPDATE SET street = EXCLUDED.street`,
    [destAddrId]
  );

  // JWTs
  const tokenDriverA = jwt.sign({ id: driverAId, role: "driver", phone: "9800000001" }, JWT_KEY, { expiresIn: "1h" });
  const tokenDriverB = jwt.sign({ id: driverBId, role: "driver", phone: "9800000002" }, JWT_KEY, { expiresIn: "1h" });

  console.log("Seeded drivers, user, and addresses successfully.");

  try {
    // --- TEST 1: Driver cancels assigned ride BEFORE trip start (arrived state) ---
    console.log("\n--- TEST 1: Cancellation Before Trip Start (Arrived at Pickup) ---");
    const ride1Id = "ride_cancel_test_001";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, cancelled, price, status, otp, arrived_at)
       VALUES ($1, $2, $3, $4, $5, NOW(), false, 150.0, 'arrived', '4829', NOW())`,
      [ride1Id, riderId, driverAId, pickupAddrId, destAddrId]
    );

    const cancel1Res = await makeRequest(
      "POST",
      `/api/driver/rides/${ride1Id}/cancel`,
      {
        reason: "Customer did not show up",
        notes: "Waited at pickup gate for 10 minutes, passenger not reachable via phone.",
      },
      tokenDriverA
    );

    console.log("Status:", cancel1Res.status, "Message:", cancel1Res.body.message);
    if (cancel1Res.status !== 200) {
      throw new Error(`Test 1 Failed: Expected status 200, got ${cancel1Res.status} -> ${JSON.stringify(cancel1Res.body)}`);
    }

    // Verify DB update
    const dbRide1 = await query("SELECT * FROM rides WHERE id = $1", [ride1Id]);
    const r1 = dbRide1.rows[0];
    if (!r1.cancelled || r1.status !== "cancelled" || r1.cancelled_by !== "driver") {
      throw new Error(`Test 1 Failed: DB ride not marked cancelled by driver: ${JSON.stringify(r1)}`);
    }
    if (r1.cancellation_reason !== "Customer did not show up") {
      throw new Error(`Test 1 Failed: DB reason mismatch: ${r1.cancellation_reason}`);
    }
    if (!r1.cancelled_at) {
      throw new Error("Test 1 Failed: cancelled_at timestamp was not saved.");
    }

    // Verify audit record in ride_cancellations table
    const audit1 = await query("SELECT * FROM ride_cancellations WHERE ride_id = $1", [ride1Id]);
    if (audit1.rows.length === 0) {
      throw new Error("Test 1 Failed: No record inserted in ride_cancellations table.");
    }
    console.log("Audit Row:", audit1.rows[0].id, "Status at cancellation:", audit1.rows[0].ride_status_at_cancellation);
    console.log("✓ TEST 1 PASSED: Ride cancelled before trip start, DB updated, and audit record logged.");

    // --- TEST 2: Driver Eligibility for New Rides After Cancellation ---
    console.log("\n--- TEST 2: Driver Eligibility for Another Ride After Cancellation ---");
    // Ensure driver has no blocking active rides
    const activeCheck = await query(
      `SELECT id FROM rides WHERE driver_id = $1 AND end_time IS NULL AND cancelled = false`,
      [driverAId]
    );
    if (activeCheck.rows.length > 0) {
      throw new Error("Test 2 Failed: Driver still has active uncancelled rides in progress.");
    }
    // Ensure driver is still online
    const dCheck = await query("SELECT is_online, active FROM drivers WHERE id = $1", [driverAId]);
    if (!dCheck.rows[0].is_online || !dCheck.rows[0].active) {
      throw new Error("Test 2 Failed: Driver should remain online and ready for new requests.");
    }
    console.log("✓ Driver active:", dCheck.rows[0].active, "is_online:", dCheck.rows[0].is_online);
    console.log("✓ TEST 2 PASSED: Driver has 0 blocking trips and is immediately eligible for new rides.");

    // --- TEST 3: Prevent Duplicate Cancellation ---
    console.log("\n--- TEST 3: Prevent Duplicate Cancellation ---");
    const dupRes = await makeRequest(
      "POST",
      `/api/driver/rides/${ride1Id}/cancel`,
      { reason: "Customer did not show up" },
      tokenDriverA
    );
    console.log("Duplicate status:", dupRes.status, "Code:", dupRes.body.error?.code);
    if (dupRes.status !== 400 || dupRes.body.error?.code !== "RIDE_ALREADY_CANCELLED") {
      throw new Error(`Test 3 Failed: Expected 400 RIDE_ALREADY_CANCELLED, got ${dupRes.status}`);
    }
    console.log("✓ TEST 3 PASSED: Duplicate cancellation rejected.");

    // --- TEST 4: Unauthorized Driver Cancellation Prevention ---
    console.log("\n--- TEST 4: Unauthorized Driver Cancellation Prevention ---");
    const ride2Id = "ride_cancel_test_002";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, cancelled, price, status)
       VALUES ($1, $2, $3, $4, $5, NOW(), false, 200.0, 'accepted')`,
      [ride2Id, riderId, driverAId, pickupAddrId, destAddrId]
    );

    const unauthRes = await makeRequest(
      "POST",
      `/api/driver/rides/${ride2Id}/cancel`,
      { reason: "Vehicle issue / breakdown" },
      tokenDriverB // Driver B is not the assigned driver!
    );
    console.log("Unauthorized driver status:", unauthRes.status, "Code:", unauthRes.body.error?.code);
    if (unauthRes.status !== 403 || unauthRes.body.error?.code !== "UNAUTHORIZED_DRIVER") {
      throw new Error(`Test 4 Failed: Expected 403 UNAUTHORIZED_DRIVER, got ${unauthRes.status}`);
    }
    console.log("✓ TEST 4 PASSED: Unauthorized driver blocked from cancelling unassigned booking.");

    // --- TEST 5: Prevent Cancellation of Already Completed Trip ---
    console.log("\n--- TEST 5: Prevent Cancellation of Completed Trip ---");
    const ride3Id = "ride_cancel_test_003";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, end_time, cancelled, price, status)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW(), false, 250.0, 'completed')`,
      [ride3Id, riderId, driverAId, pickupAddrId, destAddrId]
    );

    const compRes = await makeRequest(
      "POST",
      `/api/driver/rides/${ride3Id}/cancel`,
      { reason: "Accident / Emergency" },
      tokenDriverA
    );
    console.log("Completed ride cancel status:", compRes.status, "Code:", compRes.body.error?.code);
    if (compRes.status !== 400 || compRes.body.error?.code !== "RIDE_ALREADY_COMPLETED") {
      throw new Error(`Test 5 Failed: Expected 400 RIDE_ALREADY_COMPLETED, got ${compRes.status}`);
    }
    console.log("✓ TEST 5 PASSED: Completed ride cannot be cancelled.");

    // --- TEST 6: Cancellation AFTER Pickup / Trip Start (Started / In Progress) ---
    console.log("\n--- TEST 6: Cancellation After Pickup / Trip Start ---");
    const ride4Id = "ride_cancel_test_004";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, trip_started_at, cancelled, price, status)
       VALUES ($1, $2, $3, $4, $5, NOW(), NOW(), false, 180.0, 'started')`,
      [ride4Id, riderId, driverAId, pickupAddrId, destAddrId]
    );

    const cancel4Res = await makeRequest(
      "POST",
      `/api/driver/rides/${ride4Id}/cancel`,
      {
        reason: "Vehicle issue / breakdown",
        notes: "Engine overheating on highway, unable to proceed safely.",
      },
      tokenDriverA
    );
    console.log("Status:", cancel4Res.status, "Message:", cancel4Res.body.message);
    if (cancel4Res.status !== 200) {
      throw new Error(`Test 6 Failed: Expected 200, got ${cancel4Res.status}`);
    }

    const audit4 = await query("SELECT * FROM ride_cancellations WHERE ride_id = $1", [ride4Id]);
    if (audit4.rows.length === 0 || audit4.rows[0].ride_status_at_cancellation !== "started") {
      throw new Error(`Test 6 Failed: Audit status at cancellation not 'started'`);
    }
    console.log("Audit Row:", audit4.rows[0].id, "Status at cancellation:", audit4.rows[0].ride_status_at_cancellation);
    console.log("✓ TEST 6 PASSED: Active in-progress trip cancelled safely with audit tracking.");

    // --- TEST 7: Missing Cancellation Reason Validation ---
    console.log("\n--- TEST 7: Missing Cancellation Reason Validation ---");
    const ride5Id = "ride_cancel_test_005";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, cancelled, price, status)
       VALUES ($1, $2, $3, $4, $5, NOW(), false, 120.0, 'accepted')`,
      [ride5Id, riderId, driverAId, pickupAddrId, destAddrId]
    );

    const emptyReasonRes = await makeRequest(
      "POST",
      `/api/driver/rides/${ride5Id}/cancel`,
      { reason: "   " },
      tokenDriverA
    );
    console.log("Empty reason status:", emptyReasonRes.status, "Code:", emptyReasonRes.body.error?.code);
    if (emptyReasonRes.status !== 400 || emptyReasonRes.body.error?.code !== "EMPTY_PARAM") {
      throw new Error(`Test 7 Failed: Expected 400 EMPTY_PARAM for blank reason`);
    }
    console.log("✓ TEST 7 PASSED: Missing/blank cancellation reason rejected.");

    // --- TEST 8: Driver Cancellation History Query ---
    console.log("\n--- TEST 8: Driver Cancellation History Retrieval ---");
    const historyRes = await makeRequest(
      "GET",
      `/api/driver/rides/cancellations?page=1&limit=10`,
      null,
      tokenDriverA
    );
    console.log("History status:", historyRes.status, "Count:", historyRes.body.cancellations?.length);
    if (historyRes.status !== 200 || !Array.isArray(historyRes.body.cancellations)) {
      throw new Error("Test 8 Failed: Expected list of cancellations");
    }
    if (historyRes.body.cancellations.length < 2) {
      throw new Error(`Test 8 Failed: Expected at least 2 cancellation records, got ${historyRes.body.cancellations.length}`);
    }
    const firstCnc = historyRes.body.cancellations[0];
    console.log("Latest cancellation:", firstCnc.reason, "Passenger:", firstCnc.passenger?.name);
    console.log("✓ TEST 8 PASSED: Driver cancellation history retrieved with full ride & passenger details.");

    console.log("\n=======================================================");
    console.log(" ALL 8 DRIVER CANCELLATION TESTS PASSED (100%)");
    console.log("=======================================================\n");
  } finally {
    server.close();
  }
}

runCancellationTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});

