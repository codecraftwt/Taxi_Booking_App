// Compatibility fix for Node.js 22/25+ (SlowBuffer removed from buffer module)
const buffer = require("buffer");
if (!buffer.SlowBuffer) {
  buffer.SlowBuffer = buffer.Buffer;
}

const express = require("express");
const cors = require("cors");
const path = require("path");

// User Routes
const userRouter = require("./routes/user/user_router");
const rideRouter = require("./routes/user/ride_router");

// Driver Routes
const driverRouter = require("./routes/driver/driver_router");

// Shared Routes
const authRouter = require("./routes/shared/auth_router");
const paymentRouter = require("./routes/shared/payment_router");
const { apiRateLimiter, authRateLimiter } = require("./middlewares/security_middleware");

const app = express();

// Enable CORS for Flutter Web, iOS, Android and cross-origin requests
app.use(cors());

// Parse JSON and capture raw body for cryptographic webhook signature verification
app.use(express.json({
  limit: "15mb",
  verify: (req, res, buf) => {
    req.rawBody = buf.toString();
  }
}));
app.use(express.urlencoded({ extended: false, limit: "15mb" }));

// General API Rate Limiting (200 requests / minute)
app.use("/api", apiRateLimiter);

// Serve static uploads
app.use("/uploads", express.static(path.join(__dirname, "uploads")));

// Health check endpoint
app.get("/", (req, res) => {
  res.status(200).json({
    status: "ok",
    message: "Saffar API is running",
    timestamp: new Date().toISOString(),
  });
});

// Mount API routes
app.use("/api/auth", authRateLimiter, authRouter);
app.use("/api/ride", rideRouter);
app.use("/api/user", userRouter);
app.use("/api/driver", driverRouter);
app.use("/api/payment", paymentRouter);

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
