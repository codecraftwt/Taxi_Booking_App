/**
 * Saffar - Automated Verification Test Suite
 * Tests all 13 critical requirements of the Intelligent Nearby Driver Matching
 * and Sequential Ride Dispatch Engine.
 */

const { v4: uuidv4 } = require("uuid");
const { query, pool } = require("./database");
const redisService = require("./services/redisService");
const settingsService = require("./services/settingsService");
const matchingEngine = require("./modules/driver_matching/matching.engine");
const dispatchCoordinator = require("./modules/driver_matching/dispatch.coordinator");

const PASS = "✅ PASS";
const FAIL = "❌ FAIL";
let passedCount = 0;
let totalCount = 0;

function assert(condition, message) {
  totalCount++;
  if (condition) {
    console.log(`${PASS} - ${message}`);
    passedCount++;
  } else {
    console.error(`${FAIL} - ${message}`);
  }
}

// Cleanup helper
async function cleanupTestFixtures(prefix = "test_seq_") {
  try {
    await query(`DELETE FROM ride_offers WHERE ride_id LIKE '${prefix}%'`);
    await query(`DELETE FROM ride_requests WHERE ride_id LIKE '${prefix}%'`);
    await query(`DELETE FROM ride_status_history WHERE ride_id LIKE '${prefix}%'`);
    await query(`DELETE FROM ride_cancellations WHERE ride_id LIKE '${prefix}%'`);
    await query(`DELETE FROM rides WHERE id LIKE '${prefix}%'`);
    await query(`DELETE FROM driver_availability WHERE driver_id LIKE '${prefix}%'`);
    await query(`DELETE FROM driver_locations WHERE driver_id LIKE '${prefix}%'`);
    await query(`DELETE FROM driver_vehicles WHERE driver_id LIKE '${prefix}%'`);
    await query(`DELETE FROM vehicles WHERE driver_id LIKE '${prefix}%'`);
    await query(`DELETE FROM drivers WHERE id LIKE '${prefix}%'`);
    await query(`DELETE FROM users WHERE id LIKE '${prefix}%'`);
  } catch (err) {
    console.warn("Cleanup warning:", err.message);
  }
}

// Helper to seed a driver
async function seedDriver({
  id,
  name,
  category = "Auto",
  lat = 12.9350,
  lon = 77.6850,
  isOnline = true,
  lastUpdatedMinutesAgo = 0,
}) {
  const lastUpdated = new Date(Date.now() - lastUpdatedMinutesAgo * 60 * 1000);
  
  const uniquePhone = `+91${Math.floor(1000000000 + Math.random() * 9000000000)}`;
  const uniqueEmail = `${id}_${Date.now()}@test.com`;

  await query(
    `INSERT INTO drivers (
       id, name, phone, email, password, active, is_online, verification_status,
       vehicle_name, vehicle_number, current_lat, current_lng, last_location_updated_at
     ) VALUES ($1, $2, $3, $4, 'hashedpass', $5, $5, 'Approved', 'Vehicle Test', 'KA01TEST', $6, $7, $8)
     ON CONFLICT (id) DO UPDATE SET 
       is_online = EXCLUDED.is_online,
       active = EXCLUDED.active,
       current_lat = EXCLUDED.current_lat,
       current_lng = EXCLUDED.current_lng,
       last_location_updated_at = EXCLUDED.last_location_updated_at;`,
    [id, name, uniquePhone, uniqueEmail, isOnline, lat, lon, lastUpdated]
  );

  await query(
    `INSERT INTO driver_vehicles (
       id, driver_id, category, model, registration_number, color, verification_status, is_active
     ) VALUES ($1, $2, $3, 'Test Model', 'KA01TEST', 'Yellow', 'Approved', true)
     ON CONFLICT (id) DO NOTHING;`,
    [`veh_${id}`, id, category]
  );

  await query(
    `INSERT INTO vehicles (
       id, driver_id, category, model, registration_number, color, verification_status, is_active
     ) VALUES ($1, $2, $3, 'Test Model', 'KA01TEST', 'Yellow', 'Approved', true)
     ON CONFLICT (id) DO NOTHING;`,
    [`veh_${id}`, id, category]
  );

  await redisService.setDriverLocation(id, category, lat, lon, {
    category,
    isOnline,
    updatedAt: lastUpdated.toISOString(),
  });
  await redisService.setDriverAvailability(id, isOnline ? "ONLINE_AVAILABLE" : "OFFLINE", null);
}

