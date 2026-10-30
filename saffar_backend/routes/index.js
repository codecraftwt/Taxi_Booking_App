const express = require("express");
const authRouter = require("./auth_router");
const rideRouter = require("./ride_router");
const userRouter = require("./user_router");

const router = express.Router();

router.use("/auth", authRouter);
router.use("/ride", rideRouter);
router.use("/user", userRouter);

module.exports = router;

