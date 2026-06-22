export const REQUIRED_SCOPES = Object.freeze({
  profileRead: "banking:profile:read",
  accountsRead: "banking:accounts:read",
  cardsRead: "banking:cards:read",
  paymentsCreate: "banking:payments:create",
  paymentsRead: "banking:payments:read",
  transfersCreate: "banking:transfers:create",
  transfersRead: "banking:transfers:read",
  complianceWrite: "banking:compliance:write",
  fraudWrite: "banking:fraud:write",
  agentChat: "agent:chat",
  admin: "banking:admin"
});

const defaultScopes = [
  "openid",
  "profile",
  "email",
  ...Object.values(REQUIRED_SCOPES)
];

function unique(values) {
  return Array.from(new Set(values.filter(Boolean)));
}

function splitScopes(value) {
  if (!value) return [];
  return String(value)
    .split(/[\s,]+/)
    .map((scope) => scope.trim())
    .filter(Boolean);
}

function stripTrailingSlash(value) {
  return String(value || "").replace(/\/+$/, "");
}

function normalizeContext(value) {
  const raw = String(value || "").trim();
  if (!raw || raw === "/") return "";
  return `/${raw.replace(/^\/+|\/+$/g, "")}`;
}

const apimBaseUrl = stripTrailingSlash(import.meta.env.VITE_APIM_BASE_URL || "http://localhost:8280");
const bankingMiContext = normalizeContext(import.meta.env.VITE_BANKING_MI_CONTEXT || "");

export const CONFIG = Object.freeze({
  identity: {
    baseUrl: stripTrailingSlash(import.meta.env.VITE_IS_BASE_URL || "https://localhost:9444"),
    clientId: import.meta.env.VITE_IS_CLIENT_ID || "REPLACE_WITH_WSO2_IS_SPA_CLIENT_ID",
    redirectUrl: import.meta.env.VITE_REDIRECT_URL || window.location.origin,
    signOutRedirectUrl: import.meta.env.VITE_SIGN_OUT_REDIRECT_URL || window.location.origin,
    scopes: unique(splitScopes(import.meta.env.VITE_AUTH_SCOPES).length > 0 ? splitScopes(import.meta.env.VITE_AUTH_SCOPES) : defaultScopes)
  },
  gateway: {
    apimBaseUrl,
    bankingMiContext
  },
  agent: {
    id: import.meta.env.VITE_AGENT_ID || "not-configured",
    name: import.meta.env.VITE_AGENT_NAME || "Banking Omni Assistant Agent",
    purpose: import.meta.env.VITE_AGENT_PURPOSE || "Governed banking assistant with read-only default permissions.",
    contract: import.meta.env.VITE_AGENT_CONTRACT || "ai-adapter",
    chatUrl: import.meta.env.VITE_AGENT_CHAT_URL || `${apimBaseUrl}/v1/ai/omni_a2a/chat/completions`,
    requiredScope: REQUIRED_SCOPES.agentChat
  },
  demo: {
    enableMockAuth: import.meta.env.VITE_ENABLE_MOCK_AUTH === "true",
    mockScopes: unique(splitScopes(import.meta.env.VITE_MOCK_SCOPES).length > 0 ? splitScopes(import.meta.env.VITE_MOCK_SCOPES) : defaultScopes)
  }
});
