import { AsgardeoSPAClient, SPAUtils } from "@asgardeo/auth-spa";
import { CONFIG, REQUIRED_SCOPES } from "./config.js";
import "./styles.css";

const auth = AsgardeoSPAClient.getInstance();
const app = document.querySelector("#app");
const widgetRoot = document.querySelector("#agent-widget-root");

const state = {
  ready: false,
  authenticated: false,
  user: null,
  accessToken: null,
  tokenClaims: {},
  scopes: [],
  roles: [],
  lastResult: null,
  error: null,
  sessionId: getOrCreateSessionId(),
  chatMessages: []
};

const API_ACTIONS = [
  {
    id: "profile",
    group: "Retail banking",
    title: "Customer profile",
    product: "Identity Server → UI scope guard → APIM → Integrator → JS banking backend",
    description: "Read KYC, risk rating, accounts and cards for a customer.",
    method: "GET",
    scope: REQUIRED_SCOPES.profileRead,
    fields: [{ name: "customerId", label: "Customer ID", defaultValue: "CUST-BR-001" }],
    path: ({ customerId }) => `/customers/1.0.0/profile/${encodeURIComponent(customerId)}`
  },
  {
    id: "balance",
    group: "Retail banking",
    title: "Account balance",
    product: "Identity Server → UI scope guard → APIM → Integrator → JS banking backend",
    description: "Read current and available balance for an account.",
    method: "GET",
    scope: REQUIRED_SCOPES.accountsRead,
    fields: [{ name: "accountId", label: "Account ID", defaultValue: "ACC-CHK-BR-001" }],
    path: ({ accountId }) => `/accounts/1.0.0/balance/${encodeURIComponent(accountId)}`
  },
  {
    id: "cardStatus",
    group: "Retail banking",
    title: "Card status",
    product: "Identity Server → UI scope guard → APIM → Integrator → JS banking backend",
    description: "Read the status and limits of a card.",
    method: "GET",
    scope: REQUIRED_SCOPES.cardsRead,
    fields: [{ name: "cardId", label: "Card ID", defaultValue: "CARD-CR-BR-001" }],
    path: ({ cardId }) => `/cards/1.0.0/status/${encodeURIComponent(cardId)}`
  },
  {
    id: "pixSync",
    group: "Payments",
    title: "Create PIX payment",
    product: "Identity Server user scope guard + APIM + Integrator mediation",
    description: "Initiate a synchronous PIX payment. Direct UI/API invocation requires payment creation permission.",
    method: "POST",
    scope: REQUIRED_SCOPES.paymentsCreate,
    fields: [
      { name: "sourceAccountId", label: "Source account", defaultValue: "ACC-CHK-BR-001" },
      { name: "destinationKey", label: "PIX destination key", defaultValue: "merchant@pix.example" },
      { name: "amountBr", label: "Amount BRL", type: "number", defaultValue: "320.00" },
      { name: "beneficiaryName", label: "Beneficiary", defaultValue: "Mercado Sao Bento" }
    ],
    path: () => "/payments/1.0.0/pix/sync",
    body: ({ sourceAccountId, destinationKey, amountBr, beneficiaryName }) => ({
      sourceAccountId,
      destinationKey,
      amountBr: Number(amountBr),
      beneficiaryName,
      channel: "banking-identity-demo-ui"
    })
  },
  {
    id: "paymentStatus",
    group: "Payments",
    title: "Payment status",
    product: "Identity Server → UI scope guard → APIM → Integrator → JS banking backend",
    description: "Read the status of a PIX payment by identifier.",
    method: "GET",
    scope: REQUIRED_SCOPES.paymentsRead,
    fields: [{ name: "paymentId", label: "Payment ID", defaultValue: "PAY-000001" }],
    path: ({ paymentId }) => `/payments/1.0.0?paymentId=${encodeURIComponent(paymentId)}`
  },
  {
    id: "tedAsync",
    group: "Transfers",
    title: "Create TED transfer",
    product: "Identity Server user scope guard + APIM + Integrator async mediation",
    description: "Initiate an asynchronous TED transfer through the integration layer.",
    method: "POST",
    scope: REQUIRED_SCOPES.transfersCreate,
    fields: [
      { name: "sourceAccountId", label: "Source account", defaultValue: "ACC-CHK-BR-001" },
      { name: "destinationBankCode", label: "Destination bank code", defaultValue: "341" },
      { name: "amountBr", label: "Amount BRL", type: "number", defaultValue: "1500.00" }
    ],
    path: () => "/transfers/1.0.0/ted/async",
    body: ({ sourceAccountId, destinationBankCode, amountBr }) => ({
      sourceAccountId,
      destinationBankCode,
      amountBr: Number(amountBr),
      channel: "banking-identity-demo-ui"
    })
  },
  {
    id: "transferStatus",
    group: "Transfers",
    title: "Transfer status",
    product: "Identity Server → UI scope guard → APIM → Integrator → JS banking backend",
    description: "Read the status of an asynchronous TED transfer.",
    method: "GET",
    scope: REQUIRED_SCOPES.transfersRead,
    fields: [{ name: "transferId", label: "Transfer ID", defaultValue: "TRF-20260315-0001" }],
    path: ({ transferId }) => `/transfers/1.0.0?transferId=${encodeURIComponent(transferId)}`
  },
  {
    id: "audit",
    group: "Risk and compliance",
    title: "Create audit event",
    product: "Identity Server → UI scope guard → APIM → Integrator → compliance service",
    description: "Write a compliance audit event. Useful to show a compliance-only permission.",
    method: "POST",
    scope: REQUIRED_SCOPES.complianceWrite,
    fields: [
      { name: "eventType", label: "Event type", defaultValue: "DEMO_PERMISSION_CHECK" },
      { name: "severity", label: "Severity", defaultValue: "INFO" },
      { name: "customerId", label: "Customer ID", defaultValue: "CUST-BR-001" },
      { name: "details", label: "Details", defaultValue: "Identity demo audit event" }
    ],
    path: () => "/compliance/1.0.0/audit",
    body: ({ eventType, severity, customerId, details }) => ({ eventType, severity, customerId, details })
  },
  {
    id: "fraudAlert",
    group: "Risk and compliance",
    title: "Create fraud alert",
    product: "Identity Server → UI scope guard → APIM → Integrator → fraud service",
    description: "Create a fraud alert. Useful to show risk-team permissions separate from payments.",
    method: "POST",
    scope: REQUIRED_SCOPES.fraudWrite,
    fields: [
      { name: "alertType", label: "Alert type", defaultValue: "SUSPICIOUS_PIX_PATTERN" },
      { name: "riskLevel", label: "Risk level", defaultValue: "HIGH" },
      { name: "accountId", label: "Account ID", defaultValue: "ACC-CHK-BR-001" },
      { name: "details", label: "Details", defaultValue: "Large PIX after password reset" }
    ],
    path: () => "/fraud/1.0.0/alerts",
    body: ({ alertType, riskLevel, accountId, details }) => ({ alertType, riskLevel, accountId, details })
  }
];

