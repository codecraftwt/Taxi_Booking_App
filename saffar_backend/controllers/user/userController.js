const fs = require("fs");
const path = require("path");
const { v4: uuidv4 } = require("uuid");
const Err = require("../../config/error");
const { query } = require("../../database");

const getUserInfo = async (req, res) => {
  try {
    const id = req.body?.id ?? req.query?.id ?? req.user?.id;

    if (!id) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: Err.message.EMPTY_PARAM,
        },
      });
    }

    const userRes = await query(
      `SELECT id, name, phone, email, image_url, address, 
              COALESCE(wallet_balance, 1240.0)::float as wallet_balance,
              created_at,
              TO_CHAR(created_at, 'FMMonth YYYY') as member_since
       FROM users WHERE id = $1`,
      [id]
    );

    if (userRes.rows.length === 0) {
      return res.status(400).json({
        error: {
          code: Err.code.NO_USER_WITH_ID,
          message: Err.message.NO_USER_WITH_ID,
        },
      });
    }

    const user = userRes.rows[0];

    // Compute live stats from database
    const ridesCountRes = await query(
      "SELECT COUNT(*)::int as count FROM rides WHERE user_id = $1 AND (cancelled = false OR cancelled IS NULL)",
      [id]
    );
    const totalRides = ridesCountRes.rows[0]?.count ?? 0;

    const ratingRes = await query(
      "SELECT COALESCE(ROUND(AVG(rating)::numeric, 2), 4.92)::float as rating FROM ride_reviews WHERE user_id = $1",
      [id]
    );
    const rating = ratingRes.rows[0]?.rating ?? 4.92;

    const savedPlacesRes = await query(
      "SELECT COUNT(*)::int as count FROM saved_places WHERE user_id = $1",
      [id]
    );
    let savedCount = savedPlacesRes.rows[0]?.count ?? 0;
    if (savedCount === 0 && user.address) {
      savedCount = 1;
    }

    return res.json({
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        image_url: user.image_url,
        address: user.address,
        wallet_balance: parseFloat(user.wallet_balance),
        total_rides: totalRides,
        rating: rating,
        member_since: user.member_since ? `Member since ${user.member_since}` : "Member since March 2023",
        saved_places_count: savedCount,
      },
    });
  } catch (error) {
    console.log(`Error in getUserInfo: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const updateUserInfo = async (req, res) => {
  try {
    const id = req.user?.id;
    if (!id) {
      return res.status(401).json({
        error: {
          code: "UNAUTHORIZED",
          message: "User not authenticated.",
        },
      });
    }

    const { name, email, image_url, phone, address } = req.body;
    const fields = [];
    const values = [];
    let paramIndex = 1;

    if (name !== undefined) {
      fields.push(`name = $${paramIndex++}`);
      values.push(name);
    }
    if (email !== undefined) {
      fields.push(`email = $${paramIndex++}`);
      values.push(email);
    }
    if (image_url !== undefined) {
      let finalImageUrl = image_url;
      if (image_url && typeof image_url === "string" && image_url.startsWith("data:image")) {
        try {
          const matches = image_url.match(/^data:image\/([a-zA-Z0-9]+);base64,(.+)$/);
          if (matches) {
            const ext = matches[1] === "jpeg" ? "jpg" : matches[1];
            const buffer = Buffer.from(matches[2], "base64");
            const uploadsDir = path.join(__dirname, "../uploads/avatars");
            if (!fs.existsSync(uploadsDir)) {
              fs.mkdirSync(uploadsDir, { recursive: true });
            }
            const filename = `avatar_${id}_${Date.now()}.${ext}`;
            const filePath = path.join(uploadsDir, filename);
            fs.writeFileSync(filePath, buffer);

            const host = req.get("host") || "localhost:5000";
            const protocol = req.protocol || "http";
            finalImageUrl = `${protocol}://${host}/uploads/avatars/${filename}`;
          }
        } catch (imgErr) {
          console.error("Failed to decode and save base64 avatar image:", imgErr);
        }
      }
      fields.push(`image_url = $${paramIndex++}`);
      values.push(finalImageUrl);
    }
    if (phone !== undefined) {
      fields.push(`phone = $${paramIndex++}`);
      values.push(phone);
    }
    if (address !== undefined) {
      fields.push(`address = $${paramIndex++}`);
      values.push(address);
    }

    if (fields.length === 0) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "No fields provided to update.",
        },
      });
    }

    values.push(id);
    const result = await query(
      `UPDATE users SET ${fields.join(", ")} WHERE id = $${paramIndex} 
       RETURNING id, name, phone, email, image_url, address, COALESCE(wallet_balance, 1240.0)::float as wallet_balance`,
      values
    );

    if (result.rows.length === 0) {
      return res.status(404).json({
        error: {
          code: Err.code.NO_USER_WITH_ID,
          message: Err.message.NO_USER_WITH_ID,
        },
      });
    }

    const row = result.rows[0];

    // Also sync address to saved_places 'Home' if address was updated
    if (address) {
      await query(
        `INSERT INTO saved_places (id, user_id, title, address, type)
         VALUES ($1, $2, 'Home', $3, 'home')
         ON CONFLICT (id) DO UPDATE SET address = EXCLUDED.address`,
        [`sp_home_${id}`, id, address]
      );
    }

    return res.status(200).json({
      message: "User profile updated successfully.",
      user: {
        id: row.id,
        name: row.name,
        phone: row.phone,
        email: row.email,
        image_url: row.image_url,
        address: row.address,
        wallet_balance: parseFloat(row.wallet_balance),
      },
    });
  } catch (error) {
    console.log(`Error in updateUserInfo: ${error}`);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: Err.message.SERVER_ERROR,
      },
    });
  }
};

