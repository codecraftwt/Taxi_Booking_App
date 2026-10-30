const express = require("express");
const {
  getDriverProfile,
  updateDriverProfile,
  toggleAvailability,
  getDriverRideHistory,
  getDriverEarningsSummary,
  getDriverEarningsHistory,
  completeRide,
  getDriverDashboardStats,
} = require("../controllers/driverController");
const { validateBearerToken } = require("../middlewares/token_middleware");

const router = express.Router();

// Driver profile
router.get("/profile", validateBearerToken, getDriverProfile);
router.patch("/profile", validateBearerToken, updateDriverProfile);

// Driver availability
router.post("/availability", validateBearerToken, toggleAvailability);

// Driver dashboard
router.get("/dashboard", validateBearerToken, getDriverDashboardStats);

// Driver rides
router.get("/rides/history", validateBearerToken, getDriverRideHistory);
router.post("/rides/:rideId/complete", validateBearerToken, completeRide);

// Driver earnings
router.get("/earnings/summary", validateBearerToken, getDriverEarningsSummary);
router.get("/earnings/history", validateBearerToken, getDriverEarningsHistory);

module.exports = router;
