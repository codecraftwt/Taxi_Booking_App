const buffer = require("buffer");
if (!buffer.SlowBuffer) {
  buffer.SlowBuffer = buffer.Buffer;
}

require("dotenv").config();
const Constant = require("./constants");
const Err = require("./error");

module.exports = {
  PORT: process.env.PORT || 5000,
  TOKEN_SECRET_KEY: process.env.TOKEN_SECRET_KEY || "saffar_super_secret_jwt_key_2026",
  TOKEN_EXPIRY_TIME: process.env.TOKEN_EXPIRY_TIME || "30d",
  PGHOST: process.env.PGHOST || "localhost",
  PGPORT: parseInt(process.env.PGPORT || "5432", 10),
  PGUSER: process.env.PGUSER || "postgres",
  PGPASSWORD: process.env.PGPASSWORD || "admin",
  PGDATABASE: process.env.PGDATABASE || "postgres",
  DATABASE_URL: process.env.DATABASE_URL,
  DATABASE_SSL: process.env.DATABASE_SSL === "true",
  MONGODB_CONNECTION_URL: process.env.MONGODB_CONNECTION_URL,
  Constant,
  Err,
};
