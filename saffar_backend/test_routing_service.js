require("./config/polyfill");
const assert = require("assert");
const { calculateRoute, reverseGeocode, haversineDistance, generateRoadWaypoints } = require("./modules/location/routing.service");

async function runTests() {
  console.log("--- Starting Routing Service Unit Tests ---");

  // Test 1: Haversine distance
  const p1 = { lat: 12.9716, lon: 77.5946 }; // MG Road
  const p2 = { lat: 12.9352, lon: 77.6245 }; // Koramangala
  const dist = haversineDistance(p1.lat, p1.lon, p2.lat, p2.lon);
  console.log(`[PASS] Haversine direct distance: ${(dist / 1000).toFixed(2)} km`);
  assert(dist > 3000 && dist < 6000, "Distance should be approx 4-5 km");

  // Test 2: generateRoadWaypoints
  const waypoints = generateRoadWaypoints(p1.lat, p1.lon, p2.lat, p2.lon, 10);
  assert(waypoints.length === 11, `Expected 11 waypoints, got ${waypoints.length}`);
  assert.strictEqual(waypoints[0].latitude, p1.lat);
  assert.strictEqual(waypoints[waypoints.length - 1].latitude, p2.lat);
  console.log(`[PASS] generateRoadWaypoints generated ${waypoints.length} smooth coordinates`);

  // Test 3: calculateRoute
  const route = await calculateRoute(p1.lat, p1.lon, p2.lat, p2.lon, "Auto");
  assert(route.success === true, "Route should succeed");
  assert(route.points.length >= 2, "Route should contain waypoints");
  assert(route.distance_km > 0, "Distance should be > 0");
  assert(route.duration_minutes > 0, "Duration should be > 0");
  assert(route.bounds.northeast.latitude >= route.bounds.southwest.latitude, "Bounding box latitude valid");
  console.log(`[PASS] calculateRoute: ${route.distance_km} km, ${route.duration_text}, ${route.points.length} waypoints, source: ${route.source}`);

  // Test 4: reverseGeocode
  const geocoded = await reverseGeocode(12.9716, 77.5946);
  assert(geocoded.success === true, "Reverse geocoding should succeed");
  assert(typeof geocoded.address === "string" && geocoded.address.length > 0, "Address should be non-empty");
  console.log(`[PASS] reverseGeocode: "${geocoded.address}", source: ${geocoded.source}`);

  console.log("--- All Routing Service Unit Tests Passed! ---");
}

runTests().catch((err) => {
  console.error("Test failed:", err);
  process.exit(1);
});

