require("../../config/polyfill");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const config = require("../../config");
const Constant = require("../../config/constants");
const Err = require("../../config/error");
const { query } = require("../../database");
const Validator = require("../../utils/validator");

const signUp = async (req, res) => {
  try {
    const { name, phone, password, email } = req.body;
    const trimmedEmail = email && typeof email === 'string' && email.trim().length > 0 ? email.trim().toLowerCase() : null;

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

    // Check if email is provided and already taken
    if (trimmedEmail) {
      const existingEmail = await query("SELECT id FROM users WHERE email = $1", [trimmedEmail]);
      if (existingEmail.rows.length > 0) {
        return res.status(409).json({
          error: {
            code: "EMAIL_ALREADY_EXISTS",
            message: "A user with this email address already exists.",
          },
        });
      }
    }

    const hashedPassword = await bcrypt.hash(password, Constant.saltRounds);
    const id = uuidv4();

    await query(
      "INSERT INTO users (id, name, phone, password, email) VALUES ($1, $2, $3, $4, $5)",
      [id, name, phone, hashedPassword, trimmedEmail]
    );

    const tokenSecret = config.TOKEN_SECRET_KEY;
    const token = jwt.sign(
      { id: id, phone: phone, role: "user" },
      tokenSecret,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Signed up and created user successfully",
      user: {
        id: id,
        name: name,
        phone: phone,
        email: trimmedEmail,
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
      { id: user.id, phone: user.phone, role: "user" },
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
    const {
      name,
      phone,
      password,
      vehicle_name: vehicleName,
      vehicle_number: vehicleNumber,
      vehicle_model: vehicleModel,
      email,
    } = req.body;

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
    const cleanEmail = email && typeof email === "string" && email.trim().length > 0 ? email.trim().toLowerCase() : null;
    const cleanModel = vehicleModel && typeof vehicleModel === "string" ? vehicleModel.trim() : null;

    const insertRes = await query(
      `INSERT INTO drivers (id, name, phone, password, vehicle_name, vehicle_model, vehicle_number, email, active, verification_status)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true, 'Approved')
       RETURNING id, name, phone, email, age, gender, address, vehicle_name, vehicle_model, vehicle_number, image_url, active, verification_status, created_at`,
      [id, name, phone, hashedPassword, vehicleName, cleanModel, vehicleNumber, cleanEmail]
    );

    const tokenSecret = config.TOKEN_SECRET_KEY;
    const token = jwt.sign(
      { id: id, phone: phone, role: "driver" },
      tokenSecret,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Signed up and created driver successfully",
      driver: insertRes.rows[0],
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
      { id: driver.id, phone: driver.phone, role: "driver" },
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
        age: driver.age,
        gender: driver.gender,
        address: driver.address,
        image_url: driver.image_url,
        active: driver.active,
        verification_status: driver.verification_status || "Approved",
        vehicle_name: driver.vehicle_name,
        vehicle_model: driver.vehicle_model,
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

const driverForgotPassword = async (req, res) => {
  try {
    const { phone, email, identifier: customId } = req.body;
    const identifier = (phone || email || customId || "").toString().trim();

    if (!identifier) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "Please provide a registered mobile number or email address.",
        },
      });
    }

    const stripped = identifier.replace(/^\+91\s*/, "").replace(/\s+/g, "");

    // Lookup driver in PostgreSQL
    const driverRes = await query(
      "SELECT id, name, phone, email FROM drivers WHERE phone = $1 OR phone = $2 OR email = $1 OR LOWER(email) = LOWER($1) LIMIT 1",
      [identifier, stripped]
    );

    if (driverRes.rows.length === 0) {
      return res.status(404).json({
        error: {
          code: "DRIVER_NOT_FOUND",
          message: `No driver account found matching "${identifier}". Please check the phone number.`,
        },
      });
    }

    const driver = driverRes.rows[0];
    const resetToken = jwt.sign(
      { id: driver.id, phone: driver.phone, role: "driver", action: "password_reset" },
      config.TOKEN_SECRET_KEY,
      { expiresIn: "15m" }
    );

    return res.status(200).json({
      message: `Driver account verified for ${driver.name || driver.phone}. Proceed to set your new password.`,
      phone: driver.phone,
      email: driver.email,
      reset_token: resetToken,
      expires_in_mins: 15,
    });
  } catch (error) {
    console.error(`Error in driverForgotPassword: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to process driver password recovery.",
      },
    });
  }
};

const driverResetPassword = async (req, res) => {
  try {
    const { phone, email, identifier, new_password, reset_token } = req.body;
    const target = (phone || email || identifier || "").toString().trim();

    if (!target || !new_password) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "Registered phone and new password are required.",
        },
      });
    }

    if (new_password.length < 8) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PASSWORD,
          message: "Password must be at least 8 characters.",
        },
      });
    }

    if (reset_token) {
      try {
        const decoded = jwt.verify(reset_token, config.TOKEN_SECRET_KEY);
        if (decoded.action !== "password_reset" || decoded.role !== "driver") {
          return res.status(400).json({
            error: {
              code: "INVALID_RESET_TOKEN",
              message: "Invalid or unauthorized reset token for driver account.",
            },
          });
        }
      } catch (tokErr) {
        return res.status(400).json({
          error: {
            code: "EXPIRED_RESET_TOKEN",
            message: "Reset token has expired. Please request password recovery again.",
          },
        });
      }
    }

    const stripped = target.replace(/^\+91\s*/, "").replace(/\s+/g, "");
    const hashedPassword = await bcrypt.hash(new_password, Constant.saltRounds);

    const updateRes = await query(
      `UPDATE drivers 
       SET password = $1 
       WHERE phone = $2 OR phone = $3 OR email = $2 OR LOWER(email) = LOWER($2) 
       RETURNING id, name, phone, email, age, gender, address, vehicle_name, vehicle_model, vehicle_number, image_url, active, COALESCE(verification_status, 'Approved') as verification_status, created_at`,
      [hashedPassword, target, stripped]
    );

    if (updateRes.rows.length === 0) {
      return res.status(404).json({
        error: {
          code: "DRIVER_NOT_FOUND",
          message: `No driver account found with phone number "${target}".`,
        },
      });
    }

    const driver = updateRes.rows[0];

    const token = jwt.sign(
      { id: driver.id, phone: driver.phone, role: "driver" },
      config.TOKEN_SECRET_KEY,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Driver password reset successfully. You are now logged in.",
      driver: driver,
      token: token,
    });
  } catch (error) {
    console.error(`Error in driverResetPassword: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to reset driver password.",
      },
    });
  }
};

