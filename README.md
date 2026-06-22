# WSO2 Banking Identity, Integration, API, and Agent Demo

This repository is a complete local demo for a modern banking architecture using:

- **WSO2 Identity Server 7.3** for user authentication, roles, permissions, API-resource authorization, and AI agent identity.
- **WSO2 Micro Integrator** for banking API mediation and controlled backend integration.
- **WSO2 API Manager** for optional API and AI API governance.
- **A Ballerina banking agent layer** for retail, payments, risk, compliance, knowledge/RAG, omni orchestration, and AI adapter endpoints.
- **A JavaScript mock banking backend** for customers, accounts, cards, PIX payments, TED transfers, compliance events, fraud alerts, and telemetry.
- **A browser-based banking demo UI** for Identity Server login, permission-aware API invocation, and governed agent chat.

The demo is designed to show the difference between:

1. **User permissions**: what the authenticated human user can do.
2. **Agent permissions**: whether the banking assistant can appear and what actions it may attempt.
3. **Integration mediation**: how banking APIs flow through WSO2 Micro Integrator.
4. **Optional APIM governance**: how the same APIs and AI APIs can later be published and governed through WSO2 API Manager.

> Current default demo mode: the UI authenticates users with WSO2 Identity Server, then calls WSO2 Micro Integrator and the Ballerina banking agent directly through the UI Nginx proxy. APIM runs in the stack, but the UI does not require APIM APIs to be published unless you explicitly switch to APIM mode.

---

## 1. Architecture Overview

### Runtime components

| Component | Folder / Service | Default URL | Purpose |
|---|---|---:|---|
| Banking UI | `banking-demo-ui` / `banking-ui` | `http://localhost:5173` | Browser UI for login, scoped API access, and agent chat |
| WSO2 Identity Server | `wso2is` | `https://localhost:9444/console` | Users, roles, scopes/permissions, SPA app, agent identity |
| WSO2 API Manager | `apim` | `https://localhost:9443` | Optional API and AI API governance |
| WSO2 Micro Integrator | `banking-mi` / `wso2mi` | `http://localhost:8290` | Canonical banking APIs and mediation |
| Banking Agent | `banking_agent_bi` / `banking-agent` | `http://localhost:8293` | Ballerina agentic APIs and AI adapters |
| Mock Backend | `banking-backend-js` / `banking-backend` | `http://localhost:8080` | Mock core banking system |
| Webhook Listener | `banking-webhook-listener` | `http://localhost:8099` | Agent handoff event sink |

### Demo flow in the current local mode

```text
Browser UI
  ↓ login
WSO2 Identity Server 7.3
  ↓ access token with scopes
Browser UI
  ↓ permission-aware banking API calls
UI Nginx proxy /mi/*
  ↓
WSO2 Micro Integrator
  ↓
Mock banking backend

Browser UI
  ↓ agent chat if user has agent:chat
UI Nginx proxy /agent/*
  ↓
Ballerina Banking Agent
  ↓ tools
WSO2 Micro Integrator
  ↓
Mock banking backend
```

### Optional APIM-governed mode

```text
Browser or external client
  ↓
WSO2 API Manager
  ↓ auth, throttling, analytics, guardrails
AI adapter endpoints in banking-agent
  ↓
Specialized banking agents
  ↓ tools
WSO2 Micro Integrator
  ↓
Mock banking backend
```

---

## 2. Repository Structure

```text
banking-backend-js/
  Mock core banking backend in Node.js

banking-mi/
  WSO2 Micro Integrator artifacts, deployment config, Dockerfile

banking_agent_bi/
  Ballerina agentic APIs, tools, orchestration, prompts, RAG store, AI adapters

banking-webhook-listener/
  Simple webhook sink for handoff/interception events

banking-demo-ui/
  Browser-based Identity Server + banking API + agent demo UI

docker-compose.yml
  Local orchestration for the complete environment

.env
  Local Docker Compose and frontend build configuration

openapi/
  API contracts and related specifications, if present
```

---

## 3. Prerequisites

Install:

- Docker Desktop
- Docker Compose v2
- Git
- A modern browser
- Optional: Node.js 20+ if you want to run the UI outside Docker

Recommended machine resources:

```text
Memory: 10 GB+ available for Docker
CPUs:   4+
Disk:   15 GB+ free
```

The WSO2 containers can take several minutes to become ready on first startup.

---

## 4. Required Local Files

### 4.1 Root `.env`

Create this file beside `docker-compose.yml`:

```text
demo-banking/
├── docker-compose.yml
├── .env
├── banking-demo-ui/
├── banking-mi/
├── banking_agent_bi/
├── banking-backend-js/
└── banking-webhook-listener/
```

Example root `.env`:

