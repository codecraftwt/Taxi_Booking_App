// Compatibility fix for Node.js 22/25+ (SlowBuffer removed from buffer module)
const buffer = require("buffer");
if (!buffer.SlowBuffer) {
  buffer.SlowBuffer = buffer.Buffer;
}

const app = require("./app");
const config = require("./config");
const { initPostgresDatabase, connectMongo } = require("./database");

const PORT = config.PORT;

async function startServer() {
  try {
    // 1. Initialize PostgreSQL database tables
    await initPostgresDatabase();

    // 2. Connect to MongoDB if configured
    await connectMongo();

    // 3. Start Express server
    const server = app.listen(PORT, () => {
      console.log(`Server is running on PORT ${PORT}`);
      console.log(`API URL: http://localhost:${PORT}/api`);
    });

    // Graceful shutdown
    const shutdown = () => {
      console.log("Shutting down gracefully...");
      server.close(() => {
        console.log("Server closed.");
        process.exit(0);
      });
    };

    process.on("SIGINT", shutdown);
    process.on("SIGTERM", shutdown);
  } catch (error) {
    console.error("Failed to start server:", error.message);
    process.exit(1);
  }
}

startServer();
