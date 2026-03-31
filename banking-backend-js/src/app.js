const express = require("express");
const { requestContext } = require("./requestContext");
const { notFoundHandler } = require("./middleware/notFound");
const { errorHandler } = require("./middleware/errorHandler");

const healthRoutes = require("./routes/health.routes");
const adminRoutes = require("./routes/admin.routes");
const customersRoutes = require("./routes/customers.routes");
const accountsRoutes = require("./routes/accounts.routes");
const cardsRoutes = require("./routes/cards.routes");
const paymentsRoutes = require("./routes/payments.routes");
const transfersRoutes = require("./routes/transfers.routes");
const complianceRoutes = require("./routes/compliance.routes");
const fraudRoutes = require("./routes/fraud.routes");
const opsRoutes = require("./routes/ops.routes");

const app = express();
app.use(express.json({ limit: "1mb" }));
app.use(requestContext);

app.use((req, res, next) => {
  res.setHeader("X-Correlation-Id", req.ctx.correlationId);
  next();
});

app.use(healthRoutes);
app.use("/admin", adminRoutes);
app.use("/customers", customersRoutes);
app.use("/accounts", accountsRoutes);
app.use("/cards", cardsRoutes);
app.use("/payments", paymentsRoutes);
app.use("/transfers", transfersRoutes);
app.use("/compliance", complianceRoutes);
app.use("/fraud", fraudRoutes);
app.use("/ops", opsRoutes);

app.use(notFoundHandler);
app.use(errorHandler);

module.exports = app;