```env
# Optional OpenAI key for the Ballerina banking agent.
OPENAI_API_KEY=

# WSO2 Identity Server SPA configuration.
# Replace VITE_IS_CLIENT_ID after creating the Banking Demo UI SPA app in IS.
VITE_IS_BASE_URL=https://localhost:9444
VITE_IS_CLIENT_ID=REPLACE_WITH_WSO2_IS_SPA_CLIENT_ID
VITE_REDIRECT_URL=http://localhost:5173
VITE_SIGN_OUT_REDIRECT_URL=http://localhost:5173

# Current local demo mode:
# The UI calls MI directly through its Nginx proxy.
VITE_APIM_BASE_URL=http://localhost:5173/mi
VITE_BANKING_MI_CONTEXT=

# Current local demo mode:
# The UI calls the Ballerina banking agent directly through its Nginx proxy.
VITE_AGENT_CONTRACT=banking-agent
VITE_AGENT_CHAT_URL=http://localhost:5173/agent/v1/omni/chat

# WSO2 IS AI agent identity.
# Fill these after creating the Interactive Agent in WSO2 IS.
BANKING_AGENT_ID=
BANKING_AGENT_SECRET=
BANKING_AGENT_OAUTH_CLIENT_ID=
WSO2_IS_BASE_URL=https://wso2is:9444

# Safe-to-show frontend agent metadata.
# Never expose BANKING_AGENT_SECRET as a VITE_* variable.
VITE_AGENT_ID=
VITE_AGENT_OAUTH_CLIENT_ID=
VITE_AGENT_NAME=Banking Omni Assistant Agent
VITE_AGENT_PURPOSE=Interactive governed banking assistant with read-only default permissions and delegated sensitive actions.

# Optional UI-only rehearsal mode.
VITE_ENABLE_MOCK_AUTH=false
VITE_MOCK_SCOPES=
```

Important:

- `VITE_*` values are embedded during the Vite UI build.
- After changing any `VITE_*` value, rebuild `banking-ui`.
- Never create `VITE_AGENT_SECRET`.

---

## 5. Docker Compose Requirements

Your `docker-compose.yml` should include these services:

- `banking-backend`
- `wso2mi`
- `banking-agent`
- `banking-webhook-listener`
- `apim`
- `wso2is`
- `banking-ui`

The important new parts are `wso2is` and `banking-ui`.

### 5.1 Identity Server service

Use port offset so IS runs externally on `9444` and does not collide with APIM on `9443`.

```yaml
  wso2is:
    image: wso2/wso2is:7.3.0
    container_name: wso2is
    ports:
      - "9444:9444"
    environment:
      JAVA_OPTS: >
        -Xms512m
        -Xmx1536m
        -XX:MaxMetaspaceSize=384m
        -XX:+UseG1GC
        -DportOffset=1
    healthcheck:
      test: ["CMD-SHELL", "nc -z localhost 9444 || exit 1"]
      interval: 20s
      timeout: 10s
      retries: 15
      start_period: 120s
```

### 5.2 Banking UI service

```yaml
  banking-ui:
    build:
      context: ./banking-demo-ui
      dockerfile: Dockerfile
      args:
        VITE_IS_BASE_URL: ${VITE_IS_BASE_URL:-https://localhost:9444}
        VITE_IS_CLIENT_ID: ${VITE_IS_CLIENT_ID:-REPLACE_WITH_WSO2_IS_SPA_CLIENT_ID}
        VITE_REDIRECT_URL: ${VITE_REDIRECT_URL:-http://localhost:5173}
        VITE_SIGN_OUT_REDIRECT_URL: ${VITE_SIGN_OUT_REDIRECT_URL:-http://localhost:5173}
        VITE_APIM_BASE_URL: ${VITE_APIM_BASE_URL:-http://localhost:5173/mi}
        VITE_BANKING_MI_CONTEXT: ${VITE_BANKING_MI_CONTEXT:-}
        VITE_AGENT_CONTRACT: ${VITE_AGENT_CONTRACT:-banking-agent}
        VITE_AGENT_CHAT_URL: ${VITE_AGENT_CHAT_URL:-http://localhost:5173/agent/v1/omni/chat}
        VITE_AGENT_ID: ${VITE_AGENT_ID:-not-configured}
        VITE_AGENT_OAUTH_CLIENT_ID: ${VITE_AGENT_OAUTH_CLIENT_ID:-not-configured}
        VITE_AGENT_NAME: ${VITE_AGENT_NAME:-Banking Omni Assistant Agent}
        VITE_AGENT_PURPOSE: ${VITE_AGENT_PURPOSE:-Interactive governed banking assistant.}
        VITE_ENABLE_MOCK_AUTH: ${VITE_ENABLE_MOCK_AUTH:-false}
        VITE_MOCK_SCOPES: ${VITE_MOCK_SCOPES:-}
    container_name: banking-ui
    ports:
      - "5173:80"
    depends_on:
      - wso2is
      - wso2mi
      - banking-agent
```

### 5.3 Banking agent environment

