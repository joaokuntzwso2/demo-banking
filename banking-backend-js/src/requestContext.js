const crypto = require("crypto");

function requestContext(req, _res, next) {
  const incoming =
    req.get("x-correlation-id") ||
    req.get("x-fapi-interaction-id") ||
    req.get("x-request-id");

  req.ctx = {
    correlationId: incoming || `corr-${crypto.randomUUID()}`,
    receivedAt: new Date().toISOString(),
    clientIp: req.ip
  };

  next();
}

module.exports = { requestContext };
