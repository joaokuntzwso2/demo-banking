const express = require("express");
const { getState } = require("../stores/memory.store");

const router = express.Router();

router.get("/profile/:customerId", (req, res) => {
  const { customerId } = req.params;
  const state = getState();
  const customer = state.customersDb?.[customerId];

  if (!customer) {
    return res.json({
      exists: false,
      customerId,
      message: "Customer not found in the demo database"
    });
  }

  const accounts = (customer.accounts || []).map((accountId) => state.accountsDb?.[accountId]).filter(Boolean);
  const cards = (customer.cards || []).map((cardId) => state.cardsDb?.[cardId]).filter(Boolean);

  return res.json({
    exists: true,
    customerId: customer.customerId,
    cpf: customer.cpf,
    name: customer.name,
    kycStatus: customer.kycStatus,
    riskRating: customer.riskRating,
    preferredBranchId: customer.preferredBranchId,
    accounts,
    cards
  });
});

module.exports = router;