```yaml
  banking-agent:
    build: ./banking_agent_bi
    container_name: banking-agent
    environment:
      - OPENAI_API_KEY=${OPENAI_API_KEY:-}
      - BACKEND_BASE_URL=http://banking-mi:8290
      - HTTP_LISTENER_PORT=8293
      - BANKING_AGENT_ID=${BANKING_AGENT_ID:-}
      - BANKING_AGENT_SECRET=${BANKING_AGENT_SECRET:-}
      - BANKING_AGENT_OAUTH_CLIENT_ID=${BANKING_AGENT_OAUTH_CLIENT_ID:-}
      - WSO2_IS_BASE_URL=${WSO2_IS_BASE_URL:-https://wso2is:9444}
    ports:
      - "8293:8293"
    depends_on:
      - wso2mi
      - apim
```

If you mount `Config.toml`, prefer one simple mount:

```yaml
    volumes:
      - ./banking_agent_bi/Config.toml:/workspace/Config.toml:ro
```

If Docker complains about mounting a file onto a directory, remove the volume and rebuild the image with `Config.toml` already present in the build context.

---

## 6. Banking UI Files

The `banking-demo-ui` folder should look like this:

```text
banking-demo-ui/
├── Dockerfile
├── README.md
├── index.html
├── nginx.conf
├── package.json
└── src
    ├── config.js
    ├── main.js
    └── styles.css
```

### 6.1 UI Dockerfile

The UI is built with Node and served by Nginx.

```dockerfile
FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN if [ -f package-lock.json ]; then \
      npm ci --no-audit; \
    else \
      npm install --no-audit; \
    fi

COPY . .

ARG VITE_IS_BASE_URL=https://localhost:9444
ARG VITE_IS_CLIENT_ID=REPLACE_WITH_WSO2_IS_SPA_CLIENT_ID
ARG VITE_REDIRECT_URL=http://localhost:5173
ARG VITE_SIGN_OUT_REDIRECT_URL=http://localhost:5173
ARG VITE_APIM_BASE_URL=http://localhost:5173/mi
ARG VITE_BANKING_MI_CONTEXT=
ARG VITE_AGENT_CONTRACT=banking-agent
ARG VITE_AGENT_CHAT_URL=http://localhost:5173/agent/v1/omni/chat
ARG VITE_AGENT_ID=not-configured
ARG VITE_AGENT_OAUTH_CLIENT_ID=not-configured
ARG VITE_AGENT_NAME=Banking Omni Assistant Agent
ARG VITE_AGENT_PURPOSE=Interactive governed banking assistant.
ARG VITE_ENABLE_MOCK_AUTH=false
ARG VITE_MOCK_SCOPES=

ENV VITE_IS_BASE_URL=$VITE_IS_BASE_URL
ENV VITE_IS_CLIENT_ID=$VITE_IS_CLIENT_ID
ENV VITE_REDIRECT_URL=$VITE_REDIRECT_URL
ENV VITE_SIGN_OUT_REDIRECT_URL=$VITE_SIGN_OUT_REDIRECT_URL
ENV VITE_APIM_BASE_URL=$VITE_APIM_BASE_URL
ENV VITE_BANKING_MI_CONTEXT=$VITE_BANKING_MI_CONTEXT
ENV VITE_AGENT_CONTRACT=$VITE_AGENT_CONTRACT
ENV VITE_AGENT_CHAT_URL=$VITE_AGENT_CHAT_URL
ENV VITE_AGENT_ID=$VITE_AGENT_ID
ENV VITE_AGENT_OAUTH_CLIENT_ID=$VITE_AGENT_OAUTH_CLIENT_ID
ENV VITE_AGENT_NAME=$VITE_AGENT_NAME
ENV VITE_AGENT_PURPOSE=$VITE_AGENT_PURPOSE
ENV VITE_ENABLE_MOCK_AUTH=$VITE_ENABLE_MOCK_AUTH
ENV VITE_MOCK_SCOPES=$VITE_MOCK_SCOPES

RUN npm run build

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=20s --timeout=5s --retries=10 \
  CMD wget -qO- http://localhost/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]
```

### 6.2 UI Nginx proxy

