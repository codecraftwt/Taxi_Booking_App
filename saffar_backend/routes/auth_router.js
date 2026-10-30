const express = require("express");
const {
  signUp,
  signIn,
  driverSignUp,
  driverSignIn,
} = require("../controllers/authController");

const router = express.Router();

router.post("/sign_up", signUp);
router.post("/driver_sign_up", driverSignUp);
router.post("/sign_in", signIn);
router.post("/driver_sign_in", driverSignIn);

module.exports = router;

