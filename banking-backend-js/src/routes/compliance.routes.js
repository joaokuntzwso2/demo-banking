const express = require("express");
const { getState } = require("../stores/memory.store");
const { nowIso } = require("../utils/time");

const router = express.Router();

router.post("/audit", (req, res) => {
  const state = getState();
  const event = {
    ...(req.body || {}),
    complianceId: `CMP-${Date.now()}`,
    createdAt: nowIso()
  };

  state.complianceEvents.push(event);
  res.status(201).json(event);
});

router.get("/audit", (_req, res) => {
  res.json(getState().complianceEvents.slice(-50));
});

module.exports = router;
