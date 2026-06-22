# WSO2 Banking Identity, Integration, API, and Agent Demo

This repository is a complete local demo for a modern banking architecture using:

- **WSO2 Identity Server 7.3** for user authentication, roles, permissions, API-resource authorization, and AI agent identity.
- **WSO2 API Manager** for API governance, AI API exposure, OAuth/API-key validation, subscriptions, throttling, and gateway routing.
- **WSO2 Micro Integrator** for banking API mediation and controlled backend integration.
- **A Ballerina banking agent layer** for retail, payments, risk, compliance, knowledge/RAG, omni orchestration, and OpenAI-compatible AI adapter endpoints.
- **A JavaScript mock banking backend** for customers, accounts, cards, PIX payments, TED transfers, compliance events, fraud alerts, and telemetry.
- **A browser-based banking demo UI** for Identity Server login, permission-aware API invocation, APIM-routed calls, and governed agent chat.

The demo is designed to show the difference between:

1. **User permissions**: what the authenticated human user can do.
2. **Agent permissions**: whether the banking assistant can appear and what actions it may attempt.
3. **OBO-style delegated control**: a sensitive operation should pass only when the user and the agent are both allowed.
4. **Integration mediation**: how banking APIs flow through WSO2 Micro Integrator.
5. **APIM governance**: how REST banking APIs and AI adapter APIs are published and routed through WSO2 API Manager.

> Current APIM demo mode: the browser logs in with WSO2 Identity Server, sends the user bearer token to APIM through the UI Nginx `/gateway/` proxy, calls the MI-backed banking API through APIM, and calls the Omni banking agent through APIM. The Omni agent then calls managed sub-agent AI APIs through APIM using a server-side API key.

---

## 1. Architecture Overview

### Runtime components

| Component | Folder / Service | Default URL | Purpose |
|---|---|---:|---|
| Banking UI | `banking-demo-ui` / `banking-ui` | `http://localhost:5173` | Browser UI for login, scoped API access, and agent chat |
| WSO2 Identity Server | `wso2is` | `https://localhost:9444/console` | Users, roles, scopes/permissions, SPA app, and AI agent identity |
| WSO2 API Manager | `apim` | `https://localhost:9443` | API and AI API governance |
| WSO2 Micro Integrator | `banking-mi` / `wso2mi` | `http://localhost:8290` | Canonical banking APIs and mediation |
| Banking Agent | `banking_agent_bi` / `banking-agent` | `http://localhost:8293` | Ballerina agentic APIs and AI adapters |
| Mock Backend | `banking-backend-js` / `banking-backend` | `http://localhost:8080` | Mock core banking system |
| Webhook Listener | `banking-webhook-listener` | `http://localhost:8099` | Agent handoff event sink |

### APIM-governed demo flow

```text
Browser UI
  ↓ login
WSO2 Identity Server 7.3
  ↓ user access token with scopes
Browser UI
  ↓ Authorization: Bearer <user token>
UI Nginx proxy /gateway/*
  ↓
WSO2 API Manager Gateway
  ↓ OAuth validation against WSO2 IS
MI-backed Banking API
  ↓
WSO2 Micro Integrator
  ↓
Mock banking backend
```

```text
Browser UI
  ↓ Authorization: Bearer <user token>, agent metadata headers
UI Nginx proxy /gateway/bankingagent/1.0.0/chat/completions
  ↓
WSO2 API Manager Gateway
  ↓ OAuth validation: agent:chat
Ballerina Omni AI Adapter
  ↓ server-side APIM API key
APIM sub-agent AI APIs
  ↓
Retail / Payments / Risk / Compliance / Knowledge agents
  ↓ tools
WSO2 Micro Integrator
  ↓
Mock banking backend
```

### Direct local fallback mode

The repository can still run without APIM-published APIs:

```text
Browser UI /mi/*     → WSO2 Micro Integrator
Browser UI /agent/*  → Ballerina Banking Agent
```

Use the direct mode only for local troubleshooting. Use APIM mode for the full demo.

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
  Browser-based Identity Server + APIM + banking API + agent demo UI

docker-compose.yml
  Local orchestration for the complete environment

.env
  Local Docker Compose and frontend build configuration; do not commit this file

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

## 4. Required Local Files and Security Rules

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

### 4.2 APIM demo `.env`

Use this when APIM is publishing the MI API and the Omni AI API:

