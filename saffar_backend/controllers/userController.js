const Err = require("../config/error");
const { query } = require("../database");

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
      "SELECT id, name, phone, email, image_url FROM users WHERE id = $1",
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

    return res.json({
      user: {
        id: user.id,
        name: user.name,
        phone: user.phone,
        email: user.email,
        image_url: user.image_url,
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

    const { name, email, image_url } = req.body;
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
      fields.push(`image_url = $${paramIndex++}`);
      values.push(image_url);
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
      `UPDATE users SET ${fields.join(", ")} WHERE id = $${paramIndex} RETURNING id, name, phone, email, image_url`,
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

    return res.status(200).json({
      message: "User profile updated successfully.",
      user: result.rows[0],
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

module.exports = {
  getUserInfo,
  updateUserInfo,
};
