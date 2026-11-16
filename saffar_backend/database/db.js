const { Pool } = require("pg");
const config = require("../config");
// Create PostgreSQL connection pool
const pool = new Pool(
  config.DATABASE_URL
    ? {
        connectionString: config.DATABASE_URL,
        ssl: config.DATABASE_SSL ? { rejectUnauthorized: false } : false,
      }
    : {
        host: config.PGHOST,
        port: config.PGPORT,
        user: config.PGUSER,
        password: config.PGPASSWORD,
        database: config.PGDATABASE,
      }
);

const query = (text, params) => pool.query(text, params);

// Initialize PostgreSQL schema and seed default values
async function initPostgresDatabase() {
  const client = await pool.connect();
  try {
    console.log("Connected to PostgreSQL successfully!");

    // 1. Users table
    await client.query(`
      CREATE TABLE IF NOT EXISTS users (
        id VARCHAR(64) PRIMARY KEY,
        name VARCHAR(1000) NOT NULL,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password VARCHAR(1000) NOT NULL,
        email VARCHAR(255) UNIQUE,
        image_url TEXT,
        address VARCHAR(1000),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      ALTER TABLE users ADD COLUMN IF NOT EXISTS address VARCHAR(1000);
      ALTER TABLE users ADD COLUMN IF NOT EXISTS wallet_balance DOUBLE PRECISION DEFAULT 1240.0;
      ALTER TABLE users ALTER COLUMN image_url TYPE TEXT;
    `);

    // 1b. Saved Places table for users
    await client.query(`
      CREATE TABLE IF NOT EXISTS saved_places (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
        title VARCHAR(255) NOT NULL,
        address VARCHAR(1000) NOT NULL,
        type VARCHAR(50) DEFAULT 'other',
        lat DOUBLE PRECISION DEFAULT 12.9716,
        lon DOUBLE PRECISION DEFAULT 77.5946,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 2. Drivers table
    await client.query(`
      CREATE TABLE IF NOT EXISTS drivers (
        id VARCHAR(64) PRIMARY KEY,
        name VARCHAR(1000) NOT NULL,
        phone VARCHAR(20) UNIQUE NOT NULL,
        password VARCHAR(1000) NOT NULL,
        vehicle_name VARCHAR(1000) NOT NULL,
        vehicle_number VARCHAR(100) NOT NULL,
        email VARCHAR(255),
        image_url VARCHAR(1000),
        active BOOLEAN DEFAULT TRUE,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 3. Addresses table
    await client.query(`
      CREATE TABLE IF NOT EXISTS addresses (
        id VARCHAR(64) PRIMARY KEY,
        place VARCHAR(1000),
        street VARCHAR(1000) NOT NULL,
        state VARCHAR(255),
        country VARCHAR(255),
        lat DOUBLE PRECISION NOT NULL,
        lon DOUBLE PRECISION NOT NULL,
        pincode VARCHAR(50),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 4. Rides table
    await client.query(`
      CREATE TABLE IF NOT EXISTS rides (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64) REFERENCES users(id) ON DELETE CASCADE,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE CASCADE,
        source_address_id VARCHAR(64) REFERENCES addresses(id),
        destination_address_id VARCHAR(64) REFERENCES addresses(id),
        start_time TIMESTAMP WITH TIME ZONE NOT NULL,
        end_time TIMESTAMP WITH TIME ZONE,
        cancelled BOOLEAN DEFAULT FALSE,
        price DOUBLE PRECISION NOT NULL,
        discount_price DOUBLE PRECISION,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // Ensure Stitch UI specific columns exist on rides
    await client.query(`
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS otp VARCHAR(10) DEFAULT '4829';
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS vehicle_type VARCHAR(50) DEFAULT 'Saffar Auto';
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS status VARCHAR(50) DEFAULT 'completed';
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) DEFAULT 'Paid via UPI';
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS co2_saved DOUBLE PRECISION DEFAULT 1.2;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS rating DOUBLE PRECISION DEFAULT 5.0;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS tip_amount DOUBLE PRECISION DEFAULT 0.0;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS arrived_at TIMESTAMP WITH TIME ZONE;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS reaching_pickup_at TIMESTAMP WITH TIME ZONE;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS otp_hash VARCHAR(255);
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS otp_expires_at TIMESTAMP WITH TIME ZONE;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS otp_attempts INT DEFAULT 0;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS max_otp_attempts INT DEFAULT 5;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS otp_verified BOOLEAN DEFAULT FALSE;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS trip_started_at TIMESTAMP WITH TIME ZONE;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancelled_by VARCHAR(50);
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancellation_reason VARCHAR(255);
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancellation_notes TEXT;
      ALTER TABLE rides ADD COLUMN IF NOT EXISTS cancelled_at TIMESTAMP WITH TIME ZONE;
      ALTER TABLE rides ALTER COLUMN driver_id DROP NOT NULL;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS age INT;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS gender VARCHAR(50);
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS address TEXT;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS vehicle_model VARCHAR(255);
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS verification_status VARCHAR(50) DEFAULT 'Approved';
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS is_online BOOLEAN DEFAULT FALSE;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS current_lat DOUBLE PRECISION;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS current_lng DOUBLE PRECISION;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS heading DOUBLE PRECISION DEFAULT 0.0;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS speed DOUBLE PRECISION DEFAULT 0.0;
      ALTER TABLE drivers ADD COLUMN IF NOT EXISTS last_location_updated_at TIMESTAMP WITH TIME ZONE;
    `);

    // 5. Ride Reviews & Feedback table
    await client.query(`
      CREATE TABLE IF NOT EXISTS ride_reviews (
        id VARCHAR(64) PRIMARY KEY,
        ride_id VARCHAR(64),
        user_id VARCHAR(64),
        driver_id VARCHAR(64),
        rating DOUBLE PRECISION NOT NULL,
        tags TEXT[],
        tip_amount DOUBLE PRECISION DEFAULT 0.0,
        note TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 6. Support Tickets table
    await client.query(`
      CREATE TABLE IF NOT EXISTS support_tickets (
        id VARCHAR(64) PRIMARY KEY,
        user_id VARCHAR(64),
        ride_id VARCHAR(64),
        category VARCHAR(100) NOT NULL,
        message TEXT NOT NULL,
        status VARCHAR(50) DEFAULT 'open',
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
    `);

    // 7. Prices table
    await client.query(`
      CREATE TABLE IF NOT EXISTS prices (
        id SERIAL PRIMARY KEY,
        base_price DOUBLE PRECISION NOT NULL,
        price_per_km DOUBLE PRECISION NOT NULL
      );
    `);

    // 8. Driver Vehicles & Documents table
    await client.query(`
      CREATE TABLE IF NOT EXISTS driver_vehicles (
        id VARCHAR(64) PRIMARY KEY,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE CASCADE,
        category VARCHAR(50) NOT NULL,
        model VARCHAR(255) NOT NULL,
        registration_number VARCHAR(100) NOT NULL,
        color VARCHAR(50) DEFAULT 'Standard',
        is_active BOOLEAN DEFAULT TRUE,
        driving_license_number VARCHAR(100),
        driving_license_expiry VARCHAR(50),
        driving_license_doc TEXT,
        rc_number VARCHAR(100),
        rc_doc TEXT,
        insurance_policy_number VARCHAR(100),
        insurance_expiry VARCHAR(50),
        insurance_doc TEXT,
        verification_status VARCHAR(50) DEFAULT 'approved',
        rejection_reason TEXT,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_driver_vehicles_driver_id ON driver_vehicles(driver_id);
      CREATE INDEX IF NOT EXISTS idx_driver_vehicles_cat_active ON driver_vehicles(category, is_active, verification_status);
      CREATE INDEX IF NOT EXISTS idx_drivers_online_status ON drivers(is_online, active, verification_status);
      CREATE INDEX IF NOT EXISTS idx_drivers_location ON drivers(current_lat, current_lng);
      CREATE INDEX IF NOT EXISTS idx_drivers_last_loc_updated ON drivers(last_location_updated_at);

      -- Auto-migrate existing driver vehicles if not yet populated
      INSERT INTO driver_vehicles (id, driver_id, category, model, registration_number, color, is_active, verification_status)
      SELECT 
        'veh_' || id, 
        id, 
        COALESCE(vehicle_model, 'Auto'), 
        vehicle_name, 
        vehicle_number, 
        'Yellow & Black', 
        true, 
        'approved'
      FROM drivers
      WHERE id NOT IN (SELECT driver_id FROM driver_vehicles)
      ON CONFLICT (id) DO NOTHING;
    `);

    // 9. Driver Location Logs table
    await client.query(`
      CREATE TABLE IF NOT EXISTS driver_location_logs (
        id VARCHAR(64) PRIMARY KEY,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE CASCADE,
        latitude DOUBLE PRECISION NOT NULL,
        longitude DOUBLE PRECISION NOT NULL,
        heading DOUBLE PRECISION DEFAULT 0.0,
        speed DOUBLE PRECISION DEFAULT 0.0,
        recorded_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_driver_location_logs_driver_id ON driver_location_logs(driver_id);
      CREATE INDEX IF NOT EXISTS idx_driver_location_logs_recorded_at ON driver_location_logs(recorded_at);
    `);

    // 10. Ride Requests dispatch table
    await client.query(`
      CREATE TABLE IF NOT EXISTS ride_requests (
        id VARCHAR(64) PRIMARY KEY,
        ride_id VARCHAR(64) REFERENCES rides(id) ON DELETE CASCADE,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE CASCADE,
        status VARCHAR(32) DEFAULT 'pending',
        expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
        distance_to_pickup_km DOUBLE PRECISION DEFAULT 1.0,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(ride_id, driver_id)
      );
      CREATE INDEX IF NOT EXISTS idx_ride_requests_driver_id ON ride_requests(driver_id);
      CREATE INDEX IF NOT EXISTS idx_ride_requests_ride_id ON ride_requests(ride_id);
      CREATE INDEX IF NOT EXISTS idx_ride_requests_status ON ride_requests(status);
    `);

    // 11. Driver Earnings table
    await client.query(`
      CREATE TABLE IF NOT EXISTS driver_earnings (
        id VARCHAR(64) PRIMARY KEY,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE CASCADE,
        ride_id VARCHAR(64) REFERENCES rides(id) ON DELETE CASCADE,
        amount DOUBLE PRECISION NOT NULL,
        gross_fare DOUBLE PRECISION,
        commission_rate DOUBLE PRECISION DEFAULT 0.15,
        commission_amount DOUBLE PRECISION DEFAULT 0.0,
        other_deductions DOUBLE PRECISION DEFAULT 0.0,
        net_earnings DOUBLE PRECISION,
        distance_km DOUBLE PRECISION DEFAULT 0.0,
        duration_minutes INT DEFAULT 0,
        payment_status VARCHAR(50) DEFAULT 'Paid',
        payment_method VARCHAR(50) DEFAULT 'UPI / Cash',
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(ride_id)
      );
      ALTER TABLE driver_earnings ADD COLUMN IF NOT EXISTS gross_fare DOUBLE PRECISION;
      ALTER TABLE driver_earnings ADD COLUMN IF NOT EXISTS commission_rate DOUBLE PRECISION DEFAULT 0.15;
      ALTER TABLE driver_earnings ADD COLUMN IF NOT EXISTS commission_amount DOUBLE PRECISION DEFAULT 0.0;
      ALTER TABLE driver_earnings ADD COLUMN IF NOT EXISTS other_deductions DOUBLE PRECISION DEFAULT 0.0;
      ALTER TABLE driver_earnings ADD COLUMN IF NOT EXISTS net_earnings DOUBLE PRECISION;
      ALTER TABLE driver_earnings ADD COLUMN IF NOT EXISTS payment_status VARCHAR(50) DEFAULT 'Paid';
      ALTER TABLE driver_earnings ADD COLUMN IF NOT EXISTS payment_method VARCHAR(50) DEFAULT 'UPI / Cash';
      UPDATE driver_earnings 
      SET gross_fare = COALESCE(gross_fare, amount),
          commission_amount = COALESCE(commission_amount, ROUND((amount * 0.15)::numeric, 2)),
          net_earnings = COALESCE(net_earnings, ROUND((amount * 0.85)::numeric, 2))
      WHERE gross_fare IS NULL OR net_earnings IS NULL;
      CREATE INDEX IF NOT EXISTS idx_driver_earnings_driver_id ON driver_earnings(driver_id);
      CREATE INDEX IF NOT EXISTS idx_driver_earnings_ride_id ON driver_earnings(ride_id);
    `);

    // 12. Ride Cancellations audit table
    await client.query(`
      CREATE TABLE IF NOT EXISTS ride_cancellations (
        id VARCHAR(64) PRIMARY KEY,
        ride_id VARCHAR(64) REFERENCES rides(id) ON DELETE CASCADE,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE SET NULL,
        user_id VARCHAR(64) REFERENCES users(id) ON DELETE SET NULL,
        cancelled_by VARCHAR(50) NOT NULL,
        reason VARCHAR(255) NOT NULL,
        notes TEXT,
        ride_status_at_cancellation VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_ride_cancellations_driver_id ON ride_cancellations(driver_id);
      CREATE INDEX IF NOT EXISTS idx_ride_cancellations_ride_id ON ride_cancellations(ride_id);
      CREATE INDEX IF NOT EXISTS idx_ride_cancellations_user_id ON ride_cancellations(user_id);
    `);

    // Base pricing configuration if none exists
    const priceRes = await client.query(`SELECT * FROM prices LIMIT 1;`);
    if (priceRes.rows.length === 0) {
      await client.query(`INSERT INTO prices (base_price, price_per_km) VALUES (50.0, 15.0);`);
    }

    console.log("All PostgreSQL base tables verified/created successfully.");

    // Run normalized schema migrations
    const { runMigrations } = require("./migration_runner");
    await runMigrations();
  } catch (err) {
    console.error("Error initializing PostgreSQL schema:", err.message);
  } finally {
    client.release();
  }
}

module.exports = {
  pool,
  query,
  initPostgresDatabase,
};