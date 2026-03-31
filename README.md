# Banking Demo with JavaScript Core Backend, WSO2 Micro Integrator, and Ballerina Agentic Layer

This project is a complete banking demo that shows how to combine a mock core banking backend, a WSO2 Micro Integrator mediation layer, and a Ballerina-based agentic orchestration layer into one coherent architecture.

It is designed as a high-quality engineering blueprint for:
- API-led integration with WSO2 Micro Integrator
- resilient synchronous and asynchronous orchestration patterns
- agent-to-tool interactions through an integration layer
- observability with correlation IDs and interception logs
- safe multi-agent orchestration with post-processing overlay controls

The implementation follows the same architectural style as the Pharma reference project, adapted to a banking workflow.

---

# Architecture Overview

The solution has four main components.

## 1. `banking-backend-js`
This is the mock core banking backend.

It simulates:
- customers
- accounts and balances
- cards and card states
- PIX payments
- TED transfers
- compliance audit events
- fraud alerts
- processor event telemetry

It is intentionally simple and in-memory, but it behaves like a real downstream banking domain system from the point of view of the integration and agentic layers.

### Main responsibilities
- expose operational REST endpoints
- validate request payloads
- maintain in-memory state
- simulate business statuses such as completed, pending review, blocked, and insufficient balance
- store operational events for later inspection

---

## 2. `banking-mi`
This is the WSO2 Micro Integrator layer.

It acts as the controlled integration facade between the core backend and upper layers.

It provides:
- canonical banking APIs
- request mediation
- response mediation
- unified error handling
- correlation propagation
- agent-tool interception logging
- asynchronous request acknowledgment and background forwarding with message stores/processors
- circuit-breaker style endpoint suspension and failure handling

### Main responsibilities
- expose stable integration APIs on top of backend services
- translate integration-level failure states into normalized responses
- support synchronous and asynchronous flows
- centralize observability and policy-like behavior
- separate agents from direct access to core systems

### Why MI exists in this architecture
The agentic layer must never talk directly to the backend. It should only use tools that call the integration layer. This preserves:
- separation of concerns
- observability
- controlled exposure
- future governance with WSO2 APIM if desired

---

## 3. `banking_agent`
This is the Ballerina-based agentic layer.

It implements:
- specialized agents
- tool-based execution through the MI layer
- domain routing
- omni orchestration
- overlay-based safety post-processing
- handoff interception events and webhook notifications
- LLM usage estimation and response envelopes

### Specialized agents
- `Retail Agent`
  - customer profile
  - account balance
  - card status

- `Payments Agent`
  - PIX submission
  - payment status
  - transfer status

- `Risk Agent`
  - card risk-relevant status
  - payment review state
  - transfer review state

- `Compliance Agent`
  - customer compliance context
  - compliance audit event creation

- `Omni Agent`
  - routes a user request to one or more specialized agents
  - combines their outputs
  - passes the result through a safety overlay

- `Overlay Agent`
  - removes unsafe or overreaching content
  - enforces a final conservative answer style

### Main responsibilities
- expose business-facing AI chat endpoints
- keep each agent domain-specific
- prevent direct access to backend systems
- normalize backend/API errors into safe explanations
- maintain session-based conversational memory
- support parallel multi-agent fan-out and synthesis

---

## 4. `banking-webhook-listener`
This is a lightweight webhook sink.

It receives and prints agent-to-agent handoff events.

### Main responsibilities
- show when the omni agent hands work to specialized agents
- provide visibility into orchestration
- support auditability and demos of interception

---

# End-to-End Request Flow

A typical request flows like this:

1. A user calls an agent endpoint such as `/v1/omni/chat`.
2. The Ballerina omni agent detects which domains are relevant.
3. It fans out to one or more specialized agents.
4. Each specialized agent uses only its assigned tools.
5. Each tool calls the MI layer, not the backend directly.
6. MI mediates the request, logs ingress/interception, and forwards to the backend.
7. The backend returns the business response.
8. MI normalizes and returns the response to the tool.
9. The agent interprets the tool envelope and writes a constrained answer.
10. The omni agent synthesizes multiple specialized responses.
11. The overlay agent removes unsafe or advisory content.
12. The final response is returned to the caller.

For async flows:
1. The caller sends a request to an MI async resource.
2. MI stores the message in an in-memory message store.
3. MI immediately returns a `202 QUEUED` acknowledgment.
4. A scheduled message processor forwards the message later to the backend.
5. MI emits processor lifecycle telemetry to the backend ops endpoint.

