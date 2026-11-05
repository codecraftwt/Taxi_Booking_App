require("../config/polyfill");
const jwt = require("jsonwebtoken");
const config = require("../config");
const Err = require("../config/error");

const validateBearerToken = (req, res, next) => {
  const bearerToken = req.headers.authorization;

  if (!bearerToken) {
    return res.status(400).json({
      error: {
        code: Err.code.AUTHORIZATION_HEADER_MISSING,
        message: Err.message.AUTHORIZATION_HEADER_MISSING,
      },
    });
  }

  const arr = bearerToken.split(" ");
  if (arr.length < 2 || arr[0] !== "Bearer") {
    return res.status(400).json({
      error: {
        code: Err.code.INCORRECT_BEARER_TOKEN_FORMAT,
        message: Err.message.INCORRECT_BEARER_TOKEN_FORMAT,
      },
    });
  }

  const token = arr[1];
  const secret = config.TOKEN_SECRET_KEY;

  try {
    const decoded = jwt.verify(token, secret);
    req.user = decoded;
    if (next) {
      return next();
    }
  } catch (error) {
    return res.status(400).json({
      error: {
        code: Err.code.INVALID_BEARER_TOKEN,
        message: Err.message.INVALID_BEARER_TOKEN,
      },
    });
  }
};

const validateDriverToken = (req, res, next) => {
  validateBearerToken(req, res, () => {
    // If role is explicitly specified, enforce it
    if (req.user && req.user.role && req.user.role !== "driver") {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN_ROLE",
          message: "Access denied. Only registered drivers can access this endpoint.",
        },
      });
    }
    return next();
  });
};

const validateUserToken = (req, res, next) => {
  validateBearerToken(req, res, () => {
    if (req.user && req.user.role && req.user.role !== "user") {
      return res.status(403).json({
        error: {
          code: "FORBIDDEN_ROLE",
          message: "Access denied. Only passenger accounts can access this endpoint.",
        },
      });
    }
    return next();
  });
};

module.exports = {
  validateBearerToken,
  validateDriverToken,
  validateUserToken,
};