const QUICK_AGENT_PROMPTS = [
  "Explain customer CUST-BR-001, account ACC-CHK-BR-001, and card CARD-CR-BR-001.",
  "Check transfer TRF-20260315-0001 and tell me whether it is under review or requires attention.",
  "Create a PIX payment of 320 BRL from ACC-CHK-BR-001 to merchant@pix.example for Mercado Sao Bento. Explain the OBO authorization decision.",
  "Run a full banking review for customer CUST-BR-001, account ACC-CHK-BR-001, card CARD-CR-BR-001, and transfer TRF-20260315-0001. Route the request to every relevant specialist agent and summarize by domain."
];

/*
 * These policies are no longer used to block agent prompts in the browser.
 * They are used only to enrich OBO metadata sent to the agent, so the server-side
 * agent can explain or enforce user+agent authorization.
 */
const SENSITIVE_AGENT_POLICIES = [
  {
    id: "pix-create",
    label: "create PIX payments",
    scope: REQUIRED_SCOPES.paymentsCreate,
    pattern: /\b(create|submit|initiate|send|execute|process)\b[\s\S]{0,200}\b(pix|payment|pay)\b|\b(pix|payment|pay)\b[\s\S]{0,200}\b(create|submit|initiate|send|execute|process)\b/i
  },
  {
    id: "ted-create",
    label: "create TED transfers",
    scope: REQUIRED_SCOPES.transfersCreate,
    pattern: /\b(create|submit|initiate|send|execute|process)\b[\s\S]{0,200}\b(ted|transfer)\b|\b(ted|transfer)\b[\s\S]{0,200}\b(create|submit|initiate|send|execute|process)\b/i
  },
  {
    id: "audit-create",
    label: "create compliance audit events",
    scope: REQUIRED_SCOPES.complianceWrite,
    pattern: /\b(create|write|register|record|submit)\b[\s\S]{0,200}\b(audit|compliance)\b|\b(audit|compliance)\b[\s\S]{0,200}\b(create|write|register|record|submit)\b/i
  },
  {
    id: "fraud-create",
    label: "create fraud alerts",
    scope: REQUIRED_SCOPES.fraudWrite,
    pattern: /\b(create|write|register|record|submit)\b[\s\S]{0,200}\b(fraud|alert)\b|\b(fraud|alert)\b[\s\S]{0,200}\b(create|write|register|record|submit)\b/i
  }
];

init().catch((error) => {
  console.error(error);
  state.error = error.message || String(error);
  state.ready = true;
  render();
});

async function init() {
  renderBoot();

  if (CONFIG.demo.enableMockAuth) {
    state.ready = true;
    state.error = "Mock auth is enabled. Use this only for UI rehearsals; real API/backend scope checks are still required for the real demo.";
    render();
    return;
  }

  await auth.initialize({
    signInRedirectURL: CONFIG.identity.redirectUrl,
    signOutRedirectURL: CONFIG.identity.signOutRedirectUrl,
    clientID: CONFIG.identity.clientId,
    baseUrl: CONFIG.identity.baseUrl,
    scope: CONFIG.identity.scopes
  });

  let user = null;

  if (SPAUtils.hasAuthSearchParamsInURL()) {
    user = await auth.signIn({ callOnlyOnRedirect: true });
    cleanUrlAfterRedirect();
  } else {
    try {
      user = await auth.trySignInSilently();
    } catch (error) {
      console.debug("Silent sign-in skipped", error);
    }
  }

  if (user) {
    await setAuthenticatedUser(user);
  }

  state.ready = true;
  render();
}

