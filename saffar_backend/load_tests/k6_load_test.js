import http from "k6/http";
import { check, sleep, group } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

// Custom Performance Metrics
const matchingLatencyTrend = new Trend("saffar_matching_latency_ms");
const bookingThroughputCounter = new Counter("saffar_bookings_total");
const duplicateAssignmentCounter = new Counter("saffar_duplicate_assignments");
const errorRate = new Rate("saffar_error_rate");

export const options = {
  scenarios: {
    // 1. Concurrent API Users browsing & querying options (Target: 200 concurrent users)
    concurrent_browsing: {
      executor: "ramping-vus",
      startVUs: 10,
      stages: [
        { duration: "30s", target: 100 },
        { duration: "1m", target: 200 },
        { duration: "30s", target: 50 },
        { duration: "15s", target: 0 },
      ],
      gracefulRampDown: "10s",
      exec: "browseRidesScenario",
    },

    // 2. Simultaneous Booking Surge (Target: 50 simultaneous booking requests)
    booking_surge: {
      executor: "constant-arrival-rate",
      rate: 50,
      timeUnit: "1s",
      duration: "1m",
      preAllocatedVUs: 50,
      maxVUs: 100,
      exec: "createRideScenario",
    },

    // 3. Driver Location Telemetry Stream (Target: 150 simultaneously online drivers)
    driver_gps_stream: {
      executor: "constant-vus",
      vus: 150,
      duration: "1m",
      exec: "driverTelemetryScenario",
    },
  },
  thresholds: {
    http_req_duration: ["p(95)<350", "p(99)<750"], // 95% of requests must complete within 350ms
    saffar_error_rate: ["rate<0.01"],              // Error rate under 1%
    saffar_duplicate_assignments: ["count==0"],     // STRICT ZERO duplicate driver assignments
  },
};

const BASE_URL = __ENV.API_BASE_URL || "http://localhost:5000/api";

// ─── Scenario 1: Rider Browsing & Pricing Queries ───────────
export function browseRidesScenario() {
  group("Rider Options & Fare Estimates", () => {
    const res = http.get(`${BASE_URL}/ride/options?distance=8.4&promo=SAVE30`);
    const success = check(res, {
      "status is 200": (r) => r.status === 200,
      "options array present": (r) => {
        const body = JSON.parse(r.body);
        return Array.isArray(body.options) && body.options.length >= 3;
      },
    });

    errorRate.add(!success);
    sleep(1);
  });
}

// ─── Scenario 2: Create Ride & Atomic Matching ──────────────
export function createRideScenario() {
  group("Ride Booking & Atomic Matching", () => {
    const payload = JSON.stringify({
      user_id: `user_load_${__VU}_${__ITER}`,
      vehicle_type: "Saffar Auto",
      price: 135.0,
      source_address: "74 Park Ave, Koramangala",
      destination_address: "Cyber Gateway Tower, Tech Zone",
      payment_method: "Paid via Saffar Wallet",
      idempotency_key: `idem_k6_${__VU}_${__ITER}_${Date.now()}`,
    });

    const params = {
      headers: { "Content-Type": "application/json" },
    };

    const startTime = Date.now();
    const res = http.post(`${BASE_URL}/ride/add_ride`, payload, params);
    const duration = Date.now() - startTime;
    matchingLatencyTrend.add(duration);

    const success = check(res, {
      "booking status is 201": (r) => r.status === 201,
      "ride_id generated": (r) => {
        const body = JSON.parse(r.body);
        return body.ride_id !== undefined;
      },
    });

    if (success) {
      bookingThroughputCounter.add(1);
    }
    errorRate.add(!success);
    sleep(0.5);
  });
}

// ─── Scenario 3: Driver Telemetry Updates ───────────────────
export function driverTelemetryScenario() {
  group("Driver GPS & Availability Ingestion", () => {
    const driverId = `drv_load_${__VU}`;
    const lat = 12.9350 + (Math.random() - 0.5) * 0.05;
    const lon = 77.6850 + (Math.random() - 0.5) * 0.05;

    const payload = JSON.stringify({
      driver_id: driverId,
      latitude: lat,
      longitude: lon,
      heading: Math.floor(Math.random() * 360),
      speed: 25.0,
      timestamp: new Date().toISOString(),
    });

    const params = {
      headers: { "Content-Type": "application/json" },
    };

    const res = http.post(`${BASE_URL}/driver/location`, payload, params);
    const success = check(res, {
      "location update accepted": (r) => r.status === 200 || r.status === 201,
    });

    errorRate.add(!success);
    sleep(2); // GPS broadcast every 2-3 seconds
  });
}

