const crypto = require("crypto");
const { v4: uuidv4 } = require("uuid");
const { pool, query } = require("../../database");

// Payment Lifecycle States
const PaymentStatus = {
  PENDING: "PENDING",
  SUCCESS: "SUCCESS",
  FAILED: "FAILED",
  REFUND_INITIATED: "REFUND_INITIATED",
  REFUND_COMPLETED: "REFUND_COMPLETED",
  REFUND_FAILED: "REFUND_FAILED",
};

// Payment Methods
const PaymentMethod = {
  CASH: "CASH",
  WALLET: "WALLET",
  UPI: "UPI",
  CARD: "CARD",
  NETBANKING: "NETBANKING",
};

/**
 * Validates Razorpay / Gateway HMAC SHA-256 payment signature
 */
function verifyPaymentSignature({ orderId, paymentId, signature, secret }) {
  if (!orderId || !paymentId || !signature) return false;
  const keySecret = secret || process.env.RAZORPAY_KEY_SECRET || "dummy_razorpay_key_secret";
  const expectedSignature = crypto
    .createHmac("sha256", keySecret)
    .update(`${orderId}|${paymentId}`)
    .digest("hex");

  try {
    return crypto.timingSafeEqual(
      Buffer.from(expectedSignature, "utf8"),
      Buffer.from(signature, "utf8")
    );
  } catch (_) {
    return false;
  }
}

/**
 * Validates Gateway Webhook HMAC SHA-256 signature
 */
function verifyWebhookSignature({ rawBody, signature, secret }) {
  if (!rawBody || !signature) return false;
  const webhookSecret = secret || process.env.RAZORPAY_WEBHOOK_SECRET || process.env.PAYMENT_WEBHOOK_SECRET || "saffar_webhook_secret_2026";
  const expectedSignature = crypto
    .createHmac("sha256", webhookSecret)
    .update(typeof rawBody === "string" ? rawBody : JSON.stringify(rawBody))
    .digest("hex");

  try {
    return crypto.timingSafeEqual(
      Buffer.from(expectedSignature, "utf8"),
      Buffer.from(signature, "utf8")
    );
  } catch (_) {
    return false;
  }
}

/**
 * Creates an intent / pending payment order before gateway interaction
 */
