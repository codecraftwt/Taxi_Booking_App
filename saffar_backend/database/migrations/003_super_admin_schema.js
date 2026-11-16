const bcrypt = require("bcrypt");
const { v4: uuidv4 } = require("uuid");

module.exports = {
  id: "003_super_admin_schema",
  description: "Create admin_users, admin_audit_logs, fare_configs, driver_documents, and driver_settlements",
  async up(client) {
    // 1. Admin Users Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS admin_users (
        id VARCHAR(64) PRIMARY KEY,
        name VARCHAR(255) NOT NULL,
        email VARCHAR(255) NOT NULL,
        password VARCHAR(255) NOT NULL,
        role VARCHAR(50) DEFAULT 'super_admin',
        is_active BOOLEAN DEFAULT TRUE,
        last_login_at TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idx_admin_users_email_uniq ON admin_users(email);
    `);

    // 2. Admin Audit Logs Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS admin_audit_logs (
        id VARCHAR(64) PRIMARY KEY,
        admin_id VARCHAR(64) REFERENCES admin_users(id) ON DELETE SET NULL,
        admin_name VARCHAR(255),
        action VARCHAR(100) NOT NULL,
        target_type VARCHAR(50),
        target_id VARCHAR(64),
        details TEXT,
        ip_address VARCHAR(50),
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_action ON admin_audit_logs(action);
      CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_created ON admin_audit_logs(created_at);
    `);

    // 3. Fare Configurations Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS fare_configs (
        id VARCHAR(64) PRIMARY KEY,
        category VARCHAR(50) NOT NULL,
        base_fare DOUBLE PRECISION NOT NULL,
        per_km DOUBLE PRECISION NOT NULL,
        per_minute DOUBLE PRECISION NOT NULL,
        minimum_fare DOUBLE PRECISION NOT NULL,
        booking_fee DOUBLE PRECISION DEFAULT 10.0,
        waiting_charge_per_min DOUBLE PRECISION DEFAULT 1.5,
        free_waiting_minutes INT DEFAULT 5,
        cancellation_fee DOUBLE PRECISION DEFAULT 25.0,
        commission_percentage DOUBLE PRECISION DEFAULT 15.0,
        surge_multiplier DOUBLE PRECISION DEFAULT 1.0,
        is_active BOOLEAN DEFAULT TRUE,
        updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE UNIQUE INDEX IF NOT EXISTS idx_fare_configs_cat_uniq ON fare_configs(category);

      -- Seed standard default fare configurations using WHERE NOT EXISTS
      INSERT INTO fare_configs (id, category, base_fare, per_km, per_minute, minimum_fare, booking_fee, commission_percentage)
      SELECT 'fare_bike', 'Bike', 20.0, 8.0, 1.0, 30.0, 5.0, 15.0
      WHERE NOT EXISTS (SELECT 1 FROM fare_configs WHERE category = 'Bike');

      INSERT INTO fare_configs (id, category, base_fare, per_km, per_minute, minimum_fare, booking_fee, commission_percentage)
      SELECT 'fare_auto', 'Auto', 30.0, 12.0, 1.5, 40.0, 8.0, 15.0
      WHERE NOT EXISTS (SELECT 1 FROM fare_configs WHERE category = 'Auto');

      INSERT INTO fare_configs (id, category, base_fare, per_km, per_minute, minimum_fare, booking_fee, commission_percentage)
      SELECT 'fare_car', 'Car', 50.0, 15.0, 2.0, 70.0, 10.0, 15.0
      WHERE NOT EXISTS (SELECT 1 FROM fare_configs WHERE category = 'Car');

      INSERT INTO fare_configs (id, category, base_fare, per_km, per_minute, minimum_fare, booking_fee, commission_percentage)
      SELECT 'fare_sedan', 'Prime Sedan', 70.0, 18.0, 2.5, 90.0, 15.0, 18.0
      WHERE NOT EXISTS (SELECT 1 FROM fare_configs WHERE category = 'Prime Sedan');
    `);

    // 4. Driver Individual Documents Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS driver_documents (
        id VARCHAR(64) PRIMARY KEY,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE CASCADE,
        document_type VARCHAR(50) NOT NULL,
        document_number VARCHAR(100),
        document_url TEXT,
        expiry_date VARCHAR(50),
        verification_status VARCHAR(50) DEFAULT 'pending',
        rejection_reason TEXT,
        verified_by VARCHAR(64),
        verified_at TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_driver_documents_driver_id ON driver_documents(driver_id);
      CREATE INDEX IF NOT EXISTS idx_driver_documents_status ON driver_documents(verification_status);
      CREATE UNIQUE INDEX IF NOT EXISTS idx_driver_documents_driver_doc_type ON driver_documents(driver_id, document_type);

      -- Populate initial documents from driver_vehicles only if authentic document was uploaded
      INSERT INTO driver_documents (id, driver_id, document_type, document_number, document_url, expiry_date, verification_status)
      SELECT 
        'doc_dl_' || dv.driver_id,
        dv.driver_id,
        'driving_license',
        dv.driving_license_number,
        dv.driving_license_doc,
        dv.driving_license_expiry,
        dv.verification_status
      FROM driver_vehicles dv
      WHERE dv.driver_id IS NOT NULL AND dv.driving_license_doc IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM driver_documents dd
          WHERE dd.driver_id = dv.driver_id AND dd.document_type = 'driving_license'
        );

      INSERT INTO driver_documents (id, driver_id, document_type, document_number, document_url, verification_status)
      SELECT 
        'doc_rc_' || dv.driver_id,
        dv.driver_id,
        'rc',
        dv.rc_number,
        dv.rc_doc,
        dv.verification_status
      FROM driver_vehicles dv
      WHERE dv.driver_id IS NOT NULL AND dv.rc_doc IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM driver_documents dd
          WHERE dd.driver_id = dv.driver_id AND dd.document_type = 'rc'
        );

      INSERT INTO driver_documents (id, driver_id, document_type, document_number, document_url, expiry_date, verification_status)
      SELECT 
        'doc_ins_' || dv.driver_id,
        dv.driver_id,
        'insurance',
        dv.insurance_policy_number,
        dv.insurance_doc,
        dv.insurance_expiry,
        dv.verification_status
      FROM driver_vehicles dv
      WHERE dv.driver_id IS NOT NULL AND dv.insurance_doc IS NOT NULL
        AND NOT EXISTS (
          SELECT 1 FROM driver_documents dd
          WHERE dd.driver_id = dv.driver_id AND dd.document_type = 'insurance'
        );
    `);

    // 5. Driver Settlements Table
    await client.query(`
      CREATE TABLE IF NOT EXISTS driver_settlements (
        id VARCHAR(64) PRIMARY KEY,
        driver_id VARCHAR(64) REFERENCES drivers(id) ON DELETE CASCADE,
        gross_amount DOUBLE PRECISION NOT NULL,
        commission_amount DOUBLE PRECISION NOT NULL,
        net_payable DOUBLE PRECISION NOT NULL,
        status VARCHAR(50) DEFAULT 'pending',
        reference_no VARCHAR(100),
        period_start TIMESTAMP WITH TIME ZONE,
        period_end TIMESTAMP WITH TIME ZONE,
        created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
      );
      CREATE INDEX IF NOT EXISTS idx_driver_settlements_driver ON driver_settlements(driver_id);
    `);

    // 6. Seed Super Admin User
    const defaultPasswordHash = await bcrypt.hash("AdminPassword@2026", 10);
    await client.query(`
      INSERT INTO admin_users (id, name, email, password, role, is_active)
      SELECT 
        'admin_super_001',
        'Saffar Super Admin',
        'admin@saffar.com',
        $1,
        'super_admin',
        true
      WHERE NOT EXISTS (
        SELECT 1 FROM admin_users WHERE email = 'admin@saffar.com'
      );
    `, [defaultPasswordHash]);
  }
};