Current direct mode:

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /mi/ {
        proxy_pass http://banking-mi:8290/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Authorization $http_authorization;
        proxy_set_header X-Correlation-Id $http_x_correlation_id;
        proxy_set_header x-fapi-interaction-id $http_x_fapi_interaction_id;

        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
    }

    location /agent/ {
        proxy_pass http://banking-agent:8293/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;

        proxy_set_header Authorization $http_authorization;
        proxy_set_header X-Correlation-Id $http_x_correlation_id;
        proxy_set_header x-fapi-interaction-id $http_x_fapi_interaction_id;

        proxy_set_header X-Agent-Id $http_x_agent_id;
        proxy_set_header X-Agent-Name $http_x_agent_name;
        proxy_set_header X-Agent-OAuth-Client-Id $http_x_agent_oauth_client_id;
        proxy_set_header X-WSO2-Agent-Id $http_x_wso2_agent_id;
        proxy_set_header X-WSO2-Agent-Name $http_x_wso2_agent_name;
        proxy_set_header X-Agent-Domain $http_x_agent_domain;
        proxy_set_header X-Agent-Tool $http_x_agent_tool;
        proxy_set_header X-Agent-Intercepted $http_x_agent_intercepted;

        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
    }

    location /backend/ {
        proxy_pass http://banking-backend:8080/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header X-Correlation-Id $http_x_correlation_id;
        proxy_set_header x-fapi-interaction-id $http_x_fapi_interaction_id;
    }
}
```

### 6.3 `.dockerignore`

Do not exclude `Dockerfile` or `nginx.conf`.

```gitignore
node_modules
dist
.env
npm-debug.log
```

---

## 7. Start from Scratch

### 7.1 Clone and enter the repo

```bash
git clone https://github.com/joaokuntzwso2/demo-banking
cd demo-banking
```

### 7.2 Add the banking UI folder

Ensure the folder exists:

```bash
ls -la banking-demo-ui
```

Expected:

```text
Dockerfile
README.md
index.html
nginx.conf
package.json
src/
```

### 7.3 Create root `.env`

```bash
touch .env
```

Paste the `.env` from section 4.1.

### 7.4 Build and start

Detached mode is recommended because some Docker Compose versions can panic in attached monitor mode.

```bash
docker compose build --no-cache
docker compose up -d
docker compose ps
```

### 7.5 Open the consoles

```text
Banking UI:
http://localhost:5173

WSO2 Identity Server:
https://localhost:9444/console

WSO2 API Manager:
https://localhost:9443

APIM Publisher:
https://localhost:9443/publisher

APIM DevPortal:
https://localhost:9443/devportal

APIM Admin Portal:
https://localhost:9443/admin
```

Default WSO2 credentials:

```text
Username: admin
Password: admin
```

Accept browser certificate warnings for local WSO2 HTTPS endpoints.

---

## 8. Configure WSO2 Identity Server 7.3

Open:

```text
https://localhost:9444/console
```

Login:

```text
admin / admin
```

### 8.1 Create the SPA application

Go to:

```text
Applications → New Application → Single Page Application
```

Use:

```text
Name:
Banking Demo UI

Authorized Redirect URL:
http://localhost:5173

Authorized Sign-out Redirect URL:
http://localhost:5173
```

Save and copy the generated **Client ID**.

Update root `.env`:

```env
VITE_IS_CLIENT_ID=PASTE_BANKING_DEMO_UI_SPA_CLIENT_ID_HERE
```

Rebuild the UI:

```bash
docker compose build banking-ui --no-cache
docker compose up -d banking-ui
```

### 8.2 Create the API Resource

Go to:

```text
API Resources → New API Resource
```

Create:

```text
Name:
Banking Demo API

Identifier:
banking-demo-api
```

Add these scopes/permissions:

```text
banking:profile:read
banking:accounts:read
banking:cards:read
banking:payments:create
banking:payments:read
banking:transfers:create
banking:transfers:read
banking:compliance:write
banking:fraud:write
agent:chat
banking:admin
```

### 8.3 Authorize the API Resource for the SPA

Go to:

```text
Applications → Banking Demo UI → API Authorization
```

Authorize:

```text
Banking Demo API
```

Select all permissions/scopes:

```text
banking:profile:read
banking:accounts:read
banking:cards:read
banking:payments:create
banking:payments:read
banking:transfers:create
banking:transfers:read
banking:compliance:write
banking:fraud:write
agent:chat
banking:admin
```

Also ensure the app can request:

```text
openid
profile
email
```

### 8.4 Create application roles

Create roles as **Application roles** for the `Banking Demo UI` application.

#### `BankingRetailViewer`

Permissions:

```text
banking:profile:read
banking:accounts:read
banking:cards:read
```

#### `BankingPaymentsOperator`

Permissions:

```text
banking:payments:create
banking:payments:read
banking:transfers:create
banking:transfers:read
```

#### `BankingComplianceAnalyst`

Permissions:

```text
banking:compliance:write
banking:fraud:write
```

#### `BankingAgentUser`

Permissions:

```text
agent:chat
```

#### `BankingAdmin`

Permissions:

```text
banking:profile:read
banking:accounts:read
banking:cards:read
banking:payments:create
banking:payments:read
banking:transfers:create
banking:transfers:read
banking:compliance:write
banking:fraud:write
agent:chat
banking:admin
```

### 8.5 Create users

Create exactly these demo users.

#### Ana

```text
Username: ana
Password: Ana@12345
First name: Ana
Last name: Retail
Email: ana@banking.demo
```

Assign roles:

```text
BankingRetailViewer
BankingAgentUser
```

Expected:

```text
Ana can view profile, balance, card status, and use the agent.
Ana cannot create PIX, TED, compliance events, or fraud alerts.
```

#### Bruno

```text
Username: bruno
Password: Bruno@12345
First name: Bruno
Last name: Payments
Email: bruno@banking.demo
```

Assign roles:

```text
BankingRetailViewer
BankingPaymentsOperator
BankingAgentUser
```

Expected:

```text
Bruno can view retail data, create/read PIX payments, create/read TED transfers, and use the agent.
Bruno cannot create compliance or fraud records.
```

#### Clara

```text
Username: clara
Password: Clara@12345
First name: Clara
Last name: Compliance
Email: clara@banking.demo
```

Assign roles:

```text
BankingRetailViewer
BankingComplianceAnalyst
```

Expected:

```text
Clara can view retail data and create compliance/fraud records.
Clara cannot create payments or transfers.
Clara does not see the agent because she does not have BankingAgentUser.
```

#### Bank admin

```text
Username: bankadmin
Password: Admin@12345
First name: Banking
Last name: Admin
Email: bankadmin@banking.demo
```

Assign role:

```text
BankingAdmin
```

Expected:

```text
Bankadmin can access all UI API cards and the agent.
```

### 8.6 User/permission matrix

| User | Password | Roles | Demo behavior |
|---|---|---|---|
| `ana` | `Ana@12345` | `BankingRetailViewer`, `BankingAgentUser` | Retail reads + agent, no write operations |
| `bruno` | `Bruno@12345` | `BankingRetailViewer`, `BankingPaymentsOperator`, `BankingAgentUser` | Retail + payments/transfers + agent |
| `clara` | `Clara@12345` | `BankingRetailViewer`, `BankingComplianceAnalyst` | Retail + compliance/fraud, no agent |
| `bankadmin` | `Admin@12345` | `BankingAdmin` | Everything |

After changing roles or permissions, always log out and log in again because tokens are issued at login time.

---

## 9. Create the AI Agent Identity in WSO2 IS

This demo uses a real WSO2 IS AI agent identity in addition to human users.

### 9.1 Create an Interactive Agent

Go to:

```text
Agents → New Agent
```

Use:

```text
AI Agent Type:
Interactive Agent

