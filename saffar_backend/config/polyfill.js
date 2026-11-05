// Node.js 25+ compatibility polyfill for legacy dependencies (jwa, jsonwebtoken, etc.)
const bufferModule = require("buffer");
if (!bufferModule.SlowBuffer) {
  bufferModule.SlowBuffer = bufferModule.Buffer;
}

module.exports = bufferModule;
