const bcrypt = require("bcrypt");
const jwt = require("jsonwebtoken");
const config = require("../../config");
const { query } = require("../../database");

async function adminLogin(req, res) {
  try {
    const { email, password } = req.body;
    if (!email || !password) {
      return res.status(400).json({
        success: false,
        message: "Email and password are required.",
      });
    }

    const adminRes = await query(
      "SELECT * FROM admin_users WHERE LOWER(email) = LOWER($1)",
      [email.trim()]
    );

    if (adminRes.rows.length === 0) {
      return res.status(401).json({
        success: false,
        message: "Invalid administrator credentials.",
      });
    }

    const admin = adminRes.rows[0];
    if (!admin.is_active) {
      return res.status(403).json({
        success: false,
        message: "This administrative account is suspended. Contact Super Admin.",
      });
    }

    const isMatch = await bcrypt.compare(password, admin.password);
    if (!isMatch) {
      return res.status(401).json({
        success: false,
        message: "Invalid administrator credentials.",
      });
    }

    // Update last login
    await query("UPDATE admin_users SET last_login_at = NOW() WHERE id = $1", [admin.id]);

    // Issue JWT Token
    const token = jwt.sign(
      {
        id: admin.id,
        email: admin.email,
        role: admin.role,
        name: admin.name,
      },
      config.TOKEN_SECRET_KEY,
      { expiresIn: config.TOKEN_EXPIRY_TIME || "30d" }
    );

    // Audit log
    await query(
      `INSERT INTO admin_audit_logs (id, admin_id, admin_name, action, target_type, target_id, details, ip_address)
       VALUES ('log_' || substr(md5(random()::text), 1, 16), $1, $2, 'LOGIN', 'auth', $1, 'Successful administrator login', $3)`,
      [admin.id, admin.name, req.ip || "127.0.0.1"]
    );

    return res.status(200).json({
      success: true,
      message: "Login successful.",
      data: {
        token,
        admin: {
          id: admin.id,
          name: admin.name,
          email: admin.email,
          role: admin.role,
        },
      },
    });
  } catch (err) {
    console.error("[ADMIN LOGIN ERROR]", err);
    return res.status(500).json({
      success: false,
      message: "Failed to process administrator login.",
    });
  }
}

async function getAdminProfile(req, res) {
  try {
    return res.status(200).json({
      success: true,
      data: req.admin,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function changeAdminPassword(req, res) {
  try {
    const { currentPassword, newPassword } = req.body;
    if (!currentPassword || !newPassword || newPassword.length < 6) {
      return res.status(400).json({
        success: false,
        message: "New password must be at least 6 characters long.",
      });
    }

    const adminRes = await query("SELECT password FROM admin_users WHERE id = $1", [req.admin.id]);
    const isMatch = await bcrypt.compare(currentPassword, adminRes.rows[0].password);
    if (!isMatch) {
      return res.status(400).json({
        success: false,
        message: "Current password does not match.",
      });
    }

    const hashed = await bcrypt.hash(newPassword, 10);
    await query("UPDATE admin_users SET password = $1 WHERE id = $2", [hashed, req.admin.id]);

    return res.status(200).json({
      success: true,
      message: "Password changed successfully.",
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  adminLogin,
  getAdminProfile,
  changeAdminPassword,
};

