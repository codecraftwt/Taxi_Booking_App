const buffer = require("buffer");
if (!buffer.SlowBuffer) {
  buffer.SlowBuffer = buffer.Buffer;
}
if (typeof global !== "undefined" && !global.SlowBuffer) {
  global.SlowBuffer = buffer.Buffer;
}

