const express = require("express");
const { 
  getUserInfo, 
  updateUserInfo, 
  createSupportTicket,
  addMoneyToWallet,
  getSavedPlaces,
  addSavedPlace
} = require("../../controllers/userController");
const { validateUserToken } = require("../../middlewares/token_middleware");

const router = express.Router();

router.get("/", validateUserToken, getUserInfo);
router.patch("/", validateUserToken, updateUserInfo);
router.post("/wallet/add", validateUserToken, addMoneyToWallet);
router.get("/saved_places", validateUserToken, getSavedPlaces);
router.post("/saved_places", validateUserToken, addSavedPlace);
router.post("/support_ticket", validateUserToken, createSupportTicket);

module.exports = router;
