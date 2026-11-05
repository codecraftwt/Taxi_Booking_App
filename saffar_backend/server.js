// Compatibility fix for Node.js 22/25+ (SlowBuffer removed from buffer module)
const buffer = require("buffer");
if (!buffer.SlowBuffer) {
  buffer.SlowBuffer = buffer.Buffer;
}

const http = require("http");
const app = require("./app");
const config = require("./config");
const { initPostgresDatabase } = require("./database");
const { initSocket } = require("./socket");
const { initRedis } = require("./services/redisService");

const PORT = config.PORT;

async function startServer() {
  try {
    // 1. Initialize PostgreSQL database tables & normalized migrations
    await initPostgresDatabase();

    // 2. Initialize Redis Fast Ephemeral Cache
    await initRedis();

    // 3. Create HTTP server with Socket.IO
    const httpServer = http.createServer(app);
    initSocket(httpServer);

    const server = httpServer.listen(PORT, () => {
      console.log(`Server is running on PORT ${PORT}`);
      console.log(`API URL: http://localhost:${PORT}/api`);
      console.log(`Socket.IO listening on port ${PORT}`);
    });

    // Graceful shutdown
    let isShuttingDown = false;
    const shutdown = (signal) => {
      if (isShuttingDown) return;
      isShuttingDown = true;
      console.log(`Received ${signal}. Shutting down gracefully...`);
      server.close(() => {
        console.log("Server closed.");
        process.exit(0);
      });
      // Force exit after 3 seconds if existing sockets stay open
      setTimeout(() => {
        console.log("Forcefully closing server after shutdown timeout.");
        process.exit(0);
      }, 3000).unref();
    };

    process.on("SIGINT", () => shutdown("SIGINT"));
    process.on("SIGTERM", () => shutdown("SIGTERM"));
  } catch (error) {
    console.error("Failed to start server:", error.message);
    process.exit(1);
  }
}

startServer();
