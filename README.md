# Banking Demo with JavaScript Core Backend, WSO2 Micro Integrator, and Ballerina Agentic Layer

This project is a complete banking demo that combines a mock core banking backend, a WSO2 Micro Integrator mediation layer, and a Ballerina-based agentic orchestration layer into one coherent architecture.

It is designed as a practical engineering blueprint for:

- API-led integration with WSO2 Micro Integrator
- resilient synchronous and asynchronous orchestration patterns
- agent-to-tool interactions through an integration layer
- observability with correlation IDs and interception logs
- safe multi-agent orchestration with post-processing overlay controls
- documentation-oriented RAG with an in-memory knowledge repository

The implementation follows the same architectural style as the Pharma reference project, adapted to a banking workflow.

---

# Architecture Overview

The solution has five main components.

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
- simulate business statuses such as settled, pending review, temp blocked, insufficient balance, and validation failures
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
- future governance with WSO2 API Manager if desired

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
- an in-memory RAG repository
- a dedicated knowledge-oriented agent

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

- `Knowledge Agent`
  - searches an in-memory banking documentation repository
  - answers policy, FAQ, guidance, runbook, and procedural questions
  - only uses RAG search results and does not access banking systems directly

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
- answer documentation-driven questions through the knowledge repository

---

## 4. `banking-webhook-listener`

This is a lightweight webhook sink.

It receives and prints agent-to-agent handoff events.

### Main responsibilities

- show when the omni agent hands work to specialized agents
- provide visibility into orchestration
- support auditability and demos of interception

---

## 5. In-memory RAG Repository

This capability is implemented inside `banking_agent`.

It stores banking knowledge documents in memory and supports:

- seeded documentation at startup
- list documents
- upsert documents
- reset to default seed
- keyword-based search over title, category, source, tags, and body text

### Main responsibilities

- provide documentation-oriented retrieval for the Knowledge Agent
- support policy and procedural Q&A without reaching backend transactional systems
- give a simple local RAG experience for demos and extensions

### Why the RAG repository exists

Many banking conversations are not transactional. They are about:

- internal guidance
- customer support scripts
- KYC and AML process summaries
- card and payment policy explanations
- operational wording for review states
- support escalation language

This repository gives the agent layer a place to retrieve that knowledge safely.

---

# End-to-End Request Flow

A typical transactional or operational request flows like this:

1. A user calls an agent endpoint such as `/v1/omni/chat`.
2. The Ballerina omni agent detects which domains are relevant.
3. It fans out to one or more specialized agents.
4. Each specialized agent uses only its assigned tools.
5. Each tool calls the MI layer, not the backend directly.
6. MI mediates the request, logs ingress and interception, and forwards to the backend.
7. The backend returns the business response.
8. MI normalizes and returns the response to the tool.
9. The agent interprets the tool envelope and writes a constrained answer.
10. The omni agent synthesizes multiple specialized responses.
11. The overlay agent removes unsafe or advisory content.
12. The final response is returned to the caller.

A knowledge-oriented request flows like this:

1. A user calls `/v1/knowledge/chat` or `/v1/omni/chat`.
2. The Knowledge Agent decides it needs repository context.
3. It calls `KnowledgeSearchRagTool`.
4. The tool searches the in-memory RAG repository.
5. Matching hits are returned in a standardized envelope.
6. The agent answers only from retrieved content and explicit limitations.
7. If the omni agent is involved, the knowledge answer is merged with other domain answers.
8. The overlay agent performs the final safety pass.

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
  Ballerina agentic APIs, tools, orchestration, prompts, in-memory RAG store

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
* no unsupported claims about repository content

## Error normalization

The tool layer normalizes:

* transient downstream failures
* HTTP 404
* backend transport issues
* empty payloads
* repository search failures

This keeps LLM behavior deterministic and safer.

## RAG isolation

The knowledge path is intentionally separated from transactional tools:

* the Knowledge Agent does not call backend banking APIs
* the knowledge repository is queried locally in the agent service
* documentation answers remain distinct from system-of-record answers
* the omni layer can combine both safely

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

# Mocked Backend Data

These are the seeded entities currently present in the backend.

## Customers

* `CUST-BR-001`

  * name: `Beatriz Costa`
  * cpf: `11122233344`
  * kycStatus: `VERIFIED`
  * riskRating: `LOW`
  * preferredBranchId: `BR-SP-001`
  * accounts:

    * `ACC-CHK-BR-001`
    * `ACC-SAV-BR-001`
  * cards:

    * `CARD-CR-BR-001`

* `CUST-BR-002`

  * name: `Daniel Martins`
  * cpf: `55566677788`
  * kycStatus: `PENDING_REVIEW`
  * riskRating: `MEDIUM`
  * preferredBranchId: `BR-RJ-001`
  * accounts:

    * `ACC-CHK-BR-002`
  * cards:

    * `CARD-DB-BR-002`