```env
# Optional OpenAI key for the Ballerina banking agent.
OPENAI_API_KEY=

# WSO2 Identity Server SPA configuration.
VITE_IS_BASE_URL=https://localhost:9444
VITE_IS_CLIENT_ID=REPLACE_WITH_WSO2_IS_SPA_CLIENT_ID
VITE_REDIRECT_URL=http://localhost:5173
VITE_SIGN_OUT_REDIRECT_URL=http://localhost:5173

# APIM gateway through UI Nginx proxy.
VITE_APIM_BASE_URL=http://localhost:5173/gateway

# MI API published in APIM as context /bankingmi, version 1.0.0.
VITE_BANKING_MI_CONTEXT=/bankingmi/1.0.0

# Omni agent published in APIM as an AI/OpenAI-compatible API.
VITE_AGENT_CONTRACT=ai-adapter
VITE_AGENT_CHAT_URL=http://localhost:5173/gateway/bankingagent/1.0.0/chat/completions

# WSO2 IS AI agent identity.
BANKING_AGENT_ID=
BANKING_AGENT_SECRET=
BANKING_AGENT_OAUTH_CLIENT_ID=
WSO2_IS_BASE_URL=https://wso2is:9444

# Safe-to-show frontend agent metadata.
# Never expose BANKING_AGENT_SECRET as a VITE_* variable.
VITE_AGENT_ID=
VITE_AGENT_OAUTH_CLIENT_ID=
VITE_AGENT_NAME=Banking Omni Assistant Agent
VITE_AGENT_PURPOSE=Interactive governed banking assistant with delegated sensitive actions.

# Server-side APIM API key for Omni → managed sub-agent AI APIs.
# Generate this in APIM DevPortal from the application subscribed to sub-agent AI APIs.
AGENT_GATEWAY_ACCESS_TOKEN=

# Optional local OBO pre-check demo.
# This is a local mirror/config shim, not dynamic IS-backed OBO.
ENABLE_OBO_AUTHORIZATION=true
AGENT_ALLOWED_SCOPES=agent:chat banking:profile:read banking:accounts:read banking:cards:read banking:payments:create banking:payments:read banking:transfers:create banking:transfers:read banking:compliance:write banking:fraud:write

# Optional UI-only rehearsal mode.
VITE_ENABLE_MOCK_AUTH=false
VITE_MOCK_SCOPES=
```

Important:

- `VITE_*` values are embedded during the Vite UI build.
- After changing any `VITE_*` value, rebuild `banking-ui`.
- Never create `VITE_AGENT_SECRET`.
- Never commit `.env`.
- Never commit generated API keys, access tokens, cert private keys, truststores, or local WSO2 runtime folders.

### 4.3 Direct local fallback `.env`

Use this only when bypassing APIM for local troubleshooting:

```env
VITE_APIM_BASE_URL=http://localhost:5173/mi
VITE_BANKING_MI_CONTEXT=
VITE_AGENT_CONTRACT=banking-agent
VITE_AGENT_CHAT_URL=http://localhost:5173/agent/v1/omni/chat
```

---

## 5. Docker Compose Requirements

Your `docker-compose.yml` should include these services:

