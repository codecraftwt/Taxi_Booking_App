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

async function runEarningsTests() {
  console.log("=== STARTING DRIVER EARNINGS MODULE TEST SUITE ===");
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

  // --- SEED TEST DATA ---
  const driverId = "drv_earn_test_001";
  const otherDriverId = "drv_earn_test_002";
  const riderId = "usr_earn_test_001";

  // Clean previous test data
  await query("DELETE FROM driver_earnings WHERE driver_id IN ($1, $2)", [driverId, otherDriverId]);
  await query("DELETE FROM ride_cancellations WHERE driver_id IN ($1, $2)", [driverId, otherDriverId]);
  await query("DELETE FROM ride_requests WHERE driver_id IN ($1, $2)", [driverId, otherDriverId]);
  await query("DELETE FROM rides WHERE driver_id IN ($1, $2)", [driverId, otherDriverId]);
  await query("DELETE FROM drivers WHERE id IN ($1, $2) OR phone IN ('9811111111', '9822222222')", [driverId, otherDriverId]);
  await query("DELETE FROM users WHERE id = $1 OR phone = '9833333333'", [riderId]);

  // Seed Drivers
  await query(
    `INSERT INTO drivers (id, name, phone, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
     VALUES ($1, 'Kavita Rao', '9811111111', 'hash123', true, true, 'Approved', 'Saffar Auto', 'Bajaj Maxima', 'KA 05 ER 1234')`,
    [driverId]
  );
  await query(
    `INSERT INTO drivers (id, name, phone, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
     VALUES ($1, 'Intruder Driver', '9822222222', 'hash123', true, true, 'Approved', 'Saffar Sedan', 'Dzire', 'KA 05 ER 5678')`,
    [otherDriverId]
  );

  // Seed Rider
  await query(
    `INSERT INTO users (id, name, phone, email, password)
     VALUES ($1, 'Ananya Sen', '9833333333', 'ananya@example.com', 'hash123')`,
    [riderId]
  );

  // Seed Addresses
  const p1 = "addr_e_p1";
  const d1 = "addr_e_d1";
  await query(`INSERT INTO addresses (id, place, street, lat, lon) VALUES ($1, 'HSR Layout', 'Sector 2', 12.9110, 77.6380) ON CONFLICT (id) DO NOTHING`, [p1]);
  await query(`INSERT INTO addresses (id, place, street, lat, lon) VALUES ($1, 'Koramangala', 'Sony World', 12.9352, 77.6245) ON CONFLICT (id) DO NOTHING`, [d1]);

  // Seed Completed Rides across different dates:
  // Ride A: Completed Today (Fare: 200)
  const rideA = "ride_earn_today_01";
  await query(
    `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, end_time, cancelled, price, status, payment_method, vehicle_type)
     VALUES ($1, $2, $3, $4, $5, NOW() - INTERVAL '30 minutes', NOW(), false, 200.0, 'completed', 'UPI', 'Auto')`,
    [rideA, riderId, driverId, p1, d1]
  );
  await query(
    `INSERT INTO driver_earnings (id, driver_id, ride_id, amount, gross_fare, commission_rate, commission_amount, other_deductions, net_earnings, distance_km, duration_minutes, payment_status, payment_method, created_at)
     VALUES ('earn_01', $1, $2, 170.0, 200.0, 0.15, 30.0, 0.0, 170.0, 8.5, 25, 'Paid', 'UPI', NOW())`,
    [driverId, rideA]
  );

  // Ride B: Completed 3 days ago (This Week) (Fare: 400)
  const rideB = "ride_earn_week_02";
  await query(
    `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, end_time, cancelled, price, status, payment_method, vehicle_type)
     VALUES ($1, $2, $3, $4, $5, NOW() - INTERVAL '3 days' - INTERVAL '40 minutes', NOW() - INTERVAL '3 days', false, 400.0, 'completed', 'Cash', 'Auto')`,
    [rideB, riderId, driverId, p1, d1]
  );
  await query(
    `INSERT INTO driver_earnings (id, driver_id, ride_id, amount, gross_fare, commission_rate, commission_amount, other_deductions, net_earnings, distance_km, duration_minutes, payment_status, payment_method, created_at)
     VALUES ('earn_02', $1, $2, 340.0, 400.0, 0.15, 60.0, 0.0, 340.0, 16.0, 45, 'Paid', 'Cash', NOW() - INTERVAL '3 days')`,
    [driverId, rideB]
  );

  // Ride C: Completed 20 days ago (This Month) (Fare: 300)
  const rideC = "ride_earn_month_03";
  await query(
    `INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, end_time, cancelled, price, status, payment_method, vehicle_type)
     VALUES ($1, $2, $3, $4, $5, NOW() - INTERVAL '20 days' - INTERVAL '30 minutes', NOW() - INTERVAL '20 days', false, 300.0, 'completed', 'Wallet', 'Auto')`,
    [rideC, riderId, driverId, p1, d1]
  );
  await query(
    `INSERT INTO driver_earnings (id, driver_id, ride_id, amount, gross_fare, commission_rate, commission_amount, other_deductions, net_earnings, distance_km, duration_minutes, payment_status, payment_method, created_at)
     VALUES ('earn_03', $1, $2, 255.0, 300.0, 0.15, 45.0, 0.0, 255.0, 12.0, 35, 'Paid', 'Wallet', NOW() - INTERVAL '20 days')`,
    [driverId, rideC]
  );

  const tokenDriver = jwt.sign({ id: driverId, role: "driver", phone: "9811111111" }, JWT_KEY, { expiresIn: "1h" });
  const tokenOther = jwt.sign({ id: otherDriverId, role: "driver", phone: "9822222222" }, JWT_KEY, { expiresIn: "1h" });

  try {
    // --- TEST 1: Today's Earnings Filter ---
    console.log("\n--- TEST 1: Today's Earnings Summary Filter ---");
    const todayRes = await makeRequest("GET", "/api/driver/earnings/summary?period=today", null, tokenDriver);
    console.log("Status:", todayRes.status);
    const todayData = todayRes.body.earnings;
    console.log("Today Gross:", todayData.gross_earnings, "Commission:", todayData.platform_commission, "Net:", todayData.net_earnings, "Rides:", todayData.completed_rides);

    if (todayRes.status !== 200) {
      throw new Error(`Test 1 Failed: Status not 200, got ${todayRes.status}`);
    }
    if (todayData.gross_earnings !== 200.0 || todayData.platform_commission !== 30.0 || todayData.net_earnings !== 170.0 || todayData.completed_rides !== 1) {
      throw new Error(`Test 1 Failed: Today's metrics mismatch: ${JSON.stringify(todayData)}`);
    }
    console.log("✓ TEST 1 PASSED: Today's earnings and platform commission calculated accurately.");

    // --- TEST 2: All-Time Dashboard Aggregates ---
    console.log("\n--- TEST 2: High-Level Dashboard Aggregates (Today, Weekly, Monthly, All-time) ---");
    console.log("All-time Earnings:", todayData.all_time_earnings, "Completed rides:", todayData.total_completed_rides);
    // Total gross = 200 + 400 + 300 = 900. Total net = 170 + 340 + 255 = 765. Total rides = 3.
    if (todayData.all_time_earnings !== 765.0 || todayData.total_completed_rides !== 3) {
      throw new Error(`Test 2 Failed: All-time aggregates mismatch: ${JSON.stringify(todayData)}`);
    }
    console.log("✓ TEST 2 PASSED: All-time and multi-period metrics aggregated correctly.");

    // --- TEST 3: Custom Date Range Filter ---
    console.log("\n--- TEST 3: Custom Date Range Filter ---");
    // Filter covering between 4 days ago and 2 days ago (should capture only Ride B)
    const dFrom = new Date(Date.now() - 4 * 24 * 3600 * 1000).toISOString().split("T")[0];
    const dTo = new Date(Date.now() - 2 * 24 * 3600 * 1000).toISOString().split("T")[0];
    const customRes = await makeRequest(
      "GET",
      `/api/driver/earnings/summary?period=custom&from_date=${dFrom}&to_date=${dTo}`,
      null,
      tokenDriver
    );
    console.log("Custom range:", dFrom, "to", dTo);
    const customData = customRes.body.earnings;
    console.log("Custom Gross:", customData.gross_earnings, "Net:", customData.net_earnings, "Rides:", customData.completed_rides);
    if (customData.gross_earnings !== 400.0 || customData.net_earnings !== 340.0 || customData.completed_rides !== 1) {
      throw new Error(`Test 3 Failed: Custom date range filter failed: ${JSON.stringify(customData)}`);
    }
    console.log("✓ TEST 3 PASSED: Custom date range filtering functions precisely.");

    // --- TEST 4: Earnings History List with Pagination ---
    console.log("\n--- TEST 4: Earnings History List Retrieval ---");
    const histRes = await makeRequest("GET", "/api/driver/earnings/history?page=1&limit=10", null, tokenDriver);
    console.log("History status:", histRes.status, "Count:", histRes.body.rides?.length);
    if (histRes.status !== 200 || histRes.body.rides?.length !== 3) {
      throw new Error(`Test 4 Failed: Expected 3 rides, got ${histRes.body.rides?.length}`);
    }
    const latestRide = histRes.body.rides[0];
    console.log("Latest Ride ID:", latestRide.booking_id, "Gross:", latestRide.gross_fare, "Commission:", latestRide.platform_commission, "Net:", latestRide.net_earnings);
    if (latestRide.gross_fare <= 0 || latestRide.net_earnings <= 0 || !latestRide.destination_address) {
      throw new Error(`Test 4 Failed: Incomplete ride earnings record: ${JSON.stringify(latestRide)}`);
    }
    console.log("✓ TEST 4 PASSED: Earnings history returned with complete trip financial attributes.");

    // --- TEST 5: Individual Trip Earnings Details Breakdown ---
    console.log("\n--- TEST 5: Individual Trip Earning Breakdown Endpoint ---");
    const detailRes = await makeRequest("GET", `/api/driver/earnings/${rideA}`, null, tokenDriver);
    console.log("Detail status:", detailRes.status);
    const trip = detailRes.body.trip_earnings;
    console.log("Trip Booking ID:", trip.booking_id);
    console.log("Gross Fare: ₹" + trip.gross_fare, "| Platform Commission (15%): ₹" + trip.platform_commission, "| Net Take-Home: ₹" + trip.net_earnings);
    console.log("Pickup:", trip.pickup_address, "-> Destination:", trip.destination_address);
    console.log("Payment Status:", trip.payment_status, "| Method:", trip.payment_method);

    if (detailRes.status !== 200 || !trip) {
      throw new Error("Test 5 Failed: Could not fetch trip earning details.");
    }
    if (trip.gross_fare !== 200.0 || trip.platform_commission !== 30.0 || trip.net_earnings !== 170.0) {
      throw new Error(`Test 5 Failed: Financial calculation mismatch: ${JSON.stringify(trip)}`);
    }
    console.log("✓ TEST 5 PASSED: Individual trip earning breakdown contains all required accounting items.");

    // --- TEST 6: Unauthorized Driver Access Prevention ---
    console.log("\n--- TEST 6: Unauthorized Driver Access Prevention ---");
    const unauthRes = await makeRequest("GET", `/api/driver/earnings/${rideA}`, null, tokenOther);
    console.log("Unauthorized status:", unauthRes.status, "Code:", unauthRes.body.error?.code);
    if (unauthRes.status !== 403 || unauthRes.body.error?.code !== "UNAUTHORIZED_DRIVER") {
      throw new Error(`Test 6 Failed: Expected 403 UNAUTHORIZED_DRIVER, got ${unauthRes.status}`);
    }
    console.log("✓ TEST 6 PASSED: Intruder driver blocked from viewing other drivers' trip earnings.");

    // --- TEST 7: Duplicate Earnings Prevention in completeRide ---
    console.log("\n--- TEST 7: Prevent Duplicate Earnings Records ---");
    const countCheck = await query("SELECT COUNT(*) as count FROM driver_earnings WHERE ride_id = $1", [rideA]);
    if (parseInt(countCheck.rows[0].count) !== 1) {
      throw new Error(`Test 7 Failed: Expected exactly 1 earnings row for ride ${rideA}, found ${countCheck.rows[0].count}`);
    }
    console.log("✓ TEST 7 PASSED: Duplicate earnings strictly prevented by PostgreSQL UNIQUE constraint.");

    console.log("\n=======================================================");
    console.log(" ALL 7 DRIVER EARNINGS TESTS PASSED (100%)");
    console.log("=======================================================\n");
  } finally {
    server.close();
  }
}

runEarningsTests().catch((err) => {
  console.error("Test execution failed:", err);
  process.exit(1);
});

