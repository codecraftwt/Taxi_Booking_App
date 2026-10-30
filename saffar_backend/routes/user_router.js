const express = require("express");
const { getUserInfo, updateUserInfo } = require("../controllers/userController");
const { validateBearerToken } = require("../middlewares/token_middleware");

const router = express.Router();

router.get("/", validateBearerToken, getUserInfo);
router.patch("/", validateBearerToken, updateUserInfo);

module.exports = router;