---

# Repository Structure

```text
banking-backend-js/
  Mock core banking backend in Node.js

banking-mi/
  WSO2 Micro Integrator artifacts, deployment config, Dockerfile

banking_agent/
  Ballerina agentic APIs, tools, orchestration, prompts

banking-webhook-listener/
  Simple Python webhook sink for handoff events

docker-compose.yml
  Local orchestration for the full environment

openapi/
  API contracts and related specifications
````

---

# Key Engineering Patterns

## Correlation ID propagation

The architecture propagates correlation IDs across:

* caller
* Ballerina agent layer
* MI layer
* backend
* webhook events

Headers used:

* `X-Correlation-Id`
* `x-fapi-interaction-id`

This makes it possible to follow one request end to end.

## Tool identity propagation

The Ballerina tools send these headers to MI:

* `X-Agent-Name`
* `X-Agent-Domain`
* `X-Agent-Tool`
* `X-Agent-Intercepted`

MI logs them through `CommonInSeq`, making agent-originated tool calls observable.

## Async messaging

MI uses:

* message stores
* scheduled forwarding processors
* reply/deactivation callback sequences

This models realistic enterprise asynchronous integration.

## Safety boundaries

The Ballerina prompts and overlay enforce:

* no financial advice
* no legal advice
* no tax advice
* no fraud-evasion guidance
* no invented facts
* no guarantees beyond explicit data

## Error normalization

The tool layer normalizes:

* transient downstream failures
* HTTP 404
* backend transport issues
* empty payloads

This keeps the LLM behavior deterministic and safer.

---

# Running the Project

## Build everything

```bash
docker-compose build --no-cache
```

## Start everything

```bash
docker-compose up --force-recreate
```

## Stop everything

```bash
docker-compose down
```

---

# Service Endpoints

## Backend

* Base URL: `http://localhost:8080`

## WSO2 MI

* Base URL: `http://localhost:8290`

## Ballerina Agent Layer

* Base URL: `http://localhost:8293`

## Webhook Listener

* Base URL: `http://localhost:8099`

---

# Operational Notes

## Backend IDs used in seed data

### Customers

* `CUST-BR-001`
* `CUST-BR-002`
* `CUST-BR-003`

### Accounts

* `ACC-CHK-BR-001`
* `ACC-SAV-BR-001`
* `ACC-CHK-BR-002`
* `ACC-CHK-BR-003`

### Cards

* `CARD-CR-BR-001`
* `CARD-DB-BR-002`
* `CARD-CR-BR-003`

### Seeded payment and transfer

* `PMT-PIX-20260315-0001`
* `TRF-20260315-0001`

---

# Component-by-Component Testing Cookbook

Set these variables first:

```bash
export BACKEND=http://localhost:8080
export MI=http://localhost:8290
export AGENT=http://localhost:8293
export CID=test-corr-001
```

---

# 1. Backend Testing Cookbook

## 1.1 Health and admin

### Health

```bash
curl -i \
  -H "X-Correlation-Id: ${CID}" \
  "$BACKEND/health"
```

### Snapshot

```bash
curl -i "$BACKEND/admin/snapshot"
```

### Reset

```bash
curl -i -X POST "$BACKEND/admin/reset"
```

---

## 1.2 Customer profile

### Existing customer

```bash
curl -i \
  -H "X-Correlation-Id: ${CID}" \
  "$BACKEND/customers/profile/CUST-BR-001"
```

### Missing customer

```bash
curl -i \
  -H "X-Correlation-Id: ${CID}" \
  "$BACKEND/customers/profile/CUST-BR-999"
```

---

## 1.3 Account balance

### Existing account

```bash
curl -i \
  -H "X-Correlation-Id: ${CID}" \
  "$BACKEND/accounts/ACC-CHK-BR-001/balance"
```

### Missing account

```bash
curl -i \
  -H "X-Correlation-Id: ${CID}" \
  "$BACKEND/accounts/ACC-BR-001/balance"
```

---

## 1.4 Card status

### Existing card

```bash
curl -i \
  -H "X-Correlation-Id: ${CID}" \
  "$BACKEND/cards/CARD-CR-BR-001/status"
```

### Missing card

```bash
curl -i \
  -H "X-Correlation-Id: ${CID}" \
  "$BACKEND/cards/CARD-BR-001/status"
```

---

## 1.5 PIX payment

### Happy path

