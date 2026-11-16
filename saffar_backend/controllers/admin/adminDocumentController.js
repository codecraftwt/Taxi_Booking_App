const { query } = require("../../database");

async function getPendingDocuments(req, res) {
  try {
    const { status = "pending", documentType, page = 1, limit = 20 } = req.query;
    const offset = (parseInt(page) - 1) * parseInt(limit);

    let where = [];
    let params = [];
    let pIdx = 1;

    if (status && status !== "all") {
      where.push(`dd.verification_status = $${pIdx}`);
      params.push(status);
      pIdx++;
    }

    if (documentType && documentType !== "all") {
      where.push(`dd.document_type = $${pIdx}`);
      params.push(documentType);
      pIdx++;
    }

    const whereStr = where.length > 0 ? "WHERE " + where.join(" AND ") : "";

    const countRes = await query(
      `SELECT COUNT(*) as total FROM driver_documents dd ${whereStr};`,
      params
    );
    const total = parseInt(countRes.rows[0]?.total || 0);

    const listSql = `
      SELECT 
        dd.*,
        d.name as driver_name,
        d.phone as driver_phone,
        d.email as driver_email,
        d.vehicle_number,
        d.vehicle_name,
        COALESCE(dv.category, 'Auto') as vehicle_category
      FROM driver_documents dd
      JOIN drivers d ON dd.driver_id = d.id
      LEFT JOIN driver_vehicles dv ON d.id = dv.driver_id
      ${whereStr}
      ORDER BY dd.created_at DESC
      LIMIT $${pIdx} OFFSET $${pIdx + 1};
    `;
    params.push(parseInt(limit), offset);

    const listRes = await query(listSql, params);

    return res.status(200).json({
      success: true,
      data: {
        documents: listRes.rows,
        pagination: {
          total,
          page: parseInt(page),
          limit: parseInt(limit),
          totalPages: Math.ceil(total / parseInt(limit)) || 1,
        },
      },
    });
  } catch (err) {
    console.error("[GET PENDING DOCS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function verifyDocument(req, res) {
  try {
    const { documentId } = req.params;
    const { status, rejectionReason } = req.body;
    // status: 'approved' or 'rejected'

    if (!["approved", "rejected"].includes(status)) {
      return res.status(400).json({
        success: false,
        message: "Status must be 'approved' or 'rejected'.",
      });
    }

    if (status === "rejected" && (!rejectionReason || rejectionReason.trim().length < 5)) {
      return res.status(400).json({
        success: false,
        message: "A specific rejection reason of at least 5 characters is required.",
      });
    }

    // Update document
    const docRes = await query(
      `UPDATE driver_documents 
       SET verification_status = $1, 
           rejection_reason = $2, 
           verified_by = $3, 
           verified_at = NOW()
       WHERE id = $4
       RETURNING *;`,
      [status, status === "rejected" ? rejectionReason : null, req.admin.id, documentId]
    );

    if (docRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Document record not found." });
    }

    const doc = docRes.rows[0];

    // Check if all documents for this driver are now approved
    const allDocsRes = await query(
      `SELECT document_type, verification_status FROM driver_documents WHERE driver_id = $1;`,
      [doc.driver_id]
    );

    const hasRejected = allDocsRes.rows.some((d) => d.verification_status === "rejected");
    const allApproved =
      allDocsRes.rows.length >= 2 &&
      allDocsRes.rows.every((d) => d.verification_status === "approved");

    if (allApproved) {
      // Automatically graduate driver to Approved
      await query(
        `UPDATE drivers SET verification_status = 'approved', active = true WHERE id = $1;`,
        [doc.driver_id]
      );
      await query(
        `UPDATE driver_vehicles SET verification_status = 'approved', is_active = true WHERE driver_id = $1;`,
        [doc.driver_id]
      );
    } else if (hasRejected) {
      await query(
        `UPDATE drivers SET verification_status = 'rejected' WHERE id = $1;`,
        [doc.driver_id]
      );
    }

    // Audit log
    await query(
      `INSERT INTO admin_audit_logs (id, admin_id, admin_name, action, target_type, target_id, details, ip_address)
       VALUES ('log_' || substr(md5(random()::text), 1, 16), $1, $2, $3, 'document', $4, $5, $6)`,
      [
        req.admin.id,
        req.admin.name,
        `DOCUMENT_${status.toUpperCase()}`,
        documentId,
        `Document ${doc.document_type} ${status} for driver ${doc.driver_id}. Reason: ${rejectionReason || "Approved by staff"}`,
        req.ip || "127.0.0.1",
      ]
    );

    return res.status(200).json({
      success: true,
      message: `Document has been ${status}.`,
      data: {
        document: doc,
        allDocumentsApproved: allApproved,
      },
    });
  } catch (err) {
    console.error("[VERIFY DOCUMENT ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getPendingDocuments,
  verifyDocument,
};