Name:
Banking Omni Assistant Agent

Description:
Interactive conversational banking assistant for WSO2 demo scenarios. It helps authenticated banking users inspect accounts, cards, payments, transfers, compliance events, and fraud signals. Access is governed by WSO2 Identity Server user permissions and agent permissions.

Callback URL:
http://localhost:5173/agent/callback
```

After creation, copy:

```text
Agent ID
Agent Secret
OAuth Client ID
```

Store them in root `.env`:

```env
BANKING_AGENT_ID=PASTE_AGENT_ID_HERE
BANKING_AGENT_SECRET=PASTE_AGENT_SECRET_HERE
BANKING_AGENT_OAUTH_CLIENT_ID=PASTE_AGENT_OAUTH_CLIENT_ID_HERE

VITE_AGENT_ID=PASTE_AGENT_ID_HERE
VITE_AGENT_OAUTH_CLIENT_ID=PASTE_AGENT_OAUTH_CLIENT_ID_HERE
VITE_AGENT_NAME=Banking Omni Assistant Agent
```

Do not expose the secret:

```text
Never create VITE_AGENT_SECRET.
```

### 9.2 Create an agent role

Create a role:

```text
BankingOmniAgent
```

Recommended permissions:

```text
agent:chat
banking:profile:read
banking:accounts:read
banking:cards:read
banking:payments:read
banking:transfers:read
```

Do not give the agent direct write permissions by default:

```text
banking:payments:create
banking:transfers:create
banking:compliance:write
banking:fraud:write
banking:admin
```

This keeps the agent read-only by default. Sensitive actions must depend on the human user's permissions and, in production, backend/APIM enforcement.

### 9.3 Assign the agent role

Assign:

```text
BankingOmniAgent → Banking Omni Assistant Agent
```

### 9.4 Rebuild UI after adding agent metadata

```bash
docker compose build banking-ui --no-cache
docker compose up -d banking-ui
```

---

## 10. Banking UI Permission Model

The UI enforces two layers of behavior:

### 10.1 API card guard

Each API card requires a scope.

| UI action | Scope |
|---|---|
| Customer profile | `banking:profile:read` |
| Account balance | `banking:accounts:read` |
| Card status | `banking:cards:read` |
| Create PIX payment | `banking:payments:create` |
| Payment status | `banking:payments:read` |
| Create TED transfer | `banking:transfers:create` |
| Transfer status | `banking:transfers:read` |
| Create audit event | `banking:compliance:write` |
| Create fraud alert | `banking:fraud:write` |
| Agent chat | `agent:chat` |

### 10.2 Agent visibility guard

The agent is not mounted in the page unless:

```text
User is authenticated
AND
Token contains agent:chat
```

### 10.3 Agent sensitive action guard

In direct-agent mode, the UI also blocks sensitive prompts before they reach the Ballerina agent.

Examples:

| Prompt intent | Required scope |
|---|---|
| Create/submit/initiate/send/process PIX or payment | `banking:payments:create` |
| Create/submit/initiate/send/process TED or transfer | `banking:transfers:create` |
| Create/write/register/record audit or compliance event | `banking:compliance:write` |
| Create/write/register/record fraud alert | `banking:fraud:write` |

This prevents a user like Ana from using the chat to bypass missing payment permissions.

Production note: this frontend guard is for demo safety. In production, enforce the same policy at APIM and/or inside the agent/backend resource layer.

---

## 11. Running the Demo

### 11.1 Start everything

```bash
docker compose up -d
docker compose ps
```

### 11.2 Open the UI

```text
http://localhost:5173
```

### 11.3 Positive and negative tests

#### Ana positive test

Login:

```text
ana / Ana@12345
```

Invoke:

```text
Customer profile
Customer ID: CUST-BR-001
```

Expected:

```text
Success. Ana has banking:profile:read.
```

Ask agent:

```text
Summarize the current customer profile for CUST-BR-001 and highlight risk signals.
```

Expected:

```text
Allowed. Ana has agent:chat and retail read permissions.
```

#### Ana negative test

Try UI action:

```text
Create PIX payment
```

Expected:

```text
Button is locked or disabled with Missing banking:payments:create.
```

Ask agent:

```text
Create a PIX payment of 320 BRL from ACC-CHK-BR-001 to merchant@pix.example.
```

Expected:

```text
Blocked by Identity policy: This agent request appears to ask the agent to create PIX payments, but the current user token is missing banking:payments:create.
```

#### Bruno positive test

Login:

```text
bruno / Bruno@12345
```

Invoke:

```text
Create PIX payment
```

Expected:

```text
Allowed. Bruno has banking:payments:create.
```

Ask agent:

```text
Create a PIX payment of 320 BRL from ACC-CHK-BR-001 to merchant@pix.example.
```

Expected:

```text
Allowed in the demo UI policy because Bruno has banking:payments:create.
```

#### Clara negative/positive mix

Login:

```text
clara / Clara@12345
```

Expected:

```text
Agent is hidden because Clara does not have agent:chat.
Payment and transfer actions are locked.
Compliance and fraud actions are available.
```

Optional live demo:

1. Add `BankingAgentUser` to Clara.
2. Log out from the UI.
3. Log in again as Clara.
4. Show that the agent now appears.

---

## 12. Direct Smoke Tests

Set variables:

```bash
export BACKEND=http://localhost:8080
export MI=http://localhost:8290
export AGENT=http://localhost:8293
export UI=http://localhost:5173
export APIM=http://localhost:8280
export CID=test-corr-001
```

### 12.1 Backend

```bash
curl -i "$BACKEND/health"
curl -i "$BACKEND/admin/snapshot"
```

### 12.2 MI direct

```bash
curl -i \
  -H "X-Correlation-Id: mi-cust-001" \
  "$MI/customers/1.0.0/profile/CUST-BR-001"