const forgotPassword = async (req, res) => {
  try {
    const { phone, email, identifier: customId, channel } = req.body;
    const identifier = (phone || email || customId || "").toString().trim();

    if (!identifier) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "Please provide a registered mobile number or email address.",
        },
      });
    }

    const stripped = identifier.replace(/^\+91\s*/, "").replace(/\s+/g, "");

    // Lookup user in PostgreSQL
    const userRes = await query(
      "SELECT id, name, phone, email FROM users WHERE phone = $1 OR phone = $2 OR email = $1 OR LOWER(email) = LOWER($1) LIMIT 1",
      [identifier, stripped]
    );

    if (userRes.rows.length === 0) {
      return res.status(404).json({
        error: {
          code: "USER_NOT_FOUND",
          message: `No account found matching "${identifier}". Please check the phone number or email.`,
        },
      });
    }

    const user = userRes.rows[0];
    const resetToken = jwt.sign(
      { id: user.id, phone: user.phone, action: "password_reset" },
      config.TOKEN_SECRET_KEY,
      { expiresIn: "15m" }
    );

    return res.status(200).json({
      message: `Account verified for ${user.name || user.phone || user.email}. Proceed to set your new password.`,
      phone: user.phone,
      email: user.email,
      reset_token: resetToken,
      expires_in_mins: 15,
    });
  } catch (error) {
    console.error(`Error in forgotPassword: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to process password recovery request.",
      },
    });
  }
};

const resetPassword = async (req, res) => {
  try {
    const { phone, email, identifier, new_password, logout_all_sessions } = req.body;
    const target = (phone || email || identifier || "").toString().trim();

    if (!target || !new_password) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "Account phone/email and new password are required.",
        },
      });
    }

    if (new_password.length < 8) {
      return res.status(400).json({
        error: {
          code: Err.code.INVALID_PASSWORD,
          message: "Password must be at least 8 characters.",
        },
      });
    }

    const stripped = target.replace(/^\+91\s*/, "").replace(/\s+/g, "");
    const hashedPassword = await bcrypt.hash(new_password, Constant.saltRounds);

    const updateRes = await query(
      `UPDATE users 
       SET password = $1 
       WHERE phone = $2 OR phone = $3 OR email = $2 OR LOWER(email) = LOWER($2) 
       RETURNING id, name, phone, email, image_url`,
      [hashedPassword, target, stripped]
    );

    if (updateRes.rows.length === 0) {
      return res.status(404).json({
        error: {
          code: "USER_NOT_FOUND",
          message: `No account found with phone number or email "${target}".`,
        },
      });
    }

    const user = updateRes.rows[0];

    // Issue a fresh JWT token to immediately log in
    const token = jwt.sign(
      { id: user.id, phone: user.phone },
      config.TOKEN_SECRET_KEY,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Password reset successfully. You are now logged in.",
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        image_url: user.image_url,
      },
      token: token,
      logout_all_sessions: !!logout_all_sessions,
    });
  } catch (error) {
    console.error(`Error in resetPassword: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to reset password.",
      },
    });
  }
};

module.exports = {
  signUp,
  signIn,
  driverSignUp,
  driverSignIn,
  forgotPassword,
  resetPassword,
  driverForgotPassword,
  driverResetPassword,
};
