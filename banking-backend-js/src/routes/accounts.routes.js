const express = require("express");
const { getState } = require("../stores/memory.store");

const router = express.Router();

router.get("/:accountId/balance", (req, res) => {
  const { accountId } = req.params;
  const account = getState().accountsDb?.[accountId];

  if (!account) {
    return res.status(404).json({ message: "Account not found" });
  }

  return res.json({
    accountId: account.accountId,
    accountType: account.accountType,
    currency: account.currency,
    availableBalance: account.availableBalance,
    ledgerBalance: account.ledgerBalance,
    status: account.status,
    dailyPixLimit: account.dailyPixLimit,
    lastUpdatedAt: account.lastUpdatedAt
  });
});

module.exports = router;
