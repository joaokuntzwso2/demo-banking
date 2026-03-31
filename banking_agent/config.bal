import ballerinax/ai;

// -----------------------------------------------------------------------------
// Global configuration for Banking Agentic APIs
// -----------------------------------------------------------------------------

// Optional bearer token for calling MI/APIM.
public configurable string BACKEND_ACCESS_TOKEN = "";

// LLM configuration.
public configurable string OPENAI_API_KEY = ?;
public ai:OPEN_AI_MODEL_NAMES OPENAI_MODEL = ai:GPT_4O;

// HTTP listener for the Agentic API service.
public configurable int HTTP_LISTENER_PORT = 8293;

// Base URL of the integration layer (WSO2 MI / APIM), not the JS backend directly.
public configurable string BACKEND_BASE_URL = ?;

// Backend HTTP client resilience.
public configurable decimal BACKEND_HTTP_TIMEOUT_SECONDS = 3.0;
public configurable int BACKEND_HTTP_MAX_RETRIES = 1;
public configurable decimal BACKEND_HTTP_RETRY_INTERVAL_SECONDS = 0.5;
public configurable float BACKEND_HTTP_RETRY_BACKOFF_FACTOR = 2.0;
public configurable decimal BACKEND_HTTP_RETRY_MAX_WAIT_SECONDS = 2.0;
public configurable int[] BACKEND_HTTP_RETRY_STATUS_CODES = [500, 502, 503, 504];

// Agent observability names & prompt versions.
public configurable string BANKING_RETAIL_AGENT_NAME = "BankingRetailAgent";
public const string BANKING_RETAIL_PROMPT_VERSION = "banking-retail-v1.0.0";

public configurable string BANKING_PAYMENTS_AGENT_NAME = "BankingPaymentsAgent";
public const string BANKING_PAYMENTS_PROMPT_VERSION = "banking-payments-v1.0.0";

public configurable string BANKING_RISK_AGENT_NAME = "BankingRiskAgent";
public const string BANKING_RISK_PROMPT_VERSION = "banking-risk-v1.0.0";

public configurable string BANKING_COMPLIANCE_AGENT_NAME = "BankingComplianceAgent";
public const string BANKING_COMPLIANCE_PROMPT_VERSION = "banking-compliance-v1.0.0";

public configurable string BANKING_OMNI_AGENT_NAME = "BankingOmniAgent";
public const string BANKING_OMNI_PROMPT_VERSION = "banking-omni-v1.0.0";

public configurable string BANKING_OVERLAY_AGENT_NAME = "BankingSafetyOverlayAgent";
public const string BANKING_OVERLAY_PROMPT_VERSION = "banking-overlay-v1.0.0";

// Agent handoff interception settings.
public configurable boolean ENABLE_AGENT_HANDOFF_INTERCEPTOR = true;
public configurable boolean ENABLE_AGENT_HANDOFF_VERBOSE_LOG = true;
public configurable boolean ENABLE_AGENT_HANDOFF_WEBHOOK = true;
public configurable string AGENT_HANDOFF_WEBHOOK_URL = "http://banking-webhook-listener:8099/handoff";