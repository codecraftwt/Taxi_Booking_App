require("../../config/polyfill");
const fs = require("fs");
const path = require("path");
const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const { v4: uuidv4 } = require("uuid");
const config = require("../../config");
const Constant = require("../../config/constants");
const Err = require("../../config/error");
const { query } = require("../../database");
const Validator = require("../../utils/validator");

function saveDocumentHelper(base64Data, driverId, docType, req) {
  if (!base64Data || typeof base64Data !== "string") return null;
  if (!base64Data.startsWith("data:")) return base64Data; // Already URL or plain path

  try {
    const matches = base64Data.match(/^data:([A-Za-z-+\/]+);base64,(.+)$/);
    if (!matches || matches.length !== 3) return base64Data;

    let ext = "jpg";
    if (matches[1].includes("pdf")) ext = "pdf";
    else if (matches[1].includes("png")) ext = "png";
    else if (matches[1].includes("jpeg") || matches[1].includes("jpg")) ext = "jpg";

    const buffer = Buffer.from(matches[2], "base64");
    const docsDir = path.join(__dirname, "../../uploads/documents");
    if (!fs.existsSync(docsDir)) {
      fs.mkdirSync(docsDir, { recursive: true });
    }

    const filename = `doc_${driverId}_${docType}_${Date.now()}.${ext}`;
    const filePath = path.join(docsDir, filename);
    fs.writeFileSync(filePath, buffer);

    const host = req.get("host") || "localhost:5000";
    const protocol = req.protocol || "http";
    return `${protocol}://${host}/uploads/documents/${filename}`;
  } catch (err) {
    console.error("Error saving document file:", err);
    return base64Data;
  }
}