curl -i \
  -H "X-Correlation-Id: mi-acc-001" \
  "$MI/accounts/1.0.0/balance/ACC-CHK-BR-001"

curl -i \
  -H "X-Correlation-Id: mi-card-001" \
  "$MI/cards/1.0.0/status/CARD-CR-BR-001"
```

### 12.3 MI through UI proxy

```bash
curl -i "$UI/mi/customers/1.0.0/profile/CUST-BR-001"
curl -i "$UI/mi/accounts/1.0.0/balance/ACC-CHK-BR-001"
curl -i "$UI/mi/cards/1.0.0/status/CARD-CR-BR-001"
```

### 12.4 Agent direct

```bash
curl -i -X POST "$AGENT/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: agent-direct-001" \
  -d '{
    "sessionId": "sess-agent-direct-001",
    "message": "Show me customer CUST-BR-001 and account ACC-CHK-BR-001."
  }'
```

### 12.5 Agent through UI proxy

```bash
curl -i -X POST "$UI/agent/v1/omni/chat" \
  -H "Content-Type: application/json" \
  -H "X-Agent-Id: test-agent" \
  -H "X-Agent-Name: Banking Omni Assistant Agent" \
  -H "X-Correlation-Id: agent-proxy-001" \
  -d '{
    "sessionId": "sess-agent-proxy-001",
    "message": "Show me customer CUST-BR-001 and account ACC-CHK-BR-001."
  }'
```

---

## 13. Mocked Backend Data

### Customers

| Customer | Name | Risk | Accounts | Cards |
|---|---|---|---|---|
| `CUST-BR-001` | Beatriz Costa | LOW | `ACC-CHK-BR-001`, `ACC-SAV-BR-001` | `CARD-CR-BR-001` |
| `CUST-BR-002` | Daniel Martins | MEDIUM | `ACC-CHK-BR-002` | `CARD-DB-BR-002` |
| `CUST-BR-003` | Fernanda Lima | HIGH | `ACC-CHK-BR-003` | `CARD-CR-BR-003` |

### Useful test IDs

```text
Customer:
CUST-BR-001

Checking account:
ACC-CHK-BR-001

Savings account:
ACC-SAV-BR-001

