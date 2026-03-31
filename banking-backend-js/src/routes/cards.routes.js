const express = require("express");
const { getState } = require("../stores/memory.store");

const router = express.Router();

router.get("/:cardId/status", (req, res) => {
  const card = getState().cardsDb?.[req.params.cardId];
  if (!card) {
    return res.status(404).json({ message: "Card not found" });
  }

  return res.json(card);
});

module.exports = router;