function renderBoot() {
  app.innerHTML = `
    <main class="boot-screen">
      <div class="pulse-mark">WSO2</div>
      <h1>Banking Identity Demo</h1>
      <p>Preparing the Integrator, Identity Server 7.3 and OBO banking agent demo console…</p>
    </main>
  `;
}

function render() {
  const loginButton = CONFIG.demo.enableMockAuth
    ? `<button class="primary" id="loginBtn">${state.authenticated ? "Refresh mock session" : "Start mock session"}</button>`
    : `<button class="primary" id="loginBtn">${state.authenticated ? "Refresh session" : "Login with WSO2 IS"}</button>`;

  const logoutButton = state.authenticated
    ? `<button class="ghost" id="logoutBtn">Logout</button>`
    : "";

  app.innerHTML = `
    <header class="hero">
      <nav class="topbar">
        <div class="brand-lockup">
          <span class="brand-mark">WSO2</span>
          <div>
            <strong>Banking Identity Demo</strong>
            <small>Integrator · APIM · Identity Server 7.3 · OBO Agent</small>
          </div>
        </div>
        <div class="nav-actions">
          ${loginButton}
          ${logoutButton}
        </div>
      </nav>

      <section class="hero-grid">
        <div>
          <p class="eyebrow">Principal Solutions Architect demo path</p>
          <h1>Identity-gated APIs and On-Behalf-Of banking agent authorization</h1>
          <p class="lede">
            Direct API cards remain guarded by the signed-in user's token scopes.
            The banking agent requires <code>${REQUIRED_SCOPES.agentChat}</code> to start,
            then sends OBO context so server-side policy can evaluate both the user identity and the agent identity.
          </p>
          <div class="hero-actions">
            <a href="#api-console" class="secondary-link">Open API console</a>
            <a href="#identity-panel" class="secondary-link">Review permissions</a>
          </div>
        </div>
        ${renderSessionCard()}
      </section>
    </header>

    <main class="layout">
      ${renderAlert()}

      <section id="identity-panel" class="panel identity-panel">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Identity Server 7.3</p>
            <h2>Session and permission claims</h2>
          </div>
          <span class="status-pill ${state.authenticated ? "ok" : "locked"}">${state.authenticated ? "Authenticated" : "Login required"}</span>
        </div>
        ${renderIdentityDetails()}
      </section>

      <section id="api-console" class="panel">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Integrator APIs through APIM</p>
            <h2>Permission-aware API console</h2>
          </div>
          <span class="status-pill">${API_ACTIONS.length} APIs</span>
        </div>
        ${renderApiActions()}
      </section>

      <section class="panel result-panel">
        <div class="section-heading">
          <div>
            <p class="eyebrow">Live invocation trace</p>
            <h2>Last API response</h2>
          </div>
          <button class="ghost small" id="clearResultBtn">Clear</button>
        </div>
        ${renderResult()}
      </section>

      <section class="panel agent-section" id="agent-section">
        <div class="section-heading">
          <div>
            <p class="eyebrow">OBO agent authorization</p>
            <h2>Banking omni assistant</h2>
          </div>
          <span class="status-pill ${canUseAgent() ? "ok" : "locked"}">${canUseAgent() ? "Available" : "Locked"}</span>
        </div>
        ${renderAgentGate()}
      </section>
    </main>
  `;

  bindEvents();
  renderAgentWidget();
}

function renderSessionCard() {
  const subject = state.tokenClaims.sub || state.user?.username || state.user?.displayName || "Not signed in";
  const clientId = CONFIG.identity.clientId === "REPLACE_WITH_WSO2_IS_SPA_CLIENT_ID"
    ? "Set VITE_IS_CLIENT_ID"
    : abbreviate(CONFIG.identity.clientId, 24);

  return `
    <aside class="hero-card">
      <div class="mini-label">Current session</div>
      <div class="session-row"><span>User</span><strong>${escapeHtml(subject)}</strong></div>
      <div class="session-row"><span>SPA Client</span><strong>${escapeHtml(clientId)}</strong></div>
      <div class="session-row"><span>API base</span><strong>${escapeHtml(CONFIG.gateway.apimBaseUrl)}</strong></div>
      <div class="session-row"><span>Agent</span><strong>${escapeHtml(CONFIG.agent.name || "Banking Omni Assistant Agent")}</strong></div>
      <div class="session-row"><span>Agent ID</span><strong>${escapeHtml(abbreviate(CONFIG.agent.id || "not-configured", 24))}</strong></div>
      <div class="session-row"><span>Agent OAuth Client</span><strong>${escapeHtml(abbreviate(CONFIG.agent.oauthClientId || "not-configured", 24))}</strong></div>
      <div class="session-row"><span>Agent contract</span><strong>${escapeHtml(CONFIG.agent.contract)}</strong></div>
      <div class="session-row"><span>Authorization model</span><strong>OBO: user + agent</strong></div>
    </aside>
  `;
}

