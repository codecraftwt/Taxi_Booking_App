const { Pool } = require("pg");
const mongoose = require("mongoose");
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
        image_url VARCHAR(1000),
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

    // 5. Prices table
    await client.query(`
      CREATE TABLE IF NOT EXISTS prices (
        id SERIAL PRIMARY KEY,
        base_price DOUBLE PRECISION NOT NULL,
        price_per_km DOUBLE PRECISION NOT NULL
      );
    `);

    // Seed initial price if none exists
    const priceRes = await client.query(`SELECT * FROM prices LIMIT 1;`);
    if (priceRes.rows.length === 0) {
      await client.query(`INSERT INTO prices (base_price, price_per_km) VALUES (50.0, 15.0);`);
      console.log("Seeded default pricing: base_price=50, price_per_km=15");
    }

    console.log("All PostgreSQL tables verified/created successfully.");
  } catch (err) {
    console.error("Error initializing PostgreSQL schema:", err.message);
  } finally {
    client.release();
  }
}

// Connect to MongoDB if configured
async function connectMongo() {
  if (config.MONGODB_CONNECTION_URL) {
    try {
      await mongoose.connect(config.MONGODB_CONNECTION_URL);
      console.log("Connected to MongoDB successfully!");
    } catch (error) {
      console.log("MongoDB connection error:", error.message);
    }
  }
}

module.exports = {
  pool,
  query,
  initPostgresDatabase,
  connectMongo,
};

