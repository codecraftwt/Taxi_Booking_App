require("../config/polyfill");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const config = require("../config");
const Constant = require("../config/constants");
const Err = require("../config/error");
const { query } = require("../database");
const Validator = require("../utils/validator");

const signUp = async (req, res) => {
  try {
    const { name, phone, password } = req.body;

    if (name === undefined || phone === undefined || password === undefined) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    if (!Validator.validateName(name)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_NAME,
          message: Err.message.INVALID_NAME,
        },
      });
    }

    if (!Validator.validatePhone(phone)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PHONE,
          message: Err.message.INVALID_PHONE,
        },
      });
    }

    if (!Validator.validatePassword(password)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PASSWORD,
          message: Err.message.INVALID_PASSWORD,
        },
      });
    }

    // Check if user with phone already exists in PostgreSQL
    const existing = await query("SELECT id FROM users WHERE phone = $1", [phone]);
    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: {
          code: Err.code.PHONE_ALREADY_EXISTS,
          message: Err.message.PHONE_ALREADY_EXISTS,
        },
      });
    }

    const hashedPassword = await bcrypt.hash(password, Constant.saltRounds);
    const id = uuidv4();

    await query(
      "INSERT INTO users (id, name, phone, password) VALUES ($1, $2, $3, $4)",
      [id, name, phone, hashedPassword]
    );

    const tokenSecret = config.TOKEN_SECRET_KEY;
    const token = jwt.sign(
      { id: id, phone: phone },
      tokenSecret,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Signed up and created user successfully",
      user: {
        id: id,
        name: name,
        phone: phone,
      },
      token: token,
    });
  } catch (error) {
    console.log(`Error in sign up: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const signIn = async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (phone === undefined || password === undefined) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    if (!Validator.validatePhone(phone)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PHONE,
          message: Err.message.INVALID_PHONE,
        },
      });
    }

    if (!Validator.validatePassword(password)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PASSWORD,
          message: Err.message.INVALID_PASSWORD,
        },
      });
    }

    const userRes = await query("SELECT * FROM users WHERE phone = $1", [phone]);
    if (userRes.rows.length === 0) {
      return res.status(400).json({
        error: {
          code: Err.code.NO_USER_WITH_PHONE,
          message: Err.message.NO_USER_WITH_PHONE,
        },
      });
    }

    const user = userRes.rows[0];
    const passwordCorrect = await bcrypt.compare(password, user.password);

    if (!passwordCorrect) {
      return res.status(400).json({
        error: {
          code: Err.code.WRONG_PASSWORD,
          message: Err.message.WRONG_PASSWORD,
        },
      });
    }

    const tokenSecret = config.TOKEN_SECRET_KEY;
    const token = jwt.sign(
      { id: user.id, phone: user.phone },
      tokenSecret,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "User signed in successfully",
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        image_url: user.image_url,
      },
      token: token,
    });
  } catch (error) {
    console.log(`Error in sign in: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const driverSignUp = async (req, res) => {
  try {
    const { name, phone, password, vehicle_name: vehicleName, vehicle_number: vehicleNumber } = req.body;

    if (
      name === undefined ||
      phone === undefined ||
      password === undefined ||
      vehicleName === undefined ||
      vehicleNumber === undefined
    ) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    if (!Validator.validateName(name)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_NAME,
          message: Err.message.INVALID_NAME,
        },
      });
    }

    if (!Validator.validatePhone(phone)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PHONE,
          message: Err.message.INVALID_PHONE,
        },
      });
    }

    if (!Validator.validatePassword(password)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PASSWORD,
          message: Err.message.INVALID_PASSWORD,
        },
      });
    }

    const existing = await query("SELECT id FROM drivers WHERE phone = $1", [phone]);
    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: {
          code: Err.code.PHONE_ALREADY_EXISTS,
          message: Err.message.PHONE_ALREADY_EXISTS,
        },
      });
    }

    const hashedPassword = await bcrypt.hash(password, Constant.saltRounds);
    const id = uuidv4();

    await query(
      `INSERT INTO drivers (id, name, phone, password, vehicle_name, vehicle_number, active)
       VALUES ($1, $2, $3, $4, $5, $6, true)`,
      [id, name, phone, hashedPassword, vehicleName, vehicleNumber]
    );

    const tokenSecret = config.TOKEN_SECRET_KEY;
    const token = jwt.sign(
      { id: id, phone: phone },
      tokenSecret,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Signed up and created driver successfully",
      driver: {
        id: id,
        name: name,
        phone: phone,
      },
      token: token,
    });
  } catch (error) {
    console.log(`Error in driver sign up: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const driverSignIn = async (req, res) => {
  try {
    const { phone, password } = req.body;

    if (phone === undefined || password === undefined) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    if (!Validator.validatePhone(phone)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PHONE,
          message: Err.message.INVALID_PHONE,
        },
      });
    }

    if (!Validator.validatePassword(password)) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PASSWORD,
          message: Err.message.INVALID_PASSWORD,
        },
      });
    }

    const driverRes = await query("SELECT * FROM drivers WHERE phone = $1", [phone]);
    if (driverRes.rows.length === 0) {
      return res.status(400).json({
        error: {
          code: Err.code.NO_DRIVER_WITH_PHONE,
          message: Err.message.NO_DRIVER_WITH_PHONE,
        },
      });
    }

    const driver = driverRes.rows[0];

    const passwordCorrect =
      (await bcrypt.compare(password, driver.password)) ||
      password === driver.password;

    if (!passwordCorrect) {
      return res.status(400).json({
        error: {
          code: Err.code.WRONG_PASSWORD,
          message: Err.message.WRONG_PASSWORD,
        },
      });
    }

    const tokenSecret = config.TOKEN_SECRET_KEY;
    const token = jwt.sign(
      { id: driver.id, phone: driver.phone },
      tokenSecret,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Driver signed in successfully",
      driver: {
        id: driver.id,
        name: driver.name,
        phone: driver.phone,
        email: driver.email,
        image_url: driver.image_url,
        active: driver.active,
        vehicle_name: driver.vehicle_name,
        vehicle_number: driver.vehicle_number,
      },
      token: token,
    });
  } catch (error) {
    console.log(`Error in driver sign in: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

module.exports = {
  signUp,
  signIn,
  driverSignUp,
  driverSignIn,
};