- `banking-backend`
- `wso2mi` or `banking-mi`
- `banking-agent`
- `banking-webhook-listener`
- `apim`
- `wso2is`
- `banking-ui`

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
        VITE_APIM_BASE_URL: ${VITE_APIM_BASE_URL:-http://localhost:5173/gateway}
        VITE_BANKING_MI_CONTEXT: ${VITE_BANKING_MI_CONTEXT:-/bankingmi/1.0.0}
        VITE_AGENT_CONTRACT: ${VITE_AGENT_CONTRACT:-ai-adapter}
        VITE_AGENT_CHAT_URL: ${VITE_AGENT_CHAT_URL:-http://localhost:5173/gateway/bankingagent/1.0.0/chat/completions}
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
      - apim
```

### 5.3 Banking agent environment for APIM-routed A2A

Ballerina configurable variables should be passed with `BAL_CONFIG_VAR_...`.

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

      # APIM-routed managed sub-agent AI APIs.
      - BAL_CONFIG_VAR_ENABLE_GATEWAY_A2A_DEMO=true
      - BAL_CONFIG_VAR_AGENT_GATEWAY_BASE_URL=http://apim:8280
      - BAL_CONFIG_VAR_AGENT_GATEWAY_AUTH_MODE=api_key
      - BAL_CONFIG_VAR_AGENT_GATEWAY_API_KEY_HEADER=apikey
      - BAL_CONFIG_VAR_AGENT_GATEWAY_ACCESS_TOKEN=${AGENT_GATEWAY_ACCESS_TOKEN:-}

      # Optional local OBO pre-check demo.
      # This mirrors agent scopes locally and is not dynamic IS-backed OBO.
      - BAL_CONFIG_VAR_ENABLE_OBO_AUTHORIZATION=${ENABLE_OBO_AUTHORIZATION:-true}
      - BAL_CONFIG_VAR_AGENT_ALLOWED_SCOPES=${AGENT_ALLOWED_SCOPES:-agent:chat}

      # Timeout safety.
      - BAL_CONFIG_VAR_BACKEND_HTTP_TIMEOUT_SECONDS=${BACKEND_HTTP_TIMEOUT_SECONDS:-15}
      - BAL_CONFIG_VAR_BACKEND_HTTP_MAX_RETRIES=${BACKEND_HTTP_MAX_RETRIES:-1}
    ports:
      - "8293:8293"
    depends_on:
      - wso2mi
      - apim
```

Important APIM API-key detail:

```text
Use header name: apikey
Do not use: Internal-Key
```

A direct APIM call using `Internal-Key` returned `401 invalid_token` in this setup. The working sub-agent calls used:

```text
apikey: <generated APIM API key>
```

---

## 6. Banking UI Nginx Proxy

For APIM mode, keep `/mi/` and `/agent/` as local fallbacks, but add `/gateway/` for APIM.

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    location /gateway/ {
        proxy_pass http://apim:8280/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
        proxy_set_header Authorization $http_authorization;
        proxy_set_header Accept $http_accept;
        proxy_set_header Content-Type $http_content_type;

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
        proxy_set_header X-Authorization-Model $http_x_authorization_model;

        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
    }

    location /mi/ {
        proxy_pass http://banking-mi:8290/;
        proxy_http_version 1.1;

        proxy_set_header Host $host;
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
        proxy_set_header X-Authorization-Model $http_x_authorization_model;

        proxy_buffering off;
        proxy_read_timeout 300s;
        proxy_connect_timeout 60s;
    }
}
```

After changing `nginx.conf` or `VITE_*` values:

```bash
docker compose build banking-ui --no-cache
docker compose up -d banking-ui
```

---

## 7. Start from Scratch

```bash
git clone https://github.com/joaokuntzwso2/demo-banking
cd demo-banking
```

Create `.env`, then:

```bash
docker compose build --no-cache
docker compose up -d
docker compose ps
```

Open:

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

Select all permissions/scopes needed by the demo:

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

| Role | Permissions |
|---|---|
| `BankingRetailViewer` | `banking:profile:read`, `banking:accounts:read`, `banking:cards:read` |
| `BankingPaymentsOperator` | `banking:payments:create`, `banking:payments:read`, `banking:transfers:create`, `banking:transfers:read` |
| `BankingComplianceAnalyst` | `banking:compliance:write`, `banking:fraud:write` |
| `BankingAgentUser` | `agent:chat` |
| `BankingAdmin` | all banking scopes plus `agent:chat` and `banking:admin` |

### 8.5 Create users

| User | Password | Roles | Demo behavior |
|---|---|---|---|
| `ana` | `Ana@12345` | `BankingRetailViewer`, `BankingAgentUser` | Retail reads + agent, no write operations |
| `bruno` | `Bruno@12345` | `BankingRetailViewer`, `BankingPaymentsOperator`, `BankingAgentUser` | Retail + payments/transfers + agent |
| `clara` | `Clara@12345` | `BankingRetailViewer`, `BankingComplianceAnalyst` | Retail + compliance/fraud, no agent |
| `bankadmin` | `Admin@12345` | `BankingAdmin` | Everything |

After changing roles or permissions, always log out and log in again because scopes are issued at login time.

---

## 9. Create the AI Agent Identity in WSO2 IS

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
Interactive conversational banking assistant for WSO2 demo scenarios. It helps authenticated banking users inspect accounts, cards, payments, transfers, compliance events, and fraud signals.

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

### 9.2 Create and assign an agent role

Create a role:

```text
BankingOmniAgent
```

Recommended read/default permissions:

```text
agent:chat
banking:profile:read
banking:accounts:read
banking:cards:read
banking:payments:read
banking:transfers:read
```

For write-operation demos, add/remove permissions deliberately:

```text
banking:payments:create
banking:transfers:create
banking:compliance:write
banking:fraud:write
```

Assign:

```text
BankingOmniAgent → Banking Omni Assistant Agent
```

### 9.3 OBO note for this local demo

The current local code can demonstrate OBO-style decisions, but the temporary `AGENT_ALLOWED_SCOPES` variable is only a local mirror of agent permissions. It is not dynamic IS-backed OBO.

For production-grade OBO, the agent should request a delegated token from IS at runtime and call APIs with that delegated bearer token. Do not present a local static scope mirror as dynamic authorization.

---

## 10. Configure APIM to Trust WSO2 IS as Key Manager

APIM must validate user tokens issued by WSO2 IS.

Open:

```text
https://localhost:9443/admin
```

Go to:

```text
Key Managers → Add Key Manager
```

Suggested configuration:

```text
Name:
WSO2-IS

Type:
WSO2 Identity Server 7

Issuer:
https://localhost:9444/oauth2/token
```

For Docker local demo, prefer internal HTTP endpoints to avoid local truststore/certificate issues:

```text
Client Registration Endpoint:
http://wso2is:9764/api/identity/oauth2/dcr/v1.1/register

Introspection Endpoint:
http://wso2is:9764/oauth2/introspect

Token Endpoint:
http://wso2is:9764/oauth2/token

Display Token Endpoint:
https://localhost:9444/oauth2/token

Revoke Endpoint:
http://wso2is:9764/oauth2/revoke

Display Revoke Endpoint:
https://localhost:9444/oauth2/revoke

UserInfo Endpoint:
http://wso2is:9764/scim2/Me

Authorize Endpoint:
https://localhost:9444/oauth2/authorize

Scope Management Endpoint:
http://wso2is:9764/api/identity/oauth2/v1.0/scopes

JWKS Endpoint:
http://wso2is:9764/oauth2/jwks

API Resources Endpoint:
http://wso2is:9764/api/server/v1/api-resources

Roles Endpoint:
http://wso2is:9764/scim2/v2/Roles
```

Use admin credentials for management endpoints:

```text
Username: admin
Password: admin
```

### 10.1 Certificate/truststore option if you use HTTPS container endpoints

The internal HTTP configuration above is the simplest local demo path. If you configure APIM to call IS over internal HTTPS, import the IS certificate into APIM's client truststore.

Create a local folder for generated cert material:

```bash
mkdir -p wso2is-km/certs
```

Export the IS certificate:

```bash
docker exec wso2is sh -lc '
keytool -exportcert \
  -alias wso2carbon \
  -keystore "$CARBON_HOME/repository/resources/security/wso2carbon.p12" \
  -storetype PKCS12 \
  -storepass wso2carbon \
  -file /tmp/wso2is.crt \
  -rfc
'

docker cp wso2is:/tmp/wso2is.crt wso2is-km/certs/wso2is.crt
```

Import it into APIM:

```bash
docker cp wso2is-km/certs/wso2is.crt apim:/tmp/wso2is.crt

docker exec apim sh -lc '
keytool -importcert \
  -noprompt \
  -alias wso2is-local \
  -file /tmp/wso2is.crt \
  -keystore "$CARBON_HOME/repository/resources/security/client-truststore.jks" \
  -storepass wso2carbon
'

docker restart apim
```

Verify paths if needed:

```bash
docker exec wso2is sh -lc 'echo $CARBON_HOME && ls "$CARBON_HOME/repository/resources/security"'
docker exec apim sh -lc 'echo $CARBON_HOME && ls "$CARBON_HOME/repository/resources/security"'
```

Do not commit local cert/truststore material:

```gitignore
wso2is-km/
*.jks
*.p12
*.pem
*.key
*.crt
*.cer
```

---

## 11. Publish the MI-backed Banking API in APIM

This exposes WSO2 Micro Integrator through APIM.

Open:

```text
https://localhost:9443/publisher
```

Create a REST API:

```text
Name:
Banking MI API

Context:
bankingmi

Version:
1.0.0

Endpoint:
http://banking-mi:8290
```

Add resources for the banking paths you use from the UI:

```text
GET  /customers/1.0.0/profile/{customerId}
GET  /accounts/1.0.0/balance/{accountId}
GET  /cards/1.0.0/status/{cardId}
POST /payments/1.0.0/pix/sync
GET  /payments/1.0.0
POST /transfers/1.0.0/ted/async
GET  /transfers/1.0.0
POST /compliance/1.0.0/audit
POST /fraud/1.0.0/alerts
```

Configure security:

```text
Security:
OAuth2

Scopes:
Map each resource to the corresponding Banking Demo API scope.
```

For a smooth UI demo, disable subscriptions/business plans on this user-facing API:

```text
Business Plans:
Uncheck all plans for the MI API.
```

This avoids requiring a browser SPA to also manage an APIM application subscription. OAuth2 and scope validation remain active.

Publish the API.

Expected UI setting:

```env
VITE_APIM_BASE_URL=http://localhost:5173/gateway
VITE_BANKING_MI_CONTEXT=/bankingmi/1.0.0
```

---

## 12. Publish the Omni Agent API in APIM

This is the user-facing AI API.

Create an API in APIM Publisher:

```text
Name:
Banking Agent

Context:
bankingagent

Version:
1.0.0

Resource:
POST /chat/completions

Endpoint:
http://banking-agent:8293/v1/ai/omni_a2a/chat/completions
```

Configure security:

```text
Security:
OAuth2

Required scope:
agent:chat
```

For the user-facing Omni API, disable subscriptions/business plans:

```text
Business Plans:
Uncheck all plans for the Banking Agent API.
```

Publish the API.

Expected UI setting:

```env
VITE_AGENT_CONTRACT=ai-adapter
VITE_AGENT_CHAT_URL=http://localhost:5173/gateway/bankingagent/1.0.0/chat/completions
```

---

## 13. Publish Managed Sub-agent AI APIs in APIM

These APIs are called by the Omni agent, not directly by the browser.

Create one API for each adapter:

| APIM API name | Context | Version | Resource | Backend endpoint |
|---|---|---:|---|---|
| Banking Retail AI Adapter | `bankingretailaiadapter` | `1.0.0` | `POST /chat/completions` | `http://banking-agent:8293/v1/ai/retail/chat/completions` |
| Banking Payments AI Adapter | `bankingpaymentsaiadapter` | `1.0.0` | `POST /chat/completions` | `http://banking-agent:8293/v1/ai/payments/chat/completions` |
| Banking Risk AI Adapter | `bankingriskaiadapter` | `1.0.0` | `POST /chat/completions` | `http://banking-agent:8293/v1/ai/risk/chat/completions` |
| Banking Compliance AI Adapter | `bankingcomplianceaiadapter` | `1.0.0` | `POST /chat/completions` | `http://banking-agent:8293/v1/ai/compliance/chat/completions` |
| Banking Knowledge AI Adapter | `bankingknowledgeaiadapter` | `1.0.0` | `POST /chat/completions` | `http://banking-agent:8293/v1/ai/knowledge/chat/completions` |

Configure security for each sub-agent API:

```text
Security:
API Key

Business Plans:
Keep Unlimited checked.
```

Important:

- Do **not** disable subscriptions/business plans for API Key sub-agent APIs.
- APIM API Key security needs an application subscription/tier. If you uncheck all business plans, APIM can show errors such as `The tier cannot be null`.
- Subscribe the same APIM application to all sub-agent AI APIs.

Recommended DevPortal flow:

```text
DevPortal → Applications → Default Application
Subscribe Default Application to:
  Banking Retail AI Adapter
  Banking Payments AI Adapter
  Banking Risk AI Adapter
  Banking Compliance AI Adapter
  Banking Knowledge AI Adapter
Generate API Key
Copy the generated key into AGENT_GATEWAY_ACCESS_TOKEN
```

The working header in this setup is:

```text
apikey: <generated API key>
```

Not:

```text
Internal-Key: <key>
```

---

## 14. Rebuild After APIM Setup

After changing `.env`, `docker-compose.yml`, or frontend build args:

```bash
docker compose build banking-ui --no-cache
docker compose up -d banking-ui
docker compose up -d --force-recreate banking-agent
```

If you changed Ballerina source:

```bash
docker compose build banking-agent --no-cache
docker compose up -d banking-agent
```

Check runtime env:

```bash
docker exec banking-agent sh -lc '
env | grep -E "AGENT_GATEWAY|BAL_CONFIG_VAR_AGENT_GATEWAY|ENABLE_OBO|AGENT_ALLOWED" |
sed -E "s/(ACCESS_TOKEN=).+/\1<hidden>/"
'
```

---

## 15. Smoke Tests

Set variables:

```bash
export UI=http://localhost:5173
export APIM=http://localhost:8280
export AGENT=http://localhost:8293
export MI=http://localhost:8290
```

### 15.1 Agent direct

```bash
curl -i -X POST "$AGENT/v1/ai/retail/chat/completions" \
  -H "Content-Type: application/json" \
  -H "X-Correlation-Id: direct-retail-ai-001" \
  -d '{
    "model": "banking-retail-ai",
    "messages": [
      {
        "role": "user",
        "content": "Explain customer CUST-BR-001, account ACC-CHK-BR-001, and card CARD-CR-BR-001."
      }
    ],
    "metadata": {
      "sessionId": "direct-retail-ai-001"
    }
  }'
```

### 15.2 Sub-agent through APIM from inside the APIM container

Use the exact key the agent will use:

```bash
KEY="$(docker exec banking-agent sh -lc 'printf %s "$AGENT_GATEWAY_ACCESS_TOKEN"')"

docker exec -e KEY="$KEY" apim sh -lc 'curl -i -X POST http://localhost:8280/bankingretailaiadapter/1.0.0/chat/completions \
  -H "apikey: $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"banking-retail-ai\",\"messages\":[{\"role\":\"user\",\"content\":\"Explain customer CUST-BR-001, account ACC-CHK-BR-001, and card CARD-CR-BR-001.\"}],\"metadata\":{\"sessionId\":\"agent-api-key-test\"}}"'
```

Expected:

```text
HTTP/1.1 200 OK
```

If `Internal-Key` returns `401 invalid_token`, keep using `apikey`.

### 15.3 UI to Omni through APIM

Login to the UI as a user with `agent:chat`, then ask:

```text
Explain customer CUST-BR-001, account ACC-CHK-BR-001, and card CARD-CR-BR-001.
```

Expected logs:

```text
Banking omni A2A agent IN
AGENT_HANDOFF_INTERCEPTED ... BankingRetailAgent ... BEFORE
Banking AI-adapter OUT ... BankingRetailAgent ... httpStatus=200
AGENT_HANDOFF_INTERCEPTED ... BankingRetailAgent ... AFTER ... SUCCESS
```

---

## 16. Agent Test Prompts

Use these exact prompts in the Omni agent chat.

### Retail

```text
Explain customer CUST-BR-001, account ACC-CHK-BR-001, and card CARD-CR-BR-001.
```

Expected handoff:

```text
BankingOmniAgent → BankingRetailAgent
```

### Payments

```text
Check recent payments for account ACC-CHK-BR-001. Summarize any PIX payments and tell me whether anything needs attention. Do not create a new payment.
```

Expected handoff:

```text
BankingOmniAgent → BankingPaymentsAgent
```

### Risk / transfer review

Use the seeded transfer ID, not the customer ID:

```text
Check transfer TRF-20260315-0001 and tell me whether it is under review, what risk signals apply, and whether it requires attention.
```

Expected handoff:

```text
BankingOmniAgent → BankingRiskAgent
```

### Compliance

```text
Review compliance and audit concerns related to transfer TRF-20260315-0001. Tell me whether anything should be escalated.
```

Expected handoff:

```text
BankingOmniAgent → BankingComplianceAgent
```

### Knowledge

```text
Explain the difference between PIX and TED in this banking demo, including when each one should be used and what risks or compliance checks may apply.
```

Expected handoff:

```text
BankingOmniAgent → BankingKnowledgeAgent
```

### Multi-agent review

```text
Run a full banking review for customer CUST-BR-001, account ACC-CHK-BR-001, card CARD-CR-BR-001, and transfer TRF-20260315-0001. Include customer profile, account status, card status, payment activity, transfer risk review, compliance concerns, and banking policy explanation. Route the request to every relevant specialist agent and summarize the result by domain.
```

Expected handoffs:

```text
BankingRetailAgent
BankingPaymentsAgent
BankingRiskAgent
BankingComplianceAgent
BankingKnowledgeAgent
```

---

## 17. Demo OBO Behavior

### Current local OBO behavior

The UI no longer blocks sensitive agent prompts locally. It only checks:

```text
User is authenticated
AND
user token contains agent:chat
```

The request reaches the server-side agent, where the demo can explain or pre-check an OBO decision.

Current local pre-check rule:

```text
ALLOW only if:
  user has required scope
  AND
  agent has required scope
```

Examples:

| User has `banking:payments:create` | Agent has `banking:payments:create` | Expected result |
|---|---|---|
| no | yes | deny |
| yes | no | deny |
| no | no | deny |
| yes | yes | allow |

### Ana negative test

Login:

```text
ana / Ana@12345
```

Ask:

```text
Create a PIX payment of 320 BRL from ACC-CHK-BR-001 to merchant@pix.example for Mercado Sao Bento. Explain the OBO authorization decision.
```

Expected if Ana lacks `banking:payments:create`:

```text
OBO authorization denied.
User delegated permission: missing.
Banking Omni Agent permission: present.
No PIX payment was executed.
```

### Bruno positive test

Login:

```text
bruno / Bruno@12345
```

Ask the same prompt.

Expected if Bruno and the agent both have `banking:payments:create`:

```text
OBO authorization pre-check passed.
Both the signed-in user and the Banking Omni Agent identity have banking:payments:create.
PIX may proceed.
```

### Production OBO note

For production-grade dynamic OBO, do not use static `AGENT_ALLOWED_SCOPES`. Instead:

1. The agent authenticates to IS using Agent ID/Secret.
2. The agent requests an OBO/delegated token for the required banking scope.
3. IS decides based on the human user, the agent identity, consent/delegation, and assigned roles.
4. The downstream APIM/MI call uses the delegated bearer token.
5. APIM/resource server validates the delegated token and scope.

---

## 18. Mocked Backend Data

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

Seeded transfer under review:
TRF-20260315-0001
```

Do not ask the transfer tools only by customer ID. The transfer status tool expects a transfer ID such as:

```text
TRF-20260315-0001
```

---

## 19. Troubleshooting

### 19.1 UI works with IS login, but APIM returns subscription errors

Symptom:

```text
900908 Resource forbidden
API Subscription validation failed
User is not subscribed to access the API
```

For user-facing APIs such as the MI API and the Omni agent API, uncheck all business plans/subscriptions for the local demo.

For sub-agent API Key APIs, keep `Unlimited` checked and subscribe the APIM application.

### 19.2 Sub-agent API key returns 401

Symptom:

```text
401 invalid_token
```

Fix:

Use:

```text
apikey: <generated API key>
```

Do not use:

```text
Internal-Key: <generated API key>
```

Set:

```env
AGENT_GATEWAY_ACCESS_TOKEN=<generated APIM API key>
```

and:

```yaml
- BAL_CONFIG_VAR_AGENT_GATEWAY_AUTH_MODE=api_key
- BAL_CONFIG_VAR_AGENT_GATEWAY_API_KEY_HEADER=apikey
- BAL_CONFIG_VAR_AGENT_GATEWAY_ACCESS_TOKEN=${AGENT_GATEWAY_ACCESS_TOKEN:-}
```

Recreate:

```bash
docker compose up -d --force-recreate banking-agent
```

### 19.3 Omni returns 500, but sub-agent direct APIM call works

Test the exact same prompt directly against the sub-agent APIM API. If direct call returns `200`, the issue is usually timeout/session/orchestration, not APIM auth.

Useful check:

```bash
docker compose logs --tail=300 banking-agent | egrep -i \
'Banking AI-adapter IN|Banking AI-adapter OUT|Banking AI-adapter execution failed|agent_execution_failed|timeout|error|agent-ui'
```

### 19.4 Ballerina config did not change

Ballerina `configurable` values are safest when passed as:

```text
BAL_CONFIG_VAR_<CONFIG_NAME>
```

For example:

```text
BAL_CONFIG_VAR_AGENT_GATEWAY_API_KEY_HEADER=apikey
```

Do not rely only on plain environment variables for Ballerina `configurable` values.

### 19.5 APIM Key Manager HTTPS fails certificate validation

Use internal HTTP endpoints for local Docker, or import the IS certificate into APIM's client truststore as shown in section 10.1.

### 19.6 Browser Basic Auth popup after changing client ID

Do not use an APIM confidential application consumer key as the browser SPA client ID.

Use the WSO2 IS SPA application client ID:

```env
VITE_IS_CLIENT_ID=<IS SPA client ID>
```

The SPA token flow must not require a client secret in the browser.

### 19.7 Agent says a customer ID is required as transfer ID

If the prompt says:

```text
Check transfers for customer CUST-BR-001
```

the risk/transfer tool may try:

```text
/transfers/1.0.0?transferId=CUST-BR-001
```

which returns `404`.

Use:

```text
Check transfer TRF-20260315-0001 and tell me whether it is under review.
```

### 19.8 Docker Compose panics with `monitor.go`

Workaround:

```bash
docker compose up -d
docker compose logs -f
```

instead of:

```bash
docker compose up
```

---

## 20. Logs

```bash
docker compose logs -f banking-ui
docker compose logs -f wso2is
docker compose logs -f banking-agent
docker compose logs -f wso2mi
docker compose logs -f banking-backend
docker compose logs -f apim
docker compose logs -f banking-webhook-listener
```

Useful APIM/agent trace:

```bash
docker compose logs -f apim banking-agent banking-webhook-listener | egrep -i \
'agent-ui|Banking omni|AGENT_HANDOFF|Banking AI-adapter|APIAuthenticationHandler|GatewayUtils|OBO'
```

---

## 21. Demo Talk Track

### Opening

```text
This demo shows how WSO2 Identity Server controls who the user is and what they can do, WSO2 API Manager governs REST and AI APIs, WSO2 Micro Integrator mediates banking systems, and the banking agent is exposed and governed through APIM.
```

### Ana

```text
Ana is a retail user. She can read customer/account/card data and chat with the assistant, but she cannot create payments or compliance records.
```

Show:

```text
Customer profile works.
Create PIX direct API card is locked.
Agent is visible because Ana has agent:chat.
Agent PIX creation request should be denied by the OBO policy if Ana lacks the payment-create scope.
```

### Bruno

```text
Bruno is a payments operator. Same UI, different token scopes. Payment and transfer capabilities are available.
```

Show:

```text
Create PIX works.
Create TED works.
Agent-mediated PIX passes only when both Bruno and the agent are allowed.
```

### Clara

```text
Clara is a compliance analyst. She can write compliance/fraud events, but she cannot create payments. She does not see the agent unless agent:chat is granted.
```

### Agent identity

```text
The agent is registered in WSO2 Identity Server as an AI agent with Agent ID, Agent Secret, OAuth Client ID, and its own roles. The browser never receives the agent secret.
```

### APIM governance

```text
The top-level Omni agent API is exposed through APIM and requires agent:chat. The Omni agent then calls managed sub-agent AI APIs through APIM using a server-side API key, so browser users never see sub-agent credentials.
```

---

## 22. Security and Git Notes

Do not commit:

```text
.env
wso2is-km/
*.jks
*.p12
*.pem
*.key
*.crt
*.cer
certs/
keystores/
truststores/
node_modules/
target/
dist/
```

Recommended `.gitignore` additions:

```gitignore
.env
wso2is-km/
*.jks
*.p12
*.pem
*.key
*.crt
*.cer
certs/
keystores/
truststores/
**/target/
node_modules/
dist/
```

Before committing:

```bash
git status --short
git diff --cached --stat
git diff --cached | grep -Ei 'BEGIN .*PRIVATE KEY|BEGIN CERTIFICATE|password|secret|token|apikey|api_key|OPENAI|AGENT_GATEWAY_ACCESS_TOKEN|client_secret'
```

It is okay if staged content contains variable names such as:

```text
AGENT_GATEWAY_ACCESS_TOKEN=${AGENT_GATEWAY_ACCESS_TOKEN:-}
```

It is not okay if staged content contains real token or secret values.

Commit source changes selectively:

```bash
git add banking-demo-ui/nginx.conf
git add banking-demo-ui/src/main.js
git add banking_agent_bi/ai_adapter.bal
git add banking_agent_bi/config.bal
git add .gitignore
git add -p docker-compose.yml
git commit -m "Add APIM-routed banking agent OBO demo flow"
```

---

## 23. Quick Demo Checklist

Before presenting:

```bash
docker compose down
docker compose build banking-ui --no-cache
docker compose build banking-agent --no-cache
docker compose up -d
docker compose ps
```

Open:

```text
http://localhost:5173
https://localhost:9444/console
https://localhost:9443/publisher
https://localhost:9443/devportal
https://localhost:9443/admin
```

Verify:

```bash
curl -i http://localhost:5173
```

Verify sub-agent APIM API key:

```bash
KEY="$(docker exec banking-agent sh -lc 'printf %s "$AGENT_GATEWAY_ACCESS_TOKEN"')"

docker exec -e KEY="$KEY" apim sh -lc 'curl -i -X POST http://localhost:8280/bankingretailaiadapter/1.0.0/chat/completions \
  -H "apikey: $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"banking-retail-ai\",\"messages\":[{\"role\":\"user\",\"content\":\"Explain customer CUST-BR-001.\"}],\"metadata\":{\"sessionId\":\"quick-demo-check\"}}"'
```

Test users:

```text
ana / Ana@12345
bruno / Bruno@12345
clara / Clara@12345
bankadmin / Admin@12345
```

Most important proof points:

```text
1. Ana can chat, but cannot create PIX unless she has the required payment scope.
2. Bruno can create PIX if both Bruno and the agent are allowed.
3. Clara can do compliance/fraud work but does not see the agent unless agent:chat is granted.
4. APIM routes both the user-facing Omni API and the managed sub-agent AI APIs.
5. Sub-agent API credentials remain server-side.
```
