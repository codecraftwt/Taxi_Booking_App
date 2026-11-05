require("./config/polyfill");
const assert = require("assert");

// Import modular services
const fareService = require("./modules/fare_calculation/fare.service");
const matchingEngine = require("./modules/driver_matching/matching.engine");
const redisService = require("./services/redisService");
const settingsService = require("./services/settingsService");

async function runUnitTests() {
  console.log("=== RUNNING MODULAR SERVICES UNIT TESTS ===");

  // 1. Fare Service Tests
  console.log("\n[TEST 1] Fare Calculation Service");
  const quoted = await fareService.calculateQuotedFare({
    category: "Auto",
    distanceKm: 8.4,
    durationMins: 22,
    promoCode: "SAVE30"
  });

  console.log("Quoted Fare Result:", quoted);
  assert.strictEqual(quoted.currency, "INR", "Currency should be INR");
  assert(quoted.minorUnits.quotedTotalFare > 0, "Quoted fare in paise must be positive");
  assert.strictEqual(quoted.display.quotedFare, quoted.minorUnits.quotedTotalFare / 100, "Decimal fare must match paise conversion");

  const finalFare = await fareService.calculateFinalFare({
    category: "Auto",
    actualDistanceKm: 8.5,
    actualDurationMins: 24,
    waitTimeMins: 3,
    cancellationFeePaise: 0,
    tollChargesPaise: 0,
    tipPaise: 2000,
    commissionPct: 15
  });

  console.log("Final Fare Breakdown:", finalFare);
  assert.strictEqual(finalFare.currency, "INR", "Final fare currency must be INR");
  assert(finalFare.breakdownMinor.totalFareMinor > 0, "Final fare must be positive");
  assert(finalFare.breakdownMinor.platformFeeMinor > 0, "Platform commission must be computed");
  assert(finalFare.breakdownMinor.driverNetEarningsMinor > 0, "Driver net earnings must be computed");
  assert.strictEqual(
    finalFare.breakdownMinor.totalFareMinor - finalFare.breakdownMinor.platformFeeMinor + (finalFare.breakdownMinor.tipMinor || 0),
    finalFare.breakdownMinor.driverNetEarningsMinor,
    "Driver earnings must equal (fare - commission + tips)"
  );
  console.log(" Fare Service: PASS");

  // 2. Matching Engine Road ETA & Category Tests
  console.log("\n[TEST 2] Matching Engine Calculations");
  const roadEta = matchingEngine.calculateRoadEta(2.0, "Auto");
  console.log("Road ETA for 2.0 km Auto:", roadEta);
  assert(roadEta.roadDistanceKm >= 2.0, "Road distance should include urban tortuosity factor");
  assert(roadEta.etaMinutes > 0, "ETA minutes must be positive");

  assert.strictEqual(matchingEngine.normalizeCategory("Saffar Bike"), "Bike");
  assert.strictEqual(matchingEngine.normalizeCategory("Auto Smart Ride"), "Auto");
  assert.strictEqual(matchingEngine.normalizeCategory("Prime Sedan"), "Car");
  console.log(" Matching Engine: PASS");

  // 3. Redis Service In-Memory Fallback & Concurrency Lock
  console.log("\n[TEST 3] Redis Geospatial & Availability Fallback Engine");
  await redisService.initRedis();

  await redisService.setDriverLocation("test_drv_101", "Auto", 12.9350, 77.6850, {
    heading: 90.0,
    speed: 25.0
  });

  const nearby = await redisService.getNearbyDrivers("Auto", 12.9350, 77.6850, 2.0);
  assert(nearby.length > 0, "Nearby drivers must be found in radius");
  assert.strictEqual(nearby[0].driverId, "test_drv_101");

  await redisService.setDriverAvailability("test_drv_101", "ONLINE_AVAILABLE");
  const avail = await redisService.getDriverAvailability("test_drv_101");
  assert.strictEqual(avail.state, "ONLINE_AVAILABLE");

  // Test Offer Lock Concurrency
  const lock1 = await redisService.acquireOfferLock("ride_stitch_auto_001", "drv_1");
  assert.strictEqual(lock1, true, "First driver should acquire offer lock");

  const lock2 = await redisService.acquireOfferLock("ride_stitch_auto_001", "drv_2");
  assert.strictEqual(lock2, false, "Second concurrent driver must fail to acquire lock");

  await redisService.releaseOfferLock("ride_stitch_auto_001");
  const lock3 = await redisService.acquireOfferLock("ride_stitch_auto_001", "drv_2");
  assert.strictEqual(lock3, true, "Driver should acquire lock after release");
  await redisService.releaseOfferLock("ride_stitch_auto_001");
  console.log(" Redis Service: PASS");

  // 4. Dynamic Settings Service Tests
  console.log("\n[TEST 4] App Settings Service Cache");
  const matchingConfig = await settingsService.getMatchingConfig();
  console.log("Matching config loaded:", matchingConfig);
  assert.strictEqual(matchingConfig.initialRadiusKm, 2);
  assert.strictEqual(matchingConfig.secondRadiusKm, 5);
  assert.strictEqual(matchingConfig.thirdRadiusKm, 8);
  assert.strictEqual(matchingConfig.offerExpirySeconds, 15);
  assert.strictEqual(matchingConfig.commissionRate, 0.15);
  console.log(" Settings Service: PASS");

  console.log("\n============================================");
  console.log(" ALL MODULAR SERVICES UNIT TESTS PASSED! ");
  console.log("============================================");
}

runUnitTests().catch((err) => {
  console.error("Unit test failure:", err);
  process.exit(1);
});
