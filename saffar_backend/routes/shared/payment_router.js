const express = require("express");
const router = express.Router();
const {
  createOrder,
  verifyPayment,
  processCash,
  payWithInAppWallet,
  handleWebhook,
  getStatus,
  getHistory,
  refundPayment,
} = require("../../controllers/paymentController");
const {
  validateBearerToken,
  validateUserToken,
  validateDriverToken,
} = require("../../middlewares");

router.post("/create_order", validateUserToken, createOrder);
router.post("/verify", validateUserToken, verifyPayment);
router.post("/cash", validateDriverToken, processCash);
router.post("/wallet", validateUserToken, payWithInAppWallet);
router.post("/webhook", handleWebhook);
router.get("/status/:rideId", validateBearerToken, getStatus);
router.get("/history", validateUserToken, getHistory);
router.post("/refund", validateBearerToken, refundPayment);

module.exports = router;

