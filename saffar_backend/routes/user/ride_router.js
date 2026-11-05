const express = require("express");
const {
  getPreviousRidesOfUser,
  addRideAndRideAddresses,
  cancelRide,
  getPriceInfoAndCalculateRidePrice,
  findRideDriver,
  getRideOptions,
  rebookRide,
  rateRideDriver,
  getRideReviewDetails,
  searchPlaces,
  getSavedAndRecentPlaces,
  getUserRideOtp,
  getRideStatus,
  getNearbyVehicleAvailability,
  getActiveRideForUser,
  getRouteBetweenPoints,
  reverseGeocodeLocation,
} = require("../../controllers/rideController");
const { validateBearerToken } = require("../../middlewares/token_middleware");

const router = express.Router();

router.get("/active_ride", validateBearerToken, getActiveRideForUser);
router.get("/route", validateBearerToken, getRouteBetweenPoints);
router.get("/geocode/reverse", validateBearerToken, reverseGeocodeLocation);
router.get("/nearby_availability", validateBearerToken, getNearbyVehicleAvailability);
router.get("/nearby_categories", validateBearerToken, getNearbyVehicleAvailability);
router.get("/previous_rides", validateBearerToken, getPreviousRidesOfUser);
router.get("/search_places", validateBearerToken, searchPlaces);
router.get("/saved_places", validateBearerToken, getSavedAndRecentPlaces);
router.get("/:rideId/otp", validateBearerToken, getUserRideOtp);
router.get("/:rideId/status", validateBearerToken, getRideStatus);
router.post("/add_ride", validateBearerToken, addRideAndRideAddresses);
router.post("/cancel", validateBearerToken, cancelRide);
router.get("/total_price", validateBearerToken, getPriceInfoAndCalculateRidePrice);
router.get("/find_ride_driver", validateBearerToken, findRideDriver);
router.get("/ride_options", validateBearerToken, getRideOptions);
router.post("/rebook", validateBearerToken, rebookRide);
router.post("/rate_driver", validateBearerToken, rateRideDriver);
router.get("/review_details", validateBearerToken, getRideReviewDetails);

module.exports = router;

