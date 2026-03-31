const express = require("express");
const router = express.Router();

router.get("/health", (req, res) => {
  res.json({
    status: "UP",
    component: "Banking-Backend-BR",
    correlationId: req.ctx?.correlationId
  });
});

module.exports = router;