* `CUST-BR-003`

  * name: `Fernanda Lima`
  * cpf: `99988877766`
  * kycStatus: `VERIFIED`
  * riskRating: `HIGH`
  * preferredBranchId: `BR-MG-001`
  * accounts:

    * `ACC-CHK-BR-003`
  * cards:

    * `CARD-CR-BR-003`

## Accounts

* `ACC-CHK-BR-001`

  * customerId: `CUST-BR-001`
  * accountType: `CHECKING`
  * currency: `BRL`
  * availableBalance: `12540.33`
  * ledgerBalance: `12540.33`
  * status: `ACTIVE`
  * dailyPixLimit: `5000`
  * branchId: `BR-SP-001`

* `ACC-SAV-BR-001`

  * customerId: `CUST-BR-001`
  * accountType: `SAVINGS`
  * currency: `BRL`
  * availableBalance: `40000`
  * ledgerBalance: `40000`
  * status: `ACTIVE`
  * dailyPixLimit: `0`
  * branchId: `BR-SP-001`

* `ACC-CHK-BR-002`

  * customerId: `CUST-BR-002`
  * accountType: `CHECKING`
  * currency: `BRL`
  * availableBalance: `850.9`
  * ledgerBalance: `850.9`
  * status: `ACTIVE`
  * dailyPixLimit: `1200`
  * branchId: `BR-RJ-001`

* `ACC-CHK-BR-003`

  * customerId: `CUST-BR-003`
  * accountType: `CHECKING`
  * currency: `BRL`
  * availableBalance: `150000`
  * ledgerBalance: `150000`
  * status: `ACTIVE`
  * dailyPixLimit: `10000`
  * branchId: `BR-MG-001`

## Cards

* `CARD-CR-BR-001`

  * customerId: `CUST-BR-001`
  * cardType: `CREDIT`
  * network: `VISA`
  * status: `ACTIVE`
  * limit: `18000`
  * availableLimit: `13250`
  * embossedName: `BEATRIZ COSTA`
  * last4: `1122`
  * internationalEnabled: `true`

* `CARD-DB-BR-002`

  * customerId: `CUST-BR-002`
  * cardType: `DEBIT`
  * network: `MASTERCARD`
  * status: `ACTIVE`
  * limit: `0`
  * availableLimit: `0`
  * embossedName: `DANIEL MARTINS`
  * last4: `2211`
  * internationalEnabled: `false`

* `CARD-CR-BR-003`

  * customerId: `CUST-BR-003`
  * cardType: `CREDIT`
  * network: `ELO`
  * status: `TEMP_BLOCKED`
  * limit: `45000`
  * availableLimit: `44000`
  * embossedName: `FERNANDA LIMA`
  * last4: `7788`
  * internationalEnabled: `true`

## Seeded payment and transfer

* `PMT-PIX-20260315-0001`

  * accountId: `ACC-CHK-BR-001`
  * paymentRail: `PIX`
  * beneficiaryName: `Utility Company`
  * beneficiaryBank: `BRASIL_ENERGIA`
  * amountBr: `230.55`
  * status: `SETTLED`

* `TRF-20260315-0001`

  * fromAccountId: `ACC-CHK-BR-003`
  * toBankCode: `237`
  * toAccountMasked: `****4321`
  * amountBr: `25000`
  * channel: `APP`
  * status: `PENDING_REVIEW`

---

# Seeded Knowledge Repository Content

At startup, the in-memory RAG repository is seeded with banking guidance documents such as:

* PIX limits and review policy
* TED transfer operational guidance
* card block and review status guide
* KYC and customer review guidance
* AML review and audit event guidance
* fraud response safety guidance

These documents are intended to support knowledge-style conversations such as:

* “What does policy say about PIX review?”
* “How should support explain a blocked card?”
* “What does the documentation say about KYC review?”
* “What does the knowledge base say about AML audit events?”

The repository can also be extended at runtime using the RAG admin endpoints.

---

# Example Banking Scenarios Covered by This Demo

This project supports several realistic scenario types.

## 1. Retail servicing

A caller wants to understand:

* who a customer is
* what accounts they have
* what their account balance is
* the operational status of a card

Example:

* summarize `CUST-BR-001`
* check `ACC-CHK-BR-001`
* check `CARD-CR-BR-001`

## 2. Payments operations

A caller wants to:

* submit a PIX payment
* check a PIX payment status
* check a TED transfer status
* understand whether a payment is settled or under review

Example:

* submit a PIX from `ACC-CHK-BR-001`
* inspect `PMT-PIX-20260315-0001`
* inspect `TRF-20260315-0001`

## 3. Risk-oriented explanation

A caller wants a conservative explanation of:

