const paymentService = require("../../modules/payments/payment.service");

const createOrder = async (req, res) => {
  try {
    const userId = req.user?.id || req.body?.user_id;
    const { ride_id, amount_minor, method = "UPI", idempotency_key } = req.body;

    if (!ride_id || !amount_minor) {
      return res.status(400).json({
        error: { code: "EMPTY_PARAM", message: "ride_id and amount_minor are required." },
      });
    }

    const result = await paymentService.createPaymentOrder({
      rideId: ride_id,
      userId,
      amountMinor: parseInt(amount_minor, 10),
      method,
      idempotencyKey: idempotency_key,
    });

    return res.status(200).json(result);
  } catch (err) {
    console.error("Error in createOrder:", err);
    return res.status(500).json({
      error: { code: "PAYMENT_ORDER_ERROR", message: err.message },
    });
  }
};

const verifyPayment = async (req, res) => {
  try {
    const userId = req.user?.id || req.body?.user_id;
    const {
      ride_id,
      gateway_order_id,
      gateway_payment_id,
      gateway_signature,
      method = "UPI",
      idempotency_key,
    } = req.body;

    if (!ride_id || !gateway_order_id || !gateway_payment_id || !gateway_signature) {
      return res.status(400).json({
        error: {
          code: "EMPTY_PARAM",
          message: "ride_id, gateway_order_id, gateway_payment_id and gateway_signature are required.",
        },
      });
    }

    const result = await paymentService.verifyAndCapturePayment({
      rideId: ride_id,
      userId,
      gatewayOrderId: gateway_order_id,
      gatewayPaymentId: gateway_payment_id,
      gatewaySignature: gateway_signature,
      method,
      idempotencyKey: idempotency_key,
    });

    return res.status(200).json(result);
  } catch (err) {
    if (err.code === "INVALID_SIGNATURE") {
      return res.status(400).json({
        error: { code: "INVALID_SIGNATURE", message: err.message },
      });
    }
    console.error("Error in verifyPayment:", err);
    return res.status(500).json({
      error: { code: "PAYMENT_VERIFY_ERROR", message: err.message },
    });
  }
};

const processCash = async (req, res) => {
  try {
    const driverId = req.user?.id || req.body?.driver_id;
    const { ride_id, amount_minor, idempotency_key } = req.body;

    if (!ride_id) {
      return res.status(400).json({
        error: { code: "EMPTY_PARAM", message: "ride_id is required." },
      });
    }

    const result = await paymentService.processCashPayment({
      rideId: ride_id,
      driverId,
      amountMinor: amount_minor ? parseInt(amount_minor, 10) : null,
      idempotencyKey: idempotency_key,
    });

    return res.status(200).json(result);
  } catch (err) {
    console.error("Error in processCash:", err);
    return res.status(500).json({
      error: { code: "CASH_PAYMENT_ERROR", message: err.message },
    });
  }
};

const payWithInAppWallet = async (req, res) => {
  try {
    const userId = req.user?.id || req.body?.user_id;
    const { ride_id, amount_minor, idempotency_key } = req.body;

    if (!ride_id || !amount_minor) {
      return res.status(400).json({
        error: { code: "EMPTY_PARAM", message: "ride_id and amount_minor are required." },
      });
    }

    const result = await paymentService.payWithWallet(
      userId,
      ride_id,
      parseInt(amount_minor, 10),
      idempotency_key
    );

    return res.status(200).json(result);
  } catch (err) {
    if (err.code === "INSUFFICIENT_WALLET_BALANCE") {
      return res.status(400).json({
        error: { code: "INSUFFICIENT_WALLET_BALANCE", message: err.message },
      });
    }
    console.error("Error in payWithInAppWallet:", err);
    return res.status(500).json({
      error: { code: "WALLET_PAYMENT_ERROR", message: err.message },
    });
  }
};

const handleWebhook = async (req, res) => {
  try {
    const signature = req.headers["x-razorpay-signature"] || req.headers["x-gateway-signature"];
    const rawBody = req.rawBody || req.body;

    if (!signature) {
      return res.status(400).json({
        error: { code: "SIGNATURE_MISSING", message: "Webhook signature header missing." },
      });
    }

    const result = await paymentService.handleGatewayWebhook(rawBody, signature);
    return res.status(200).json(result);
  } catch (err) {
    if (err.code === "INVALID_WEBHOOK_SIGNATURE") {
      return res.status(400).json({
        error: { code: "INVALID_WEBHOOK_SIGNATURE", message: err.message },
      });
    }
    console.error("Error in handleWebhook:", err);
    return res.status(500).json({
      error: { code: "WEBHOOK_PROCESSING_ERROR", message: err.message },
    });
  }
};

const getStatus = async (req, res) => {
  try {
    const rideId = req.params.rideId || req.query.ride_id;
    if (!rideId) {
      return res.status(400).json({
        error: { code: "EMPTY_PARAM", message: "rideId parameter is required." },
      });
    }

    const status = await paymentService.reconcilePaymentStatus(rideId);
    return res.status(200).json(status);
  } catch (err) {
    console.error("Error in getStatus:", err);
    return res.status(500).json({
      error: { code: "PAYMENT_STATUS_ERROR", message: err.message },
    });
  }
};

const getHistory = async (req, res) => {
  try {
    const userId = req.user?.id || req.query?.user_id;
    const page = parseInt(req.query?.page || "1", 10);
    const limit = parseInt(req.query?.limit || "20", 10);

    const history = await paymentService.getPaymentHistory({ userId, page, limit });
    return res.status(200).json(history);
  } catch (err) {
    console.error("Error in getHistory:", err);
    return res.status(500).json({
      error: { code: "PAYMENT_HISTORY_ERROR", message: err.message },
    });
  }
};

const refundPayment = async (req, res) => {
  try {
    const { payment_id, amount_minor, reason } = req.body;
    if (!payment_id) {
      return res.status(400).json({
        error: { code: "EMPTY_PARAM", message: "payment_id is required." },
      });
    }

    const result = await paymentService.initiateRefund({
      paymentId: payment_id,
      amountMinor: amount_minor ? parseInt(amount_minor, 10) : null,
      reason,
    });

    return res.status(200).json(result);
  } catch (err) {
    console.error("Error in refundPayment:", err);
    return res.status(500).json({
      error: { code: "REFUND_ERROR", message: err.message },
    });
  }
};

module.exports = {
  createOrder,
  verifyPayment,
  processCash,
  payWithInAppWallet,
  handleWebhook,
  getStatus,
  getHistory,
  refundPayment,
};

