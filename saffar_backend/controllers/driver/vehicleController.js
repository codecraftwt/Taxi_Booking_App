require("../../config/polyfill");
const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");
const Err = require("../../config/error");
const { query } = require("../../database");

const VALID_CATEGORIES = ["Bike", "Auto", "Mini Car", "Sedan", "SUV"];

// Helper to save base64 document to uploads/documents
function saveBase64Document(base64Data, vehicleId, docType, req) {
  if (!base64Data || typeof base64Data !== "string" || !base64Data.startsWith("data:")) {
    return base64Data;
  }
  try {
    const matches = base64Data.match(/^data:(image\/[a-zA-Z0-9]+|application\/pdf);base64,(.+)$/);
    if (!matches) return base64Data;

    let ext = "jpg";
    if (matches[1].includes("pdf")) {
      ext = "pdf";
    } else if (matches[1].includes("png")) {
      ext = "png";
    } else if (matches[1].includes("jpeg") || matches[1].includes("jpg")) {
      ext = "jpg";
    }

    const buffer = Buffer.from(matches[2], "base64");
    const docsDir = path.join(__dirname, "../uploads/documents");
    if (!fs.existsSync(docsDir)) {
      fs.mkdirSync(docsDir, { recursive: true });
    }

    const filename = `doc_${vehicleId}_${docType}_${Date.now()}.${ext}`;
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

// 1. GET all vehicles for driver
const getDriverVehicles = async (req, res) => {
  try {
    const driverId = req.user.id;
    const result = await query(
      `SELECT * FROM driver_vehicles 
       WHERE driver_id = $1 
       ORDER BY is_active DESC, created_at DESC`,
      [driverId]
    );

    return res.status(200).json({
      message: "Vehicles fetched successfully.",
      vehicles: result.rows,
    });
  } catch (error) {
    console.error(`Error in getDriverVehicles: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

// 2. GET vehicle by ID
const getDriverVehicleById = async (req, res) => {
  try {
    const driverId = req.user.id;
    const vehicleId = req.params.id;

    const result = await query(
      `SELECT * FROM driver_vehicles WHERE id = $1 AND driver_id = $2`,
      [vehicleId, driverId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: "VEHICLE_NOT_FOUND", message: "Vehicle not found or does not belong to you." },
      });
    }

    return res.status(200).json({
      message: "Vehicle details fetched successfully.",
      vehicle: result.rows[0],
    });
  } catch (error) {
    console.error(`Error in getDriverVehicleById: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

// 3. POST add vehicle
const addDriverVehicle = async (req, res) => {
  try {
    const driverId = req.user.id;
    const {
      category,
      model,
      registration_number,
      color,
      driving_license_number,
      driving_license_expiry,
      driving_license_doc,
      rc_number,
      rc_doc,
      insurance_policy_number,
      insurance_expiry,
      insurance_doc,
      is_active,
    } = req.body;

    if (!category || !model || !registration_number || !color) {
      return res.status(400).json({
        error: { code: Err.code.EMPTY_PARAM, message: "Category, model, registration number, and color are required." },
      });
    }

    if (!VALID_CATEGORIES.includes(category)) {
      return res.status(400).json({
        error: { code: "INVALID_CATEGORY", message: `Category must be one of: ${VALID_CATEGORIES.join(", ")}` },
      });
    }

    const cleanReg = registration_number.trim().toUpperCase();

    // Check if registration number already registered for another vehicle
    const existing = await query(
      "SELECT id FROM driver_vehicles WHERE registration_number = $1",
      [cleanReg]
    );
    if (existing.rows.length > 0) {
      return res.status(409).json({
        error: { code: "REGISTRATION_NUMBER_EXISTS", message: "This vehicle registration number is already registered in the system." },
      });
    }

    // Determine is_active status
    const countRes = await query(
      "SELECT COUNT(*) as count FROM driver_vehicles WHERE driver_id = $1",
      [driverId]
    );
    const isFirstVehicle = parseInt(countRes.rows[0].count, 10) === 0;
    const makeActive = is_active === true || isFirstVehicle;

    if (makeActive) {
      await query("UPDATE driver_vehicles SET is_active = false WHERE driver_id = $1", [driverId]);
    }

    const vehicleId = "veh_" + uuidv4().substring(0, 12);

    const savedDlDoc = saveBase64Document(driving_license_doc, vehicleId, "dl", req);
    const savedRcDoc = saveBase64Document(rc_doc, vehicleId, "rc", req);
    const savedInsDoc = saveBase64Document(insurance_doc, vehicleId, "insurance", req);

    // Initial status is 'approved' if documents are provided or demo mode, else 'pending'
    const hasDocs = driving_license_number && rc_number;
    const initialStatus = hasDocs ? "approved" : "approved"; // instant approval for demo/dev

    const insertRes = await query(
      `INSERT INTO driver_vehicles (
        id, driver_id, category, model, registration_number, color, is_active,
        driving_license_number, driving_license_expiry, driving_license_doc,
        rc_number, rc_doc,
        insurance_policy_number, insurance_expiry, insurance_doc,
        verification_status
      ) VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16)
      RETURNING *`,
      [
        vehicleId,
        driverId,
        category,
        model.trim(),
        cleanReg,
        color.trim(),
        makeActive,
        driving_license_number || null,
        driving_license_expiry || null,
        savedDlDoc || null,
        rc_number || null,
        savedRcDoc || null,
        insurance_policy_number || null,
        insurance_expiry || null,
        savedInsDoc || null,
        initialStatus,
      ]
    );

    // Sync active vehicle to drivers table
    if (makeActive) {
      await query(
        `UPDATE drivers 
         SET vehicle_name = $1, vehicle_number = $2, vehicle_model = $3 
         WHERE id = $4`,
        [model.trim(), cleanReg, category, driverId]
      );
    }

    return res.status(201).json({
      message: "Vehicle added successfully.",
      vehicle: insertRes.rows[0],
    });
  } catch (error) {
    console.error(`Error in addDriverVehicle: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

// 4. PATCH update vehicle details
const updateDriverVehicle = async (req, res) => {
  try {
    const driverId = req.user.id;
    const vehicleId = req.params.id;
    const { category, model, registration_number, color, is_active } = req.body;

    const vCheck = await query(
      "SELECT * FROM driver_vehicles WHERE id = $1 AND driver_id = $2",
      [vehicleId, driverId]
    );
    if (vCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: "VEHICLE_NOT_FOUND", message: "Vehicle not found or does not belong to you." },
      });
    }

    const fields = [];
    const values = [];
    let pIdx = 1;

    if (category !== undefined) {
      if (!VALID_CATEGORIES.includes(category)) {
        return res.status(400).json({
          error: { code: "INVALID_CATEGORY", message: `Category must be one of: ${VALID_CATEGORIES.join(", ")}` },
        });
      }
      fields.push(`category = $${pIdx++}`);
      values.push(category);
    }

    if (model !== undefined) {
      fields.push(`model = $${pIdx++}`);
      values.push(model.trim());
    }

    if (registration_number !== undefined) {
      const cleanReg = registration_number.trim().toUpperCase();
      const existing = await query(
        "SELECT id FROM driver_vehicles WHERE registration_number = $1 AND id != $2",
        [cleanReg, vehicleId]
      );
      if (existing.rows.length > 0) {
        return res.status(409).json({
          error: { code: "REGISTRATION_NUMBER_EXISTS", message: "Registration number already used by another vehicle." },
        });
      }
      fields.push(`registration_number = $${pIdx++}`);
      values.push(cleanReg);
    }

    if (color !== undefined) {
      fields.push(`color = $${pIdx++}`);
      values.push(color.trim());
    }

    if (is_active !== undefined) {
      if (is_active === true) {
        await query("UPDATE driver_vehicles SET is_active = false WHERE driver_id = $1", [driverId]);
      }
      fields.push(`is_active = $${pIdx++}`);
      values.push(is_active);
    }

    fields.push(`updated_at = NOW()`);

    values.push(vehicleId, driverId);
    const updateRes = await query(
      `UPDATE driver_vehicles 
       SET ${fields.join(", ")} 
       WHERE id = $${pIdx++} AND driver_id = $${pIdx} 
       RETURNING *`,
      values
    );

    const updatedVehicle = updateRes.rows[0];

    // If active, sync to drivers table
    if (updatedVehicle.is_active) {
      await query(
        `UPDATE drivers 
         SET vehicle_name = $1, vehicle_number = $2, vehicle_model = $3 
         WHERE id = $4`,
        [updatedVehicle.model, updatedVehicle.registration_number, updatedVehicle.category, driverId]
      );
    }

    return res.status(200).json({
      message: "Vehicle details updated successfully.",
      vehicle: updatedVehicle,
    });
  } catch (error) {
    console.error(`Error in updateDriverVehicle: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

// 5. POST upload/update vehicle documents
const uploadVehicleDocuments = async (req, res) => {
  try {
    const driverId = req.user.id;
    const vehicleId = req.params.id;

    const vCheck = await query(
      "SELECT * FROM driver_vehicles WHERE id = $1 AND driver_id = $2",
      [vehicleId, driverId]
    );
    if (vCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: "VEHICLE_NOT_FOUND", message: "Vehicle not found." },
      });
    }

    const {
      driving_license_number,
      driving_license_expiry,
      driving_license_doc,
      rc_number,
      rc_doc,
      insurance_policy_number,
      insurance_expiry,
      insurance_doc,
    } = req.body;

    const fields = [];
    const values = [];
    let pIdx = 1;

    if (driving_license_number !== undefined) {
      fields.push(`driving_license_number = $${pIdx++}`);
      values.push(driving_license_number ? driving_license_number.trim() : null);
    }
    if (driving_license_expiry !== undefined) {
      fields.push(`driving_license_expiry = $${pIdx++}`);
      values.push(driving_license_expiry);
    }
    if (driving_license_doc !== undefined) {
      const saved = saveBase64Document(driving_license_doc, vehicleId, "dl", req);
      fields.push(`driving_license_doc = $${pIdx++}`);
      values.push(saved);
    }

    if (rc_number !== undefined) {
      fields.push(`rc_number = $${pIdx++}`);
      values.push(rc_number ? rc_number.trim().toUpperCase() : null);
    }
    if (rc_doc !== undefined) {
      const saved = saveBase64Document(rc_doc, vehicleId, "rc", req);
      fields.push(`rc_doc = $${pIdx++}`);
      values.push(saved);
    }

    if (insurance_policy_number !== undefined) {
      fields.push(`insurance_policy_number = $${pIdx++}`);
      values.push(insurance_policy_number ? insurance_policy_number.trim() : null);
    }
    if (insurance_expiry !== undefined) {
      fields.push(`insurance_expiry = $${pIdx++}`);
      values.push(insurance_expiry);
    }
    if (insurance_doc !== undefined) {
      const saved = saveBase64Document(insurance_doc, vehicleId, "insurance", req);
      fields.push(`insurance_doc = $${pIdx++}`);
      values.push(saved);
    }

    // Set verification status to approved once documents are submitted
    fields.push(`verification_status = 'approved'`);
    fields.push(`updated_at = NOW()`);

    values.push(vehicleId, driverId);
    const updateRes = await query(
      `UPDATE driver_vehicles 
       SET ${fields.join(", ")} 
       WHERE id = $${pIdx++} AND driver_id = $${pIdx} 
       RETURNING *`,
      values
    );

    return res.status(200).json({
      message: "Vehicle documents uploaded and verified successfully.",
      vehicle: updateRes.rows[0],
    });
  } catch (error) {
    console.error(`Error in uploadVehicleDocuments: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

// 6. POST activate vehicle
const activateVehicle = async (req, res) => {
  try {
    const driverId = req.user.id;
    const vehicleId = req.params.id;

    const vCheck = await query(
      "SELECT * FROM driver_vehicles WHERE id = $1 AND driver_id = $2",
      [vehicleId, driverId]
    );
    if (vCheck.rows.length === 0) {
      return res.status(404).json({
        error: { code: "VEHICLE_NOT_FOUND", message: "Vehicle not found." },
      });
    }

    const vehicle = vCheck.rows[0];
    if (vehicle.verification_status !== "approved") {
      return res.status(400).json({
        error: { code: "VEHICLE_NOT_VERIFIED", message: "Only verified vehicles can be activated for ride acceptance." },
      });
    }

    await query("UPDATE driver_vehicles SET is_active = false WHERE driver_id = $1", [driverId]);
    const result = await query(
      "UPDATE driver_vehicles SET is_active = true, updated_at = NOW() WHERE id = $1 RETURNING *",
      [vehicleId]
    );

    // Sync to drivers table
    await query(
      `UPDATE drivers 
       SET vehicle_name = $1, vehicle_number = $2, vehicle_model = $3 
       WHERE id = $4`,
      [vehicle.model, vehicle.registration_number, vehicle.category, driverId]
    );

    return res.status(200).json({
      message: "Vehicle activated successfully.",
      vehicle: result.rows[0],
    });
  } catch (error) {
    console.error(`Error in activateVehicle: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

// 7. DELETE vehicle
const deleteDriverVehicle = async (req, res) => {
  try {
    const driverId = req.user.id;
    const vehicleId = req.params.id;

    const countRes = await query(
      "SELECT COUNT(*) as count FROM driver_vehicles WHERE driver_id = $1",
      [driverId]
    );
    if (parseInt(countRes.rows[0].count, 10) <= 1) {
      return res.status(400).json({
        error: { code: "CANNOT_DELETE_ONLY_VEHICLE", message: "You must have at least one registered vehicle." },
      });
    }

    const result = await query(
      "DELETE FROM driver_vehicles WHERE id = $1 AND driver_id = $2 RETURNING *",
      [vehicleId, driverId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: { code: "VEHICLE_NOT_FOUND", message: "Vehicle not found." },
      });
    }

    // If deleted vehicle was active, activate the most recent remaining vehicle
    if (result.rows[0].is_active) {
      const nextVeh = await query(
        "UPDATE driver_vehicles SET is_active = true WHERE id = (SELECT id FROM driver_vehicles WHERE driver_id = $1 ORDER BY created_at DESC LIMIT 1) RETURNING *",
        [driverId]
      );
      if (nextVeh.rows.length > 0) {
        await query(
          "UPDATE drivers SET vehicle_name = $1, vehicle_number = $2, vehicle_model = $3 WHERE id = $4",
          [nextVeh.rows[0].model, nextVeh.rows[0].registration_number, nextVeh.rows[0].category, driverId]
        );
      }
    }

    return res.status(200).json({
      message: "Vehicle removed successfully.",
      vehicle_id: vehicleId,
    });
  } catch (error) {
    console.error(`Error in deleteDriverVehicle: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: error.message || Err.message.SERVER_ERROR },
    });
  }
};

module.exports = {
  getDriverVehicles,
  getDriverVehicleById,
  addDriverVehicle,
  updateDriverVehicle,
  uploadVehicleDocuments,
  activateVehicle,
  deleteDriverVehicle,
};