Credit card:
CARD-CR-BR-001

Seeded PIX:
PMT-PIX-20260315-0001

Seeded TED:
TRF-20260315-0001
```

---

## 14. Agentic Layer Endpoints

### Business chat endpoints

```text
POST /v1/retail/chat
POST /v1/payments/chat
POST /v1/risk/chat
POST /v1/compliance/chat
POST /v1/knowledge/chat
POST /v1/omni/chat
POST /v1/omni_a2a/chat
```

Direct Ballerina request shape:

```json
{
  "sessionId": "sess-001",
  "message": "Show me customer CUST-BR-001."
}
```

### RAG endpoints

```text
GET  /v1/rag/documents
POST /v1/rag/search
POST /v1/rag/documents
POST /v1/rag/reset
```

### AI adapter endpoints

```text
POST /v1/ai/retail/chat/completions
POST /v1/ai/payments/chat/completions
POST /v1/ai/risk/chat/completions
POST /v1/ai/compliance/chat/completions
POST /v1/ai/knowledge/chat/completions
POST /v1/ai/omni_a2a/chat/completions
```

OpenAI-compatible request shape:

```json
{
  "model": "banking-retail-ai",
  "messages": [
    {
      "role": "user",
      "content": "Explain customer CUST-BR-001."
    }
  ]
}
```

---

## 15. Optional APIM Mode

The local UI currently bypasses APIM because no APIs need to be published for the Identity Server-focused demo.

To switch the UI to APIM mode later:

1. Publish the MI-backed APIs in APIM.
2. Publish the AI adapter endpoints as APIM AI APIs.
3. Configure API scopes in APIM.
4. Configure token validation/key manager as needed.
5. Change root `.env`.

Example APIM mode:

```env
VITE_APIM_BASE_URL=http://localhost:5173/gateway
VITE_AGENT_CONTRACT=ai-adapter
VITE_AGENT_CHAT_URL=http://localhost:5173/gateway/v1/ai/omni_a2a/chat/completions
```

Then update `banking-demo-ui/nginx.conf` to include:

```nginx
location /gateway/ {
    proxy_pass http://apim:8280/;
    proxy_http_version 1.1;

    proxy_set_header Host $host;
    proxy_set_header Authorization $http_authorization;
    proxy_set_header X-Correlation-Id $http_x_correlation_id;
    proxy_set_header x-fapi-interaction-id $http_x_fapi_interaction_id;

    proxy_buffering off;
    proxy_read_timeout 300s;
    proxy_connect_timeout 60s;
}
```

Rebuild:

```bash
docker compose build banking-ui --no-cache
docker compose up -d banking-ui
```

---

## 16. APIM AI API Examples

If APIM APIs are published, example gateway paths may look like:

```text
/bankingretailaiadapter/1.0.0/chat/completions
/bankingpaymentsaiadapter/1.0.0/chat/completions
/bankingriskaiadapter/1.0.0/chat/completions
/bankingcomplianceaiadapter/1.0.0/chat/completions
/bankingknowledgeaiadapter/1.0.0/chat/completions
/bankingomnia2aaiadapter/1.0.0/chat/completions
```

Example:

```bash
curl -i -X POST "$APIM/bankingretailaiadapter/1.0.0/chat/completions" \
  -H "ApiKey: $APIKEY" \
  -H "Content-Type: application/json" \
  -H "X-Session-Id: apim-retail-ai-001" \
  -d '{
    "model":"banking-retail-ai",
    "messages":[
      {
        "role":"user",
        "content":"Explain customer CUST-BR-001, account ACC-CHK-BR-001, and card CARD-CR-BR-001."
      }
    ]
  }'
```

---

## 17. Troubleshooting

### 17.1 `https://localhost:9444/console` shows API Manager error

Problem:

```text
Cannot find an application associated with the given consumer key.
```

Cause:

```text
Identity Server was exposed as host 9444 but still running internally as 9443, causing redirect confusion with APIM.
```

Fix:

Use `-DportOffset=1` and map:

```yaml
ports:
  - "9444:9444"
```

Then reset the old IS volume if needed:

```bash
docker compose down
docker volume ls | grep is_home
docker volume rm <your_is_volume_name>
docker compose up -d wso2is
```

### 17.2 Docker says `COPY nginx.conf` failed

Cause:

```text
banking-demo-ui/.dockerignore excluded nginx.conf.
```

Fix:

```bash
cat > banking-demo-ui/.dockerignore <<'EOF'
node_modules
dist
.env
npm-debug.log
EOF
```

Then:

```bash
docker compose build banking-ui --no-cache
```

### 17.3 APIM logs `Invalid URL` for `/customers/...`

Cause:

```text
The UI is pointing to APIM but those APIs are not published in APIM.
```

Fix for direct mode:

```env
VITE_APIM_BASE_URL=http://localhost:5173/mi
VITE_AGENT_CONTRACT=banking-agent
VITE_AGENT_CHAT_URL=http://localhost:5173/agent/v1/omni/chat
```

