require("./config/polyfill");
const assert = require("assert");
const crypto = require("crypto");
const paymentService = require("./modules/payments/payment.service");
const {
  authRateLimiter,
  apiRateLimiter,
  checkLoginLockout,
  recordFailedLogin,
  resetFailedLogin,
  maskSensitiveData,
} = require("./middlewares/security_middleware");

async function runPaymentAndSecurityTests() {
  console.log("=== RUNNING PAYMENT & SECURITY SUITE ===");

  // ─── 1. Payment Signature Verification ───────────────────
  console.log("\n[TEST 1] Payment Gateway Signature Validation");
  const secret = "test_razorpay_secret_123";
  const orderId = "order_test_999";
  const paymentId = "pay_test_888";

  // Calculate genuine signature
  const validSignature = crypto
    .createHmac("sha256", secret)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");

  const isGenuine = paymentService.verifyPaymentSignature({
    orderId,
    paymentId,
    signature: validSignature,
    secret,
  });
  assert.strictEqual(isGenuine, true, "Valid payment signature must be verified successfully");

  const isTampered = paymentService.verifyPaymentSignature({
    orderId,
    paymentId,
    signature: "tampered_fake_signature_hex_value_000",
    secret,
  });
  assert.strictEqual(isTampered, false, "Tampered payment signature must be rejected");
  console.log(" Payment Signature Verification: PASS");

  // ─── 2. Gateway Webhook Signature Verification ──────────
  console.log("\n[TEST 2] Gateway Webhook Signature Validation");
  const webhookSecret = "test_webhook_secret_456";
  const webhookPayload = JSON.stringify({
    event: "payment.captured",
    payload: {
      payment: {
        entity: {
          id: "pay_wh_123",
          order_id: "order_wh_456",
          amount: 13500,
          status: "captured",
        },
      },
    },
  });

  const validWebhookSig = crypto
    .createHmac("sha256", webhookSecret)
    .update(webhookPayload)
    .digest("hex");

  const isWebhookValid = paymentService.verifyWebhookSignature({
    rawBody: webhookPayload,
    signature: validWebhookSig,
    secret: webhookSecret,
  });
  assert.strictEqual(isWebhookValid, true, "Genuine webhook payload signature must verify");

  const isWebhookFake = paymentService.verifyWebhookSignature({
    rawBody: webhookPayload,
    signature: "fake_webhook_sig",
    secret: webhookSecret,
  });
  assert.strictEqual(isWebhookFake, false, "Forged webhook payload signature must fail");
  console.log(" Gateway Webhook Signature Validation: PASS");

  // ─── 3. Payment Status State Machine ────────────────────
  console.log("\n[TEST 3] Payment State Machine Enumeration");
  assert.strictEqual(paymentService.PaymentStatus.PENDING, "PENDING");
  assert.strictEqual(paymentService.PaymentStatus.SUCCESS, "SUCCESS");
  assert.strictEqual(paymentService.PaymentStatus.FAILED, "FAILED");
  assert.strictEqual(paymentService.PaymentStatus.REFUND_INITIATED, "REFUND_INITIATED");
  assert.strictEqual(paymentService.PaymentStatus.REFUND_COMPLETED, "REFUND_COMPLETED");
  assert.strictEqual(paymentService.PaymentStatus.REFUND_FAILED, "REFUND_FAILED");
  console.log(" Payment Status State Machine: PASS");

  // ─── 4. Sensitive Data Redaction & Masking ───────────────
  console.log("\n[TEST 4] Sensitive Data Redaction");
  const rawLogData = {
    user: {
      id: "usr_1",
      phone: "+919876543210",
      password: "SuperSecretPassword123!",
      otp: "4829",
      otp_hash: "8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918",
    },
    payment: {
      gateway_secret: "rzp_live_secret_key_abc",
      token: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
      amount: 135.0,
    },
  };

  const masked = maskSensitiveData(rawLogData);
  console.log("Masked Data Sample:", masked);
  assert.strictEqual(masked.user.password, "[REDACTED]");
  assert.strictEqual(masked.user.otp, "[REDACTED]");
  assert.strictEqual(masked.user.otp_hash, "[REDACTED]");
  assert.strictEqual(masked.payment.token, "[REDACTED]");
  assert.strictEqual(masked.user.phone, "+919876543210", "Non-sensitive fields must remain intact");
  console.log(" Sensitive Data Redaction: PASS");

  // ─── 5. Brute Force Login Lockout Protection ─────────────
  console.log("\n[TEST 5] Brute Force Login Protection");
  const testPhone = "+919999900001";
  resetFailedLogin(testPhone);

  // Simulate 4 failed logins - should not be locked yet
  for (let i = 0; i < 4; i++) {
    recordFailedLogin(testPhone);
  }

  let lockedResponse = null;
  const mockReq = { body: { phone: testPhone }, ip: "127.0.0.1" };
  const mockRes = {
    status(code) {
      this.statusCode = code;
      return this;
    },
    json(data) {
      this.data = data;
      lockedResponse = { code: this.statusCode, data };
    },
  };
  let nextCalled = false;

  checkLoginLockout(mockReq, mockRes, () => {
    nextCalled = true;
  });
  assert.strictEqual(nextCalled, true, "Account should not be locked after 4 attempts");

  // 5th failed login triggers 15-min lockout
  recordFailedLogin(testPhone);
  nextCalled = false;
  checkLoginLockout(mockReq, mockRes, () => {
    nextCalled = true;
  });

  assert.strictEqual(nextCalled, false, "Next() must not be called when locked");
  assert.strictEqual(lockedResponse.code, 423, "Must return HTTP 423 Locked");
  assert.strictEqual(lockedResponse.data.error.code, "ACCOUNT_TEMPORARILY_LOCKED");
  console.log(" Brute Force Login Protection: PASS");

  // Reset lockout
  resetFailedLogin(testPhone);
  nextCalled = false;
  checkLoginLockout(mockReq, mockRes, () => {
    nextCalled = true;
  });
  assert.strictEqual(nextCalled, true, "Account should be unlocked after successful reset");

  // ─── 6. Rate Limiter Middleware ──────────────────────────
  console.log("\n[TEST 6] Sliding Window Rate Limiter");
  let rateLimited = false;
  const rateLimitReq = { ip: "192.168.1.100" };
  const rateLimitRes = {
    setHeader() {},
    status(code) {
      if (code === 429) rateLimited = true;
      return this;
    },
    json() {},
  };

  const strictLimiter = authRateLimiter;
  for (let i = 0; i < 15; i++) {
    strictLimiter(rateLimitReq, rateLimitRes, () => {});
  }
  assert.strictEqual(rateLimited, true, "Strict auth rate limiter must trigger 429 after exceeding limit");
  console.log(" Sliding Window Rate Limiter: PASS");

  console.log("\n============================================");
  console.log(" ALL PAYMENT & SECURITY TESTS PASSED! ");
  console.log("============================================");
}

runPaymentAndSecurityTests().catch((err) => {
  console.error("Payment & Security test failure:", err);
  process.exit(1);
});

