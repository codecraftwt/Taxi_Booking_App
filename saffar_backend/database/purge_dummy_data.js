const path = require("path");
require("dotenv").config({ path: path.join(__dirname, "../.env") });
const { pool } = require("./db");
const { redisClient } = require("../config/redis");

async function purgeAllDummyData() {
  const client = await pool.connect();
  try {
    console.log("[PURGE] ========================================================");
    console.log("[PURGE] Starting comprehensive purge of ALL test and dummy data...");
    console.log("[PURGE] ========================================================");

    await client.query("BEGIN;");

    // 1. Delete ratings
    const r1 = await client.query("DELETE FROM ratings;");
    console.log(`[PURGE] Deleted ratings: ${r1.rowCount}`);

    // 2. Delete fare accounting and payments (ON DELETE RESTRICT child tables of rides/users)
    const r2 = await client.query("DELETE FROM fare_breakdowns;");
    console.log(`[PURGE] Deleted fare_breakdowns: ${r2.rowCount}`);

    const r3 = await client.query("DELETE FROM fare_estimates;");
    console.log(`[PURGE] Deleted fare_estimates: ${r3.rowCount}`);

    const r4 = await client.query("DELETE FROM payments;");
    console.log(`[PURGE] Deleted payments: ${r4.rowCount}`);

    const r5 = await client.query("DELETE FROM wallet_transactions;");
    console.log(`[PURGE] Deleted wallet_transactions: ${r5.rowCount}`);

    // 3. Delete driver finances & settlements
    const r6 = await client.query("DELETE FROM driver_settlements;");
    console.log(`[PURGE] Deleted driver_settlements: ${r6.rowCount}`);

    const r7 = await client.query("DELETE FROM driver_earnings;");
    console.log(`[PURGE] Deleted driver_earnings: ${r7.rowCount}`);

    // 4. Delete ride lifecycle and dispatch records
    const r8 = await client.query("DELETE FROM ride_cancellations;");
    console.log(`[PURGE] Deleted ride_cancellations: ${r8.rowCount}`);

    const r9 = await client.query("DELETE FROM ride_status_history;");
    console.log(`[PURGE] Deleted ride_status_history: ${r9.rowCount}`);

    const r10 = await client.query("DELETE FROM ride_offers;");
    console.log(`[PURGE] Deleted ride_offers: ${r10.rowCount}`);

    const r11 = await client.query("DELETE FROM ride_requests;");
    console.log(`[PURGE] Deleted ride_requests: ${r11.rowCount}`);

    const r12 = await client.query("DELETE FROM ride_reviews;");
    console.log(`[PURGE] Deleted ride_reviews: ${r12.rowCount}`);

    const r13 = await client.query("DELETE FROM support_tickets;");
    console.log(`[PURGE] Deleted support_tickets: ${r13.rowCount}`);

    const r14 = await client.query("DELETE FROM notifications;");
    console.log(`[PURGE] Deleted notifications: ${r14.rowCount}`);

    // 5. Delete driver tracking, documents, availability, and vehicles
    const r15 = await client.query("DELETE FROM driver_location_logs;");
    console.log(`[PURGE] Deleted driver_location_logs: ${r15.rowCount}`);

    const r16 = await client.query("DELETE FROM driver_locations;");
    console.log(`[PURGE] Deleted driver_locations: ${r16.rowCount}`);

    const r17 = await client.query("DELETE FROM driver_availability;");
    console.log(`[PURGE] Deleted driver_availability: ${r17.rowCount}`);

    const r18 = await client.query("DELETE FROM driver_documents;");
    console.log(`[PURGE] Deleted driver_documents: ${r18.rowCount}`);

    const r19 = await client.query("DELETE FROM driver_vehicles;");
    console.log(`[PURGE] Deleted driver_vehicles: ${r19.rowCount}`);

    const r20 = await client.query("DELETE FROM vehicles;");
    console.log(`[PURGE] Deleted vehicles: ${r20.rowCount}`);

    const r21 = await client.query("DELETE FROM driver_profiles;");
    console.log(`[PURGE] Deleted driver_profiles: ${r21.rowCount}`);

    // 6. Delete all rides
    const r22 = await client.query("DELETE FROM rides;");
    console.log(`[PURGE] Deleted ALL rides: ${r22.rowCount}`);

    // 7. Delete all drivers
    const r23 = await client.query("DELETE FROM drivers;");
    console.log(`[PURGE] Deleted ALL drivers: ${r23.rowCount}`);

    // 8. Delete test users and their profiles & wallets (Keep authentic user accounts)
    const testUserWhere = `
      id IN ('user_001', 'usr_e2e_master_001', 'user_test_matcher', '997ee0c7-f465-42f6-872e-b5472639d6b2', '3d4c08a3-9028-4bba-8de0-be137053171a')
      OR phone IN ('9876599999', '9888800001', '9876500001', '9322823220', '9322823223', '9876543210')
      OR email IN ('sameer.v@example.com', 'aamir@saffar.com', 'tu1@gmail.com')
      OR id LIKE 'user_test_%'
      OR id LIKE 'usr_%'
      OR id LIKE 'test_%'
      OR name LIKE 'Test%'
    `;

    const r24 = await client.query(`
      DELETE FROM saved_places 
      WHERE user_id IN (SELECT id FROM users WHERE ${testUserWhere});
    `);
    console.log(`[PURGE] Deleted test saved_places: ${r24.rowCount}`);

    const r25 = await client.query(`
      DELETE FROM user_profiles 
      WHERE user_id IN (SELECT id FROM users WHERE ${testUserWhere});
    `);
    console.log(`[PURGE] Deleted test user_profiles: ${r25.rowCount}`);

    const r26 = await client.query(`
      DELETE FROM wallets 
      WHERE entity_type = 'DRIVER' 
         OR entity_id IN (SELECT id FROM users WHERE ${testUserWhere});
    `);
    console.log(`[PURGE] Deleted test/driver wallets: ${r26.rowCount}`);

    const r27 = await client.query(`
      DELETE FROM users 
      WHERE ${testUserWhere};
    `);
    console.log(`[PURGE] Deleted test users: ${r27.rowCount}`);

    // 9. Reset admin audit logs to clean slate
    const r28 = await client.query("DELETE FROM admin_audit_logs;");
    console.log(`[PURGE] Cleared admin_audit_logs: ${r28.rowCount}`);

    await client.query("COMMIT;");
    console.log("[PURGE] ✅ PostgreSQL database purge committed successfully.");

    // 10. Flush Redis cache and ephemeral indexes
    console.log("[PURGE] Connecting to Redis to flush keys...");
    if (!redisClient.isOpen) {
      await redisClient.connect();
    }
    await redisClient.flushDb();
    console.log("[PURGE] ✅ Redis FLUSHDB completed successfully (all keys wiped).");

    // 11. Final verification checks
    console.log("\n[VERIFICATION] Final DB record counts:");
    const [cDrivers, cRides, cDocs, cUsers, cAdmin] = await Promise.all([
      client.query("SELECT COUNT(*) FROM drivers;"),
      client.query("SELECT COUNT(*) FROM rides;"),
      client.query("SELECT COUNT(*) FROM driver_documents;"),
      client.query("SELECT COUNT(*) FROM users;"),
      client.query("SELECT COUNT(*) FROM admin_users;"),
    ]);

    console.log(`  - Drivers:           ${cDrivers.rows[0].count}`);
    console.log(`  - Rides:             ${cRides.rows[0].count}`);
    console.log(`  - Driver Documents:  ${cDocs.rows[0].count}`);
    console.log(`  - Authentic Users:   ${cUsers.rows[0].count}`);
    console.log(`  - Admin Users:       ${cAdmin.rows[0].count}`);

    const redisKeys = await redisClient.keys("*");
    console.log(`  - Redis Keys:        ${redisKeys.length}`);
    console.log("[PURGE] ========================================================\n");

  } catch (err) {
    await client.query("ROLLBACK;");
    console.error("[PURGE ERROR] Transaction failed and rolled back:", err);
    throw err;
  } finally {
    client.release();
    if (redisClient.isOpen) {
      await redisClient.disconnect();
    }
    await pool.end();
  }
}

if (require.main === module) {
  purgeAllDummyData()
    .then(() => process.exit(0))
    .catch(() => process.exit(1));
}

module.exports = { purgeAllDummyData };
