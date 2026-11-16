const { query } = require("../../database");

async function getFareConfigs(req, res) {
  try {
    const resList = await query(
      "SELECT * FROM fare_configs ORDER BY base_fare ASC"
    );
    return res.status(200).json({
      success: true,
      data: resList.rows,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

async function updateFareConfig(req, res) {
  try {
    const { category } = req.params;
    const b = req.body || {};

    const baseFare = b.baseFare ?? b.base_fare;
    const perKm = b.perKm ?? b.per_km ?? b.per_km_rate;
    const perMinute = b.perMinute ?? b.per_minute ?? b.per_minute_rate ?? 0;
    const minimumFare = b.minimumFare ?? b.minimum_fare ?? baseFare;
    const bookingFee = b.bookingFee ?? b.booking_fee;
    const commissionPercentage = b.commissionPercentage ?? b.commission_percentage ?? b.commission_rate;
    const surgeMultiplier = b.surgeMultiplier ?? b.surge_multiplier;
    const cancellationFee = b.cancellationFee ?? b.cancellation_fee;

    if (
      baseFare == null ||
      perKm == null ||
      perMinute == null ||
      minimumFare == null
    ) {
      return res.status(400).json({
        success: false,
        message: "Base fare, per km, per minute, and minimum fare are required.",
      });
    }

    if (baseFare < 0 || perKm < 0 || perMinute < 0 || minimumFare < 0) {
      return res.status(400).json({
        success: false,
        message: "Pricing values cannot be negative.",
      });
    }

    const updatedRes = await query(
      `UPDATE fare_configs 
       SET base_fare = $1,
           per_km = $2,
           per_minute = $3,
           minimum_fare = $4,
           booking_fee = COALESCE($5, booking_fee),
           commission_percentage = COALESCE($6, commission_percentage),
           surge_multiplier = COALESCE($7, surge_multiplier),
           cancellation_fee = COALESCE($8, cancellation_fee),
           updated_at = NOW()
       WHERE LOWER(category) = LOWER($9)
       RETURNING *`,
      [
        parseFloat(baseFare),
        parseFloat(perKm),
        parseFloat(perMinute),
        parseFloat(minimumFare),
        bookingFee != null ? parseFloat(bookingFee) : null,
        commissionPercentage != null ? parseFloat(commissionPercentage) : null,
        surgeMultiplier != null ? parseFloat(surgeMultiplier) : null,
        cancellationFee != null ? parseFloat(cancellationFee) : null,
        category,
      ]
    );

    if (updatedRes.rows.length === 0) {
      return res.status(404).json({ success: false, message: "Category fare config not found." });
    }

    const updatedRow = updatedRes.rows[0];

    // Keep legacy prices table in sync
    try {
      await query("UPDATE prices SET base_price = $1, price_per_km = $2 WHERE id = 1", [
        parseFloat(baseFare),
        parseFloat(perKm),
      ]);
    } catch (_) {}

    // Write audit log
    await query(
      `INSERT INTO admin_audit_logs (id, admin_id, admin_name, action, target_type, target_id, details, ip_address)
       VALUES ('log_' || substr(md5(random()::text), 1, 16), $1, $2, 'UPDATE_FARE', 'fare', $3, $4, $5)`,
      [
        req.admin.id,
        req.admin.name,
        category,
        `Fare updated for ${category}: Base ₹${baseFare}, PerKm ₹${perKm}, MinFare ₹${minimumFare}, Commission ${commissionPercentage}%`,
        req.ip || "127.0.0.1",
      ]
    );

    // Broadcast real-time WebSocket event to all connected users and drivers
    try {
      const { getIO } = require("../../socket");
      const io = getIO();
      if (io) {
        io.emit("fare_config_updated", {
          category: updatedRow.category,
          base_fare: parseFloat(updatedRow.base_fare),
          per_km: parseFloat(updatedRow.per_km),
          per_minute: parseFloat(updatedRow.per_minute),
          minimum_fare: parseFloat(updatedRow.minimum_fare),
          commission_percentage: parseFloat(updatedRow.commission_percentage),
          updated_at: updatedRow.updated_at,
        });
        console.log(`[SOCKET] Broadcasted fare_config_updated for ${category}`);
      }
    } catch (sockErr) {
      console.warn("[SOCKET FARE BROADCAST ERROR]", sockErr.message);
    }

    return res.status(200).json({
      success: true,
      message: `Fare configuration for ${category} updated successfully.`,
      data: updatedRow,
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
}

module.exports = {
  getFareConfigs,
  updateFareConfig,
};

