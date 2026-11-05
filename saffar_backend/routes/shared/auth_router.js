const express = require("express");
const {
  signUp,
  signIn,
  driverSignUp,
  driverSignIn,
  forgotPassword,
  resetPassword,
  driverForgotPassword,
  driverResetPassword,
} = require("../../controllers/authController");

const router = express.Router();

router.post("/sign_up", signUp);
router.post("/driver_sign_up", driverSignUp);
router.post("/sign_in", signIn);
router.post("/driver_sign_in", driverSignIn);
router.post("/forgot_password", forgotPassword);
router.post("/reset_password", resetPassword);
router.post("/driver_forgot_password", driverForgotPassword);
router.post("/driver_reset_password", driverResetPassword);

module.exports = router;

