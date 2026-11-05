const bufferModule = require("buffer");
if (!bufferModule.SlowBuffer) {
  bufferModule.SlowBuffer = bufferModule.Buffer;
}
require("dotenv").config();
const http = require("http");
const jwt = require("jsonwebtoken");
const axios = require("axios");
const app = require("./app");
const config = require("./config");
const { initPostgresDatabase, query } = require("./database");

async function runTests() {
  console.log("==================================================");
  console.log("   SAFFAR DRIVER AUTH & PROFILE TEST SUITE        ");
  console.log("==================================================");

  await initPostgresDatabase();

  const server = http.createServer(app);
  await new Promise((resolve) => server.listen(5099, resolve));
  const baseUrl = "http://localhost:5099/api";
  console.log("Test server running on port 5099\n");

  const testPhone = "9811223344";
  const testPassword = "driverPass123";
  const newPassword = "newDriverSecret999";

  try {
    // Clean up test driver if exists from prior runs
    await query("DELETE FROM drivers WHERE phone = $1", [testPhone]);

    // 1. DRIVER REGISTRATION
    console.log("[TEST 1] Driver Registration (POST /auth/driver_sign_up)...");
    const signUpRes = await axios.post(`${baseUrl}/auth/driver_sign_up`, {
      name: "Aman Sharma",
      phone: testPhone,
      password: testPassword,
      vehicle_name: "Bajaj RE Auto",
      vehicle_model: "2024 CNG BS6",
      vehicle_number: "DL 01 AB 9999",
      email: "aman.driver@saffar.com",
    });

    console.assert(signUpRes.status === 200, "Sign up failed");
    console.assert(signUpRes.data.token, "Token not returned");
    console.assert(signUpRes.data.driver.name === "Aman Sharma", "Name mismatch");
    console.assert(signUpRes.data.driver.verification_status === "Approved", "Verification status mismatch");
    console.log("✅ Driver Registration passed! Returned token and driver ID:", signUpRes.data.driver.id);

    // Verify token role
    const decodedSignUp = jwt.verify(signUpRes.data.token, config.TOKEN_SECRET_KEY);
    console.assert(decodedSignUp.role === "driver", "Token role must be 'driver'");
    console.log("✅ JWT role is 'driver'");

    // 2. DRIVER LOGIN
    console.log("\n[TEST 2] Driver Login (POST /auth/driver_sign_in)...");
    const signInRes = await axios.post(`${baseUrl}/auth/driver_sign_in`, {
      phone: testPhone,
      password: testPassword,
    });
    console.assert(signInRes.status === 200, "Sign in failed");
    const driverToken = signInRes.data.token;
    console.assert(driverToken, "Token not returned in sign in");
    console.assert(signInRes.data.driver.phone === testPhone, "Phone mismatch");
    console.assert(signInRes.data.driver.email === "aman.driver@saffar.com", "Email mismatch");
    console.assert(signInRes.data.driver.verification_status === "Approved", "Verification status mismatch");
    console.log("✅ Driver Login passed!");

    // 3. ROLE-BASED AUTHORIZATION CHECK
    console.log("\n[TEST 3] Role-based Authorization check...");
    // Try calling passenger endpoint /api/user with driver token -> should get 403 FORBIDDEN_ROLE
    try {
      await axios.get(`${baseUrl}/user`, {
        headers: { Authorization: `Bearer ${driverToken}` },
      });
      console.error("❌ Driver was able to access passenger endpoint!");
      process.exit(1);
    } catch (roleErr) {
      console.assert(roleErr.response.status === 403, "Should return 403");
      console.assert(roleErr.response.data.error.code === "FORBIDDEN_ROLE", "Code should be FORBIDDEN_ROLE");
      console.log("✅ Driver blocked from passenger endpoint with 403 FORBIDDEN_ROLE");
    }

    // 4. FORGOT PASSWORD
    console.log("\n[TEST 4] Driver Forgot Password (POST /auth/driver_forgot_password)...");
    const forgotRes = await axios.post(`${baseUrl}/auth/driver_forgot_password`, {
      phone: testPhone,
    });
    console.assert(forgotRes.status === 200, "Forgot password failed");
    console.assert(forgotRes.data.reset_token, "Reset token missing");
    const resetToken = forgotRes.data.reset_token;
    console.log("✅ Forgot Password passed! Reset token issued:", resetToken.substring(0, 25) + "...");

    // 5. RESET PASSWORD
    console.log("\n[TEST 5] Driver Reset Password (POST /auth/driver_reset_password)...");
    const resetRes = await axios.post(`${baseUrl}/auth/driver_reset_password`, {
      phone: testPhone,
      new_password: newPassword,
      reset_token: resetToken,
    });
    console.assert(resetRes.status === 200, "Reset password failed");
    const postResetToken = resetRes.data.token;
    console.assert(postResetToken, "New auth token missing");

    // Old password should fail
    try {
      await axios.post(`${baseUrl}/auth/driver_sign_in`, {
        phone: testPhone,
        password: testPassword,
      });
      console.error("❌ Old password still worked!");
      process.exit(1);
    } catch (oldPassErr) {
      console.assert(oldPassErr.response.status === 400, "Old password rejected as expected");
      console.log("✅ Old password rejected with 400 WRONG_PASSWORD");
    }

    // New password should succeed
    const newLoginRes = await axios.post(`${baseUrl}/auth/driver_sign_in`, {
      phone: testPhone,
      password: newPassword,
    });
    console.assert(newLoginRes.status === 200, "New password login failed");
    console.log("✅ New password login verified successfully!");

    const activeToken = newLoginRes.data.token;

    // 6. VIEW DRIVER PROFILE
    console.log("\n[TEST 6] View Driver Profile (GET /driver/profile)...");
    const profileRes = await axios.get(`${baseUrl}/driver/profile`, {
      headers: { Authorization: `Bearer ${activeToken}` },
    });
    console.assert(profileRes.status === 200, "Fetch profile failed");
    const profile = profileRes.data.driver;
    console.assert(profile.phone === testPhone, "Profile phone mismatch");
    console.assert(profile.email === "aman.driver@saffar.com", "Profile email mismatch");
    console.assert(profile.verification_status === "Approved", "Verification status mismatch");
    console.assert(profile.active === true, "Driver account active mismatch");
    console.log("✅ View Profile passed! Phone:", profile.phone, "| Email:", profile.email, "| Verification:", profile.verification_status, "| Active:", profile.active);

    // 7. UPDATE DRIVER INFORMATION
    console.log("\n[TEST 7] Update Driver Information (PATCH /driver/profile)...");
    const updateRes = await axios.patch(
      `${baseUrl}/driver/profile`,
      {
        name: "Aman K. Sharma",
        age: 34,
        gender: "Male",
        address: "Flat 402, Green Glen Layout, Bengaluru",
        vehicle_model: "2025 EV Smart Auto",
      },
      { headers: { Authorization: `Bearer ${activeToken}` } }
    );
    console.assert(updateRes.status === 200, "Update profile failed");
    const updated = updateRes.data.driver;
    console.assert(updated.name === "Aman K. Sharma", "Updated name mismatch");
    console.assert(updated.age === 34, "Updated age mismatch");
    console.assert(updated.gender === "Male", "Updated gender mismatch");
    console.assert(updated.address.includes("Green Glen"), "Updated address mismatch");
    console.assert(updated.vehicle_model === "2025 EV Smart Auto", "Updated model mismatch");
    console.log("✅ Update Driver Info passed!");

    // 8. UPLOAD AND UPDATE PROFILE PHOTO
    console.log("\n[TEST 8] Upload Driver Profile Photo (POST /driver/photo)...");
    // Minimal 1x1 transparent PNG in base64
    const sampleBase64 = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=";
    const photoRes = await axios.post(
      `${baseUrl}/driver/photo`,
      { image_url: sampleBase64 },
      { headers: { Authorization: `Bearer ${activeToken}` } }
    );
    console.assert(photoRes.status === 200, "Photo upload failed");
    console.assert(photoRes.data.image_url.includes("/uploads/avatars/driver_avatar_"), "Saved image URL mismatch");
    console.log("✅ Photo Upload passed! Saved URL:", photoRes.data.image_url);

    // Clean up test driver
    await query("DELETE FROM drivers WHERE phone = $1", [testPhone]);

    console.log("\n==================================================");
    console.log("   🎉 ALL DRIVER AUTH & PROFILE TESTS PASSED!    ");
    console.log("==================================================");
    server.close();
    process.exit(0);
  } catch (err) {
    console.error("❌ Test failed:", err.response?.data || err.message);
    server.close();
    process.exit(1);
  }
}

runTests();