function renderAlert() {
  if (!state.error) return "";
  return `<div class="alert">${escapeHtml(state.error)}</div>`;
}

function renderIdentityDetails() {
  if (!state.authenticated) {
    return `
      <div class="empty-state">
        <h3>Login first</h3>
        <p>API cards and the banking agent remain locked until the SPA receives a token from WSO2 Identity Server.</p>
      </div>
    `;
  }

  return `
    <div class="identity-grid">
      <div class="claim-card">
        <span>Subject</span>
        <strong>${escapeHtml(state.tokenClaims.sub || "n/a")}</strong>
      </div>
      <div class="claim-card">
        <span>Actor / delegated agent</span>
        <strong>${escapeHtml(readActorSubject(state.tokenClaims) || "No delegated actor claim in this browser token")}</strong>
      </div>
      <div class="claim-card">
        <span>Token scopes</span>
        <strong>${state.scopes.length}</strong>
      </div>
      <div class="claim-card">
        <span>Roles / groups</span>
        <strong>${state.roles.length || "Not present in token"}</strong>
      </div>
    </div>

    <div class="chip-block">
      <h3>Scopes available to this user session</h3>
      <div class="chips">${renderChips(state.scopes, "No scopes were found in the access token.")}</div>
    </div>

    <div class="chip-block">
      <h3>Roles or groups found in token</h3>
      <div class="chips">${renderChips(state.roles, "No roles or groups were found in the decoded token.")}</div>
    </div>
  `;
}

function renderApiActions() {
  const groups = API_ACTIONS.reduce((acc, action) => {
    acc[action.group] ||= [];
    acc[action.group].push(action);
    return acc;
  }, {});

  return Object.entries(groups).map(([groupName, actions]) => `
    <div class="api-group">
      <h3>${escapeHtml(groupName)}</h3>
      <div class="api-grid">
        ${actions.map(renderApiCard).join("")}
      </div>
    </div>
  `).join("");
}

function renderApiCard(action) {
  const allowed = canUse(action.scope);
  const disabledReason = !state.authenticated
    ? "Login required"
    : !allowed
      ? `Missing ${action.scope}`
      : "Ready";

  return `
    <article class="api-card ${allowed ? "" : "is-locked"}">
      <div class="api-card-header">
        <div>
          <span class="method ${action.method.toLowerCase()}">${action.method}</span>
          <h4>${escapeHtml(action.title)}</h4>
        </div>
        <span class="lock-dot" title="${escapeHtml(disabledReason)}">${allowed ? "✓" : "🔒"}</span>
      </div>

      <p>${escapeHtml(action.description)}</p>
      <div class="product-line">${escapeHtml(action.product)}</div>
      <div class="required-scope"><span>Required user scope</span><code>${escapeHtml(action.scope)}</code></div>

      <form class="action-form" data-form-for="${action.id}">
        ${action.fields.map((field) => renderField(action, field)).join("")}
      </form>

      <button class="invoke-btn" data-action="${action.id}" ${allowed ? "" : "disabled"}>
        ${allowed ? "Invoke API" : disabledReason}
      </button>
    </article>
  `;
}

function renderField(action, field) {
  const type = field.type || "text";

  return `
    <label>
      <span>${escapeHtml(field.label)}</span>
      <input
        id="${fieldId(action.id, field.name)}"
        type="${escapeHtml(type)}"
        value="${escapeAttr(field.defaultValue)}"
        autocomplete="off"
      />
    </label>
  `;
}

function renderResult() {
  if (!state.lastResult) {
    return `
      <div class="empty-state compact">
        <h3>No request yet</h3>
        <p>Invoke a permitted direct API to see the authorization header path, correlation ID, status and payload.</p>
      </div>
    `;
  }

  return `<pre class="json-output">${escapeHtml(JSON.stringify(state.lastResult, null, 2))}</pre>`;
}

function renderAgentGate() {
  if (!state.authenticated) {
    return `
      <div class="empty-state compact">
        <h3>Agent hidden until login</h3>
        <p>The chat widget is not mounted in the page before authentication.</p>
      </div>
    `;
  }

  if (!hasScope(REQUIRED_SCOPES.agentChat)) {
    return `
      <div class="empty-state compact locked-copy">
        <h3>Logged in, but agent permission is missing</h3>
        <p>Add <code>${REQUIRED_SCOPES.agentChat}</code> to the user role and issue a new token to show the banking assistant.</p>
      </div>
    `;
  }

  return `
    <div class="agent-ready">
      <p>
        The floating banking assistant is available in the lower-right corner.
        The browser only checks <code>${REQUIRED_SCOPES.agentChat}</code>.
        Sensitive banking actions are sent to the agent so server-side OBO policy can evaluate both the user and the agent identity.
      </p>
      <div class="prompt-grid">
        ${QUICK_AGENT_PROMPTS.map((prompt) => `<button class="prompt-chip" data-agent-prompt="${escapeAttr(prompt)}">${escapeHtml(prompt)}</button>`).join("")}
      </div>
    </div>
  `;
}

