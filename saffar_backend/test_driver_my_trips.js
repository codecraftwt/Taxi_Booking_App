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

async function runMyTripsTests() {
  console.log("=== STARTING DRIVER MY TRIPS MODULE INTEGRATION TEST ===");
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

  try {
    // 1. Prepare Test Driver A and Driver B
    const driverAId = "test_driver_trips_A";
    const driverBId = "test_driver_trips_B";
    const userId = "test_user_trips";
    const phoneA = "9876540001";
    const phoneB = "9876540002";

    // Clean up past records
    await query(`DELETE FROM driver_earnings WHERE driver_id IN ($1, $2)`, [driverAId, driverBId]);
    await query(`DELETE FROM ride_cancellations WHERE driver_id IN ($1, $2)`, [driverAId, driverBId]);
    await query(`DELETE FROM rides WHERE driver_id IN ($1, $2)`, [driverAId, driverBId]);
    await query(`DELETE FROM drivers WHERE id IN ($1, $2) OR phone IN ($3, $4)`, [driverAId, driverBId, phoneA, phoneB]);
    await query(`DELETE FROM users WHERE id = $1`, [userId]);

    // Create user if not exists
    await query(
      `INSERT INTO users (id, name, phone, email, password) 
       VALUES ($1, 'Trips Test User', '9998881111', 'trips_user@test.com', 'hashed_pw')`,
      [userId]
    );

    // Create addresses if not exists
    await query(
      `INSERT INTO addresses (id, place, street, state, lat, lon)
       VALUES ('addr_trips_src', 'Trips Pickup Point', 'Tech Blvd', 'Kashmir', 34.0837, 74.7973),
              ('addr_trips_dst', 'Trips Destination Point', 'Airport Rd', 'Kashmir', 34.0500, 74.7500)
       ON CONFLICT (id) DO NOTHING`
    );

    // Create Driver A
    await query(
      `INSERT INTO drivers (id, name, phone, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
       VALUES ($1, 'Trips Driver A', $2, 'hashed', true, true, 'Approved', 'Saffar Sedan', 'Dzire', 'KA 05 ER 1234')`,
      [driverAId, phoneA]
    );

    // Create Driver B
    await query(
      `INSERT INTO drivers (id, name, phone, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
       VALUES ($1, 'Trips Driver B', $2, 'hashed', true, true, 'Approved', 'Saffar Sedan', 'Dzire', 'KA 05 ER 5678')`,
      [driverBId, phoneB]
    );

    const tokenA = jwt.sign({ id: driverAId, role: "driver", phone: phoneA }, JWT_KEY, { expiresIn: "1h" });
    const tokenB = jwt.sign({ id: driverBId, role: "driver", phone: phoneB }, JWT_KEY, { expiresIn: "1h" });

    // Clean up past test rides for Driver A
    await query(`DELETE FROM driver_earnings WHERE driver_id = $1`, [driverAId]);
    await query(`DELETE FROM ride_cancellations WHERE driver_id = $1`, [driverAId]);
    await query(`DELETE FROM rides WHERE driver_id = $1`, [driverAId]);

    // Insert 4 trips for Driver A:
    // 1. Assigned / Upcoming
    const assignedRideId = "ride_trips_assigned";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, vehicle_type, source_address_id, destination_address_id, status, cancelled, price, start_time, created_at)
       VALUES ($1, $2, $3, 'Sedan', 'addr_trips_src', 'addr_trips_dst', 'accepted', false, 300.0, NOW(), NOW())`,
      [assignedRideId, userId, driverAId]
    );

    // 2. Ongoing
    const ongoingRideId = "ride_trips_ongoing";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, vehicle_type, source_address_id, destination_address_id, status, cancelled, price, start_time, trip_started_at, created_at)
       VALUES ($1, $2, $3, 'Sedan', 'addr_trips_src', 'addr_trips_dst', 'started', false, 450.0, NOW(), NOW(), NOW())`,
      [ongoingRideId, userId, driverAId]
    );

    // 3. Completed
    const completedRideId = "ride_trips_completed";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, vehicle_type, source_address_id, destination_address_id, status, cancelled, price, start_time, trip_started_at, end_time, created_at)
       VALUES ($1, $2, $3, 'Sedan', 'addr_trips_src', 'addr_trips_dst', 'completed', false, 500.0, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '90 minutes', NOW() - INTERVAL '30 minutes', NOW() - INTERVAL '2 hours')`,
      [completedRideId, userId, driverAId]
    );
    await query(
      `INSERT INTO driver_earnings (id, driver_id, ride_id, amount, gross_fare, commission_rate, commission_amount, other_deductions, net_earnings, distance_km, duration_minutes, payment_status, payment_method, created_at)
       VALUES ('earning_trips_comp', $1, $2, 425.0, 500.0, 0.15, 75.0, 0.0, 425.0, 15.2, 45, 'Paid', 'UPI', NOW() - INTERVAL '30 minutes')`,
      [driverAId, completedRideId]
    );

    // 4. Cancelled
    const cancelledRideId = "ride_trips_cancelled";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, vehicle_type, source_address_id, destination_address_id, status, cancelled, cancelled_by, cancellation_reason, cancellation_notes, cancelled_at, price, start_time, created_at)
       VALUES ($1, $2, $3, 'Sedan', 'addr_trips_src', 'addr_trips_dst', 'cancelled', true, 'driver', 'Heavy Traffic / Road Blocked', 'Bridge construction bypass blocked', NOW() - INTERVAL '1 hour', 250.0, NOW() - INTERVAL '1 hour', NOW() - INTERVAL '1 hour')`,
      [cancelledRideId, userId, driverAId]
    );

    console.log("✓ Test rides inserted successfully.");

    // TEST 1: Fetch All Trips (No Filter)
    console.log("\n[TEST 1] Fetch All Trips for Driver A");
    const resAll = await makeRequest("GET", "/api/driver/rides/history", null, tokenA);
    console.log(`Status: ${resAll.status}, Total rides returned: ${resAll.body.rides.length}`);
    console.log("Category counts:", resAll.body.category_counts);
    if (resAll.status !== 200) throw new Error(`Status was ${resAll.status}`);
    if (resAll.body.rides.length !== 4) throw new Error("Expected 4 total rides");
    if (resAll.body.category_counts.all !== 4) throw new Error("Expected category count all = 4");
    if (resAll.body.category_counts.assigned !== 1) throw new Error("Expected category count assigned = 1");
    if (resAll.body.category_counts.ongoing !== 1) throw new Error("Expected category count ongoing = 1");
    if (resAll.body.category_counts.completed !== 1) throw new Error("Expected category count completed = 1");
    if (resAll.body.category_counts.cancelled !== 1) throw new Error("Expected category count cancelled = 1");
    console.log("✓ TEST 1 PASSED");

    // TEST 2: Filter by category 'assigned'
    console.log("\n[TEST 2] Filter by category 'assigned'");
    const resAssigned = await makeRequest("GET", "/api/driver/rides/history?status=assigned", null, tokenA);
    console.log(`Status: ${resAssigned.status}, Count: ${resAssigned.body.rides.length}`);
    if (resAssigned.body.rides.length !== 1 || resAssigned.body.rides[0].id !== assignedRideId) {
      throw new Error("Assigned filter did not return the expected assigned ride");
    }
    console.log("✓ TEST 2 PASSED");

    // TEST 3: Filter by category 'ongoing'
    console.log("\n[TEST 3] Filter by category 'ongoing'");
    const resOngoing = await makeRequest("GET", "/api/driver/rides/history?status=ongoing", null, tokenA);
    console.log(`Status: ${resOngoing.status}, Count: ${resOngoing.body.rides.length}`);
    if (resOngoing.body.rides.length !== 1 || resOngoing.body.rides[0].id !== ongoingRideId) {
      throw new Error("Ongoing filter did not return the expected ongoing ride");
    }
    console.log("✓ TEST 3 PASSED");

    // TEST 4: Filter by category 'completed'
    console.log("\n[TEST 4] Filter by category 'completed'");
    const resCompleted = await makeRequest("GET", "/api/driver/rides/history?status=completed", null, tokenA);
    console.log(`Status: ${resCompleted.status}, Count: ${resCompleted.body.rides.length}`);
    if (resCompleted.body.rides.length !== 1 || resCompleted.body.rides[0].id !== completedRideId) {
      throw new Error("Completed filter did not return the expected completed ride");
    }
    if (resCompleted.body.rides[0].gross_fare !== 500 || resCompleted.body.rides[0].net_earnings !== 425) {
      throw new Error("Fare calculations incorrect for completed ride");
    }
    console.log("✓ TEST 4 PASSED");

    // TEST 5: Filter by category 'cancelled'
    console.log("\n[TEST 5] Filter by category 'cancelled'");
    const resCancelled = await makeRequest("GET", "/api/driver/rides/history?status=cancelled", null, tokenA);
    console.log(`Status: ${resCancelled.status}, Count: ${resCancelled.body.rides.length}`);
    if (resCancelled.body.rides.length !== 1 || resCancelled.body.rides[0].id !== cancelledRideId) {
      throw new Error("Cancelled filter did not return the expected cancelled ride");
    }
    if (!resCancelled.body.rides[0].cancelled || resCancelled.body.rides[0].cancellation_reason !== "Heavy Traffic / Road Blocked") {
      throw new Error("Cancellation reason or status incorrect");
    }
    console.log("✓ TEST 5 PASSED");

    // TEST 6: Get Full Trip Details for Completed Ride
    console.log("\n[TEST 6] GET Trip Details for Completed Ride");
    const resDetails = await makeRequest("GET", `/api/driver/rides/${completedRideId}/details`, null, tokenA);
    console.log(`Status: ${resDetails.status}, Trip ID: ${resDetails.body.trip.id}`);
    const trip = resDetails.body.trip;
    if (trip.passenger.name !== "Trips Test User") throw new Error("Passenger data missing or mismatch");
    if (trip.source_address.place !== "Trips Pickup Point") throw new Error("Source address mismatch");
    if (trip.destination_address.place !== "Trips Destination Point") throw new Error("Destination address mismatch");
    if (trip.gross_fare !== 500 || trip.platform_commission !== 75 || trip.net_earnings !== 425) {
      throw new Error("Itemized fare breakdown mismatch");
    }
    if (trip.distance_km !== 15.2 || trip.duration_minutes !== 45) {
      throw new Error("Distance or duration mismatch");
    }
    console.log("✓ TEST 6 PASSED");

    // TEST 7: Get Full Trip Details for Cancelled Ride
    console.log("\n[TEST 7] GET Trip Details for Cancelled Ride");
    const resCancelDetails = await makeRequest("GET", `/api/driver/rides/${cancelledRideId}/details`, null, tokenA);
    const cancelTrip = resCancelDetails.body.trip;
    if (!cancelTrip.cancelled || cancelTrip.cancellation_reason !== "Heavy Traffic / Road Blocked") {
      throw new Error("Cancellation info not properly returned");
    }
    if (cancelTrip.cancellation_notes !== "Bridge construction bypass blocked") {
      throw new Error("Cancellation notes mismatch");
    }
    console.log("✓ TEST 7 PASSED");

    // TEST 8: Driver Ownership Authorization check (Driver B attempting to access Driver A's trip details)
    console.log("\n[TEST 8] Driver B attempts to access Driver A's trip details (Expect 403 Forbidden)");
    const resAuthForbidden = await makeRequest("GET", `/api/driver/rides/${completedRideId}/details`, null, tokenB);
    if (resAuthForbidden.status === 403 && resAuthForbidden.body.error && resAuthForbidden.body.error.code === "UNAUTHORIZED_DRIVER") {
      console.log(`✓ Access blocked with 403 Forbidden: ${resAuthForbidden.body.error.code}`);
    } else {
      throw new Error(`Expected 403 UNAUTHORIZED_DRIVER, got status: ${resAuthForbidden.status}`);
    }
    console.log("✓ TEST 8 PASSED");

    console.log("\n=======================================================");
    console.log("🎉 ALL 8 DRIVER MY TRIPS BACKEND INTEGRATION TESTS PASSED!");
    console.log("=======================================================");
    server.close();
  } catch (error) {
    console.error("Test failed:", error);
    if (server) server.close();
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

runMyTripsTests();
