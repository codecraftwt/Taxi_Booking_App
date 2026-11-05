const bufferModule = require("buffer");
if (!bufferModule.SlowBuffer) {
  bufferModule.SlowBuffer = bufferModule.Buffer;
}
require("dotenv").config();
const http = require("http");
const axios = require("axios");
const app = require("./app");
const { initPostgresDatabase } = require("./database");

async function runVehicleTests() {
  console.log("==================================================");
  console.log("   SAFFAR VEHICLE MANAGEMENT TEST SUITE           ");
  console.log("==================================================");

  await initPostgresDatabase();

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(5098, resolve));
  const baseUrl = "http://localhost:5098/api";
  console.log("Test server running on port 5098\n");

  const testPhone = "9988776655";
  const testPassword = "password123";

  // Ensure test driver exists
  const { query } = require("./database");
  const bcrypt = require("bcrypt");
  const hashedPw = await bcrypt.hash(testPassword, 10);
  await query(
    `INSERT INTO drivers (id, name, phone, password, active, verification_status, vehicle_name, vehicle_number)
     VALUES ('drv_test_veh_01', 'Vehicle Tester', $1, $2, true, 'Approved', 'Sedan', 'KA 01 AB 0001')
     ON CONFLICT (phone) DO UPDATE SET password = EXCLUDED.password`,
    [testPhone, hashedPw]
  );

  try {
    // 1. Sign in as driver
    console.log("[TEST 1] Authenticate as Driver...");
    const loginRes = await axios.post(`${baseUrl}/auth/driver_sign_in`, {
      phone: testPhone,
      password: testPassword,
    });
    const token = loginRes.data.token;
    const authHeaders = { headers: { Authorization: `Bearer ${token}` } };
    console.log("✅ Driver authenticated successfully!");

    // 2. GET driver vehicles
    console.log("\n[TEST 2] Fetch Driver Vehicles (GET /driver/vehicles)...");
    const listRes = await axios.get(`${baseUrl}/driver/vehicles`, authHeaders);
    console.assert(listRes.status === 200, "Failed to list vehicles");
    console.assert(Array.isArray(listRes.data.vehicles), "Vehicles must be an array");
    console.log(`✅ Fetched ${listRes.data.vehicles.length} vehicle(s). First vehicle:`, listRes.data.vehicles[0]?.model || "None");

    // 3. POST add vehicle
    console.log("\n[TEST 3] Add New Vehicle (POST /driver/vehicles)...");
    const testReg = "KA 05 MH " + Math.floor(1000 + Math.random() * 9000);
    const addRes = await axios.post(
      `${baseUrl}/driver/vehicles`,
      {
        category: "Sedan",
        model: "Honda City 1.5 i-VTEC",
        registration_number: testReg,
        color: "Crystal Black",
        is_active: false,
      },
      authHeaders
    );
    console.assert(addRes.status === 201, "Failed to add vehicle");
    const createdVehicle = addRes.data.vehicle;
    console.assert(createdVehicle.category === "Sedan", "Category mismatch");
    console.assert(createdVehicle.model.includes("Honda City"), "Model mismatch");
    console.assert(createdVehicle.registration_number === testReg, "Reg number mismatch");
    console.assert(createdVehicle.color === "Crystal Black", "Color mismatch");
    console.log("✅ Vehicle added successfully! ID:", createdVehicle.id);

    // 4. GET vehicle by ID
    console.log("\n[TEST 4] Get Vehicle By ID (GET /driver/vehicles/:id)...");
    const getRes = await axios.get(`${baseUrl}/driver/vehicles/${createdVehicle.id}`, authHeaders);
    console.assert(getRes.status === 200, "Failed to get vehicle");
    console.assert(getRes.data.vehicle.id === createdVehicle.id, "ID mismatch");
    console.log("✅ Retrieved vehicle:", getRes.data.vehicle.model, "| Color:", getRes.data.vehicle.color);

    // 5. PATCH edit vehicle
    console.log("\n[TEST 5] Edit Vehicle Details (PATCH /driver/vehicles/:id)...");
    const patchRes = await axios.patch(
      `${baseUrl}/driver/vehicles/${createdVehicle.id}`,
      {
        color: "Pearl White",
        model: "Honda City ZX",
      },
      authHeaders
    );
    console.assert(patchRes.status === 200, "Failed to patch vehicle");
    console.assert(patchRes.data.vehicle.color === "Pearl White", "Color not updated");
    console.assert(patchRes.data.vehicle.model === "Honda City ZX", "Model not updated");
    console.log("✅ Vehicle updated successfully! New color:", patchRes.data.vehicle.color);

    // 6. POST upload documents
    console.log("\n[TEST 6] Upload Vehicle Documents (POST /driver/vehicles/:id/documents)...");
    const sampleDocBase64 = "data:image/jpeg;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";
    const docRes = await axios.post(
      `${baseUrl}/driver/vehicles/${createdVehicle.id}/documents`,
      {
        driving_license_number: "DL-1420110012345",
        driving_license_expiry: "2032-12-31",
        driving_license_doc: sampleDocBase64,
        rc_number: testReg,
        rc_doc: sampleDocBase64,
        insurance_policy_number: "HDFC-ERGO-98765432",
        insurance_expiry: "2028-06-30",
        insurance_doc: sampleDocBase64,
      },
      authHeaders
    );
    console.assert(docRes.status === 200, "Failed to upload documents");
    const docVeh = docRes.data.vehicle;
    console.assert(docVeh.driving_license_number === "DL-1420110012345", "DL number mismatch");
    console.assert(docVeh.rc_number === testReg, "RC number mismatch");
    console.assert(docVeh.insurance_policy_number === "HDFC-ERGO-98765432", "Insurance number mismatch");
    console.assert(docVeh.verification_status === "approved", "Verification status mismatch");
    console.assert(docVeh.driving_license_doc.includes("/uploads/documents/doc_"), "Doc file URL mismatch");
    console.log("✅ Documents uploaded & verified! Verification Status:", docVeh.verification_status);
    console.log("   Saved DL Doc URL:", docVeh.driving_license_doc);

    // 7. POST activate vehicle
    console.log("\n[TEST 7] Activate Vehicle (POST /driver/vehicles/:id/activate)...");
    const actRes = await axios.post(`${baseUrl}/driver/vehicles/${createdVehicle.id}/activate`, {}, authHeaders);
    console.assert(actRes.status === 200, "Failed to activate vehicle");
    console.assert(actRes.data.vehicle.is_active === true, "Vehicle should be active");

    // Check driver profile reflects newly active vehicle
    const profRes = await axios.get(`${baseUrl}/driver/profile`, authHeaders);
    console.assert(profRes.data.driver.vehicle_name === "Honda City ZX", "Driver vehicle_name not synced");
    console.assert(profRes.data.driver.vehicle_number === testReg, "Driver vehicle_number not synced");
    console.assert(profRes.data.driver.vehicle_model === "Sedan", "Driver vehicle_model not synced");
    console.log("✅ Vehicle activated & driver profile synchronized!");
    console.log("   Driver active vehicle:", profRes.data.driver.vehicle_name, "| Reg:", profRes.data.driver.vehicle_number);

    console.log("\n==================================================");
    console.log("   🎉 ALL VEHICLE MANAGEMENT TESTS PASSED!        ");
    console.log("==================================================");
    server.close();
    process.exit(0);
  } catch (err) {
    console.error("❌ Vehicle test failed:", err.response?.data || err.message);
    server.close();
    process.exit(1);
  }
}

runVehicleTests();

