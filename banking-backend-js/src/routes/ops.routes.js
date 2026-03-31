const express = require("express");
const { getState } = require("../stores/memory.store");
const { nowIso } = require("../utils/time");

const router = express.Router();

router.post("/processor-events", (req, res) => {
  const event = { ...(req.body || {}), receivedAt: nowIso() };
  getState().processorEvents.push(event);
  console.log("Processor event from MI:", JSON.stringify(event, null, 2));
  return res.status(202).json({ status: "RECEIVED", count: getState().processorEvents.length });
});

router.get("/processor-events", (_req, res) => {
  res.json([...getState().processorEvents].reverse().slice(0, 50));
});

module.exports = router;
