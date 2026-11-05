const { query } = require("../db");

async function up(client) {
  // 1. App Settings Table
  await client.query(`
    CREATE TABLE IF NOT EXISTS app_settings (
      key VARCHAR(100) PRIMARY KEY,
      value_json JSONB NOT NULL,
      description TEXT,
      category VARCHAR(50) DEFAULT 'general',
      is_public BOOLEAN DEFAULT false,
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
  `);

  // Seed default matching and pricing settings if missing
  const defaultSettings = [
    { key: "matching.initial_radius_km", val: 2, desc: "Initial driver search radius in km", cat: "matching" },
    { key: "matching.second_radius_km", val: 5, desc: "Secondary driver search radius in km", cat: "matching" },
    { key: "matching.third_radius_km", val: 8, desc: "Tertiary driver search radius in km", cat: "matching" },
    { key: "matching.offer_expiry_seconds", val: 15, desc: "Driver offer timeout in seconds", cat: "matching" },
    { key: "matching.max_candidates_per_batch", val: 10, desc: "Maximum drivers dispatched in a batch", cat: "matching" },
    { key: "matching.max_search_duration_seconds", val: 60, desc: "Maximum total search timeout in seconds", cat: "matching" },
    { key: "pricing.commission_rate", val: 0.15, desc: "Saffar platform commission rate (15%)", cat: "pricing" },
    { key: "pricing.base_fare_minor.bike", val: 3000, desc: "Bike base fare in paise (₹30.00)", cat: "pricing" },
    { key: "pricing.base_fare_minor.auto", val: 4500, desc: "Auto base fare in paise (₹45.00)", cat: "pricing" },
    { key: "pricing.base_fare_minor.car", val: 8000, desc: "Car base fare in paise (₹80.00)", cat: "pricing" },
    { key: "pricing.per_km_minor.bike", val: 1000, desc: "Bike rate per km in paise (₹10.00/km)", cat: "pricing" },
    { key: "pricing.per_km_minor.auto", val: 1500, desc: "Auto rate per km in paise (₹15.00/km)", cat: "pricing" },
    { key: "pricing.per_km_minor.car", val: 2200, desc: "Car rate per km in paise (₹22.00/km)", cat: "pricing" },
    { key: "location.stale_timeout_seconds", val: 180, desc: "Driver location staleness threshold in seconds", cat: "location" }
  ];

  for (const s of defaultSettings) {
    await client.query(`
      INSERT INTO app_settings (key, value_json, description, category)
      VALUES ($1, $2, $3, $4)
      ON CONFLICT (key) DO NOTHING;
    `, [s.key, JSON.stringify(s.val), s.desc, s.cat]);
  }

  // 2. User Profiles Table (1:1 with users)
  await client.query(`
    CREATE TABLE IF NOT EXISTS user_profiles (
      id VARCHAR(64) PRIMARY KEY,
      user_id VARCHAR(64) UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      full_name VARCHAR(255) NOT NULL,
      avatar_url TEXT,
      primary_address VARCHAR(1000),
      default_payment_method VARCHAR(50) DEFAULT 'UPI',
      rating DOUBLE PRECISION DEFAULT 5.0,
      total_rides INT DEFAULT 0,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_user_profiles_user_id ON user_profiles(user_id);

    -- Auto-seed user_profiles from existing users table
    INSERT INTO user_profiles (id, user_id, full_name, avatar_url, primary_address)
    SELECT 'prof_' || id, id, name, image_url, address
    FROM users
    WHERE id NOT IN (SELECT user_id FROM user_profiles)
    ON CONFLICT (user_id) DO NOTHING;
  `);

  // 3. Driver Profiles Table (1:1 with drivers)
  await client.query(`
    CREATE TABLE IF NOT EXISTS driver_profiles (
      id VARCHAR(64) PRIMARY KEY,
      driver_id VARCHAR(64) UNIQUE NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
      full_name VARCHAR(255) NOT NULL,
      avatar_url TEXT,
      age INT,
      gender VARCHAR(50),
      address TEXT,
      rating DOUBLE PRECISION DEFAULT 5.0,
      total_trips INT DEFAULT 0,
      acceptance_rate DOUBLE PRECISION DEFAULT 1.0,
      cancellation_rate DOUBLE PRECISION DEFAULT 0.0,
      verification_status VARCHAR(50) DEFAULT 'approved',
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_driver_profiles_driver_id ON driver_profiles(driver_id);

    -- Auto-seed driver_profiles from existing drivers table
    INSERT INTO driver_profiles (id, driver_id, full_name, avatar_url, age, gender, address, verification_status)
    SELECT 'dprof_' || id, id, name, image_url, age, gender, address, COALESCE(verification_status, 'approved')
    FROM drivers
    WHERE id NOT IN (SELECT driver_id FROM driver_profiles)
    ON CONFLICT (driver_id) DO NOTHING;
  `);

  // 4. Vehicles Table (complements / aliases driver_vehicles)
  await client.query(`
    CREATE TABLE IF NOT EXISTS vehicles (
      id VARCHAR(64) PRIMARY KEY,
      driver_id VARCHAR(64) NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
      category VARCHAR(50) NOT NULL, -- 'Bike', 'Auto', 'Car'
      model VARCHAR(255) NOT NULL,
      registration_number VARCHAR(100) NOT NULL,
      color VARCHAR(50) NOT NULL,
      is_active BOOLEAN DEFAULT true,
      verification_status VARCHAR(50) DEFAULT 'approved',
      rejection_reason TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_vehicles_driver_id ON vehicles(driver_id);
    CREATE INDEX IF NOT EXISTS idx_vehicles_active_cat ON vehicles(category, is_active, verification_status);

    -- Auto-sync from driver_vehicles if populated
    INSERT INTO vehicles (id, driver_id, category, model, registration_number, color, is_active, verification_status)
    SELECT id, driver_id, category, model, registration_number, color, is_active, verification_status
    FROM driver_vehicles
    WHERE id NOT IN (SELECT id FROM vehicles)
    ON CONFLICT (id) DO NOTHING;
  `);

  // 5. Driver Documents Table
  await client.query(`
    CREATE TABLE IF NOT EXISTS driver_documents (
      id VARCHAR(64) PRIMARY KEY,
      driver_id VARCHAR(64) NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
      vehicle_id VARCHAR(64) REFERENCES vehicles(id) ON DELETE SET NULL,
      document_type VARCHAR(50) NOT NULL, -- 'DRIVING_LICENSE', 'RC', 'INSURANCE'
      document_number VARCHAR(100),
      expiry_date VARCHAR(50),
      document_url TEXT NOT NULL,
      verification_status VARCHAR(50) DEFAULT 'approved',
      rejection_reason TEXT,
      verified_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id ON driver_documents(driver_id);
  `);

  // 6. Driver Availability State Table
  await client.query(`
    CREATE TABLE IF NOT EXISTS driver_availability (
      driver_id VARCHAR(64) PRIMARY KEY REFERENCES drivers(id) ON DELETE CASCADE,
      state VARCHAR(50) NOT NULL DEFAULT 'OFFLINE', -- 'OFFLINE', 'ONLINE_AVAILABLE', 'OFFER_PENDING', 'ON_TRIP', 'TEMPORARILY_UNAVAILABLE'
      current_ride_id VARCHAR(64) REFERENCES rides(id) ON DELETE SET NULL,
      last_state_change TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_driver_availability_state ON driver_availability(state);

    -- Seed availability from drivers table
    INSERT INTO driver_availability (driver_id, state)
    SELECT id, CASE WHEN is_online = true THEN 'ONLINE_AVAILABLE' ELSE 'OFFLINE' END
    FROM drivers
    WHERE id NOT IN (SELECT driver_id FROM driver_availability)
    ON CONFLICT (driver_id) DO NOTHING;
  `);

  // 7. Driver Locations Table (latest snapshot)
  await client.query(`
    CREATE TABLE IF NOT EXISTS driver_locations (
      driver_id VARCHAR(64) PRIMARY KEY REFERENCES drivers(id) ON DELETE CASCADE,
      latitude DOUBLE PRECISION NOT NULL,
      longitude DOUBLE PRECISION NOT NULL,
      heading DOUBLE PRECISION DEFAULT 0.0,
      speed DOUBLE PRECISION DEFAULT 0.0,
      accuracy DOUBLE PRECISION DEFAULT 5.0,
      is_stale BOOLEAN DEFAULT false,
      recorded_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_driver_locations_coords ON driver_locations(latitude, longitude);
  `);

  // 8. Prevent duplicate active ride assignment to the same driver
  await client.query(`
    CREATE UNIQUE INDEX IF NOT EXISTS idx_unique_active_driver_ride 
    ON rides(driver_id) 
    WHERE status IN ('accepted', 'reaching_pickup', 'arrived', 'in_progress');
  `);

  // 9. Ride Status History (Audit trail of every state transition)
  await client.query(`
    CREATE TABLE IF NOT EXISTS ride_status_history (
      id VARCHAR(64) PRIMARY KEY,
      ride_id VARCHAR(64) NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
      old_status VARCHAR(50),
      new_status VARCHAR(50) NOT NULL,
      triggered_by_role VARCHAR(50) NOT NULL, -- 'customer', 'driver', 'system'
      triggered_by_id VARCHAR(64),
      notes TEXT,
      metadata JSONB,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_ride_status_history_ride_id ON ride_status_history(ride_id);
  `);

  // 10. Ride Offers (Normalized dispatch candidates tracking)
  await client.query(`
    CREATE TABLE IF NOT EXISTS ride_offers (
      id VARCHAR(64) PRIMARY KEY,
      ride_id VARCHAR(64) NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
      driver_id VARCHAR(64) NOT NULL REFERENCES drivers(id) ON DELETE CASCADE,
      batch_number INT DEFAULT 1,
      search_ring VARCHAR(20) DEFAULT 'ring_1', -- 'ring_1' (2km), 'ring_2' (5km), 'ring_3' (8km)
      distance_km DOUBLE PRECISION NOT NULL,
      eta_minutes INT NOT NULL,
      status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'ACCEPTED', 'REJECTED', 'EXPIRED'
      score DOUBLE PRECISION DEFAULT 0.0,
      offered_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      expires_at TIMESTAMP WITH TIME ZONE NOT NULL,
      responded_at TIMESTAMP WITH TIME ZONE,
      UNIQUE(ride_id, driver_id)
    );
    CREATE INDEX IF NOT EXISTS idx_ride_offers_driver_status ON ride_offers(driver_id, status);
    CREATE INDEX IF NOT EXISTS idx_ride_offers_ride_id ON ride_offers(ride_id);
  `);

  // 11. Fare Estimates & Breakdowns in Integer Minor Units (Paise)
  await client.query(`
    CREATE TABLE IF NOT EXISTS fare_estimates (
      id VARCHAR(64) PRIMARY KEY,
      ride_id VARCHAR(64) REFERENCES rides(id) ON DELETE CASCADE,
      vehicle_category VARCHAR(50) NOT NULL,
      distance_meters INT NOT NULL,
      duration_seconds INT NOT NULL,
      estimated_fare_minor INT NOT NULL, -- integer paisa
      currency VARCHAR(10) DEFAULT 'INR',
      surge_multiplier DOUBLE PRECISION DEFAULT 1.0,
      expires_at TIMESTAMP WITH TIME ZONE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );

    CREATE TABLE IF NOT EXISTS fare_breakdowns (
      id VARCHAR(64) PRIMARY KEY,
      ride_id VARCHAR(64) UNIQUE NOT NULL REFERENCES rides(id) ON DELETE RESTRICT, -- protect completed ride accounting
      currency VARCHAR(10) DEFAULT 'INR',
      base_fare_minor INT NOT NULL,
      distance_fare_minor INT NOT NULL,
      time_fare_minor INT DEFAULT 0,
      surge_amount_minor INT DEFAULT 0,
      platform_fee_minor INT NOT NULL, -- 15% platform commission
      taxes_minor INT DEFAULT 0,
      tip_amount_minor INT DEFAULT 0,
      discount_minor INT DEFAULT 0,
      total_fare_minor INT NOT NULL,
      driver_net_earnings_minor INT NOT NULL,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_fare_breakdowns_ride_id ON fare_breakdowns(ride_id);
  `);

  // 12. Payments Table (Idempotent, integer minor units, preventing duplicate payments)
  await client.query(`
    CREATE TABLE IF NOT EXISTS payments (
      id VARCHAR(64) PRIMARY KEY,
      ride_id VARCHAR(64) NOT NULL REFERENCES rides(id) ON DELETE RESTRICT,
      user_id VARCHAR(64) NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
      amount_minor INT NOT NULL,
      currency VARCHAR(10) DEFAULT 'INR',
      payment_gateway VARCHAR(50) DEFAULT 'RAZORPAY', -- 'RAZORPAY', 'WALLET', 'CASH'
      gateway_order_id VARCHAR(255),
      gateway_payment_id VARCHAR(255),
      idempotency_key VARCHAR(255) UNIQUE,
      status VARCHAR(50) NOT NULL DEFAULT 'PENDING', -- 'PENDING', 'SUCCESS', 'FAILED', 'REFUNDED'
      method VARCHAR(50) DEFAULT 'UPI',
      failure_reason TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_payments_ride_id ON payments(ride_id);
    CREATE INDEX IF NOT EXISTS idx_payments_user_id ON payments(user_id);
  `);

  // 13. Wallets and Wallet Transactions
  await client.query(`
    CREATE TABLE IF NOT EXISTS wallets (
      id VARCHAR(64) PRIMARY KEY,
      entity_type VARCHAR(20) NOT NULL, -- 'USER', 'DRIVER'
      entity_id VARCHAR(64) NOT NULL,
      balance_minor BIGINT NOT NULL DEFAULT 124000, -- ₹1240.00 default in paise
      currency VARCHAR(10) DEFAULT 'INR',
      is_frozen BOOLEAN DEFAULT false,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      updated_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      UNIQUE(entity_type, entity_id)
    );

    CREATE TABLE IF NOT EXISTS wallet_transactions (
      id VARCHAR(64) PRIMARY KEY,
      wallet_id VARCHAR(64) NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
      transaction_type VARCHAR(20) NOT NULL, -- 'CREDIT', 'DEBIT'
      amount_minor INT NOT NULL,
      balance_after_minor BIGINT NOT NULL,
      reference_type VARCHAR(50) NOT NULL, -- 'RIDE_PAYMENT', 'TOPUP', 'TRIP_EARNING', 'WITHDRAWAL'
      reference_id VARCHAR(64),
      description TEXT,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);

    -- Seed user_001 wallet
    INSERT INTO wallets (id, entity_type, entity_id, balance_minor)
    VALUES ('wal_user_001', 'USER', 'user_001', 124000)
    ON CONFLICT (entity_type, entity_id) DO NOTHING;
  `);

  // 14. Normalized Ratings Table
  await client.query(`
    CREATE TABLE IF NOT EXISTS ratings (
      id VARCHAR(64) PRIMARY KEY,
      ride_id VARCHAR(64) NOT NULL REFERENCES rides(id) ON DELETE CASCADE,
      reviewer_type VARCHAR(20) NOT NULL, -- 'USER', 'DRIVER'
      reviewer_id VARCHAR(64) NOT NULL,
      reviewee_id VARCHAR(64) NOT NULL,
      rating_score DOUBLE PRECISION NOT NULL,
      tags TEXT[],
      comments TEXT,
      tip_amount_minor INT DEFAULT 0,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      UNIQUE(ride_id, reviewer_type)
    );
    CREATE INDEX IF NOT EXISTS idx_ratings_reviewee ON ratings(reviewee_id);
  `);

  // 15. In-App & Push Notifications Table
  await client.query(`
    CREATE TABLE IF NOT EXISTS notifications (
      id VARCHAR(64) PRIMARY KEY,
      recipient_type VARCHAR(20) NOT NULL, -- 'USER', 'DRIVER'
      recipient_id VARCHAR(64) NOT NULL,
      title VARCHAR(255) NOT NULL,
      body TEXT NOT NULL,
      channel VARCHAR(50) DEFAULT 'IN_APP', -- 'IN_APP', 'PUSH', 'SMS'
      data_payload JSONB,
      is_read BOOLEAN DEFAULT false,
      sent_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC'),
      created_at TIMESTAMP WITH TIME ZONE DEFAULT (NOW() AT TIME ZONE 'UTC')
    );
    CREATE INDEX IF NOT EXISTS idx_notifications_recipient ON notifications(recipient_type, recipient_id, is_read);
  `);
}

module.exports = { up };