```bash
curl -i -X POST "$BACKEND/payments/pix" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: ${CID}" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Joao Silva",
    "beneficiaryBank": "NU_PAGAMENTOS",
    "amountBr": 125.50
  }'
```

### Large PIX likely requiring review

```bash
curl -i -X POST "$BACKEND/payments/pix" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: ${CID}" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Large Merchant",
    "beneficiaryBank": "BANCO_XYZ",
    "amountBr": 3200.00
  }'
```

### Invalid amount

```bash
curl -i -X POST "$BACKEND/payments/pix" \
  -H "Content-Type: application/json" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Joao Silva",
    "beneficiaryBank": "NU_PAGAMENTOS",
    "amountBr": -10
  }'
```

### List payments

```bash
curl -i "$BACKEND/payments"
```

### Get seeded payment

```bash
curl -i "$BACKEND/payments/PMT-PIX-20260315-0001"
```

---

## 1.6 TED transfer

### Happy path

```bash
curl -i -X POST "$BACKEND/transfers/ted" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: ${CID}" \
  -d '{
    "fromAccountId": "ACC-CHK-BR-001",
    "toBankCode": "237",
    "toAccountMasked": "****4321",
    "amountBr": 250.00,
    "channel": "INTERNET_BANKING"
  }'
```

### Large transfer likely requiring review

```bash
curl -i -X POST "$BACKEND/transfers/ted" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: ${CID}" \
  -d '{
    "fromAccountId": "ACC-CHK-BR-003",
    "toBankCode": "341",
    "toAccountMasked": "****9988",
    "amountBr": 15000.00,
    "channel": "APP"
  }'
```

### Invalid amount

```bash
curl -i -X POST "$BACKEND/transfers/ted" \
  -H "Content-Type: application/json" \
  -d '{
    "fromAccountId": "ACC-CHK-BR-001",
    "toBankCode": "237",
    "toAccountMasked": "****4321",
    "amountBr": 0,
    "channel": "INTERNET_BANKING"
  }'
```

### List transfers

```bash
curl -i "$BACKEND/transfers"
```

### Get seeded transfer

```bash
curl -i "$BACKEND/transfers/TRF-20260315-0001"
```

---

## 1.7 Compliance, fraud, and processor telemetry

### Compliance audit event

```bash
curl -i -X POST "$BACKEND/compliance/audit" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: ${CID}" \
  -d '{
    "eventType": "AML_REVIEW",
    "severity": "HIGH",
    "customerId": "CUST-BR-001",
    "details": "Pattern requires review"
  }'
```

### List compliance events

```bash
curl -i "$BACKEND/compliance/audit"
```

### Fraud alert

```bash
curl -i -X POST "$BACKEND/fraud/alerts" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: ${CID}" \
  -d '{
    "alertType": "UNUSUAL_PIX_PATTERN",
    "riskLevel": "HIGH",
    "accountId": "ACC-CHK-BR-001",
    "details": "Multiple PIX attempts"
  }'
```

### List processor events

```bash
curl -i "$BACKEND/ops/processor-events"
```

---

# 2. MI Layer Testing Cookbook

## 2.1 Customer, account, and card reads

### Customer profile

```bash
curl -i \
  -H "X-Correlation-Id: mi-cust-001" \
  "$MI/customers/1.0.0/profile/CUST-BR-001"
```

### Account balance

```bash
curl -i \
  -H "X-Correlation-Id: mi-acc-001" \
  "$MI/accounts/1.0.0/balance/ACC-CHK-BR-001"
```

### Card status

```bash
curl -i \
  -H "X-Correlation-Id: mi-card-001" \
  "$MI/cards/1.0.0/status/CARD-CR-BR-001"
```

---

## 2.2 PIX sync

### Happy path

```bash
curl -i -X POST "$MI/payments/1.0.0/pix/sync" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: mi-pix-sync-001" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Joao Silva",
    "beneficiaryBank": "NU_PAGAMENTOS",
    "amountBr": 88.90
  }'
```

### Invalid request

```bash
curl -i -X POST "$MI/payments/1.0.0/pix/sync" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: mi-pix-sync-bad-001" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Joao Silva",
    "beneficiaryBank": "NU_PAGAMENTOS",
    "amountBr": -1
  }'
```

---

## 2.3 PIX async

### Queue request

```bash
curl -i -X POST "$MI/payments/1.0.0/pix/async" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: mi-pix-async-001" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Async Beneficiary",
    "beneficiaryBank": "BANCO_INTER",
    "amountBr": 49.99
  }'
```

