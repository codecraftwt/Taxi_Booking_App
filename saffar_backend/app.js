// Compatibility fix for Node.js 22/25+ (SlowBuffer removed from buffer module)
const buffer = require("buffer");
if (!buffer.SlowBuffer) {
  buffer.SlowBuffer = buffer.Buffer;
}

const express = require("express");
const cors = require("cors");
const authRouter = require("./routes/auth_router");
const rideRouter = require("./routes/ride_router");
const userRouter = require("./routes/user_router");
const driverRouter = require("./routes/driver_router");

const app = express();

// Enable CORS for Flutter Web and cross-origin requests
app.use(cors());

// Parse JSON and urlencoded request bodies
app.use(express.json());
app.use(express.urlencoded({ extended: false }));

// Health check endpoint
app.get("/", (req, res) => {
  res.status(200).json({
    status: "ok",
    message: "Saffar API is running",
    timestamp: new Date().toISOString(),
  });
});

// Mount API routes
app.use("/api/auth", authRouter);
app.use("/api/ride", rideRouter);
app.use("/api/user", userRouter);
app.use("/api/driver", driverRouter);

// 404 handler
app.use((req, res) => {
  res.status(404).json({
    error: {
      code: "NOT_FOUND",
      message: `Cannot ${req.method} ${req.originalUrl}`,
    },
  });
});

// Global error handler
app.use((err, req, res, next) => {
  console.error("Unhandled error:", err);
  res.status(500).json({
    error: {
      code: "SERVER_ERROR",
      message: err.message || "Internal server error",
    },
  });
});

module.exports = app;
