const express = require("express");
const { getState } = require("../stores/memory.store");
const { nowIso, nowIdTs, hoursDiff } = require("../utils/time");
const { assertRequired, notFound, badRequest, forbidden } = require("../utils/validation");

const router = express.Router();

router.post("/ted", (req, res, next) => {
  try {
    const body = req.body || {};
    assertRequired(body, ["fromAccountId", "toBankCode", "toAccountMasked", "amountBr", "channel"]);

    const state = getState();
    const account = state.accountsDb?.[body.fromAccountId];
    if (!account) throw notFound("Origin account not found");
    if (account.status !== "ACTIVE") throw forbidden("Origin account is not active");
    if (typeof body.amountBr !== "number" || body.amountBr <= 0) throw badRequest("amountBr must be > 0");
    if (body.amountBr > account.availableBalance) throw badRequest("Insufficient balance");

    const createdAt = nowIso();
    const transferId = `TRF-${nowIdTs()}`;
    const needsReview = body.amountBr >= 10000;
    const transfer = {
      transferId,
      fromAccountId: body.fromAccountId,
      toBankCode: body.toBankCode,
      toAccountMasked: body.toAccountMasked,
      amountBr: body.amountBr,
      channel: body.channel,
      status: needsReview ? "PENDING_REVIEW" : "PROCESSING",
      createdAt,
      lastUpdatedAt: createdAt
    };

    if (!needsReview) {
      account.availableBalance = Number((account.availableBalance - body.amountBr).toFixed(2));
      account.ledgerBalance = account.availableBalance;
      account.lastUpdatedAt = createdAt;
    }

    state.transfersStore[transferId] = transfer;
    return res.status(201).json(transfer);
  } catch (e) {
    return next(e);
  }
});

router.get("/:transferId", (req, res) => {
  const state = getState();
  const transfer = state.transfersStore?.[req.params.transferId];
  if (!transfer) return res.status(404).json({ message: "Transfer not found" });

  if (transfer.status === "PROCESSING" && hoursDiff(transfer.createdAt) > 0.1) {
    transfer.status = "SETTLED";
    transfer.lastUpdatedAt = nowIso();
  }

  return res.json(transfer);
});

router.get("/", (_req, res) => {
  const all = Object.values(getState().transfersStore || {}).sort(
    (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
  );
  res.json(all.slice(0, 50));
});

module.exports = router;
