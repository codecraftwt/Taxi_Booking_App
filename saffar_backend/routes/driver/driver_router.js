const express = require("express");
const {
  getDriverProfile,
  updateDriverProfile,
  uploadDriverPhoto,
  toggleAvailability,
  updateDriverLocation,
  getDriverStatus,
  getDriverRideHistory,
  getDriverEarningsSummary,
  getDriverEarningsHistory,
  getDriverTripEarningDetails,
  completeRide,
  cancelDriverRide,
  getDriverCancellationHistory,
  getDriverDashboardStats,
  getDriverTripDetails,
  getActiveTripForDriver,
} = require("../../controllers/driverController");
const {
  getDriverVehicles,
  getDriverVehicleById,
  addDriverVehicle,
  updateDriverVehicle,
  uploadVehicleDocuments,
  activateVehicle,
  deleteDriverVehicle,
} = require("../../controllers/vehicleController");
const {
  getPendingRequestsForDriver,
  acceptRideRequest,
  rejectRideRequest,
  getAssignedBookingDetails,
  markReachingPickup,
  markDriverArrived,
  verifyRideStartOtp,
} = require("../../controllers/rideRequestController");
const { validateDriverToken } = require("../../middlewares/token_middleware");
const { getPublicFareConfigs } = require("../../controllers/shared/authController");

const router = express.Router();

// Vehicle pricing decided by Super Admin (public/pre-login for registration)
router.get("/fares", getPublicFareConfigs);

// Driver profile & photo
router.get("/profile", validateDriverToken, getDriverProfile);
router.patch("/profile", validateDriverToken, updateDriverProfile);
router.post("/photo", validateDriverToken, uploadDriverPhoto);

// Driver Vehicles Management
router.get("/vehicles", validateDriverToken, getDriverVehicles);
router.post("/vehicles", validateDriverToken, addDriverVehicle);
router.get("/vehicles/:id", validateDriverToken, getDriverVehicleById);
router.patch("/vehicles/:id", validateDriverToken, updateDriverVehicle);
router.post("/vehicles/:id/documents", validateDriverToken, uploadVehicleDocuments);
router.post("/vehicles/:id/activate", validateDriverToken, activateVehicle);
router.delete("/vehicles/:id", validateDriverToken, deleteDriverVehicle);

// Driver availability & location
router.get("/active_trip", validateDriverToken, getActiveTripForDriver);
router.post("/availability", validateDriverToken, toggleAvailability);
router.post("/toggle_availability", validateDriverToken, toggleAvailability);
router.post("/location", validateDriverToken, updateDriverLocation);
router.get("/status", validateDriverToken, getDriverStatus);

// Driver dashboard
router.get("/dashboard", validateDriverToken, getDriverDashboardStats);

// Driver rides & request management
router.get("/rides/pending_requests", validateDriverToken, getPendingRequestsForDriver);
router.post("/rides/:rideId/accept", validateDriverToken, acceptRideRequest);
router.post("/rides/:rideId/reject", validateDriverToken, rejectRideRequest);
router.get("/rides/:rideId/assigned", validateDriverToken, getAssignedBookingDetails);
router.post("/rides/:rideId/reaching", validateDriverToken, markReachingPickup);
router.post("/rides/:rideId/arrive", validateDriverToken, markDriverArrived);
router.post("/rides/:rideId/verify_otp_start", validateDriverToken, verifyRideStartOtp);
router.get("/rides/history", validateDriverToken, getDriverRideHistory);
router.get("/rides/:rideId/details", validateDriverToken, getDriverTripDetails);
router.post("/rides/:rideId/complete", validateDriverToken, completeRide);
router.post("/rides/:rideId/cancel", validateDriverToken, cancelDriverRide);
router.get("/rides/cancellations", validateDriverToken, getDriverCancellationHistory);

// Driver earnings
router.get("/earnings/summary", validateDriverToken, getDriverEarningsSummary);
router.get("/earnings/history", validateDriverToken, getDriverEarningsHistory);
router.get("/earnings/:rideId", validateDriverToken, getDriverTripEarningDetails);

module.exports = router;