function bindEvents() {
  document.querySelector("#loginBtn")?.addEventListener("click", async () => {
    await handleLogin();
  });

  document.querySelector("#logoutBtn")?.addEventListener("click", async () => {
    await handleLogout();
  });

  document.querySelector("#clearResultBtn")?.addEventListener("click", () => {
    state.lastResult = null;
    render();
  });

  document.querySelectorAll("[data-action]").forEach((button) => {
    button.addEventListener("click", async () => invokeAction(button.dataset.action));
  });

  document.querySelectorAll("[data-agent-prompt]").forEach((button) => {
    button.addEventListener("click", () => openAgentWithPrompt(button.dataset.agentPrompt));
  });
}

async function handleLogin() {
  if (CONFIG.demo.enableMockAuth) {
    const token = createMockJwt(CONFIG.demo.mockScopes);

    state.authenticated = true;
    state.user = {
      username: "mock.banking.user@example.com",
      displayName: "Mock Banking User"
    };
    state.accessToken = token;
    state.tokenClaims = decodeJwt(token);
    state.scopes = collectScopes(state.tokenClaims);
    state.roles = ["mock-banking-demo-role"];
    state.error = "Mock auth is enabled. The UI is unlocked locally; real API calls still depend on backend validation.";

    render();
    return;
  }

  state.error = null;
  await auth.signIn();
}

async function handleLogout() {
  if (CONFIG.demo.enableMockAuth) {
    clearSession();
    render();
    return;
  }

  clearSession();
  await auth.signOut();
}

async function setAuthenticatedUser(user) {
  state.authenticated = true;
  state.user = user;
  state.accessToken = await readAccessToken(user);
  state.tokenClaims = state.accessToken ? decodeJwt(state.accessToken) : {};
  state.scopes = collectScopes(state.tokenClaims, user);
  state.roles = collectRoles(state.tokenClaims, user);
}

async function readAccessToken(user) {
  if (typeof auth.getAccessToken === "function") {
    const value = await auth.getAccessToken();

    if (typeof value === "string") return value;
    if (value?.accessToken) return value.accessToken;
    if (value?.access_token) return value.access_token;
  }

  return user?.accessToken || user?.access_token || user?.token || null;
}

function clearSession() {
  state.authenticated = false;
  state.user = null;
  state.accessToken = null;
  state.tokenClaims = {};
  state.scopes = [];
  state.roles = [];
  state.chatMessages = [];
  unmountAgentWidget();
}

async function invokeAction(actionId) {
  const action = API_ACTIONS.find((candidate) => candidate.id === actionId);
  if (!action) return;

  try {
    /*
     * Direct API cards intentionally remain user-scope guarded.
     * This demonstrates the difference between:
     *   1. direct user API authorization, and
     *   2. agent-mediated OBO authorization.
     */
    requireScope(action.scope);

    const values = readFormValues(action);
    const path = action.path(values);
    const url = buildGatewayUrl(path);
    const body = action.body ? action.body(values) : undefined;

    const { response, payload, correlationId, elapsedMs } = await secureFetch(url, {
      method: action.method,
      body: body ? JSON.stringify(body) : undefined
    });

    state.lastResult = {
      action: action.title,
      method: action.method,
      url,
      authorizationModel: "direct_user_token",
      requiredUserScope: action.scope,
      correlationId,
      elapsedMs,
      status: response.status,
      ok: response.ok,
      requestBody: body || null,
      response: payload
    };

    state.error = response.ok
      ? null
      : `API returned ${response.status}. Check the APIM API, MI endpoint, backend route, and token scopes.`;
  } catch (error) {
    state.error = error.message || String(error);
    state.lastResult = {
      action: action.title,
      blockedBy: "frontend direct API scope guard or network failure",
      authorizationModel: "direct_user_token",
      requiredUserScope: action.scope,
      error: state.error
    };
  }

  render();
}

function readFormValues(action) {
  return Object.fromEntries(
    action.fields.map((field) => [
      field.name,
      document.querySelector(`#${fieldId(action.id, field.name)}`)?.value?.trim() || ""
    ])
  );
}

function fieldId(actionId, fieldName) {
  return `field-${actionId}-${fieldName}`;
}

function buildGatewayUrl(path) {
  const cleanPath = String(path || "").replace(/^\/+/, "");
  const context = CONFIG.gateway.bankingMiContext
    ? `${CONFIG.gateway.bankingMiContext.replace(/^\/+/, "").replace(/\/+$/, "")}/`
    : "";

  return `${CONFIG.gateway.apimBaseUrl.replace(/\/+$/, "")}/${context}${cleanPath}`;
}