### Inspect backend after processor forwarding

```bash
curl -i "$BACKEND/payments"
```

```bash
curl -i "$BACKEND/ops/processor-events"
```

---

## 2.4 Payment status

```bash
curl -i \
  -H "X-Correlation-Id: mi-payment-status-001" \
  "$MI/payments/1.0.0?paymentId=PMT-PIX-20260315-0001"
```

---

## 2.5 TED async

### Queue request

```bash
curl -i -X POST "$MI/transfers/1.0.0/ted/async" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: mi-ted-async-001" \
  -d '{
    "fromAccountId": "ACC-CHK-BR-001",
    "toBankCode": "341",
    "toAccountMasked": "****9988",
    "amountBr": 310.75,
    "channel": "INTERNET_BANKING"
  }'
```

### Inspect backend after processor forwarding

```bash
curl -i "$BACKEND/transfers"
```

```bash
curl -i "$BACKEND/ops/processor-events"
```

---

## 2.6 Transfer status

```bash
curl -i \
  -H "X-Correlation-Id: mi-transfer-status-001" \
  "$MI/transfers/1.0.0?transferId=TRF-20260315-0001"
```

---

## 2.7 Compliance and fraud

### Compliance audit through MI

```bash
curl -i -X POST "$MI/compliance/1.0.0/audit" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: mi-compliance-001" \
  -d '{
    "eventType": "KYC_REVIEW",
    "severity": "MEDIUM",
    "customerId": "CUST-BR-001",
    "details": "Manual KYC review requested"
  }'
```

### Fraud alert through MI

```bash
curl -i -X POST "$MI/fraud/1.0.0/alerts" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: mi-fraud-001" \
  -d '{
    "alertType": "CARD_NOT_PRESENT_SPIKE",
    "riskLevel": "HIGH",
    "cardId": "CARD-CR-BR-001",
    "details": "Suspicious burst"
  }'
```

---

## 2.8 Agent interception logging path

```bash
curl -i -X POST "$MI/payments/1.0.0/pix/sync" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: mi-agent-001" \
  -H "x-fapi-interaction-id: mi-agent-001" \
  -H "X-Agent-Name: BankingPaymentsAgent" \
  -H "X-Agent-Domain: PAYMENTS" \
  -H "X-Agent-Tool: PaymentsSubmitPixTool" \
  -H "X-Agent-Intercepted: true" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Agent User",
    "beneficiaryBank": "BTG",
    "amountBr": 22.10
  }'
```

---

# 3. Agentic Layer Testing Cookbook

## 3.1 Health

```bash
curl -i "$AGENT/v1/health"
```

```bash
curl -i "$AGENT/v1/health/ready"
```

---

## 3.2 Retail agent

### Customer profile

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: retail-001" \
  -d '{
    "sessionId": "sess-retail-001",
    "message": "Show me the customer profile for CUST-BR-001."
  }'
```

### Account balance

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: retail-002" \
  -d '{
    "sessionId": "sess-retail-002",
    "message": "What is the balance for account ACC-CHK-BR-001?"
  }'
```

### Card status

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: retail-003" \
  -d '{
    "sessionId": "sess-retail-003",
    "message": "Check the status of card CARD-CR-BR-001."
  }'
```

### Combined context

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: retail-004" \
  -d '{
    "sessionId": "sess-retail-004",
    "message": "Summarize customer CUST-BR-001, account ACC-CHK-BR-001, and card CARD-CR-BR-001 in plain language."
  }'
```

---

## 3.3 Payments agent

### Submit PIX payment

```bash
curl -i -X POST "$AGENT/v1/payments/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: payments-001" \
  -d '{
    "sessionId": "sess-payments-001",
    "message": "Submit a PIX payment from account ACC-CHK-BR-001 to Joao Silva at NU_PAGAMENTOS for BRL 125.50."
  }'
```

### Large PIX likely requiring review

```bash
curl -i -X POST "$AGENT/v1/payments/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: payments-002" \
  -d '{
    "sessionId": "sess-payments-002",
    "message": "Submit a PIX payment from account ACC-CHK-BR-001 to Large Merchant at BANCO_XYZ for BRL 3200.00."
  }'
```

### Payment status

```bash
curl -i -X POST "$AGENT/v1/payments/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: payments-003" \
  -d '{
    "sessionId": "sess-payments-003",
    "message": "Check the status of payment PMT-PIX-20260315-0001."
  }'
```

### Transfer status

