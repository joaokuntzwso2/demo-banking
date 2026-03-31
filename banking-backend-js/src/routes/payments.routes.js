const express = require("express");
const { getState } = require("../stores/memory.store");
const { nowIso, nowIdTs, hoursDiff } = require("../utils/time");
const { assertRequired, notFound, badRequest, forbidden } = require("../utils/validation");

const router = express.Router();

router.post("/pix", (req, res, next) => {
  try {
    const body = req.body || {};
    assertRequired(body, ["accountId", "beneficiaryName", "beneficiaryBank", "amountBr"]);

    const state = getState();
    const account = state.accountsDb?.[body.accountId];
    if (!account) throw notFound("Account not found");
    if (account.status !== "ACTIVE") throw forbidden("Account is not active");
    if (typeof body.amountBr !== "number" || body.amountBr <= 0) throw badRequest("amountBr must be > 0");
    if (body.amountBr > account.availableBalance) throw badRequest("Insufficient balance");
    if (body.amountBr > account.dailyPixLimit) throw forbidden("PIX daily limit exceeded");

    account.availableBalance = Number((account.availableBalance - body.amountBr).toFixed(2));
    account.ledgerBalance = account.availableBalance;
    account.lastUpdatedAt = nowIso();

    const paymentId = `PMT-PIX-${nowIdTs()}`;
    const createdAt = nowIso();
    const payment = {
      paymentId,
      accountId: account.accountId,
      paymentRail: "PIX",
      beneficiaryName: body.beneficiaryName,
      beneficiaryBank: body.beneficiaryBank,
      amountBr: body.amountBr,
      status: body.amountBr >= 3000 ? "PENDING_REVIEW" : "PROCESSING",
      createdAt,
      lastUpdatedAt: createdAt
    };

    state.paymentsStore[paymentId] = payment;
    return res.status(201).json(payment);
  } catch (e) {
    return next(e);
  }
});

router.get("/:paymentId", (req, res) => {
  const payment = getState().paymentsStore?.[req.params.paymentId];
  if (!payment) return res.status(404).json({ message: "Payment not found" });

  if (payment.status === "PROCESSING" && hoursDiff(payment.createdAt) > 0.05) {
    payment.status = "SETTLED";
    payment.lastUpdatedAt = nowIso();
  }

  return res.json(payment);
});

router.get("/", (_req, res) => {
  const all = Object.values(getState().paymentsStore || {}).sort(
    (a, b) => new Date(b.createdAt) - new Date(a.createdAt)
  );
  res.json(all.slice(0, 50));
});

module.exports = router;