const getPublicFareConfigs = async (req, res) => {
  try {
    const fareRes = await query(
      "SELECT category, base_fare, per_km, per_minute, minimum_fare, booking_fee, commission_percentage, surge_multiplier FROM fare_configs WHERE is_active = true ORDER BY base_fare ASC"
    );
    return res.status(200).json({
      success: true,
      fares: fareRes.rows,
    });
  } catch (error) {
    console.error("Error in getPublicFareConfigs:", error);
    return res.status(500).json({ success: false, message: "Failed to fetch vehicle fare configurations" });
  }
};

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
      vehicle_category: vehicleCategory,
      email,
      // Document fields from multi-step registration
      driving_license_number: dlNumber,
      driving_license_expiry: dlExpiry,
      driving_license_doc: dlDoc,
      rc_number: rcNumber,
      rc_doc: rcDoc,
      insurance_policy_number: insuranceNumber,
      insurance_expiry: insuranceExpiry,
      insurance_doc: insuranceDoc,
      aadhaar_number: aadhaarNumber,
      aadhaar_doc: aadhaarDoc,
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
    const category = vehicleCategory || vehicleName || "Auto";
    const vehicleColor = req.body.vehicle_color || (category === "Auto" ? "Yellow & Black" : "Standard");

    // Process & store document files safely
    const dlUrl = saveDocumentHelper(dlDoc, id, "dl", req);
    const rcUrl = saveDocumentHelper(rcDoc, id, "rc", req);
    const insUrl = saveDocumentHelper(insuranceDoc, id, "ins", req);
    const adhUrl = saveDocumentHelper(aadhaarDoc, id, "adh", req);

    // Initial driver account created in 'pending' status - Super Admin approval is mandatory
    const insertRes = await query(
      `INSERT INTO drivers (
        id, name, phone, password, vehicle_name, vehicle_model, vehicle_number, email, active, verification_status, is_online
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, false, 'pending', false)
      RETURNING id, name, phone, email, age, gender, address, vehicle_name, vehicle_model, vehicle_number, image_url, active, verification_status, created_at`,
      [id, name, phone, hashedPassword, vehicleName, cleanModel, vehicleNumber, cleanEmail]
    );

    // Register active vehicle record linked to driver
    const vehicleId = "veh_" + uuidv4().substring(0, 16);
    await query(
      `INSERT INTO driver_vehicles (
        id, driver_id, category, model, registration_number, color,
        driving_license_number, driving_license_expiry, driving_license_doc,
        rc_number, rc_doc,
        insurance_policy_number, insurance_expiry, insurance_doc,
        verification_status, is_active
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, 'pending', true)`,
      [
        vehicleId, id, category, cleanModel || vehicleName, vehicleNumber, vehicleColor,
        dlNumber || null, dlExpiry || null, dlUrl || null,
        rcNumber || vehicleNumber, rcUrl || null,
        insuranceNumber || null, insuranceExpiry || null, insUrl || null
      ]
    );

    // Insert driver_documents for Super Admin compliance inspection
    if (dlNumber || dlUrl) {
      await query(
        `INSERT INTO driver_documents (id, driver_id, vehicle_id, document_type, document_number, expiry_date, document_url, verification_status)
         VALUES ($1, $2, $3, 'driving_license', $4, $5, $6, 'pending')
         ON CONFLICT (driver_id, document_type) DO UPDATE
         SET document_number = EXCLUDED.document_number,
             expiry_date = EXCLUDED.expiry_date,
             document_url = EXCLUDED.document_url,
             verification_status = 'pending'`,
        ["doc_dl_" + uuidv4().substring(0, 16), id, vehicleId, dlNumber || null, dlExpiry || null, dlUrl || ""]
      );
    }

    if (rcNumber || rcUrl) {
      await query(
        `INSERT INTO driver_documents (id, driver_id, vehicle_id, document_type, document_number, document_url, verification_status)
         VALUES ($1, $2, $3, 'registration_certificate', $4, $5, 'pending')
         ON CONFLICT (driver_id, document_type) DO UPDATE
         SET document_number = EXCLUDED.document_number,
             document_url = EXCLUDED.document_url,
             verification_status = 'pending'`,
        ["doc_rc_" + uuidv4().substring(0, 16), id, vehicleId, rcNumber || vehicleNumber, rcUrl || ""]
      );
    }

    if (insuranceNumber || insUrl) {
      await query(
        `INSERT INTO driver_documents (id, driver_id, vehicle_id, document_type, document_number, expiry_date, document_url, verification_status)
         VALUES ($1, $2, $3, 'insurance', $4, $5, $6, 'pending')
         ON CONFLICT (driver_id, document_type) DO UPDATE
         SET document_number = EXCLUDED.document_number,
             expiry_date = EXCLUDED.expiry_date,
             document_url = EXCLUDED.document_url,
             verification_status = 'pending'`,
        ["doc_ins_" + uuidv4().substring(0, 16), id, vehicleId, insuranceNumber || null, insuranceExpiry || null, insUrl || ""]
      );
    }

    if (aadhaarNumber || adhUrl) {
      await query(
        `INSERT INTO driver_documents (id, driver_id, vehicle_id, document_type, document_number, document_url, verification_status)
         VALUES ($1, $2, $3, 'identity_card', $4, $5, 'pending')
         ON CONFLICT (driver_id, document_type) DO UPDATE
         SET document_number = EXCLUDED.document_number,
             document_url = EXCLUDED.document_url,
             verification_status = 'pending'`,
        ["doc_adh_" + uuidv4().substring(0, 16), id, vehicleId, aadhaarNumber || null, adhUrl || ""]
      );
    }

    const tokenSecret = config.TOKEN_SECRET_KEY;
    const token = jwt.sign(
      { id: id, phone: phone, role: "driver" },
      tokenSecret,
      { expiresIn: config.TOKEN_EXPIRY_TIME }
    );

    return res.status(200).json({
      message: "Signed up successfully. Account submitted for Super Admin approval.",
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
        verification_status: driver.verification_status || "pending",
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
       RETURNING id, name, phone, email, age, gender, address, vehicle_name, vehicle_model, vehicle_number, image_url, active, COALESCE(verification_status, 'pending') as verification_status, created_at`,
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
  getPublicFareConfigs,
};
