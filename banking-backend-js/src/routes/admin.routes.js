const express = require("express");
const { getState, resetState } = require("../stores/memory.store");

const router = express.Router();

function summarize(state) {
  return {
    customers: Object.keys(state.customersDb || {}).length,
    accounts: Object.keys(state.accountsDb || {}).length,
    cards: Object.keys(state.cardsDb || {}).length,
    payments: Object.keys(state.paymentsStore || {}).length,
    transfers: Object.keys(state.transfersStore || {}).length,
    complianceEvents: (state.complianceEvents || []).length,
    fraudAlerts: (state.fraudAlerts || []).length,
    processorEvents: (state.processorEvents || []).length
  };
}

router.post("/reset", (_req, res) => {
  res.json({ status: "RESET", snapshot: summarize(resetState()) });
});

router.get("/snapshot", (_req, res) => {
  res.json({ snapshot: summarize(getState()) });
});

module.exports = router;