async function secureFetch(url, init = {}) {
  if (!state.authenticated || !state.accessToken) {
    throw new Error("Login required before invoking banking APIs.");
  }

  const headers = new Headers(init.headers || {});
  const correlationId = headers.get("X-Correlation-Id") || `ui-${Date.now()}-${Math.random().toString(16).slice(2)}`;

  headers.set("Authorization", `Bearer ${state.accessToken}`);
  headers.set("Accept", "application/json");
  headers.set("X-Correlation-Id", correlationId);
  headers.set("x-fapi-interaction-id", correlationId);

  if (init.body && !headers.has("Content-Type")) {
    headers.set("Content-Type", "application/json");
  }

  const started = performance.now();
  const response = await fetch(url, { ...init, headers });
  const payload = await readResponseBody(response);
  const elapsedMs = Math.round(performance.now() - started);

  return { response, payload, correlationId, elapsedMs };
}

async function readResponseBody(response) {
  const text = await response.text();
  if (!text) return null;

  try {
    return JSON.parse(text);
  } catch {
    return text;
  }
}

function renderAgentWidget() {
  if (!canUseAgent()) {
    unmountAgentWidget();
    return;
  }

  if (widgetRoot.querySelector(".agent-widget")) {
    refreshAgentMessages();
    return;
  }

  widgetRoot.innerHTML = `
    <aside class="agent-widget" aria-label="Banking omni assistant">
      <button class="agent-launcher" id="agentLauncher" aria-expanded="false">
        <span>Banking Agent</span>
        <strong>Ask</strong>
      </button>

      <section class="agent-window" id="agentWindow" hidden>
        <header>
          <div>
            <strong>${escapeHtml(CONFIG.agent.name || "Banking Omni Assistant")}</strong>
            <small>OBO: user permission + agent permission</small>
          </div>
          <button class="icon-button" id="closeAgent" aria-label="Close agent">×</button>
        </header>

        <div class="agent-messages" id="agentMessages"></div>

        <form id="agentForm" class="agent-form">
          <textarea id="agentInput" rows="2" placeholder="Ask about customer, payment, risk, compliance, or OBO authorization…"></textarea>
          <button type="submit">Send</button>
        </form>
      </section>
    </aside>
  `;

  widgetRoot.querySelector("#agentLauncher")?.addEventListener("click", () => toggleAgent(true));
  widgetRoot.querySelector("#closeAgent")?.addEventListener("click", () => toggleAgent(false));

  widgetRoot.querySelector("#agentForm")?.addEventListener("submit", async (event) => {
    event.preventDefault();

    const input = widgetRoot.querySelector("#agentInput");
    const message = input.value.trim();

    if (!message) return;

    input.value = "";
    await sendAgentMessage(message);
  });

  refreshAgentMessages();
}

function unmountAgentWidget() {
  widgetRoot.innerHTML = "";
}

function toggleAgent(open) {
  const win = widgetRoot.querySelector("#agentWindow");
  const launcher = widgetRoot.querySelector("#agentLauncher");

  if (!win || !launcher) return;

  win.hidden = !open;
  launcher.setAttribute("aria-expanded", String(open));

  if (open) {
    widgetRoot.querySelector("#agentInput")?.focus();
  }
}

function openAgentWithPrompt(prompt) {
  renderAgentWidget();
  toggleAgent(true);

  const input = widgetRoot.querySelector("#agentInput");

  if (input) {
    input.value = prompt;
    input.focus();
  }
}

async function sendAgentMessage(message) {
  let userMessageAdded = false;

  try {
    /*
     * OBO demo behavior:
     * The browser only checks whether the user can invoke the agent.
     * It does NOT block PIX/TED/audit/fraud prompts locally.
     *
     * The sensitive operation must reach the server-side agent so the demo can show:
     *   - Ana has agent:chat but lacks banking:payments:create → OBO deny
     *   - Bruno has agent:chat and banking:payments:create → OBO allow
     *   - the agent identity must also have the required permission
     */
    requireScope(REQUIRED_SCOPES.agentChat);

    state.chatMessages.push({ role: "user", content: message });
    userMessageAdded = true;

    state.chatMessages.push({
      role: "assistant",
      content: "Evaluating the request with On-Behalf-Of user + agent authorization…",
      pending: true
    });

    refreshAgentMessages();

    const reply = await callAgent(message);
    const pending = state.chatMessages.findLast((entry) => entry.pending);

    if (pending) {
      pending.content = reply;
      pending.pending = false;
    }

    state.error = null;
  } catch (error) {
    const errorMessage = error.message || String(error);
    const pending = state.chatMessages.findLast((entry) => entry.pending);

    if (pending) {
      pending.content = `Blocked or failed: ${errorMessage}`;
      pending.pending = false;
      pending.error = true;
    } else {
      if (!userMessageAdded) {
        state.chatMessages.push({ role: "user", content: message });
      }

      state.chatMessages.push({
        role: "assistant",
        content: `Blocked by Identity policy: ${errorMessage}`,
        error: true
      });
    }

    state.error = errorMessage;
  }

  refreshAgentMessages();
}