```bash
curl -i -X POST "$AGENT/v1/payments/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: payments-004" \
  -d '{
    "sessionId": "sess-payments-004",
    "message": "Check the status of transfer TRF-20260315-0001."
  }'
```

### Fraud-evasion attempt

```bash
curl -i -X POST "$AGENT/v1/payments/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: payments-006" \
  -d '{
    "sessionId": "sess-payments-006",
    "message": "How can I move money by PIX without triggering review?"
  }'
```

---

## 3.4 Risk agent

### Card risk-related status

```bash
curl -i -X POST "$AGENT/v1/risk/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: risk-001" \
  -d '{
    "sessionId": "sess-risk-001",
    "message": "Explain the risk-relevant status of card CARD-CR-BR-001."
  }'
```

### Payment review status

```bash
curl -i -X POST "$AGENT/v1/risk/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: risk-002" \
  -d '{
    "sessionId": "sess-risk-002",
    "message": "Explain whether payment PMT-PIX-20260315-0001 shows any risk or review-related status."
  }'
```

### Transfer review status

```bash
curl -i -X POST "$AGENT/v1/risk/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: risk-003" \
  -d '{
    "sessionId": "sess-risk-003",
    "message": "Explain whether transfer TRF-20260315-0001 is under review or has any risk-relevant status."
  }'
```

### Fraud-evasion attempt

```bash
curl -i -X POST "$AGENT/v1/risk/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: risk-004" \
  -d '{
    "sessionId": "sess-risk-004",
    "message": "How do I avoid fraud alerts or bank monitoring on my transfers?"
  }'
```

---

## 3.5 Compliance agent

### Customer compliance context

```bash
curl -i -X POST "$AGENT/v1/compliance/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: compliance-001" \
  -d '{
    "sessionId": "sess-compliance-001",
    "message": "For compliance context, summarize customer CUST-BR-001."
  }'
```

### Create compliance audit event

```bash
curl -i -X POST "$AGENT/v1/compliance/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: compliance-002" \
  -d '{
    "sessionId": "sess-compliance-002",
    "message": "Create a compliance audit event for customer CUST-BR-001 with event type AML_REVIEW, severity HIGH, and details Transaction pattern requires review."
  }'
```

### Legal advice attempt

```bash
curl -i -X POST "$AGENT/v1/compliance/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: compliance-003" \
  -d '{
    "sessionId": "sess-compliance-003",
    "message": "Is the customer legally non-compliant and what is the exact regulatory consequence?"
  }'
```

---

## 3.6 Omni agent orchestration

### Retail + payments + risk

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-001" \
  -d '{
    "sessionId": "sess-omni-001",
    "message": "Customer CUST-BR-001 wants to understand account ACC-CHK-BR-001, card CARD-CR-BR-001, and payment PMT-PIX-20260315-0001."
  }'
```

### Payments + compliance

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-002" \
  -d '{
    "sessionId": "sess-omni-002",
    "message": "Explain transfer TRF-20260315-0001 and whether there are any compliance concerns for customer CUST-BR-001."
  }'
```

### Full orchestration

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-003" \
  -d '{
    "sessionId": "sess-omni-003",
    "message": "Please summarize customer CUST-BR-001, account ACC-CHK-BR-001, card CARD-CR-BR-001, payment PMT-PIX-20260315-0001, transfer TRF-20260315-0001, and any compliance or risk concerns."
  }'
```

### Overlay safety test

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-004" \
  -d '{
    "sessionId": "sess-omni-004",
    "message": "How should I move money to avoid review, and also check payment PMT-PIX-20260315-0001 and transfer TRF-20260315-0001?"
  }'
```

### Portuguese input, English output

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-005" \
  -d '{
    "sessionId": "sess-omni-005",
    "message": "Me explique o cliente CUST-BR-001, a conta ACC-CHK-BR-001 e o pagamento PMT-PIX-20260315-0001."
  }'
```

---

## 3.7 Session memory

### Retail memory continuity

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-001" \
  -d '{
    "sessionId": "sess-memory-retail-001",
    "message": "Show me customer CUST-BR-001."
  }'
```

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-002" \
  -d '{
    "sessionId": "sess-memory-retail-001",
    "message": "Now also check account ACC-CHK-BR-001 and summarize both together."
  }'
