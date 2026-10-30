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

module.exports = {
  validateBearerToken,
};