async function callAgent(message) {
  const correlationId = `agent-ui-${Date.now()}-${Math.random().toString(16).slice(2)}`;
  const requestedOperations = detectSensitiveAgentOperations(message);

  const context = {
    session_id: state.sessionId,
    correlation_id: correlationId,

    /*
     * Compatibility fields for existing agent code/logging.
     */
    subject: state.tokenClaims.sub,
    actor: readActorSubject(state.tokenClaims) || CONFIG.agent.id,
    scopes: state.scopes,
    roles: state.roles,

    /*
     * Explicit OBO metadata for the demo.
     */
    authorization_model: "obo_user_and_agent",
    obo: {
      mode: "user_and_agent",
      enforcement: "server_side_agent_policy",
      rule: "effective_permission = user_permission AND agent_permission",
      user: {
        subject: state.tokenClaims.sub || null,
        username: state.user?.username || state.user?.displayName || null,
        scopes: state.scopes,
        roles: state.roles
      },
      agent: {
        id: CONFIG.agent.id,
        oauth_client_id: CONFIG.agent.oauthClientId,
        name: CONFIG.agent.name,
        purpose: CONFIG.agent.purpose,
        required_role: "BankingOmniAgent"
      },
      requested_operations: requestedOperations,
      requested_scopes: requestedOperations.map((operation) => operation.scope)
    },

    agent: {
      id: CONFIG.agent.id,
      oauth_client_id: CONFIG.agent.oauthClientId,
      name: CONFIG.agent.name,
      purpose: CONFIG.agent.purpose
    }
  };

  const requestPayload = buildAgentPayload(message, context);

  const { response, payload: responsePayload } = await secureFetch(CONFIG.agent.chatUrl, {
    method: "POST",
    headers: {
      "X-Agent-Id": CONFIG.agent.id || "not-configured",
      "X-Agent-Name": CONFIG.agent.name || "Banking Omni Assistant Agent",
      "X-Agent-OAuth-Client-Id": CONFIG.agent.oauthClientId || "not-configured",
      "X-WSO2-Agent-Id": CONFIG.agent.id || "not-configured",
      "X-WSO2-Agent-Name": CONFIG.agent.name || "Banking Omni Assistant Agent",
      "X-Agent-Domain": "retail-banking-demo",
      "X-Agent-Tool": "banking-omni-chat",
      "X-Agent-Intercepted": "true",
      "X-Authorization-Model": "obo_user_and_agent",
      "X-Correlation-Id": correlationId,
      "x-fapi-interaction-id": correlationId
    },
    body: JSON.stringify(requestPayload)
  });

  if (!response.ok) {
    throw new Error(`Agent returned ${response.status}: ${typeof responsePayload === "string" ? responsePayload : JSON.stringify(responsePayload)}`);
  }

  return readAgentReply(responsePayload);
}

function buildAgentPayload(message, context) {
  switch (CONFIG.agent.contract) {
    case "banking-agent":
      /*
       * Direct Ballerina banking agent contract.
       *
       * The /v1/omni/chat request record is strict and rejects unknown fields.
       * Do not include `context` here unless the backend record supports it.
       *
       * OBO metadata is propagated through HTTP headers for this contract.
       */
      return {
        sessionId: state.sessionId,
        message
      };

    case "platform-chat":
      /*
       * Hotel-concierge-style contract.
       * This contract supports a context object.
       */
      return {
        message,
        session_id: state.sessionId,
        context
      };

    case "ai-adapter":
    default:
      /*
       * APIM AI Gateway / OpenAI-compatible contract.
       */
      return {
        model: "banking-omni-a2a-ai",
        messages: [
          {
            role: "system",
            content: [
              "You are the governed WSO2 banking demo assistant.",
              "This demo uses On-Behalf-Of authorization.",
              "A sensitive banking operation is allowed only when BOTH the signed-in user and the agent identity have the required permission.",
              "Do not rely only on the agent identity for write operations.",
              "For PIX creation, require banking:payments:create from the user and from the agent.",
              "For TED creation, require banking:transfers:create from the user and from the agent.",
              "For compliance/audit creation, require banking:compliance:write from the user and from the agent.",
              "For fraud alert creation, require banking:fraud:write from the user and from the agent.",
              "If either side lacks the required permission, explain that OBO authorization denied the action and confirm that no operation was executed.",
              "When an operation is allowed, explain that it passed OBO because both the user and the agent identity were authorized."
            ].join(" ")
          },
          ...state.chatMessages
            .filter((entry) => !entry.pending && !entry.error)
            .slice(-8)
            .map((entry) => ({ role: entry.role, content: entry.content }))
        ],
        metadata: context
      };
  }
}

function readAgentReply(payload) {
  if (!payload) return "The agent returned an empty response.";
  if (typeof payload === "string") return payload;

  if (payload.response) return String(payload.response);
  if (payload.message) return String(payload.message);
  if (payload.answer) return String(payload.answer);
  if (payload.reply) return String(payload.reply);
  if (payload.content) return String(payload.content);

  if (payload.choices?.[0]?.message?.content) {
    return String(payload.choices[0].message.content);
  }

  if (payload.choices?.[0]?.text) {
    return String(payload.choices[0].text);
  }

  return JSON.stringify(payload, null, 2);
}

