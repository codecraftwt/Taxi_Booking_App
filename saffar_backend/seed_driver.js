require('dotenv').config();
const { query } = require('./database');

async function seedDriver() {
  try {
    const res = await query(`
      INSERT INTO drivers (id, name, phone, password, vehicle_name, vehicle_number, email, image_url, active)
      VALUES (
        'driver_001',
        'Raj Driver',
        '9988776655',
        '$2b$10$SHMDhyEl5zxlWFTAebCUXeJUz8uYQdeOXgOuQ369bSBoelfqQ7jgu',
        'Toyota Innova',
        'MH01AB1234',
        'driver@saffar.com',
        'https://randomuser.me/api/portraits/men/32.jpg',
        true
      )
      ON CONFLICT (phone) DO UPDATE 
      SET password = EXCLUDED.password, active = true
      RETURNING *;
    `);

    console.log("DRIVER_UPDATED_WITH_ADMIN1234:", res.rows[0]);
    process.exit(0);
  } catch (err) {
    console.error("Error inserting driver:", err);
    process.exit(1);
  }
}

seedDriver();
