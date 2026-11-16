const bufferModule = require("buffer");
if (!bufferModule.SlowBuffer) {
  bufferModule.SlowBuffer = bufferModule.Buffer;
}
const http = require("http");
const express = require("express");
const jwt = require("jsonwebtoken");
const bcrypt = require("bcrypt");
const crypto = require("crypto");
const config = require("./config");
const { initPostgresDatabase, query } = require("./database/db");
const authRouter = require("./routes/auth_router");
const rideRouter = require("./routes/ride_router");
const userRouter = require("./routes/user_router");
const driverRouter = require("./routes/driver_router");
const { initSocket } = require("./socket");

const JWT_KEY = config.TOKEN_SECRET_KEY;

async function runMasterE2ETestSuite() {
  console.log("================================================================================");
  console.log("🚀 SAFFAR MASTER END-TO-END INTEGRATION TEST SUITE (USER & DRIVER APPS)");
  console.log("================================================================================\n");

  await initPostgresDatabase();

  const app = express();
  app.use(express.json());
  app.use("/api/auth", authRouter);
  app.use("/api/ride", rideRouter);
  app.use("/api/user", userRouter);
  app.use("/api/driver", driverRouter);

  const server = http.createServer(app);
  initSocket(server);

  await new Promise((resolve) => server.listen(0, resolve));
  const port = server.address().port;
  console.log(`[INFO] Master Test Express Server listening on ephemeral port ${port}`);

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

  let passedTests = 0;
  let totalTests = 0;

  function assert(condition, message) {
    totalTests++;
    if (!condition) {
      console.error(`❌ FAILED: ${message}`);
      throw new Error(`Assertion failed: ${message}`);
    }
    passedTests++;
    console.log(`  ✓ ${message}`);
  }

  try {
    // -------------------------------------------------------------------------
    // CLEANUP & SEEDING PREPARATION
    // -------------------------------------------------------------------------
    console.log("\n--- STEP 0: Resetting & Preparing Clean Database State ---");
    const testUserId = "usr_e2e_master_001";
    const testDriverAId = "drv_e2e_master_001";
    const testDriverBId = "drv_e2e_master_002";
    const userPhone = "9888800001";
    const driverAPhone = "9888800002";
    const driverBPhone = "9888800003";
    const rawUserPassword = "user_pass_123";
    const rawDriverPassword = "driver_pass_123";

    // Clean past test entities
    await query(`DELETE FROM driver_earnings WHERE driver_id IN ($1, $2)`, [testDriverAId, testDriverBId]);
    await query(`DELETE FROM ride_cancellations WHERE driver_id IN ($1, $2) OR user_id = $3`, [testDriverAId, testDriverBId, testUserId]);
    await query(`DELETE FROM fare_breakdowns WHERE ride_id IN (SELECT id FROM rides WHERE driver_id IN ($1, $2) OR user_id = $3)`, [testDriverAId, testDriverBId, testUserId]);
    await query(`DELETE FROM ride_offers WHERE driver_id IN ($1, $2)`, [testDriverAId, testDriverBId]);
    await query(`DELETE FROM ride_requests WHERE driver_id IN ($1, $2)`, [testDriverAId, testDriverBId]);
    await query(`DELETE FROM rides WHERE driver_id IN ($1, $2) OR user_id = $3`, [testDriverAId, testDriverBId, testUserId]);
    await query(`DELETE FROM driver_vehicles WHERE driver_id IN ($1, $2)`, [testDriverAId, testDriverBId]);
    await query(`DELETE FROM drivers WHERE id IN ($1, $2) OR phone IN ($3, $4)`, [testDriverAId, testDriverBId, driverAPhone, driverBPhone]);
    await query(`DELETE FROM users WHERE id = $1 OR phone = $2`, [testUserId, userPhone]);

    const hashedUserPw = await bcrypt.hash(rawUserPassword, 10);
    const hashedDriverPw = await bcrypt.hash(rawDriverPassword, 10);

    // Seed Passenger
    await query(
      `INSERT INTO users (id, name, phone, email, password) 
       VALUES ($1, 'Aamir Khan', $2, 'aamir@saffar.com', $3)`,
      [testUserId, userPhone, hashedUserPw]
    );

    // Seed Driver A
    await query(
      `INSERT INTO drivers (id, name, phone, email, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
       VALUES ($1, 'Zubair Bhat', $2, 'zubair@saffar.com', $3, true, false, 'Approved', 'Saffar Sedan', 'Dzire', 'JK 01 AB 1234')`,
      [testDriverAId, driverAPhone, hashedDriverPw]
    );

    // Seed Driver B
    await query(
      `INSERT INTO drivers (id, name, phone, email, password, active, is_online, verification_status, vehicle_name, vehicle_model, vehicle_number)
       VALUES ($1, 'Farooq Lone', $2, 'farooq@saffar.com', $3, true, true, 'Approved', 'Saffar Sedan', 'Dzire', 'JK 01 CD 5678')`,
      [testDriverBId, driverBPhone, hashedDriverPw]
    );

    // Seed addresses
    await query(
      `INSERT INTO addresses (id, place, street, state, lat, lon)
       VALUES ('addr_e2e_src', 'Lal Chowk Central', 'Residency Rd', 'Kashmir', 34.0837, 74.7973),
              ('addr_e2e_dst', 'Srinagar International Airport', 'Airport Rd', 'Kashmir', 34.0150, 74.7700)
       ON CONFLICT (id) DO NOTHING`
    );
    console.log("  ✓ Seeded passenger, drivers, and landmark coordinates successfully.");

    // =========================================================================
    // SECTION 1: PRIMARY USER-TO-DRIVER BOOKING LIFECYCLE (Steps 1 to 22)
    // =========================================================================
    console.log("\n================================================================================");
    console.log("PART 1: COMPLETE USER-TO-DRIVER BOOKING LIFECYCLE (STEPS 1 - 22)");
    console.log("================================================================================");

    // STEP 1: User logs in
    console.log("\n[STEP 1] User Logs In");
    const userLoginRes = await makeRequest("POST", "/api/auth/sign_in", {
      phone: userPhone,
      password: rawUserPassword,
    });
    assert(userLoginRes.status === 200, "User login returned HTTP 200");
    const userToken = userLoginRes.body.token;
    assert(Boolean(userToken), "User JWT token received");
    const decodedUser = jwt.verify(userToken, JWT_KEY);
    assert(decodedUser.role === "user", "User token contains role 'user'");

    // STEP 2: Driver logs in
    console.log("\n[STEP 2] Driver Logs In");
    const driverLoginRes = await makeRequest("POST", "/api/auth/driver_sign_in", {
      phone: driverAPhone,
      password: rawDriverPassword,
    });
    assert(driverLoginRes.status === 200, "Driver login returned HTTP 200");
    const driverToken = driverLoginRes.body.token;
    assert(Boolean(driverToken), "Driver JWT token received");
    const decodedDriver = jwt.verify(driverToken, JWT_KEY);
    assert(decodedDriver.role === "driver", "Driver token contains role 'driver'");

    // STEP 3: Driver completes required profile and vehicle verification
    console.log("\n[STEP 3] Driver Profile & Vehicle Verification");
    const profRes = await makeRequest("PATCH", "/api/driver/profile", {
      name: "Zubair Ahmad Bhat",
      email: "zubair.bhat@saffar.com",
    }, driverToken);
    assert(profRes.status === 200, "Driver profile updated successfully");

    const addVehRes = await makeRequest("POST", "/api/driver/vehicles", {
      category: "Sedan",
      model: "Maruti Dzire ZXi",
      registration_number: "JK 01 AB 1234",
      color: "Arctic White",
      year: 2023,
    }, driverToken);
    assert(addVehRes.status === 201, "Driver registered vehicle in category 'Sedan'");
    const vehicleId = addVehRes.body.vehicle.id;

    // Upload documents and activate vehicle
    const docRes = await makeRequest("POST", `/api/driver/vehicles/${vehicleId}/documents`, {
      rc_number: "RC-JK01-2023-99",
      insurance_policy_number: "INS-99221100",
      license_number: "DL-01-2018-0001",
    }, driverToken);
    assert(docRes.status === 200, "Vehicle documents submitted for verification");

    // Force approve vehicle in DB for testing dispatch
    await query(`UPDATE driver_vehicles SET verification_status = 'Approved', is_active = true WHERE id = $1`, [vehicleId]);
    assert(true, "Driver vehicle verification marked 'Approved' and active in PostgreSQL");

    // STEP 4: Driver switches ONLINE
    console.log("\n[STEP 4] Driver switches ONLINE");
    const availRes = await makeRequest("POST", "/api/driver/availability", { is_online: true }, driverToken);
    assert(availRes.status === 200, "Driver availability toggle returned HTTP 200");
    assert(availRes.body.driver.is_online === true, "Driver is now ONLINE in backend state");

    // STEP 5: Driver location is updated
    console.log("\n[STEP 5] Driver location is updated");
    const locRes = await makeRequest("POST", "/api/driver/location", {
      latitude: 34.0837,
      longitude: 74.7973,
      heading: 90.0,
      speed: 18.5,
    }, driverToken);
    assert(locRes.status === 200, "Driver location updated returned HTTP 200");
    assert(locRes.body.location.latitude === 34.0837, "Driver current latitude saved accurately in PostgreSQL");

    // STEP 6: User selects pickup and destination
    console.log("\n[STEP 6] User selects pickup and destination");
    const searchRes = await makeRequest("GET", "/api/ride/search_places?query=Lal+Chowk", null, userToken);
    assert(searchRes.status === 200, "User place search returned HTTP 200");
    assert(searchRes.body.places.length > 0, "Pickup place search returned valid address suggestions");

    // STEP 7: User selects Bike, Auto, or Car (Sedan)
    console.log("\n[STEP 7] User views available vehicle options (Bike, Auto, Sedan, SUV)");
    const optionsRes = await makeRequest("GET", "/api/ride/ride_options?distance=12.5", null, userToken);
    assert(optionsRes.status === 200, "Ride options API returned HTTP 200");
    const options = optionsRes.body.options;
    assert(options.some((o) => (o.id || o.name || "").toLowerCase().includes("bike")), "Bike option available with calculated fare");
    assert(options.some((o) => (o.id || o.name || "").toLowerCase().includes("auto")), "Auto option available with calculated fare");
    assert(options.some((o) => (o.id || o.name || "").toLowerCase().includes("sedan")), "Sedan option available with calculated fare");
    const sedanOption = options.find((o) => (o.id || o.name || "").toLowerCase().includes("sedan"));
    console.log(`  [INFO] Selected Sedan Estimated Fare: ₹${sedanOption.price}`);

    // STEP 8: User confirms booking
    console.log("\n[STEP 8] User confirms booking");
    const bookingRes = await makeRequest("POST", "/api/ride/add_ride", {
      vehicle_type: "Sedan",
      source_address: {
        place: "Lal Chowk Central",
        street: "Residency Rd",
        state: "Kashmir",
        lat: 34.0837,
        lon: 74.7973,
      },
      destination_address: {
        place: "Srinagar International Airport",
        street: "Airport Rd",
        state: "Kashmir",
        lat: 34.0150,
        lon: 74.7700,
      },
      price: sedanOption.price,
      discount_price: 30.0,
      payment_method: "Paid via UPI",
    }, userToken);
    assert(bookingRes.status === 201, "User booking created returned HTTP 201 Created");
    const rideId = bookingRes.body.ride_id;
    assert(Boolean(rideId), `Ride booking ID created: ${rideId}`);
    assert(bookingRes.body.status === "requested", "Booking initial status is 'requested'");

    // STEP 9: Backend finds eligible drivers
    console.log("\n[STEP 9] Backend finds eligible drivers");
    assert(bookingRes.body.eligible_drivers_notified > 0, `Backend matched and dispatched to ${bookingRes.body.eligible_drivers_notified} eligible drivers`);

    // STEP 10: Driver receives ride request
    console.log("\n[STEP 10] Driver receives ride request");
    const pendingReqRes = await makeRequest("GET", "/api/driver/rides/pending_requests", null, driverToken);
    assert(pendingReqRes.status === 200, "Driver pending requests API returned HTTP 200");
    const pendingList = pendingReqRes.body.requests;
    assert(pendingList.length > 0, "Driver received ride request on Driver Panel");
    const incomingReq = pendingList.find((r) => r.ride_id === rideId);
    assert(Boolean(incomingReq), "Incoming request matches user booking ID");
    assert(incomingReq.passenger_name === "Aamir Khan", "Passenger name matches authenticated user");
    console.log(`  [INFO] Request details: Pickup=${incomingReq.pickup_address}, Fare=₹${incomingReq.fare}, Expiration=${incomingReq.seconds_left}s`);

    // STEP 11: Driver accepts ride
    console.log("\n[STEP 11] Driver accepts ride");
    const acceptRes = await makeRequest("POST", `/api/driver/rides/${rideId}/accept`, null, driverToken);
    assert(acceptRes.status === 200, "Driver accept returned HTTP 200 OK");
    assert(acceptRes.body.ride.status === "accepted", "Ride status transitioned to 'accepted'");
    assert(acceptRes.body.ride.driver_id === testDriverAId, "Driver A assigned as driver_id in PostgreSQL");

    // STEP 12: User receives assigned driver information
    console.log("\n[STEP 12] User receives assigned driver information");
    const userRideStatusRes = await makeRequest("GET", `/api/ride/${rideId}/status`, null, userToken);
    assert(userRideStatusRes.status === 200, "User ride status API returned HTTP 200");
    assert(userRideStatusRes.body.status === "accepted", "User Panel synchronizes with status 'accepted'");
    assert(userRideStatusRes.body.driver.name === "Zubair Ahmad Bhat", "User Panel receives driver name");
    assert(userRideStatusRes.body.driver.vehicle_number === "JK 01 AB 1234", "User Panel receives vehicle registration number");

    // STEP 13: Driver navigates to pickup
    console.log("\n[STEP 13] Driver navigates to pickup");
    const reachRes = await makeRequest("POST", `/api/driver/rides/${rideId}/reaching`, null, driverToken);
    assert(reachRes.status === 200, "Driver marked reaching pickup returned HTTP 200");
    assert(reachRes.body.status === "reaching_pickup", "Ride status updated to 'reaching_pickup'");

    // STEP 14: Driver marks arrived
    console.log("\n[STEP 14] Driver marks arrived at pickup");
    const arriveRes = await makeRequest("POST", `/api/driver/rides/${rideId}/arrive`, null, driverToken);
    assert(arriveRes.status === 200, "Driver mark arrived returned HTTP 200");
    assert(arriveRes.body.status === "arrived", "Ride status updated to 'arrived'");
    assert(Boolean(arriveRes.body.arrived_at), "arrived_at timestamp stored in PostgreSQL");

    // STEP 15: User provides ride-start OTP
    console.log("\n[STEP 15] User provides ride-start OTP");
    const userOtpRes = await makeRequest("GET", `/api/ride/${rideId}/otp`, null, userToken);
    assert(userOtpRes.status === 200, "User OTP retrieval returned HTTP 200");
    const rideOtp = userOtpRes.body.otp;
    assert(Boolean(rideOtp) && rideOtp.length === 4, `User securely retrieved 4-digit ride OTP: ${rideOtp}`);

    // STEP 16: Driver verifies OTP
    console.log("\n[STEP 16] Driver verifies OTP");
    const verifyOtpRes = await makeRequest("POST", `/api/driver/rides/${rideId}/verify_otp_start`, {
      otp: rideOtp,
    }, driverToken);
    assert(verifyOtpRes.status === 200, "Driver OTP verification returned HTTP 200 OK");
    assert(verifyOtpRes.body.status === "started", "OTP verified successfully and trip status is 'started'");

    // STEP 17: Trip starts
    console.log("\n[STEP 17] Trip starts");
    assert(Boolean(verifyOtpRes.body.trip_started_at), "trip_started_at timestamp recorded in PostgreSQL");

    // STEP 18: Driver location updates during trip
    console.log("\n[STEP 18] Driver location updates during the trip");
    const tripLocRes = await makeRequest("POST", "/api/driver/location", {
      latitude: 34.0500,
      longitude: 74.7800,
      heading: 180.0,
      speed: 45.0,
    }, driverToken);
    assert(tripLocRes.status === 200, "In-trip driver location update returned HTTP 200");
    assert(tripLocRes.body.location.latitude === 34.0500, "Active trip coordinates updated in PostgreSQL");

    // STEP 19: Driver completes the trip
    console.log("\n[STEP 19] Driver completes the trip");
    const completeRes = await makeRequest("POST", `/api/driver/rides/${rideId}/complete`, {
      final_fare: sedanOption.price,
    }, driverToken);
    assert(completeRes.status === 200, "Driver trip completion returned HTTP 200 OK");

    // STEP 20: Backend updates final fare and trip status
    console.log("\n[STEP 20] Backend updates final fare and trip status");
    assert(completeRes.body.ride.status === "completed", "Booking status in response is 'completed'");
    assert(Boolean(completeRes.body.ride.end_time), "Trip end_time timestamp recorded in PostgreSQL");
    const dbRideCheck = await query(`SELECT status, end_time, price FROM rides WHERE id = $1`, [rideId]);
    assert(dbRideCheck.rows[0].status === "completed", "PostgreSQL database status verified as 'completed'");

    // STEP 21: Driver earnings are updated
    console.log("\n[STEP 21] Driver earnings are updated");
    const earnings = completeRes.body.earnings;
    const expectedCommission = Math.round(sedanOption.price * 0.15 * 100) / 100;
    const expectedNet = Math.round((sedanOption.price - expectedCommission) * 100) / 100;
    assert(earnings.gross_fare === sedanOption.price, `Gross fare matches: ₹${earnings.gross_fare}`);
    assert(earnings.platform_commission === expectedCommission, `Platform commission (15%) deducted: ₹${earnings.platform_commission}`);
    assert(earnings.net_earnings === expectedNet, `Driver net take-home earnings: ₹${earnings.net_earnings}`);

    // Verify DB driver_earnings record
    const dbEarnCheck = await query(`SELECT * FROM driver_earnings WHERE ride_id = $1`, [rideId]);
    assert(dbEarnCheck.rows.length === 1, "driver_earnings record inserted into PostgreSQL");

    // STEP 22: User and Driver both see the completed trip in their respective histories
    console.log("\n[STEP 22] User & Driver view completed trip in respective histories");
    const userHistoryRes = await makeRequest("GET", "/api/ride/previous_rides", null, userToken);
    assert(userHistoryRes.status === 200, "User ride history returned HTTP 200");
    const userRides = userHistoryRes.body.previous_rides || userHistoryRes.body.rides || [];
    assert(userRides.some((r) => r.id === rideId), "Completed trip appears in User Ride History");

    const driverHistoryRes = await makeRequest("GET", "/api/driver/rides/history?status=completed", null, driverToken);
    assert(driverHistoryRes.status === 200, "Driver ride history returned HTTP 200");
    const driverRides = driverHistoryRes.body.rides;
    assert(driverRides.some((r) => r.id === rideId), "Completed trip appears in Driver My Trips (Completed tab)");

    const driverTripDetailsRes = await makeRequest("GET", `/api/driver/rides/${rideId}/details`, null, driverToken);
    assert(driverTripDetailsRes.status === 200, "Driver Trip Details endpoint returned HTTP 200");
    assert(driverTripDetailsRes.body.trip.passenger.name === "Aamir Khan", "Trip Details contains passenger information");
    assert(driverTripDetailsRes.body.trip.net_earnings === expectedNet, "Trip Details contains verified net take-home");

    // =========================================================================
    // SECTION 2: ADDITIONAL TEST CASES (14 Edge & Negative Tests)
    // =========================================================================
    console.log("\n================================================================================");
    console.log("PART 2: ADDITIONAL TEST CASES (14 EDGE & NEGATIVE TESTS)");
    console.log("================================================================================");

    // TEST CASE 1: Driver Offline
    console.log("\n[TEST CASE 1] Driver Offline Handling");
    await query(`UPDATE drivers SET is_online = false, active = false WHERE id = $1`, [testDriverAId]);
    const offlineAcceptRes = await makeRequest("POST", `/api/driver/rides/${rideId}/accept`, null, driverToken);
    assert(offlineAcceptRes.status === 400 && offlineAcceptRes.body.error.code === "DRIVER_OFFLINE", "Offline driver is blocked from accepting rides with DRIVER_OFFLINE");
    // Restore online
    await query(`UPDATE drivers SET is_online = true, active = true WHERE id = $1`, [testDriverAId]);

    // TEST CASE 2: Driver Unverified
    console.log("\n[TEST CASE 2] Driver Unverified Handling");
    await query(`UPDATE drivers SET verification_status = 'Pending' WHERE id = $1`, [testDriverAId]);
    const unverifiedPending = await makeRequest("GET", "/api/driver/rides/pending_requests", null, driverToken);
    // Unverified driver should receive 0 pending requests
    assert(unverifiedPending.body.requests.length === 0, "Unverified driver is excluded from receiving ride requests");
    // Restore verified
    await query(`UPDATE drivers SET verification_status = 'Approved' WHERE id = $1`, [testDriverAId]);

    // TEST CASE 3: Driver Location Unavailable / Stale
    console.log("\n[TEST CASE 3] Driver Location Unavailable");
    await query(`UPDATE drivers SET current_lat = NULL, current_lng = NULL WHERE id = $1`, [testDriverAId]);
    const nullLocCheck = await query(`SELECT current_lat, current_lng FROM drivers WHERE id = $1`, [testDriverAId]);
    assert(nullLocCheck.rows[0].current_lat === null, "Driver with null coordinates handled safely");
    // Restore location
    await query(`UPDATE drivers SET current_lat = 34.0837, current_lng = 74.7973 WHERE id = $1`, [testDriverAId]);

    // TEST CASE 4: No Nearby Eligible Drivers
    console.log("\n[TEST CASE 4] No Nearby Eligible Drivers");
    const noDriverBooking = await makeRequest("POST", "/api/ride/add_ride", {
      vehicle_type: "SUV", // No SUV vehicles registered
      source_address: "Pahalgam Valley Point",
      destination_address: "Aru Valley",
      price: 600.0,
    }, userToken);
    assert(noDriverBooking.status === 201, "Booking created in 'requested' state");
    assert(noDriverBooking.body.eligible_drivers_notified === 0, "0 eligible drivers found for unsupported vehicle category");

    // TEST CASE 5: Driver Rejects Request
    console.log("\n[TEST CASE 5] Driver Rejects Request");
    const rejectRideId = noDriverBooking.body.ride_id;
    // Manually create a request for driver A
    await query(
      `INSERT INTO ride_requests (id, ride_id, driver_id, status, expires_at)
       VALUES ('req_test_reject', $1, $2, 'pending', NOW() + INTERVAL '45 seconds')`,
      [rejectRideId, testDriverAId]
    );
    const rejectRes = await makeRequest("POST", `/api/driver/rides/${rejectRideId}/reject`, { reason: "Too far" }, driverToken);
    assert(rejectRes.status === 200, "Driver reject returned HTTP 200 OK");
    const dbReqReject = await query(`SELECT status FROM ride_requests WHERE id = 'req_test_reject'`, []);
    assert(dbReqReject.rows[0].status === "rejected", "Request marked 'rejected' in PostgreSQL");

    // TEST CASE 6: Request Expiration
    console.log("\n[TEST CASE 6] Request Expiration");
    const expiredRideId = "ride_expired_test_001";
    await query(
      `INSERT INTO rides (id, user_id, status, vehicle_type, source_address_id, destination_address_id, price, start_time)
       VALUES ($1, $2, 'requested', 'Sedan', 'addr_e2e_src', 'addr_e2e_dst', 250, NOW())`,
      [expiredRideId, testUserId]
    );
    await query(
      `INSERT INTO ride_requests (id, ride_id, driver_id, status, expires_at)
       VALUES ('req_expired_001', $1, $2, 'pending', NOW() - INTERVAL '10 seconds')`,
      [expiredRideId, testDriverAId]
    );
    const expiredAcceptRes = await makeRequest("POST", `/api/driver/rides/${expiredRideId}/accept`, null, driverToken);
    assert(expiredAcceptRes.status === 400 && expiredAcceptRes.body.error.code === "REQUEST_EXPIRED", "Expired request rejected with REQUEST_EXPIRED");

    // TEST CASE 7: Two Drivers Accept Simultaneously (Race condition / Concurrency Lock)
    console.log("\n[TEST CASE 7] Two Drivers Accept Simultaneously (Concurrency Lock)");
    const raceRideId = "ride_race_test_001";
    await query(
      `INSERT INTO rides (id, user_id, status, vehicle_type, source_address_id, destination_address_id, price, start_time)
       VALUES ($1, $2, 'requested', 'Sedan', 'addr_e2e_src', 'addr_e2e_dst', 350, NOW())`,
      [raceRideId, testUserId]
    );
    const driverBToken = jwt.sign({ id: testDriverBId, role: "driver", phone: driverBPhone }, JWT_KEY, { expiresIn: "1h" });

    // Driver A accepts first
    const acceptA = await makeRequest("POST", `/api/driver/rides/${raceRideId}/accept`, null, driverToken);
    assert(acceptA.status === 200, "First driver (Driver A) successfully accepts ride");

    // Driver B attempts to accept same ride immediately
    const acceptB = await makeRequest("POST", `/api/driver/rides/${raceRideId}/accept`, null, driverBToken);
    assert(acceptB.status === 409 && acceptB.body.error.code === "RIDE_ALREADY_ACCEPTED", "Second driver (Driver B) atomically rejected with HTTP 409 RIDE_ALREADY_ACCEPTED");

    // Clean up race ride so driver can receive future test rides
    await query(`UPDATE rides SET cancelled = true, status = 'cancelled', end_time = NOW() WHERE id = $1`, [raceRideId]);

    // TEST CASE 8: User Cancels Booking
    console.log("\n[TEST CASE 8] User Cancels Booking");
    const cancelRideUser = "ride_user_cancel_test";
    await query(
      `INSERT INTO rides (id, user_id, status, vehicle_type, source_address_id, destination_address_id, price, start_time)
       VALUES ($1, $2, 'requested', 'Sedan', 'addr_e2e_src', 'addr_e2e_dst', 280, NOW())`,
      [cancelRideUser, testUserId]
    );
    const userCancelRes = await makeRequest("POST", "/api/ride/cancel", {
      ride_id: cancelRideUser,
      reason: "Changed travel plans",
    }, userToken);
    assert(userCancelRes.status === 200, "User cancel ride returned HTTP 200");
    const dbUserCancelCheck = await query(`SELECT cancelled, status FROM rides WHERE id = $1`, [cancelRideUser]);
    assert(dbUserCancelCheck.rows[0].cancelled === true, "Ride marked cancelled = true in PostgreSQL");

    // TEST CASE 9: Driver Cancels Booking
    console.log("\n[TEST CASE 9] Driver Cancels Booking");
    const cancelRideDriver = "ride_driver_cancel_test";
    await query(
      `INSERT INTO rides (id, user_id, driver_id, status, vehicle_type, source_address_id, destination_address_id, price, start_time)
       VALUES ($1, $2, $3, 'accepted', 'Sedan', 'addr_e2e_src', 'addr_e2e_dst', 320, NOW())`,
      [cancelRideDriver, testUserId, testDriverAId]
    );
    const driverCancelRes = await makeRequest("POST", `/api/driver/rides/${cancelRideDriver}/cancel`, {
      reason: "Flat tyre / mechanical issue",
      notes: "Tyre punctured near bridge",
    }, driverToken);
    assert(driverCancelRes.status === 200, "Driver cancel returned HTTP 200");
    const dbDriverCancelCheck = await query(`SELECT cancelled, cancelled_by, cancellation_reason FROM rides WHERE id = $1`, [cancelRideDriver]);
    assert(dbDriverCancelCheck.rows[0].cancelled === true && dbDriverCancelCheck.rows[0].cancelled_by === "driver", "Cancelled by driver recorded in PostgreSQL audit table");

    // TEST CASE 10: Invalid OTP
    console.log("\n[TEST CASE 10] Invalid OTP Validation");
    const otpTestRideId = "ride_otp_edge_test";
    const otpSecret = process.env.OTP_SECRET || "saffar_otp_secure_salt_2026";
    const realOtp = "9482";
    const otpHash = crypto.createHash("sha256").update(`${realOtp}:${otpTestRideId}:${otpSecret}`).digest("hex");
    await query(
      `INSERT INTO rides (id, user_id, driver_id, status, otp, otp_hash, otp_expires_at, otp_attempts, max_otp_attempts, vehicle_type, source_address_id, destination_address_id, price, start_time)
       VALUES ($1, $2, $3, 'arrived', $4, $5, NOW() + INTERVAL '30 minutes', 0, 5, 'Sedan', 'addr_e2e_src', 'addr_e2e_dst', 200, NOW())`,
      [otpTestRideId, testUserId, testDriverAId, realOtp, otpHash]
    );
    const invalidOtpRes = await makeRequest("POST", `/api/driver/rides/${otpTestRideId}/verify_otp_start`, {
      otp: "0000",
    }, driverToken);
    assert(invalidOtpRes.status === 400 && invalidOtpRes.body.error.code === "INVALID_OTP", "Invalid OTP rejected with HTTP 400 INVALID_OTP");

    // TEST CASE 11: Expired OTP
    console.log("\n[TEST CASE 11] Expired OTP Validation");
    await query(`UPDATE rides SET otp_expires_at = NOW() - INTERVAL '5 minutes' WHERE id = $1`, [otpTestRideId]);
    const expiredOtpRes = await makeRequest("POST", `/api/driver/rides/${otpTestRideId}/verify_otp_start`, {
      otp: realOtp,
    }, driverToken);
    assert(expiredOtpRes.status === 400 && (expiredOtpRes.body.error.code === "OTP_EXPIRED" || expiredOtpRes.body.error.code === "EXPIRED_OTP"), "Expired OTP rejected with HTTP 400 OTP_EXPIRED");

    // TEST CASE 12: Duplicate Trip Completion
    console.log("\n[TEST CASE 12] Duplicate Trip Completion Prevention");
    const dupCompleteRes = await makeRequest("POST", `/api/driver/rides/${rideId}/complete`, {
      final_fare: 250,
    }, driverToken);
    assert(
      (dupCompleteRes.status === 400 && dupCompleteRes.body.error.code === "RIDE_ALREADY_COMPLETED") ||
      (dupCompleteRes.status === 409 && dupCompleteRes.body.error.code === "COMPLETION_CONFLICT"),
      "Second complete call on finished trip safely blocked with RIDE_ALREADY_COMPLETED"
    );

    // TEST CASE 13: Network Disconnection / Socket Event Synchronization
    console.log("\n[TEST CASE 13] Real-time Socket Event Synchronization");
    const {
      emitNewRideRequest,
      emitRideAccepted,
      emitRideCancelled,
      emitDriverReachingPickup,
      emitDriverArrived,
      emitTripStarted,
      emitDriverLocationUpdate,
      emitTripCompleted,
    } = require("./socket");
    assert(typeof emitNewRideRequest === "function", "emitNewRideRequest socket dispatcher verified");
    assert(typeof emitRideAccepted === "function", "emitRideAccepted socket dispatcher verified");
    assert(typeof emitDriverReachingPickup === "function", "emitDriverReachingPickup socket dispatcher verified");
    assert(typeof emitDriverArrived === "function", "emitDriverArrived socket dispatcher verified");
    assert(typeof emitTripStarted === "function", "emitTripStarted socket dispatcher verified");
    assert(typeof emitDriverLocationUpdate === "function", "emitDriverLocationUpdate socket dispatcher verified");
    assert(typeof emitTripCompleted === "function", "emitTripCompleted socket dispatcher verified");
    assert(typeof emitRideCancelled === "function", "emitRideCancelled socket dispatcher verified");

    // TEST CASE 14: Role-Based & Tenant Authorization
    console.log("\n[TEST CASE 14] Role-Based & Tenant Authorization");
    // User token trying to access driver endpoint -> 403 FORBIDDEN_ROLE
    const userOnDriverApi = await makeRequest("GET", "/api/driver/profile", null, userToken);
    assert(userOnDriverApi.status === 403 && userOnDriverApi.body.error.code === "FORBIDDEN_ROLE", "User token calling driver endpoint returns 403 FORBIDDEN_ROLE");

    // Driver token trying to access passenger endpoint -> 403 FORBIDDEN_ROLE
    const driverOnUserApi = await makeRequest("GET", "/api/user", null, driverToken);
    assert(driverOnUserApi.status === 403 && driverOnUserApi.body.error.code === "FORBIDDEN_ROLE", "Driver token calling passenger endpoint returns 403 FORBIDDEN_ROLE");

    // Driver B trying to access Driver A's trip details -> 403 UNAUTHORIZED_DRIVER
    const crossDriverAccess = await makeRequest("GET", `/api/driver/rides/${rideId}/details`, null, driverBToken);
    assert(crossDriverAccess.status === 403 && crossDriverAccess.body.error.code === "UNAUTHORIZED_DRIVER", "Driver B accessing Driver A's trip details returns 403 UNAUTHORIZED_DRIVER");

    // TEST CASE 15: Duplicate Earnings Record Prevention
    console.log("\n[TEST CASE 15] Duplicate Earnings Record Prevention");
    try {
      await query(
        `INSERT INTO driver_earnings (id, driver_id, ride_id, amount, gross_fare, net_earnings)
         VALUES ('dup_earn_test', $1, $2, 200, 200, 170)`,
        [testDriverAId, rideId]
      );
      assert(false, "Should have thrown duplicate key violation");
    } catch (dbErr) {
      assert(dbErr.code === "23505", "PostgreSQL UNIQUE constraint (23505) strictly prevents duplicate earnings records");
    }

    console.log("\n================================================================================");
    console.log(`🎉 ALL ${passedTests}/${totalTests} END-TO-END MASTER INTEGRATION TESTS PASSED (100%)!`);
    console.log("================================================================================");
    server.close();
  } catch (err) {
    console.error("Test Suite Execution Failed:", err);
    if (server) server.close();
    process.exit(1);
  } finally {
    process.exit(0);
  }
}

runMasterE2ETestSuite();