Rebuild UI:

```bash
docker compose build banking-ui --no-cache
docker compose up -d banking-ui
```

### 17.4 Agent returns `data binding failed: undefined field 'context'`

Cause:

```text
The direct Ballerina /v1/omni/chat endpoint rejects unknown JSON fields.
```

Fix:

Use:

```env
VITE_AGENT_CONTRACT=banking-agent
```

The UI must send:

```json
{
  "sessionId": "...",
  "message": "..."
}
```

not:

```json
{
  "sessionId": "...",
  "message": "...",
  "context": {}
}
```

### 17.5 Ana can create PIX through the agent

Cause:

```text
The agent chat path was not applying the same write-scope policy as the UI API cards.
```

Fix:

Ensure `main.js` contains `SENSITIVE_AGENT_POLICIES` and calls `enforceAgentPromptPolicy(message)` before `callAgent(message)`.

Expected Ana result:

```text
Blocked by Identity policy: This agent request appears to ask the agent to create PIX payments, but the current user token is missing banking:payments:create.
```

### 17.6 Docker Compose panics with `monitor.go`

This is a Docker Compose CLI issue in some versions.

Workaround:

```bash
docker compose up -d
docker compose logs -f
```

instead of:

```bash
docker compose up
```

### 17.7 `Config.toml` mount error

Error:

```text
not a directory: Are you trying to mount a directory onto a file?
```

Check:

```bash
file banking_agent_bi/Config.toml
```

Expected:

```text
ASCII text
```

Prefer one mount:

```yaml
volumes:
  - ./banking_agent_bi/Config.toml:/workspace/Config.toml:ro
```

Or remove the volume if the Dockerfile already copies the config.

---

## 18. Useful Logs

```bash
docker compose logs -f banking-ui
docker compose logs -f wso2is
docker compose logs -f banking-agent
docker compose logs -f wso2mi
docker compose logs -f banking-backend
docker compose logs -f apim
docker compose logs -f banking-webhook-listener
```

---

## 19. Demo Talk Track

### Opening

```text
This demo shows how WSO2 Identity Server controls who the user is and what they can do, WSO2 Micro Integrator mediates banking APIs, and the banking agent is governed as a separate identity. The user cannot use the agent to bypass missing permissions.
```

### Ana

```text
Ana is a retail user. She can read customer/account/card data and chat with the assistant, but she cannot create payments or compliance records.
```

Show:

```text
Customer profile works.
Create PIX is locked.
Agent is visible.
Agent PIX creation request is blocked by identity policy.
```

### Bruno

```text
Bruno is a payments operator. Same UI, different roles and scopes. Payment and transfer capabilities are now available.
```

Show:

```text
Create PIX works.
Create TED works.
Compliance/fraud remain unavailable.
```

### Clara

```text
Clara is a compliance analyst. She can write compliance/fraud events, but she cannot create payments. She also cannot see the agent until agent:chat is granted.
```

Show:

```text
Agent hidden.
Payment locked.
Compliance/fraud available.
```

### Agent identity

```text
The agent is not just a UI widget. It is registered in WSO2 Identity Server as an AI agent with Agent ID, Agent Secret, OAuth Client ID, and its own roles. The browser never receives the agent secret.
```

### Production note

```text
This local demo enforces user permissions in the UI and agent prompt guard while calling MI and the agent directly. In production, the same policies should be enforced at APIM and resource-server layers, with IS-issued tokens validated at the gateway/backend.
```

---

## 20. Security Notes

- The browser must never receive the agent secret.
- `VITE_*` variables are public in the browser bundle.
- Use least privilege for both users and agents.
- Keep the agent read-only by default.
- Sensitive operations should require human user permissions.
- In production, never rely only on frontend guards.
- Enforce scopes at APIM and/or backend/resource server.
- Use correlation IDs for auditability.
- Keep APIM as the recommended governance boundary for AI APIs and A2A flows.

---

## 21. Quick Demo Checklist

Before presenting:

```bash
docker compose down
docker compose build banking-ui --no-cache
docker compose up -d
docker compose ps
```

Open:

```text
http://localhost:5173
https://localhost:9444/console
https://localhost:9443/publisher
```

Verify:

```bash
curl -i http://localhost:5173
curl -i http://localhost:5173/mi/customers/1.0.0/profile/CUST-BR-001
curl -i -X POST http://localhost:5173/agent/v1/omni/chat \
  -H "Content-Type: application/json" \
  -d '{
    "sessionId": "sess-smoke",
    "message": "Show me customer CUST-BR-001."
  }'
```

Then test the users:

```text
ana / Ana@12345
bruno / Bruno@12345
clara / Clara@12345
bankadmin / Admin@12345
```

The most important proof point:

```text
Ana can chat, but cannot ask the agent to execute PIX.
Bruno can execute PIX because he has the payment scope.
Clara can do compliance/fraud work, but does not see the agent unless agent:chat is granted.
```