async function createPaymentOrder({ rideId, userId, amountMinor, method = "UPI", idempotencyKey = null }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    // 1. Check if an active successful payment already exists for this ride
    const existing = await client.query(
      `SELECT id, status, amount_minor FROM payments WHERE ride_id = $1 AND status = 'SUCCESS' FOR UPDATE;`,
      [rideId]
    );
    if (existing.rows.length > 0) {
      await client.query("ROLLBACK;");
      return {
        alreadyPaid: true,
        paymentId: existing.rows[0].id,
        amountMinor: existing.rows[0].amount_minor,
        status: PaymentStatus.SUCCESS,
      };
    }

    const effectiveIdempotency = idempotencyKey || `idem_order_${rideId}_${Date.now()}`;
    const paymentId = `pay_${uuidv4().replace(/-/g, "").slice(0, 16)}`;
    const gatewayOrderId = `order_${uuidv4().replace(/-/g, "").slice(0, 16)}`;

    // 2. Insert or load via idempotency
    const insertRes = await client.query(`
      INSERT INTO payments (
        id, ride_id, user_id, amount_minor, currency, payment_gateway,
        gateway_order_id, idempotency_key, status, method, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, 'INR', 'RAZORPAY', $5, $6, 'PENDING', $7, (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
      ON CONFLICT (idempotency_key) DO UPDATE SET
        updated_at = (NOW() AT TIME ZONE 'UTC')
      RETURNING id, gateway_order_id, status, amount_minor;
    `, [paymentId, rideId, userId, amountMinor, gatewayOrderId, effectiveIdempotency, method]);

    await client.query("COMMIT;");
    const row = insertRes.rows[0];
    return {
      success: true,
      paymentId: row.id,
      gatewayOrderId: row.gateway_order_id,
      amountMinor: row.amount_minor,
      displayAmount: (row.amount_minor / 100).toFixed(2),
      status: row.status,
      currency: "INR",
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Authoritative payment verification via cryptographic signature or gateway confirmation
 */
async function verifyAndCapturePayment({
  rideId,
  userId,
  gatewayOrderId,
  gatewayPaymentId,
  gatewaySignature,
  method = "UPI",
  idempotencyKey = null,
}) {
  // 1. Cryptographic signature verification - never trust client blind report
  const isValidSig = verifyPaymentSignature({
    orderId: gatewayOrderId,
    paymentId: gatewayPaymentId,
    signature: gatewaySignature,
  });

  if (!isValidSig) {
    const error = new Error("Invalid payment signature. Verification failed.");
    error.code = "INVALID_SIGNATURE";
    throw error;
  }

  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    // 2. Concurrency protection - check if already captured
    const checkRes = await client.query(
      `SELECT id, status, amount_minor FROM payments WHERE gateway_payment_id = $1 FOR UPDATE;`,
      [gatewayPaymentId]
    );

    if (checkRes.rows.length > 0 && checkRes.rows[0].status === PaymentStatus.SUCCESS) {
      await client.query("COMMIT;");
      return {
        success: true,
        alreadyProcessed: true,
        paymentId: checkRes.rows[0].id,
        status: PaymentStatus.SUCCESS,
        amountMinor: checkRes.rows[0].amount_minor,
      };
    }

    // 3. Mark payment as SUCCESS and attach signatures
    const updateRes = await client.query(`
      UPDATE payments
      SET status = 'SUCCESS',
          gateway_payment_id = $1,
          gateway_signature = $2,
          method = $3,
          updated_at = (NOW() AT TIME ZONE 'UTC')
      WHERE gateway_order_id = $4 AND ride_id = $5
      RETURNING id, amount_minor;
    `, [gatewayPaymentId, gatewaySignature, method, gatewayOrderId, rideId]);

    let paymentRecord = updateRes.rows[0];
    if (!paymentRecord) {
      // If payment row wasn't pre-created via createPaymentOrder, insert with idempotency
      const paymentId = `pay_${uuidv4().replace(/-/g, "").slice(0, 16)}`;
      const effectiveIdem = idempotencyKey || `idem_cap_${rideId}_${gatewayPaymentId}`;
      const insRes = await client.query(`
        INSERT INTO payments (
          id, ride_id, user_id, amount_minor, currency, payment_gateway,
          gateway_order_id, gateway_payment_id, gateway_signature, idempotency_key,
          status, method, created_at, updated_at
        ) VALUES ($1, $2, $3, 13500, 'INR', 'RAZORPAY', $4, $5, $6, $7, 'SUCCESS', $8, (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
        ON CONFLICT (idempotency_key) DO UPDATE SET status = 'SUCCESS'
        RETURNING id, amount_minor;
      `, [paymentId, rideId, userId, gatewayOrderId, gatewayPaymentId, gatewaySignature, effectiveIdem, method]);
      paymentRecord = insRes.rows[0];
    }

    // 4. Update ride payment method (separate trip state from payment state)
    await client.query(
      `UPDATE rides SET payment_method = $1 WHERE id = $2;`,
      [`Paid via ${method}`, rideId]
    );

    await client.query("COMMIT;");
    return {
      success: true,
      paymentId: paymentRecord.id,
      status: PaymentStatus.SUCCESS,
      amountMinor: paymentRecord.amount_minor,
      displayAmount: (paymentRecord.amount_minor / 100).toFixed(2),
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Driver confirms Cash collected from passenger
 */
async function processCashPayment({ rideId, driverId, amountMinor, idempotencyKey = null }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    // 1. Verify driver owns this completed ride
    const rideRes = await client.query(
      `SELECT id, user_id, price, status FROM rides WHERE id = $1 AND driver_id = $2 FOR UPDATE;`,
      [rideId, driverId]
    );
    if (rideRes.rows.length === 0) {
      await client.query("ROLLBACK;");
      const err = new Error("Ride not found or not assigned to this driver.");
      err.code = "RIDE_NOT_FOUND";
      throw err;
    }

    const userId = rideRes.rows[0].user_id;
    const finalAmountMinor = amountMinor || Math.round(parseFloat(rideRes.rows[0].price || 0) * 100);

    // 2. Check if already settled
    const existing = await client.query(
      `SELECT id, status FROM payments WHERE ride_id = $1 AND status = 'SUCCESS' FOR UPDATE;`,
      [rideId]
    );
    if (existing.rows.length > 0) {
      await client.query("COMMIT;");
      return {
        success: true,
        alreadyProcessed: true,
        paymentId: existing.rows[0].id,
        status: PaymentStatus.SUCCESS,
      };
    }

    const paymentId = `pay_cash_${uuidv4().replace(/-/g, "").slice(0, 16)}`;
    const effectiveIdem = idempotencyKey || `idem_cash_${rideId}`;

    await client.query(`
      INSERT INTO payments (
        id, ride_id, user_id, amount_minor, currency, payment_gateway,
        idempotency_key, status, method, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, 'INR', 'CASH', $5, 'SUCCESS', 'CASH', (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
      ON CONFLICT (idempotency_key) DO NOTHING;
    `, [paymentId, rideId, userId, finalAmountMinor, effectiveIdem]);

    await client.query(
      `UPDATE rides SET payment_method = 'Paid via Cash' WHERE id = $1;`,
      [rideId]
    );

    await client.query("COMMIT;");
    return {
      success: true,
      paymentId,
      amountMinor: finalAmountMinor,
      displayAmount: (finalAmountMinor / 100).toFixed(2),
      status: PaymentStatus.SUCCESS,
      method: PaymentMethod.CASH,
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Handles Webhook Events asynchronously from Payment Gateway
 */
async function handleGatewayWebhook(rawBody, signature) {
  // 1. Signature verification
  const isValid = verifyWebhookSignature({ rawBody, signature });
  if (!isValid) {
    const error = new Error("Invalid gateway webhook signature");
    error.code = "INVALID_WEBHOOK_SIGNATURE";
    throw error;
  }

  const payload = typeof rawBody === "string" ? JSON.parse(rawBody) : rawBody;
  const event = payload.event;
  const paymentEntity = payload.payload?.payment?.entity;
  const refundEntity = payload.payload?.refund?.entity;

  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    if (event === "payment.captured" && paymentEntity) {
      const gatewayPaymentId = paymentEntity.id;
      const gatewayOrderId = paymentEntity.order_id;
      const amountMinor = paymentEntity.amount;

      await client.query(`
        UPDATE payments
        SET status = 'SUCCESS',
            amount_minor = COALESCE($1, amount_minor),
            updated_at = (NOW() AT TIME ZONE 'UTC')
        WHERE gateway_order_id = $2 OR gateway_payment_id = $3;
      `, [amountMinor, gatewayOrderId, gatewayPaymentId]);
    } else if (event === "payment.failed" && paymentEntity) {
      const gatewayPaymentId = paymentEntity.id;
      const gatewayOrderId = paymentEntity.order_id;
      const failureReason = paymentEntity.error_description || "Payment failed at gateway";

      await client.query(`
        UPDATE payments
        SET status = 'FAILED',
            failure_reason = $1,
            updated_at = (NOW() AT TIME ZONE 'UTC')
        WHERE gateway_order_id = $2 OR gateway_payment_id = $3;
      `, [failureReason, gatewayOrderId, gatewayPaymentId]);
    } else if (event === "refund.processed" && refundEntity) {
      const refundId = refundEntity.id;
      const gatewayPaymentId = refundEntity.payment_id;
      const refundAmountMinor = refundEntity.amount;

      await client.query(`
        UPDATE payments
        SET status = 'REFUND_COMPLETED',
            refund_id = $1,
            refund_amount_minor = $2,
            updated_at = (NOW() AT TIME ZONE 'UTC')
        WHERE gateway_payment_id = $3;
      `, [refundId, refundAmountMinor, gatewayPaymentId]);
    } else if (event === "refund.failed" && refundEntity) {
      const gatewayPaymentId = refundEntity.payment_id;
      const failureReason = refundEntity.error_description || "Refund processing failed";

      await client.query(`
        UPDATE payments
        SET status = 'REFUND_FAILED',
            failure_reason = $1,
            updated_at = (NOW() AT TIME ZONE 'UTC')
        WHERE gateway_payment_id = $2;
      `, [failureReason, gatewayPaymentId]);
    }

    await client.query("COMMIT;");
    return { received: true, event };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Initiates a Refund for a payment
 */
async function initiateRefund({ paymentId, amountMinor, reason = "Rider cancelled" }) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    const payRes = await client.query(
      `SELECT id, ride_id, user_id, amount_minor, status, payment_gateway FROM payments WHERE id = $1 FOR UPDATE;`,
      [paymentId]
    );

    if (payRes.rows.length === 0) {
      await client.query("ROLLBACK;");
      throw new Error(`Payment ${paymentId} not found.`);
    }

    const payment = payRes.rows[0];
    if (payment.status !== PaymentStatus.SUCCESS) {
      await client.query("ROLLBACK;");
      throw new Error(`Cannot refund payment in status ${payment.status}.`);
    }

    const refundId = `ref_${uuidv4().replace(/-/g, "").slice(0, 16)}`;
    const refundAmount = amountMinor || payment.amount_minor;

    // If payment was made via wallet, credit back immediately
    if (payment.payment_gateway === "WALLET") {
      const walRes = await client.query(
        `SELECT id, balance_minor FROM wallets WHERE entity_id = $1 AND entity_type = 'USER' FOR UPDATE;`,
        [payment.user_id]
      );
      if (walRes.rows.length > 0) {
        const newBalance = parseInt(walRes.rows[0].balance_minor, 10) + refundAmount;
        await client.query(
          `UPDATE wallets SET balance_minor = $1, updated_at = (NOW() AT TIME ZONE 'UTC') WHERE id = $2;`,
          [newBalance, walRes.rows[0].id]
        );
        await client.query(
          `UPDATE users SET wallet_balance = $1 WHERE id = $2;`,
          [newBalance / 100, payment.user_id]
        );
        await client.query(`
          INSERT INTO wallet_transactions (
            id, wallet_id, transaction_type, amount_minor, balance_after_minor, reference_type, reference_id, description
          ) VALUES ($1, $2, 'CREDIT', $3, $4, 'REFUND', $5, $6);
        `, [`wtx_${uuidv4().slice(0, 8)}`, walRes.rows[0].id, refundAmount, newBalance, paymentId, reason]);
      }

      await client.query(`
        UPDATE payments
        SET status = 'REFUND_COMPLETED',
            refund_id = $1,
            refund_amount_minor = $2,
            refund_reason = $3,
            updated_at = (NOW() AT TIME ZONE 'UTC')
        WHERE id = $4;
      `, [refundId, refundAmount, reason, paymentId]);
    } else {
      // Gateway refund initiated
      await client.query(`
        UPDATE payments
        SET status = 'REFUND_INITIATED',
            refund_id = $1,
            refund_amount_minor = $2,
            refund_reason = $3,
            updated_at = (NOW() AT TIME ZONE 'UTC')
        WHERE id = $4;
      `, [refundId, refundAmount, reason, paymentId]);
    }

    await client.query("COMMIT;");
    return {
      success: true,
      refundId,
      refundAmountMinor: refundAmount,
      status: payment.payment_gateway === "WALLET" ? PaymentStatus.REFUND_COMPLETED : PaymentStatus.REFUND_INITIATED,
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Deducts fare from customer in-app wallet atomically
 */
async function payWithWallet(userId, rideId, amountMinor, idempotencyKey = null) {
  const client = await pool.connect();
  try {
    await client.query("BEGIN;");

    // 1. Lock wallet row for update
    const walletRes = await client.query(
      `SELECT id, balance_minor FROM wallets WHERE entity_id = $1 AND entity_type = 'USER' FOR UPDATE;`,
      [userId]
    );

    let walletId = null;
    let balanceMinor = 124000; // default ₹1240.00
    if (walletRes.rows.length === 0) {
      walletId = `wal_${userId}`;
      await client.query(`
        INSERT INTO wallets (id, entity_type, entity_id, balance_minor)
        VALUES ($1, 'USER', $2, 124000);
      `, [walletId, userId]);
    } else {
      walletId = walletRes.rows[0].id;
      balanceMinor = parseInt(walletRes.rows[0].balance_minor, 10);
    }

    if (balanceMinor < amountMinor) {
      await client.query("ROLLBACK;");
      const err = new Error(`Insufficient wallet balance (₹${(balanceMinor / 100).toFixed(2)} available, ₹${(amountMinor / 100).toFixed(2)} required).`);
      err.code = "INSUFFICIENT_WALLET_BALANCE";
      throw err;
    }

    const newBalanceMinor = balanceMinor - amountMinor;
    await client.query(
      `UPDATE wallets SET balance_minor = $1, updated_at = (NOW() AT TIME ZONE 'UTC') WHERE id = $2;`,
      [newBalanceMinor, walletId]
    );

    // Sync legacy users.wallet_balance
    await client.query(
      `UPDATE users SET wallet_balance = $1 WHERE id = $2;`,
      [newBalanceMinor / 100, userId]
    );

    // Log wallet transaction
    const txId = `wtx_${uuidv4().slice(0, 8)}`;
    await client.query(`
      INSERT INTO wallet_transactions (
        id, wallet_id, transaction_type, amount_minor, balance_after_minor, 
        reference_type, reference_id, description
      ) VALUES ($1, $2, 'DEBIT', $3, $4, 'RIDE_PAYMENT', $5, 'Payment for ride booking');
    `, [txId, walletId, amountMinor, newBalanceMinor, rideId]);

    // Record in payments table with idempotency
    const paymentId = `pay_wal_${uuidv4().replace(/-/g, "").slice(0, 16)}`;
    const effectiveIdem = idempotencyKey || `idem_wal_${rideId}`;
    await client.query(`
      INSERT INTO payments (
        id, ride_id, user_id, amount_minor, currency, payment_gateway,
        status, method, idempotency_key, created_at, updated_at
      ) VALUES ($1, $2, $3, $4, 'INR', 'WALLET', 'SUCCESS', 'Saffar Wallet', $5, (NOW() AT TIME ZONE 'UTC'), (NOW() AT TIME ZONE 'UTC'))
      ON CONFLICT (idempotency_key) DO UPDATE SET status = 'SUCCESS';
    `, [paymentId, rideId, userId, amountMinor, effectiveIdem]);

    await client.query(
      `UPDATE rides SET payment_method = 'Paid via Saffar Wallet' WHERE id = $1;`,
      [rideId]
    );

    await client.query("COMMIT;");
    return {
      success: true,
      paymentId,
      remainingBalanceMinor: newBalanceMinor,
      remainingBalanceDisplay: (newBalanceMinor / 100).toFixed(2),
      status: PaymentStatus.SUCCESS,
    };
  } catch (err) {
    await client.query("ROLLBACK;");
    throw err;
  } finally {
    client.release();
  }
}

/**
 * Reconciles authoritative payment status for a ride after network interruptions
 */
async function reconcilePaymentStatus(rideId) {
  const res = await query(
    `SELECT p.*, r.price, r.status as trip_status
     FROM payments p
     JOIN rides r ON p.ride_id = r.id
     WHERE p.ride_id = $1
     ORDER BY p.created_at DESC
     LIMIT 1;`,
    [rideId]
  );

  if (res.rows.length === 0) {
    return {
      rideId,
      paymentStatus: PaymentStatus.PENDING,
      isPaid: false,
      message: "No payment record initiated for this trip.",
    };
  }

  const p = res.rows[0];
  return {
    rideId,
    paymentId: p.id,
    paymentStatus: p.status,
    isPaid: p.status === PaymentStatus.SUCCESS,
    amountMinor: p.amount_minor,
    displayAmount: (p.amount_minor / 100).toFixed(2),
    method: p.method,
    paymentGateway: p.payment_gateway,
    tripStatus: p.trip_status,
    refundId: p.refund_id,
    updatedAt: p.updated_at,
  };
}

/**
 * Retrieves paginated payment history for a user
 */
async function getPaymentHistory({ userId, page = 1, limit = 20 }) {
  const offset = (page - 1) * limit;
  const countRes = await query("SELECT COUNT(*) FROM payments WHERE user_id = $1;", [userId]);
  const totalCount = parseInt(countRes.rows[0].count, 10);

  const res = await query(
    `SELECT p.*, r.vehicle_type, sa.street as pickup_street, da.street as drop_street
     FROM payments p
     LEFT JOIN rides r ON p.ride_id = r.id
     LEFT JOIN addresses sa ON r.source_address_id = sa.id
     LEFT JOIN addresses da ON r.destination_address_id = da.id
     WHERE p.user_id = $1
     ORDER BY p.created_at DESC
     LIMIT $2 OFFSET $3;`,
    [userId, limit, offset]
  );

  return {
    total: totalCount,
    page,
    limit,
    payments: res.rows.map((row) => ({
      id: row.id,
      rideId: row.ride_id,
      amountMinor: row.amount_minor,
      displayAmount: (row.amount_minor / 100).toFixed(2),
      currency: row.currency,
      status: row.status,
      method: row.method,
      paymentGateway: row.payment_gateway,
      vehicleType: row.vehicle_type,
      pickupStreet: row.pickup_street,
      dropStreet: row.drop_street,
      refundId: row.refund_id,
      createdAt: row.created_at,
    })),
  };
}

module.exports = {
  PaymentStatus,
  PaymentMethod,
  verifyPaymentSignature,
  verifyWebhookSignature,
  createPaymentOrder,
  verifyAndCapturePayment,
  processCashPayment,
  handleGatewayWebhook,
  initiateRefund,
  payWithWallet,
  reconcilePaymentStatus,
  getPaymentHistory,
};
