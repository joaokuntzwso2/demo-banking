# WSO2 Banking Identity Demo UI

This SPA is designed for the `demo-banking` repository and adds a WSO2 Identity Server 7.3 permission-aware interface on top of the existing API Manager, Integrator, JavaScript mock banking backend and omni A2A agent.

## What it demonstrates

- Login through WSO2 Identity Server using the SPA/OIDC authorization-code-with-PKCE pattern.
- API cards are disabled until a user is authenticated.
- Each API card requires a specific OAuth2 scope before it can be invoked.
- Every API call sends `Authorization: Bearer <access_token>`, `X-Correlation-Id`, and `x-fapi-interaction-id`.
- The banking chat agent is not mounted until the user is authenticated and has `agent:chat`.
- The agent can use one of three contracts:
  - `ai-adapter`: OpenAI-compatible APIM AI API, default.
  - `banking-agent`: direct demo-banking Ballerina agent contract: `{ sessionId, message, context }`.
  - `platform-chat`: global BU hotel concierge style contract: `{ message, session_id, context }`.

## Scope model

| Capability | Required scope |
| --- | --- |
| Customer profile | `banking:profile:read` |
| Account balance | `banking:accounts:read` |
| Card status | `banking:cards:read` |
| Create PIX payment | `banking:payments:create` |
| Read payment status | `banking:payments:read` |
| Create TED transfer | `banking:transfers:create` |
| Read transfer status | `banking:transfers:read` |
| Create compliance audit event | `banking:compliance:write` |
| Create fraud alert | `banking:fraud:write` |
| Chat with banking agent | `agent:chat` |
| Administrative operations, optional | `banking:admin` |

The frontend is a user-experience guard. Final enforcement must be done in WSO2 API Manager, WSO2 Identity Server and the downstream resource servers.

## Run

```bash
cd banking-demo-ui
cp .env.example .env
npm install
npm run dev
```

Open `http://localhost:5173`.

## Configure WSO2 Identity Server 7.3

1. Register a Single Page Application.
2. Set the authorized redirect URL to `http://localhost:5173`.
3. Set the sign-out redirect URL to `http://localhost:5173`.
4. Copy the client ID into `.env` as `VITE_IS_CLIENT_ID`.
5. Create or expose an API resource for the banking scopes listed above.
6. Assign scopes to roles and users.
7. Create an agent and assign only the scopes the agent should be allowed to use.

Suggested demo users:

| User | Intended role | Scopes |
| --- | --- | --- |
| Ana Retail | Retail user | profile, accounts, cards, agent chat |
| Bruno Payments | Payments operator | retail scopes, payments, transfers, agent chat |
| Clara Compliance | Compliance analyst | profile, compliance, fraud, agent chat |
| Admin | Full platform owner | all banking scopes |

Suggested agent roles:

| Agent role | Scopes |
| --- | --- |
| `agent_banking_readonly` | `agent:chat`, profile/accounts/cards/payment-read/transfer-read |
| `agent_banking_operator` | read-only scopes plus payment/transfer create, only if you want the agent to act directly |
| `agent_banking_delegated` | read-only token by default; sensitive payment/transfer scopes should be obtained through CIBA/OBO approval |

## Configure API Manager

Publish the banking MI APIs and AI APIs through API Manager and attach the matching scopes to each resource.

Example resource mapping:

| Gateway resource | Method | Scope |
| --- | --- | --- |
| `/customers/1.0.0/profile/{customerId}` | GET | `banking:profile:read` |
| `/accounts/1.0.0/balance/{accountId}` | GET | `banking:accounts:read` |
| `/cards/1.0.0/status/{cardId}` | GET | `banking:cards:read` |
| `/payments/1.0.0/pix/sync` | POST | `banking:payments:create` |
| `/payments/1.0.0` | GET | `banking:payments:read` |
| `/transfers/1.0.0/ted/async` | POST | `banking:transfers:create` |
| `/transfers/1.0.0` | GET | `banking:transfers:read` |
| `/compliance/1.0.0/audit` | POST | `banking:compliance:write` |
| `/fraud/1.0.0/alerts` | POST | `banking:fraud:write` |
| `/v1/ai/omni_a2a/chat/completions` | POST | `agent:chat` |

Enable CORS for `http://localhost:5173` on the APIs used by the browser.

## Environment variables

```bash
VITE_IS_BASE_URL=https://localhost:9444
VITE_IS_CLIENT_ID=<spa-client-id>
VITE_REDIRECT_URL=http://localhost:5173
VITE_SIGN_OUT_REDIRECT_URL=http://localhost:5173
VITE_APIM_BASE_URL=http://localhost:8280
VITE_BANKING_MI_CONTEXT=
VITE_AGENT_CONTRACT=ai-adapter
VITE_AGENT_CHAT_URL=http://localhost:8280/v1/ai/omni_a2a/chat/completions
```

Use `VITE_BANKING_MI_CONTEXT` when the API Manager context adds a prefix. For example, if API Manager exposes the customer profile as `http://localhost:8280/banking-mi/customers/1.0.0/profile/CUST-BR-001`, set:

```bash
VITE_BANKING_MI_CONTEXT=/banking-mi
```

## Dry-run mode

A local mock-login mode exists only for UI rehearsal:

```bash
VITE_ENABLE_MOCK_AUTH=true
```

Keep it disabled for the actual WSO2 Identity Server demo.