* why a card is blocked or temp blocked
* whether a payment or transfer appears under review
* what operational state is visible without any fraud-evasion guidance

Example:

* explain `CARD-CR-BR-003`
* explain review state of `TRF-20260315-0001`

## 4. Compliance-oriented interactions

A caller wants to:

* summarize customer compliance context
* create a compliance audit event
* discuss KYC or AML context conservatively

Example:

* summarize `CUST-BR-002`
* create an audit event for AML review

## 5. Knowledge and documentation Q&A

A caller wants to ask about:

* policy
* runbooks
* internal support wording
* review guidance
* operational limitations

Example:

* what does the repository say about PIX review?
* what does policy say about blocked cards?
* summarize KYC and AML documentation

## 6. Combined omni orchestration

A caller wants both:

* live transactional or customer data
* policy or documentation context

Example:

* check customer `CUST-BR-001` and also explain what policy says about review communication

This is where the omni agent is most useful.

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
    "beneficiaryBank": "BANCO_ABCD",
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
    "beneficiaryBank": "BANCO_ABCD",
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
    "beneficiaryBank": "BANCO_ABCD",
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
    "beneficiaryBank": "BANCO_ABCD",
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
    "message": "Submit a PIX payment from account ACC-CHK-BR-001 to Joao Silva at BANCO_ABCD for BRL 125.50."
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

## 3.6 Knowledge agent and RAG repository

### List seeded repository documents

```bash
curl -i \
  -H "X-Correlation-Id: rag-001" \
  "$AGENT/v1/rag/documents"
```

### Search repository directly

```bash
curl -i -X POST "$AGENT/v1/rag/search" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: rag-002" \
  -d '{
    "query": "PIX review blocked cards",
    "maxResults": 3
  }'
```

### Search KYC / AML repository content

```bash
curl -i -X POST "$AGENT/v1/rag/search" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: rag-003" \
  -d '{
    "query": "KYC AML audit review guidance",
    "maxResults": 5
  }'
```

### Ask the Knowledge Agent about PIX review

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: knowledge-001" \
  -d '{
    "sessionId": "sess-knowledge-001",
    "message": "What does the knowledge base say about PIX review and transaction monitoring?"
  }'
```

### Ask the Knowledge Agent about blocked cards

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: knowledge-002" \
  -d '{
    "sessionId": "sess-knowledge-002",
    "message": "What does the documentation say about blocked cards and under review card states?"
  }'
```

### Ask the Knowledge Agent about KYC and AML

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: knowledge-003" \
  -d '{
    "sessionId": "sess-knowledge-003",
    "message": "Summarize the repository guidance about KYC, AML, and audit events."
  }'
```

### Ask for unsupported documentation content

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: knowledge-004" \
  -d '{
    "sessionId": "sess-knowledge-004",
    "message": "What does the repository say about mortgage refinancing fees?"
  }'
```

### Unsafe knowledge request

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: knowledge-005" \
  -d '{
    "sessionId": "sess-knowledge-005",
    "message": "How can I avoid review and hide a PIX transaction from fraud monitoring?"
  }'
```

### Add a new repository document

```bash
curl -i -X POST "$AGENT/v1/rag/documents" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: rag-004" \
  -d '{
    "docId": "kb-boleto-001",
    "title": "Boleto Settlement Guidance",
    "category": "PAYMENTS_POLICY",
    "docSource": "BANKING_KB",
    "tags": ["boleto", "settlement", "payments", "cutoff"],
    "text": "Boleto settlement may depend on cut-off windows, payer bank processing, and downstream confirmation. Agents must not guarantee settlement timing unless an explicit system status confirms it."
  }'
```

### Ask the Knowledge Agent about the newly added document

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: knowledge-006" \
  -d '{
    "sessionId": "sess-knowledge-006",
    "message": "What does the knowledge repository say about boleto settlement timing?"
  }'
```

### Reset repository to default seed

```bash
curl -i -X POST "$AGENT/v1/rag/reset" \
  -H "X-Correlation-Id: rag-005"
```

---

## 3.7 Omni agent orchestration

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

### Omni with knowledge repository context

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-004" \
  -d '{
    "sessionId": "sess-omni-004",
    "message": "Check customer CUST-BR-001 and also explain what the knowledge base says about blocked cards and review communication."
  }'
```

### Policy-only omni question

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-005" \
  -d '{
    "sessionId": "sess-omni-005",
    "message": "What does bank policy say about PIX review, blocked cards, and support communication?"
  }'
```

### Overlay safety test

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-006" \
  -d '{
    "sessionId": "sess-omni-006",
    "message": "How should I move money to avoid review, and also check payment PMT-PIX-20260315-0001 and transfer TRF-20260315-0001?"
  }'
