const express = require("express");
const {
  getPreviousRidesOfUser,
  addRideAndRideAddresses,
  getPriceInfoAndCalculateRidePrice,
  findRideDriver,
} = require("../controllers/rideController");
const { validateBearerToken } = require("../middlewares/token_middleware");

const router = express.Router();

router.get("/previous_rides", validateBearerToken, getPreviousRidesOfUser);
router.post("/add_ride", validateBearerToken, addRideAndRideAddresses);
router.get("/total_price", validateBearerToken, getPriceInfoAndCalculateRidePrice);
router.get("/find_ride_driver", validateBearerToken, findRideDriver);

module.exports = router;