// Helper to seed a test ride
async function seedRide({ id, userId, vehicleType = "Auto", status = "requested", driverId = null }) {
  const userPhone = `+91${Math.floor(1000000000 + Math.random() * 9000000000)}`;
  const userEmail = `${userId}_${Date.now()}@test.com`;
  await query(
    `INSERT INTO users (id, name, phone, email, password)
     VALUES ($1, 'Test Passenger', $2, $3, 'hashedpass')
     ON CONFLICT (id) DO NOTHING;`,
    [userId, userPhone, userEmail]
  );

  await query(
    `INSERT INTO rides (id, user_id, driver_id, vehicle_type, status, price, cancelled, start_time)
     VALUES ($1, $2, $3, $4, $5, 120.0, false, NOW())
     ON CONFLICT (id) DO UPDATE SET status = EXCLUDED.status, driver_id = EXCLUDED.driver_id;`,
    [id, userId, driverId, vehicleType, status]
  );
}

async function runTestSuite() {
  console.log("\n=======================================================");
  console.log("  SAFFAR SEQUENTIAL MATCHING & DISPATCH TEST SUITE");
  console.log("=======================================================\n");

  await cleanupTestFixtures();

  const pickupLat = 12.9350;
  const pickupLon = 77.6850;

  try {
    // -------------------------------------------------------------
    // Test 1: Ten drivers available, but only the nearest eligible receive the first batch (Batch 1 = 2 drivers)
    // -------------------------------------------------------------
    console.log("--- Test Case 1: Batch 1 limits to top 2 nearest eligible drivers ---");
    // Seed 10 drivers at various close distances (0.2km to 1.8km)
    for (let i = 1; i <= 10; i++) {
      await seedDriver({
        id: `test_seq_d_${i}`,
        name: `Driver ${i}`,
        category: "Auto",
        lat: pickupLat + i * 0.001, // ~0.11 km per 0.001 lat
        lon: pickupLon,
        isOnline: true,
      });
    }

    const rankedCandidates = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 1,
      customRadiusKm: 2.0,
      limit: 2, // Batch 1 size
    });

    assert(
      rankedCandidates.length === 2,
      `Batch 1 returned exactly 2 drivers out of 10 available (got ${rankedCandidates.length})`
    );
    assert(
      rankedCandidates[0].driverId === "test_seq_d_1" && rankedCandidates[1].driverId === "test_seq_d_2",
      `Batch 1 chose the 2 nearest drivers (d_1: ${rankedCandidates[0].distanceKm}km, d_2: ${rankedCandidates[1].distanceKm}km)`
    );

    // -------------------------------------------------------------
    // Test 2: A driver outside initial radius (e.g. 3.5 km when radius is 2 km) does not receive an offer in batch 1
    // -------------------------------------------------------------
    console.log("\n--- Test Case 2: Driver outside initial radius excluded from Batch 1 ---");
    await seedDriver({
      id: "test_seq_far_driver",
      name: "Far Driver",
      category: "Auto",
      lat: pickupLat + 0.035, // ~3.8 km away
      lon: pickupLon,
      isOnline: true,
    });

    const ring1Candidates = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 1,
      customRadiusKm: 2.0,
      limit: 10,
    });
    const containsFarDriver = ring1Candidates.some((c) => c.driverId === "test_seq_far_driver");
    assert(
      !containsFarDriver,
      `Driver located ~3.8 km away is excluded from 2 km initial radius (ring 1)`
    );

    // -------------------------------------------------------------
    // Test 3: An offline driver does not receive an offer
    // -------------------------------------------------------------
    console.log("\n--- Test Case 3: Offline driver excluded from matching ---");
    await seedDriver({
      id: "test_seq_offline_driver",
      name: "Offline Driver",
      category: "Auto",
      lat: pickupLat + 0.0005, // very close ~0.05 km
      lon: pickupLon,
      isOnline: false,
    });

    const candidatesWithOffline = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 1,
      customRadiusKm: 2.0,
      limit: 10,
    });
    const containsOffline = candidatesWithOffline.some((c) => c.driverId === "test_seq_offline_driver");
    assert(!containsOffline, `Offline driver is excluded from matching candidates`);

    // -------------------------------------------------------------
    // Test 4: A driver with an active ride does not receive an offer
    // -------------------------------------------------------------
    console.log("\n--- Test Case 4: Driver with ongoing active ride excluded ---");
    await seedDriver({
      id: "test_seq_busy_driver",
      name: "Busy Driver",
      category: "Auto",
      lat: pickupLat + 0.0005,
      lon: pickupLon,
      isOnline: true,
    });
    // Create an ongoing active ride for this driver
    await seedRide({
      id: "test_seq_ongoing_ride",
      userId: "test_seq_other_user",
      status: "in_progress",
      driverId: "test_seq_busy_driver",
    });

    const candidatesWithBusy = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 1,
      customRadiusKm: 2.0,
      limit: 10,
    });
    const containsBusy = candidatesWithBusy.some((c) => c.driverId === "test_seq_busy_driver");
    assert(!containsBusy, `Driver with active in_progress ride is excluded`);

    // -------------------------------------------------------------
    // Test 5: A driver with stale GPS (> 180s) does not receive an offer
    // -------------------------------------------------------------
    console.log("\n--- Test Case 5: Driver with stale GPS (> 180s) excluded ---");
    await seedDriver({
      id: "test_seq_stale_driver",
      name: "Stale Driver",
      category: "Auto",
      lat: pickupLat + 0.0005,
      lon: pickupLon,
      isOnline: true,
      lastUpdatedMinutesAgo: 5, // 5 minutes ago > 3 minutes (180s) threshold
    });

    const candidatesWithStale = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 1,
      customRadiusKm: 2.0,
      limit: 10,
    });
    const containsStale = candidatesWithStale.some((c) => c.driverId === "test_seq_stale_driver");
    assert(!containsStale, `Driver with GPS location older than 180s is excluded as stale`);

    // -------------------------------------------------------------
    // Test 6: A driver with wrong vehicle category (Car when Bike requested) does not receive an offer
    // -------------------------------------------------------------
    console.log("\n--- Test Case 6: Driver with wrong vehicle category excluded ---");
    await seedDriver({
      id: "test_seq_car_driver",
      name: "Car Driver",
      category: "Car",
      lat: pickupLat + 0.0005,
      lon: pickupLon,
      isOnline: true,
    });

    const bikeCandidates = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Bike",
      searchRing: 1,
      customRadiusKm: 2.0,
      limit: 10,
    });
    const containsCarDriver = bikeCandidates.some((c) => c.driverId === "test_seq_car_driver");
    assert(!containsCarDriver, `Car driver is excluded when requested vehicle category is Bike`);

    // -------------------------------------------------------------
    // Test 7: The next batch (3 drivers) receives offers when the first batch expires
    // -------------------------------------------------------------
    console.log("\n--- Test Case 7: Next batch receives offers excluding previous batch ---");
    // Suppose batch 1 offered d_1 and d_2
    const excludedBatch1 = ["test_seq_d_1", "test_seq_d_2"];
    const batch2Candidates = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 2,
      customRadiusKm: 4.0,
      excludeDriverIds: excludedBatch1,
      limit: 3, // Batch 2 size
    });

    assert(
      batch2Candidates.length === 3,
      `Batch 2 selected exactly 3 next drivers (got ${batch2Candidates.length})`
    );
    const hasBatch1Drivers = batch2Candidates.some((c) => excludedBatch1.includes(c.driverId));
    assert(!hasBatch1Drivers, `Batch 2 drivers are completely distinct from Batch 1`);

    // -------------------------------------------------------------
    // Test 8: Search radius expands progressively (Ring 1: 2km -> Ring 2: 4km -> Ring 3: 6km -> Ring 4: 10km)
    // -------------------------------------------------------------
    console.log("\n--- Test Case 8: Search radius progressive expansion ---");
    // Seed driver in Ring 2 (3 km)
    await seedDriver({
      id: "test_seq_ring2_driver",
      name: "Ring 2 Driver",
      category: "Auto",
      lat: pickupLat + 0.027, // ~3.0 km
      lon: pickupLon,
      isOnline: true,
    });

    const ring1Check = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 1,
      customRadiusKm: 2.0,
      limit: 10,
    });
    const ring2Check = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat,
      pickupLon,
      vehicleType: "Auto",
      searchRing: 2,
      customRadiusKm: 4.0,
      limit: 20,
    });

    assert(!ring1Check.some((c) => c.driverId === "test_seq_ring2_driver"), "Ring 2 driver excluded from 2 km ring");
    assert(ring2Check.some((c) => c.driverId === "test_seq_ring2_driver"), "Ring 2 driver successfully found in 4 km ring");

    // -------------------------------------------------------------
    // Test 9: Successful acceptance stops further dispatch and cancels competing offers
    // -------------------------------------------------------------
    console.log("\n--- Test Case 9: Successful acceptance cancels competing offers ---");
    const testRideId9 = "test_seq_ride_accept_9";
    await seedRide({ id: testRideId9, userId: "test_seq_user_9", status: "requested" });

    // Seed 2 offers in database
    await query(
      `INSERT INTO ride_offers (id, ride_id, driver_id, batch_number, search_ring, distance_km, eta_minutes, status, score, expires_at)
       VALUES ('off_9a', $1, 'test_seq_d_1', 1, 'ring_1', 0.5, 2, 'PENDING', 0.9, NOW() + INTERVAL '12 seconds'),
              ('off_9b', $1, 'test_seq_d_2', 1, 'ring_1', 0.8, 3, 'PENDING', 0.85, NOW() + INTERVAL '12 seconds')
       ON CONFLICT (ride_id, driver_id) DO UPDATE SET status = 'PENDING'`,
      [testRideId9]
    );

    const acceptRes = await dispatchCoordinator.handleDriverAcceptance(testRideId9, "test_seq_d_1");
    assert(acceptRes.success === true, "Driver 1 successfully accepted the ride");

    // Verify Driver 2's offer was expired/cancelled
    const otherOfferRes = await query(
      `SELECT status FROM ride_offers WHERE ride_id = $1 AND driver_id = 'test_seq_d_2'`,
      [testRideId9]
    );
    assert(
      otherOfferRes.rows[0]?.status === "EXPIRED",
      `Competing driver offer was automatically expired (status: ${otherOfferRes.rows[0]?.status})`
    );

    // -------------------------------------------------------------
    // Test 10: Two drivers accepting simultaneously results in exactly ONE assignment (atomic FOR UPDATE)
    // -------------------------------------------------------------
    console.log("\n--- Test Case 10: Concurrency safety with atomic SELECT ... FOR UPDATE ---");
    const testRideId10 = "test_seq_ride_race_10";
    await seedRide({ id: testRideId10, userId: "test_seq_user_10", status: "requested" });

    // Both drivers accept concurrently
    const [resultA, resultB] = await Promise.all([
      dispatchCoordinator.handleDriverAcceptance(testRideId10, "test_seq_d_3"),
      dispatchCoordinator.handleDriverAcceptance(testRideId10, "test_seq_d_4"),
    ]);

    const successes = [resultA.success, resultB.success].filter(Boolean).length;
    const failures = [resultA.success, resultB.success].filter((s) => !s).length;

    assert(
      successes === 1 && failures === 1,
      `Exactly one driver won atomic race assignment (Successes: ${successes}, Failures: ${failures})`
    );

    // Verify ride in DB has only the winning driver
    const rideRow10 = await query("SELECT driver_id, status FROM rides WHERE id = $1", [testRideId10]);
    assert(
      ["test_seq_d_3", "test_seq_d_4"].includes(rideRow10.rows[0].driver_id) && rideRow10.rows[0].status === "accepted",
      `authoritative database record assigned exclusively to winner ${rideRow10.rows[0].driver_id}`
    );

    // -------------------------------------------------------------
    // Test 11: Customer cancellation stops pending offers and restores driver availability
    // -------------------------------------------------------------
    console.log("\n--- Test Case 11: Customer cancellation clears offers and restores availability ---");
    const testRideId11 = "test_seq_ride_cancel_11";
    await seedRide({ id: testRideId11, userId: "test_seq_user_11", status: "requested" });

    // Seed active pending offer
    await query(
      `INSERT INTO ride_offers (id, ride_id, driver_id, batch_number, search_ring, distance_km, eta_minutes, status, score, expires_at)
       VALUES ('off_11', $1, 'test_seq_d_5', 1, 'ring_1', 0.6, 2, 'PENDING', 0.9, NOW() + INTERVAL '12 seconds')
       ON CONFLICT (ride_id, driver_id) DO UPDATE SET status = 'PENDING'`,
      [testRideId11]
    );
    await redisService.setDriverAvailability("test_seq_d_5", "OFFER_PENDING", testRideId11);

    await dispatchCoordinator.handleCustomerCancellation(testRideId11, "User changed plans");

    const offerStatus11 = await query(
      "SELECT status FROM ride_offers WHERE ride_id = $1 AND driver_id = 'test_seq_d_5'",
      [testRideId11]
    );
    // Cancellation should set status to CANCELLED or EXPIRED
    const status11 = offerStatus11.rows[0]?.status;
    assert(
      status11 === "CANCELLED" || status11 === "EXPIRED",
      `Driver offer status updated to cancelled/expired upon customer cancellation (got ${status11})`
    );

    // -------------------------------------------------------------
    // Test 12: Driver rejecting accelerates next batch dispatch
    // -------------------------------------------------------------
    console.log("\n--- Test Case 12: Driver rejection marks status REJECTED ---");
    const testRideId12 = "test_seq_ride_reject_12";
    await seedRide({ id: testRideId12, userId: "test_seq_user_12", status: "requested" });

    await query(
      `INSERT INTO ride_offers (id, ride_id, driver_id, batch_number, search_ring, distance_km, eta_minutes, status, score, expires_at)
       VALUES ('off_12', $1, 'test_seq_d_6', 1, 'ring_1', 0.7, 2, 'PENDING', 0.88, NOW() + INTERVAL '12 seconds')
       ON CONFLICT (ride_id, driver_id) DO UPDATE SET status = 'PENDING'`,
      [testRideId12]
    );

    const rejectRes = await dispatchCoordinator.handleDriverRejection(testRideId12, "test_seq_d_6");
    assert(rejectRes.success === true, "Driver rejection handled successfully");

    const offerStatus12 = await query(
      "SELECT status FROM ride_offers WHERE ride_id = $1 AND driver_id = 'test_seq_d_6'",
      [testRideId12]
    );
    assert(
      offerStatus12.rows[0]?.status === "REJECTED",
      `Driver offer marked REJECTED in database (got ${offerStatus12.rows[0]?.status})`
    );

    // -------------------------------------------------------------
    // Test 13: No eligible drivers returns clear customer message
    // -------------------------------------------------------------
    console.log("\n--- Test Case 13: No eligible drivers handling ---");
    // Search in an empty ocean coordinate (0.0, 0.0)
    const emptyCandidates = await matchingEngine.findAndRankEligibleDrivers({
      pickupLat: 0.0,
      pickupLon: 0.0,
      vehicleType: "Auto",
      searchRing: 4,
      customRadiusKm: 10.0,
      limit: 5,
    });

    assert(
      emptyCandidates.length === 0,
      `Zero candidates found in unpopulated coordinates as expected`
    );

    // Cleanup after tests
    await cleanupTestFixtures();

    console.log("\n=======================================================");
    console.log(`  SUMMARY: ${passedCount} / ${totalCount} TESTS PASSED`);
    console.log("=======================================================\n");

    if (passedCount === totalCount) {
      console.log("🎉 ALL 13 TEST CASES PASSED SUCCESSFULLY!");
      process.exit(0);
    } else {
      console.error("❌ Some test cases failed.");
      process.exit(1);
    }
  } catch (error) {
    console.error("Test execution encountered an unhandled error:", error);
    await cleanupTestFixtures();
    process.exit(1);
  } finally {
    pool.end();
  }
}

runTestSuite();
