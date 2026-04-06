import ballerinax/ai;

// -----------------------------------------------------------------------------
// Global configuration for Banking Agentic APIs
// -----------------------------------------------------------------------------

public configurable string BACKEND_ACCESS_TOKEN = "";

// Direct vendor access (fallback only)
public configurable string OPENAI_API_KEY = "";

// Preferred mode for demo: WSO2 AI Gateway
public configurable boolean USE_WSO2_AI_GATEWAY_FOR_LLM = true;
public configurable string AI_GATEWAY_LLM_SERVICE_URL = "";
public configurable string AI_GATEWAY_LLM_ACCESS_TOKEN = "";

public ai:OPEN_AI_MODEL_NAMES OPENAI_MODEL = ai:GPT_4O;
public configurable int HTTP_LISTENER_PORT = 8293;
public configurable string BACKEND_BASE_URL = ?;

public configurable decimal BACKEND_HTTP_TIMEOUT_SECONDS = 3.0;
public configurable int BACKEND_HTTP_MAX_RETRIES = 1;
public configurable decimal BACKEND_HTTP_RETRY_INTERVAL_SECONDS = 0.5;
public configurable float BACKEND_HTTP_RETRY_BACKOFF_FACTOR = 2.0;
public configurable decimal BACKEND_HTTP_RETRY_MAX_WAIT_SECONDS = 2.0;
public configurable int[] BACKEND_HTTP_RETRY_STATUS_CODES = [500, 502, 503, 504];

public configurable string BANKING_RETAIL_AGENT_NAME = "BankingRetailAgent";
public configurable string BANKING_PAYMENTS_AGENT_NAME = "BankingPaymentsAgent";
public configurable string BANKING_RISK_AGENT_NAME = "BankingRiskAgent";
public configurable string BANKING_COMPLIANCE_AGENT_NAME = "BankingComplianceAgent";
public configurable string BANKING_KNOWLEDGE_AGENT_NAME = "BankingKnowledgeAgent";
public configurable string BANKING_OMNI_AGENT_NAME = "BankingOmniAgent";
public configurable string BANKING_OVERLAY_AGENT_NAME = "BankingSafetyOverlayAgent";

public const string BANKING_RETAIL_PROMPT_VERSION = "banking-retail-v1.0.0";
public const string BANKING_PAYMENTS_PROMPT_VERSION = "banking-payments-v1.0.0";
public const string BANKING_RISK_PROMPT_VERSION = "banking-risk-v1.0.0";
public const string BANKING_COMPLIANCE_PROMPT_VERSION = "banking-compliance-v1.0.0";
public const string BANKING_KNOWLEDGE_PROMPT_VERSION = "banking-knowledge-v1.0.0";
public const string BANKING_OMNI_PROMPT_VERSION = "banking-omni-v1.0.0";
public const string BANKING_OVERLAY_PROMPT_VERSION = "banking-overlay-v1.0.0";

public configurable boolean ENABLE_AGENT_HANDOFF_INTERCEPTOR = true;
public configurable boolean ENABLE_AGENT_HANDOFF_VERBOSE_LOG = true;
public configurable boolean ENABLE_AGENT_HANDOFF_WEBHOOK = true;
public configurable string AGENT_HANDOFF_WEBHOOK_URL = "http://banking-webhook-listener:8099/handoff";

// -----------------------------------------------------------------------------
// A2A / gateway-routed subagent AI-API calls
// -----------------------------------------------------------------------------

public configurable boolean ENABLE_GATEWAY_A2A_DEMO = true;
public configurable string AGENT_GATEWAY_BASE_URL = "";
public configurable string AGENT_GATEWAY_ACCESS_TOKEN = "";

// Supported values: "api_key" or "bearer"
public configurable string AGENT_GATEWAY_AUTH_MODE = "api_key";
public configurable string AGENT_GATEWAY_API_KEY_HEADER = "ApiKey";

// These now point to APIM AI APIs, not REST APIs.
public configurable string RETAIL_AGENT_GATEWAY_PATH = "/bankingretailaiadapter/1.0.0/chat/completions";
public configurable string PAYMENTS_AGENT_GATEWAY_PATH = "/bankingpaymentsaiadapter/1.0.0/chat/completions";
public configurable string RISK_AGENT_GATEWAY_PATH = "/bankingriskaiadapter/1.0.0/chat/completions";
public configurable string COMPLIANCE_AGENT_GATEWAY_PATH = "/bankingcomplianceaiadapter/1.0.0/chat/completions";
public configurable string KNOWLEDGE_AGENT_GATEWAY_PATH = "/bankingknowledgeaiadapter/1.0.0/chat/completions";