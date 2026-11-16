const { createClient } = require("redis");

const redisClient = createClient({
  socket: {
    host: process.env.REDIS_HOST || "127.0.0.1",
    port: Number(process.env.REDIS_PORT || 6379),
  },
  password: process.env.REDIS_PASSWORD|| "redispass@123" ,
});

redisClient.on("error", (error) => {
  console.error("Redis Error:", error);
});

redisClient.on("connect", () => {
  console.log("Redis connecting...");
});

redisClient.on("ready", () => {
  console.log("Redis connected successfully!");
});

async function connectRedis() {
  if (!redisClient.isOpen) {
    try {
      await redisClient.connect();
    } catch (err) {
      console.warn("[REDIS] Could not connect to Redis daemon:", err.message);
    }
  }
}

module.exports = {
  redisClient,
  connectRedis,
};