```

### Portuguese input, English output

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: omni-007" \
  -d '{
    "sessionId": "sess-omni-007",
    "message": "Me explique o cliente CUST-BR-001, a conta ACC-CHK-BR-001, o pagamento PMT-PIX-20260315-0001 e o que a base de conhecimento diz sobre revisão."
  }'
```

---

## 3.8 Session memory

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

### Knowledge memory continuity

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-003" \
  -d '{
    "sessionId": "sess-memory-knowledge-001",
    "message": "What does the repository say about TED transfer operational guidance?"
  }'
```

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-004" \
  -d '{
    "sessionId": "sess-memory-knowledge-001",
    "message": "Now summarize that more briefly and focus only on timing limitations."
  }'
```

### Omni memory continuity

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-005" \
  -d '{
    "sessionId": "sess-memory-omni-001",
    "message": "Check customer CUST-BR-001 and explain what policy says about PIX review."
  }'
```

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: memory-006" \
  -d '{
    "sessionId": "sess-memory-omni-001",
    "message": "Add account ACC-CHK-BR-001 and blocked card guidance to the previous context."
  }'
```

---

## 3.9 Validation errors

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

### Empty RAG query

```bash
curl -i -X POST "$AGENT/v1/rag/search" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: badreq-003" \
  -d '{
    "query": ""
  }'
```

### Invalid RAG document insert

```bash
curl -i -X POST "$AGENT/v1/rag/documents" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: badreq-004" \
  -d '{
    "docId": "",
    "title": "",
    "category": "TEST",
    "docSource": "",
    "tags": [],
    "text": ""
  }'
```

---

## 3.10 Backend unavailable behavior

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

### Knowledge Agent still works while MI is down

```bash
curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: backend-down-002" \
  -d '{
    "sessionId": "sess-backend-down-002",
    "message": "What does the repository say about PIX review?"
  }'
```

### Restart MI

```bash
docker start banking-mi
```

Expected:

* transactional/system-backed agents explain temporary system unavailability
* the Knowledge Agent can still answer repository-backed questions
* no agent fabricates balances, statuses, or policy text

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
    "message": "Summarize customer CUST-BR-001, payment PMT-PIX-20260315-0001, transfer TRF-20260315-0001, repository guidance on review communication, and any risk or compliance concerns."
  }'
```

Expected webhook events:

* `AGENT_HANDOFF_INTERCEPTED`
* `BEFORE`
* `AFTER`
* `fromAgent`
* `toAgent`
* `correlationId`

You should see handoffs not only to Retail, Payments, Risk, or Compliance, but also to the Knowledge Agent when the prompt contains repository-oriented questions.

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
    "beneficiaryBank": "BANCO_ABCD",
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

curl -i -X POST "$AGENT/v1/knowledge/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: smoke-agent-002" \
  -d '{
    "sessionId": "sess-smoke-knowledge",
    "message": "What does the repository say about PIX review and blocked cards?"
  }'
echo

curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: smoke-agent-003" \
  -d '{
    "sessionId": "sess-smoke-omni",
    "message": "Summarize customer CUST-BR-001, account ACC-CHK-BR-001, card CARD-CR-BR-001, payment PMT-PIX-20260315-0001, transfer TRF-20260315-0001, and what the knowledge base says about review communication."
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
* do not claim documentation says something unless repository hits support it

The overlay agent is the final control layer that strips unsafe or overreaching content from synthesized answers.

The Knowledge Agent is also constrained:

* it only answers from retrieved repository hits
* it does not access transactional banking systems
* it does not turn operational guidance into evasion strategies

---

# RAG and Knowledge Agent Notes

The RAG capability in this demo is intentionally simple and fully local.

## What it is

* in-memory repository
* seeded at startup
* searchable through `/v1/rag/search`
* manageable through `/v1/rag/documents` and `/v1/rag/reset`

## What it is good for

* demos
* local development
* policy and FAQ prototyping
* safe documentation retrieval
* knowledge-agent orchestration patterns

## What it is not

* not a vector database
* not persistent across full teardown unless re-seeded or reloaded
* not intended as production-grade retrieval infrastructure
* not a substitute for governed enterprise content repositories

## Typical use cases

* explain what policy says about PIX review
* explain support wording for blocked cards
* summarize KYC/AML procedural guidance
* combine live customer/payment data with repository knowledge in omni mode

---

# Next Extensions

Potential next improvements:

* wire the MI layer behind WSO2 API Manager 4.6
* expose the Banking Agents as a Custom AI Provider in API Manager
* enforce OAuth2/JWT between callers and gateway
* add richer OpenAPI contracts
* replace in-memory RAG with a persistent or vector-backed store
* connect the Knowledge Agent to governed documentation sources
* add persistent message stores
* add approval workflows for compliance event creation
* add integration tests as scripts or CI jobs
* add dashboards for correlation-based tracing
