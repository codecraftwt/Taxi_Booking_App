const jwt = require("jsonwebtoken");
const config = require("../config");
const { query } = require("../database");

async function verifyAdminAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith("Bearer ")) {
      return res.status(401).json({
        success: false,
        message: "Authentication token missing or invalid format. Please login as Admin.",
      });
    }

    const token = authHeader.split(" ")[1];
    let decoded;
    try {
      decoded = jwt.verify(token, config.TOKEN_SECRET_KEY);
    } catch (tokenErr) {
      return res.status(401).json({
        success: false,
        message: "Invalid or expired session. Please login again.",
      });
    }

    // Verify admin user exists and is active
    const adminRes = await query(
      "SELECT id, name, email, role, is_active FROM admin_users WHERE id = $1",
      [decoded.id]
    );

    if (adminRes.rows.length === 0) {
      return res.status(403).json({
        success: false,
        message: "Admin account not found or access revoked.",
      });
    }

    const admin = adminRes.rows[0];
    if (!admin.is_active) {
      return res.status(403).json({
        success: false,
        message: "Your administrative account has been deactivated. Contact Super Admin.",
      });
    }

    req.admin = admin;
    next();
  } catch (err) {
    console.error("[ADMIN AUTH ERROR]", err);
    return res.status(500).json({
      success: false,
      message: "Internal authentication error.",
    });
  }
}

function requireRoles(...allowedRoles) {
  return (req, res, next) => {
    if (!req.admin) {
      return res.status(401).json({ success: false, message: "Unauthorized." });
    }
    if (req.admin.role === "super_admin" || allowedRoles.includes(req.admin.role)) {
      return next();
    }
    return res.status(403).json({
      success: false,
      message: `Access denied. Requires role: ${allowedRoles.join(" or ")}.`,
    });
  };
}

module.exports = {
  verifyAdminAuth,
  requireRoles,
};

