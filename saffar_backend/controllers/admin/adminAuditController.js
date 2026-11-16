const bcrypt = require("bcrypt");
const { query } = require("../../database");

async function getAuditLogs(req, res) {
  try {
    const { action, limit = 50 } = req.query;
    let sql = "SELECT * FROM admin_audit_logs";
    let params = [];

    if (action) {
      sql += " WHERE action = $1";
      params.push(action);
    }
    sql += " ORDER BY created_at DESC LIMIT $" + (params.length + 1);
    params.push(parseInt(limit));

    const logsRes = await query(sql, params);
    return res.status(200).json({ success: true, data: logsRes.rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function getAdminUsers(req, res) {
  try {
    const list = await query(
      "SELECT id, name, email, role, is_active, last_login_at, created_at FROM admin_users ORDER BY created_at ASC"
    );
    return res.status(200).json({ success: true, data: list.rows });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function createAdminUser(req, res) {
  try {
    const { name, email, password, role = "operations_manager" } = req.body;
    if (!name || !email || !password || password.length < 6) {
      return res.status(400).json({
        success: false,
        message: "Name, valid email, and password (min 6 chars) are required.",
      });
    }

    const hashed = await bcrypt.hash(password, 10);
    const id = "admin_" + Date.now();

    await query(
      `INSERT INTO admin_users (id, name, email, password, role, is_active)
       VALUES ($1, $2, $3, $4, $5, true)`,
      [id, name, email.trim().toLowerCase(), hashed, role]
    );

    // Audit log
    await query(
      `INSERT INTO admin_audit_logs (id, admin_id, admin_name, action, target_type, target_id, details, ip_address)
       VALUES ('log_' || substr(md5(random()::text), 1, 16), $1, $2, 'CREATE_ADMIN', 'admin_user', $3, $4, $5)`,
      [
        req.admin.id,
        req.admin.name,
        id,
        `Created new admin account for ${email} with role ${role}`,
        req.ip || "127.0.0.1",
      ]
    );

    return res.status(201).json({
      success: true,
      message: "Admin account created successfully.",
      data: { id, name, email, role },
    });
  } catch (err) {
    if (err.code === "23505") {
      return res.status(400).json({ success: false, message: "An admin with this email already exists." });
    }
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getAuditLogs,
  getAdminUsers,
  createAdminUser,
};

