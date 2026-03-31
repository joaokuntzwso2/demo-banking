const express = require("express");
const { getState } = require("../stores/memory.store");
const { nowIso } = require("../utils/time");

const router = express.Router();

router.post("/alerts", (req, res) => {
  const alert = {
    ...(req.body || {}),
    alertId: `FRD-${Date.now()}`,
    createdAt: nowIso()
  };
  getState().fraudAlerts.push(alert);
  res.status(201).json(alert);
});

router.get("/alerts", (_req, res) => {
  res.json(getState().fraudAlerts.slice(-50));
});

module.exports = router;
