const path = require("path");
const fs = require("fs");
const { pool } = require("./db");

async function runMigrations() {
  const client = await pool.connect();
  try {
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
      );
    `);

    const migrationsDir = path.join(__dirname, "migrations");
    if (!fs.existsSync(migrationsDir)) return;

    const files = fs
      .readdirSync(migrationsDir)
      .filter((f) => f.endsWith(".js") || f.endsWith(".sql"))
      .sort();

    for (const file of files) {
      const checkRes = await client.query(
        "SELECT version FROM schema_migrations WHERE version = $1",
        [file]
      );
      if (checkRes.rows.length === 0) {
        console.log(`[MIGRATION] Applying migration: ${file}...`);
        await client.query("BEGIN;");
        try {
          if (file.endsWith(".js")) {
            const migration = require(path.join(migrationsDir, file));
            if (typeof migration.up === "function") {
              await migration.up(client);
            }
          } else if (file.endsWith(".sql")) {
            const sql = fs.readFileSync(path.join(migrationsDir, file), "utf8");
            await client.query(sql);
          }
          await client.query(
            "INSERT INTO schema_migrations (version) VALUES ($1);",
            [file]
          );
          await client.query("COMMIT;");
          console.log(`[MIGRATION] Successfully applied: ${file}`);
        } catch (migrationErr) {
          await client.query("ROLLBACK;");
          console.error(`[MIGRATION ERROR] Failed in ${file}:`, migrationErr.message);
          throw migrationErr;
        }
      }
    }

    // One-time dummy purge already completed; do not wipe live data on startup
  } catch (err) {
    console.error("[MIGRATION ERROR] Could not complete migrations:", err.message);
  } finally {
    client.release();
  }
}

module.exports = { runMigrations };

