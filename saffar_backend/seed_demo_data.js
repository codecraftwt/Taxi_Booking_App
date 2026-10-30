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

    // 3. Seed Addresses
    const addr1Id = 'addr_bkc_001';
    const addr2Id = 'addr_airport_002';
    const addr3Id = 'addr_marinedrive_003';

    await query(`
      INSERT INTO addresses (id, place, street, state, country, lat, lon, pincode)
      VALUES 
        ($1, 'Bandra Kurla Complex', 'BKC Road, G Block', 'Maharashtra', 'India', 19.0657, 72.8687, '400051'),
        ($2, 'Chhatrapati Shivaji International Airport', 'Terminal 2, Sahar', 'Maharashtra', 'India', 19.0968, 72.8744, '400099'),
        ($3, 'Marine Drive', 'Netaji Subhash Chandra Bose Road', 'Maharashtra', 'India', 18.9432, 72.8230, '400020')
      ON CONFLICT (id) DO UPDATE SET street = EXCLUDED.street;
    `, [addr1Id, addr2Id, addr3Id]);
    console.log("✅ Seeded Sample Addresses");

    // 4. Seed Sample Completed Rides
    const ride1Id = 'ride_demo_001';
    const ride2Id = 'ride_demo_002';

    await query(`
      INSERT INTO rides (id, user_id, driver_id, source_address_id, destination_address_id, start_time, end_time, cancelled, price, discount_price)
      VALUES 
        ($1, $2, $3, $4, $5, NOW() - INTERVAL '2 hours', NOW() - INTERVAL '1 hour', false, 350.0, 0.0),
        ($6, $2, $3, $5, $7, NOW() - INTERVAL '1 day', NOW() - INTERVAL '23 hours', false, 480.0, 30.0)
      ON CONFLICT (id) DO UPDATE 
      SET user_id = EXCLUDED.user_id, driver_id = EXCLUDED.driver_id, end_time = EXCLUDED.end_time;
    `, [
      ride1Id, userId, driverId, addr1Id, addr2Id,
      ride2Id, addr3Id,
    ]);
    console.log("✅ Seeded Sample Completed Rides for Driver & Passenger");

    console.log("\nAll demo data seeded successfully into PostgreSQL!");
    process.exit(0);
  } catch (err) {
    console.error("❌ Seed error:", err.message);
    process.exit(1);
  }
}

seedAll();
