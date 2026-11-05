const tokenMiddleware = require("./token_middleware");
const securityMiddleware = require("./security_middleware");

module.exports = {
  ...tokenMiddleware,
  ...securityMiddleware,
};