const addMoneyToWallet = async (req, res) => {
  try {
    const id = req.user?.id;
    if (!id) {
      return res.status(401).json({
        error: { code: "UNAUTHORIZED", message: "User not authenticated." },
      });
    }

    const amount = parseFloat(req.body?.amount);
    if (isNaN(amount) || amount <= 0) {
      return res.status(400).json({
        error: { code: "INVALID_AMOUNT", message: "Please provide a valid positive amount." },
      });
    }

    const updateRes = await query(
      `UPDATE users 
       SET wallet_balance = COALESCE(wallet_balance, 0.0) + $1 
       WHERE id = $2 
       RETURNING id, name, phone, email, image_url, address, wallet_balance::float`,
      [amount, id]
    );

    if (updateRes.rows.length === 0) {
      return res.status(404).json({
        error: { code: "USER_NOT_FOUND", message: "User not found." },
      });
    }

    const updatedUser = updateRes.rows[0];
    return res.status(200).json({
      message: `Successfully added ₹${amount.toFixed(2)} to wallet!`,
      wallet_balance: parseFloat(updatedUser.wallet_balance),
      user: {
        id: updatedUser.id,
        name: updatedUser.name,
        phone: updatedUser.phone,
        email: updatedUser.email,
        image_url: updatedUser.image_url,
        address: updatedUser.address,
        wallet_balance: parseFloat(updatedUser.wallet_balance),
      },
    });
  } catch (error) {
    console.log(`Error in addMoneyToWallet: ${error}`);
    return res.status(500).json({
      error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR },
    });
  }
};

const getSavedPlaces = async (req, res) => {
  try {
    const userId = req.user?.id || req.query?.user_id;
    if (!userId) {
      return res.status(401).json({ error: { code: "UNAUTHORIZED", message: "User not authenticated." } });
    }

    const placesRes = await query(
      "SELECT id, title, address, type, lat, lon FROM saved_places WHERE user_id = $1 ORDER BY created_at ASC",
      [userId]
    );

    let places = placesRes.rows;
    // If empty, check user's main address
    if (places.length === 0) {
      const uRes = await query("SELECT address FROM users WHERE id = $1", [userId]);
      const userAddr = uRes.rows[0]?.address || "12 Elm Street, Indiranagar, Bengaluru";
      places = [
        { id: "sp_default_1", title: "Home", address: userAddr, type: "home", lat: 12.9780, lon: 77.6400 },
        { id: "sp_default_2", title: "Office", address: "Tech Park Block B, Outer Ring Road", type: "work", lat: 12.9250, lon: 77.6800 },
      ];
    }

    return res.status(200).json({
      saved_places: places,
    });
  } catch (error) {
    console.error("Error in getSavedPlaces:", error);
    return res.status(500).json({ error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR } });
  }
};

const addSavedPlace = async (req, res) => {
  try {
    const userId = req.user?.id;
    if (!userId) {
      return res.status(401).json({ error: { code: "UNAUTHORIZED", message: "User not authenticated." } });
    }

    const { title, address, type, lat, lon } = req.body;
    if (!title || !address) {
      return res.status(400).json({ error: { code: "EMPTY_PARAM", message: "Title and address are required." } });
    }

    const id = "sp_" + uuidv4().substring(0, 8);
    await query(
      `INSERT INTO saved_places (id, user_id, title, address, type, lat, lon)
       VALUES ($1, $2, $3, $4, $5, $6, $7)`,
      [id, userId, title, address, type || "other", lat || 12.9716, lon || 77.5946]
    );

    return res.status(201).json({
      message: "Place saved successfully",
      place: { id, title, address, type: type || "other", lat: lat || 12.9716, lon: lon || 77.5946 },
    });
  } catch (error) {
    console.error("Error in addSavedPlace:", error);
    return res.status(500).json({ error: { code: Err.code.SERVER_ERROR, message: Err.message.SERVER_ERROR } });
  }
};

const createSupportTicket = async (req, res) => {
  try {
    const userId = req.user?.id || req.body?.user_id;
    const { category = "General Assistance", message, ride_id } = req.body;

    if (!message) {
      return res.status(400).json({
        error: {
          code: Err.code.EMPTY_PARAM,
          message: "Support message/details cannot be empty.",
        },
      });
    }

    const ticketId = "TICK_" + uuidv4().substring(0, 8).toUpperCase();

    await query(
      `INSERT INTO support_tickets (id, user_id, ride_id, category, message, status)
       VALUES ($1, $2, $3, $4, $5, 'open')`,
      [ticketId, userId || null, ride_id || null, category, message]
    );

    return res.status(201).json({
      message: "Support request received. Saffar 24/7 Agent is on the way to assist you.",
      ticket_id: ticketId,
      status: "open",
    });
  } catch (error) {
    console.error("Error in createSupportTicket:", error);
    return res.status(500).json({
      error: {
        code: Err.code.SERVER_ERROR,
        message: error.message || "Failed to create support ticket",
      },
    });
  }
};

module.exports = {
  getUserInfo,
  updateUserInfo,
  addMoneyToWallet,
  getSavedPlaces,
  addSavedPlace,
  createSupportTicket,
};