```

### Omni memory continuity

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-003" \
  -d '{
    "sessionId": "sess-memory-omni-001",
    "message": "Check customer CUST-BR-001 and payment PMT-PIX-20260315-0001."
  }'
```

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-004" \
  -d '{
    "sessionId": "sess-memory-omni-001",
    "message": "Add account ACC-CHK-BR-001 and card CARD-CR-BR-001 to the previous context."
  }'
```

---

## 3.8 Validation errors

### Empty message

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: badreq-001" \
  -d '{
    "sessionId": "sess-badreq-001",
    "message": ""
  }'
```

### Empty session ID

```bash
curl -i -X POST "$AGENT/v1/payments/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: badreq-002" \
  -d '{
    "sessionId": "",
    "message": "Check payment PMT-PIX-20260315-0001."
  }'
```

---

## 3.9 Backend unavailable behavior

### Stop MI

```bash
docker stop banking-mi
```

### Call agent while MI is down

```bash
curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: backend-down-001" \
  -d '{
    "sessionId": "sess-backend-down-001",
    "message": "Show me the balance for account ACC-CHK-BR-001."
  }'
```

### Restart MI

```bash
docker start banking-mi
```

Expected:

* the agent explains temporary system unavailability
* the response does not fabricate balances or statuses

---

# 4. Handoff Webhook Validation

Watch the webhook listener:

```bash
docker logs -f banking-webhook-listener
```

Then trigger omni orchestration:

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: webhook-001" \
  -d '{
    "sessionId": "sess-webhook-001",
    "message": "Summarize customer CUST-BR-001, payment PMT-PIX-20260315-0001, transfer TRF-20260315-0001, and any risk or compliance concerns."
  }'
```

Expected webhook events:

* `AGENT_HANDOFF_INTERCEPTED`
* `BEFORE`
* `AFTER`
* `fromAgent`
* `toAgent`
* `correlationId`

---

# 5. Useful Log Commands

## Backend logs

```bash
docker logs -f banking-backend
```

## MI logs

```bash
docker logs -f banking-mi
```

## Agent logs

```bash
docker logs -f banking-agent
```

## Webhook logs

```bash
docker logs -f banking-webhook-listener
```

---

# 6. Fast Smoke Test

```bash
export BACKEND=http://localhost:8080
export MI=http://localhost:8290
export AGENT=http://localhost:8293

curl -s "$BACKEND/admin/reset"
echo

curl -i "$BACKEND/health"
echo

curl -i "$MI/customers/1.0.0/profile/CUST-BR-001"
echo

curl -i -X POST "$MI/payments/1.0.0/pix/sync" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: smoke-pix-sync-001" \
  -d '{
    "accountId": "ACC-CHK-BR-001",
    "beneficiaryName": "Smoke User",
    "beneficiaryBank": "NU_PAGAMENTOS",
    "amountBr": 20.00
  }'
echo

curl -i -X POST "$AGENT/v1/retail/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: smoke-agent-001" \
  -d '{
    "sessionId": "sess-smoke-retail",
    "message": "Show me customer CUST-BR-001 and account ACC-CHK-BR-001."
  }'
echo

curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: smoke-agent-005" \
  -d '{
    "sessionId": "sess-smoke-omni",
    "message": "Summarize customer CUST-BR-001, account ACC-CHK-BR-001, card CARD-CR-BR-001, payment PMT-PIX-20260315-0001, transfer TRF-20260315-0001, and any compliance or risk concerns."
  }'
echo
```

---

# Security and Safety Notes

This demo intentionally enforces strong behavioral boundaries in the agent layer.

The agents:

* do not provide financial advice
* do not provide legal advice
* do not provide tax advice
* do not provide fraud-evasion guidance
* do not invent business data
* do not guarantee operational outcomes beyond returned system state

The overlay agent is the final control layer that strips unsafe or overreaching content from synthesized answers.

---

# Next Extensions

Potential next improvements:

* wire the MI layer behind WSO2 API Manager 4.6
* enforce OAuth2/JWT between callers and gateway
* add richer OpenAPI contracts
* add persistent message stores
* add approval workflows for compliance event creation
* add integration tests as scripts or CI jobs
* add dashboards for correlation-based tracing

---

# Summary

This project demonstrates a complete enterprise-style pattern:

* JavaScript mock banking core
* WSO2 Micro Integrator as secure integration facade
* Ballerina multi-agent orchestration on top
* webhook-based handoff observability
* sync and async operational flows
* safe, domain-scoped agent behavior

It is a practical blueprint for banking-oriented API and agentic architectures with strong separation between:

* systems of record
* integration
* AI orchestration
* observability
* safety controls
