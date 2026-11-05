const bufferModule = require("buffer");
if (!bufferModule.SlowBuffer) {
  bufferModule.SlowBuffer = bufferModule.Buffer;
}
require('dotenv').config();
const bcrypt = require('bcrypt');
const { v4: uuidv4 } = require('uuid');
const { query, initPostgresDatabase } = require('./database');

async function seedAll() {
  try {
    console.log("Ensuring PostgreSQL tables exist...");
    await initPostgresDatabase();

    const saltRounds = 10;
    const commonPasswordHash = await bcrypt.hash('password123', saltRounds);

    // 1. Seed or Get Demo Passenger
    const userInsertRes = await query(`
      INSERT INTO users (id, name, phone, password, email, image_url)
      VALUES ($1, $2, $3, $4, $5, $6)
      ON CONFLICT (phone) DO UPDATE 
      SET name = EXCLUDED.name, password = EXCLUDED.password
      RETURNING id, name, phone;
    `, [
      uuidv4(),
      'Raj Mangesh',
      '9322823295',
      commonPasswordHash,
      'raj@saffar.com',
      'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?w=150',
    ]);
    const userId = userInsertRes.rows[0].id;
    console.log(`✅ Seeded/Updated User: [ID: ${userId}] Phone: 9322823295 | Pass: password123`);

    // 2. Seed or Get Demo Driver
    const driverInsertRes = await query(`
      INSERT INTO drivers (id, name, phone, password, vehicle_name, vehicle_number, email, image_url, active)
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, true)
      ON CONFLICT (phone) DO UPDATE 
      SET password = EXCLUDED.password, active = true, vehicle_name = EXCLUDED.vehicle_name
      RETURNING id, name, phone;
    `, [
      uuidv4(),
      'Vikram Singh',
      '9988776655',
      commonPasswordHash,
      'Toyota Innova Crysta',
      'MH 02 AB 1234',
      'vikram.driver@saffar.com',
      'https://images.unsplash.com/photo-1570295999919-56ceb5ecca61?w=150',
    ]);
    const driverId = driverInsertRes.rows[0].id;
    console.log(`✅ Seeded/Updated Driver: [ID: ${driverId}] Phone: 9988776655 | Pass: password123`);

    console.log("\nSetup completed. Authentic users and driver available without dummy ride history.");
    process.exit(0);
  } catch (err) {
    console.error("❌ Seed error:", err.message);
    process.exit(1);
  }
}

seedAll();