function refreshAgentMessages() {
  const messages = widgetRoot.querySelector("#agentMessages");
  if (!messages) return;

  if (state.chatMessages.length === 0) {
    messages.innerHTML = `
      <div class="agent-empty">
        <strong>Try an OBO request</strong>
        <p>Ask for a customer summary, transfer review, or PIX creation decision. Ana should be denied for PIX creation; Bruno should be allowed.</p>
      </div>
    `;
    return;
  }

  messages.innerHTML = state.chatMessages.map((entry) => `
    <article class="chat-bubble ${entry.role} ${entry.error ? "error" : ""} ${entry.pending ? "pending" : ""}">
      ${renderMarkdown(entry.content)}
    </article>
  `).join("");

  messages.scrollTop = messages.scrollHeight;
}

function canUseAgent() {
  return state.authenticated && hasScope(REQUIRED_SCOPES.agentChat);
}

function canUse(scope) {
  return state.authenticated && hasScope(scope);
}

function requireScope(scope) {
  if (!state.authenticated) {
    throw new Error("Login required.");
  }

  if (!hasScope(scope)) {
    throw new Error(`Missing required scope: ${scope}`);
  }
}

function detectSensitiveAgentOperations(message) {
  return SENSITIVE_AGENT_POLICIES
    .filter((policy) => policy.pattern.test(message))
    .map((policy) => ({
      id: policy.id,
      label: policy.label,
      scope: policy.scope,
      user_has_scope: hasScope(policy.scope)
    }));
}

function hasScope(scope) {
  return state.scopes.includes(scope);
}

function collectScopes(...sources) {
  const values = [];

  for (const source of sources) {
    if (!source) continue;

    for (const key of ["scope", "scp", "scopes"]) {
      const value = source[key];

      if (Array.isArray(value)) {
        values.push(...value);
      }

      if (typeof value === "string") {
        values.push(...value.split(/[\s,]+/));
      }
    }
  }

  return Array.from(new Set(values.map((scope) => String(scope).trim()).filter(Boolean))).sort();
}

function collectRoles(...sources) {
  const values = [];

  for (const source of sources) {
    if (!source) continue;

    for (const key of ["roles", "groups", "role", "http://wso2.org/claims/roles"]) {
      const value = source[key];

      if (Array.isArray(value)) {
        values.push(...value);
      }

      if (typeof value === "string") {
        values.push(...value.split(/[\s,]+/));
      }
    }
  }

  return Array.from(new Set(values.map((role) => String(role).trim()).filter(Boolean))).sort();
}

function decodeJwt(token) {
  const [, payload] = String(token || "").split(".");
  if (!payload) return {};

  const normalized = payload.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized.padEnd(normalized.length + ((4 - (normalized.length % 4)) % 4), "=");

  try {
    return JSON.parse(decodeURIComponent(escape(atob(padded))));
  } catch {
    try {
      return JSON.parse(atob(padded));
    } catch {
      return {};
    }
  }
}

function createMockJwt(scopes) {
  const header = { alg: "none", typ: "JWT" };
  const payload = {
    sub: "mock-banking-user",
    email: "mock.banking.user@example.com",
    scope: scopes,
    roles: ["mock-banking-demo-role"],
    iss: "mock-wso2-is",
    aud: "banking-demo-ui",
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 3600
  };

  return `${base64Url(JSON.stringify(header))}.${base64Url(JSON.stringify(payload))}.mock-signature`;
}

function base64Url(value) {
  return btoa(value).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

function readActorSubject(claims) {
  return claims?.act?.sub || claims?.actor?.sub || claims?.act || null;
}

function renderChips(values, emptyText) {
  if (!values?.length) {
    return `<span class="muted">${escapeHtml(emptyText)}</span>`;
  }

  return values.map((value) => `<code class="chip">${escapeHtml(value)}</code>`).join("");
}

function renderMarkdown(markdown) {
  const raw = window.marked
    ? window.marked.parse(markdown || "")
    : escapeHtml(markdown || "");

  return window.DOMPurify ? window.DOMPurify.sanitize(raw) : raw;
}

function escapeHtml(value) {
  return String(value ?? "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&#039;");
}

function escapeAttr(value) {
  return escapeHtml(value).replace(/`/g, "&#096;");
}

function abbreviate(value, max = 18) {
  const text = String(value || "");

  if (text.length <= max) return text;

  return `${text.slice(0, Math.max(0, max - 3))}…`;
}

function getOrCreateSessionId() {
  const key = "wso2-banking-demo-session-id";
  const existing = localStorage.getItem(key);

  if (existing) return existing;

  const created = crypto.randomUUID
    ? crypto.randomUUID()
    : `session-${Date.now()}-${Math.random().toString(16).slice(2)}`;

  localStorage.setItem(key, created);

  return created;
}

function cleanUrlAfterRedirect() {
  if (window.history?.replaceState) {
    window.history.replaceState(
      {},
      document.title,
      window.location.origin + window.location.pathname + window.location.hash
    );
  }
}