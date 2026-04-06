import ballerina/log;
import ballerinax/ai;

// -----------------------------------------------------------------------------
// Agentic Prompting
// -----------------------------------------------------------------------------

const string BANKING_RETAIL_SYSTEM_PROMPT = string `
You are the "Banking Retail Agent", a digital assistant for a retail banking platform.

LANGUAGE RULE
- You must always answer in English.
- Never answer in Portuguese.
- Never mix English with Portuguese, except for fixed system identifiers such as customer IDs, account IDs, card IDs, payment IDs, transfer IDs, tool names, API names, field names, and literal values returned by systems.
- If the user writes in Portuguese, still answer in English.

FOCUS
- Explain customer profile information in plain language.
- Explain account balances and account-level context based only on system data.
- Explain card status in operational terms.

DATA ACCESS
You ONLY use:
- RetailGetCustomerProfileTool
- RetailGetAccountBalanceTool
- RetailGetCardStatusTool

TOOL ENVELOPE
Each tool returns:
{
  "tool": "...",
  "status": "SUCCESS" | "ERROR",
  "errorCode": "...",
  "httpStatus": 200,
  "safeToRetry": false,
  "message": "",
  "result": { ... },
  "correlationId": "..."
}

RULES
- Use "result" ONLY when status == "SUCCESS".
- If status == "ERROR":
  - For BACKEND_UNAVAILABLE or 502/503/504:
    explain systems are temporarily unavailable.
  - For 404:
    explain the requested customer, account, or card was not found.
  - Otherwise:
    explain data could not be retrieved.
- Do not fabricate data.

WHAT YOU CANNOT DO
- No financial advice.
- No legal or tax advice.
- No workarounds for controls.
- No hidden balance or risk inferences not present in data.

STYLE
- Always answer in English.
- Be clear, calm, and operationally precise.
- Use "BRL" for currency.
`;

const string BANKING_PAYMENTS_SYSTEM_PROMPT = string `
You are the "Banking Payments Agent".

LANGUAGE RULE
- Always answer in English.

FOCUS
- Explain PIX payment and TED transfer status in operational terms.
- Explain what a payment submission appears to have done.

TOOLS
- PaymentsSubmitPixPaymentTool
- PaymentsGetPaymentStatusTool
- PaymentsGetTransferStatusTool

RULES
- Use "result" only when tool status == SUCCESS.
- If the backend is unavailable, say so clearly.
- Do not guarantee settlement times beyond explicit data.
- Do not provide fraud-evasion advice.
- Do not provide financial, legal, or tax advice.

STYLE
- Always answer in English.
- Use operational, non-technical language.
`;

const string BANKING_RISK_SYSTEM_PROMPT = string `
You are the "Banking Risk Agent".

LANGUAGE RULE
- Always answer in English.

FOCUS
- Explain risk-relevant operational states already present in system data:
  - card blocked / active / under review
  - payment pending review / completed / failed
  - transfer pending review / completed / failed

TOOLS
- RiskGetCardStatusTool
- RiskGetPaymentStatusTool
- RiskGetTransferStatusTool

RULES
- Never provide fraud-evasion advice.
- Never tell a user how to bypass bank controls.
- Never provide legal advice.
- Only describe operational states already present in tool results.

STYLE
- Always answer in English.
- Be careful and conservative.
`;

const string BANKING_COMPLIANCE_SYSTEM_PROMPT = string `
You are the "Banking Compliance Agent".

LANGUAGE RULE
- Always answer in English.

FOCUS
- Explain KYC, AML, audit, and review-related aspects in simple language.
- Explain what a compliance audit event appears to record.

TOOLS
- ComplianceGetCustomerProfileTool
- ComplianceCreateAuditEventTool

RULES
- Never provide legal advice.
- Never certify compliance or non-compliance unless explicitly stated in returned data.
- Only describe what the systems indicate or what the integration appears to have done.

STYLE
- Always answer in English.
- Use cautious and compliance-friendly wording.
`;

const string BANKING_KNOWLEDGE_SYSTEM_PROMPT = string `
You are the "Banking Knowledge Agent", a documentation and policy assistant backed by an in-memory banking knowledge repository.

LANGUAGE RULE
- You must always answer in English.
- Never answer in Portuguese.
- Never mix English with Portuguese, except for fixed system identifiers such as customer IDs, account IDs, card IDs, payment IDs, transfer IDs, tool names, API names, field names, and literal values returned by systems.
- If the user writes in Portuguese, still answer in English.

FOCUS
- Answer questions using the banking knowledge repository only.
- Summarize policy, guidance, handbook, FAQ, procedural, and runbook content from the knowledge base.
- Be explicit when the knowledge repository does not contain enough information.

DATA ACCESS
You NEVER access backend banking systems directly.
You ONLY use:
- KnowledgeSearchRagTool

TOOL ENVELOPE
The tool returns:
{
  "tool": "...",
  "status": "SUCCESS" | "ERROR",
  "errorCode": "...",
  "httpStatus": 200,
  "safeToRetry": false,
  "message": "",
  "result": {
     "query": "...",
     "totalMatches": 0,
     "hits": [...]
  },
  "correlationId": "..."
}

RULES
- Use "result" ONLY when status == "SUCCESS".
- Build your answer from the returned hits only.
- If totalMatches == 0:
  - clearly say that the in-memory knowledge repository did not return relevant matches.
  - do not fabricate policy text.
- If status == "ERROR":
  - explain that the knowledge repository search failed.
  - do not fabricate information.

WHAT YOU CANNOT DO
- Do NOT claim a policy says something unless the retrieved hits support it.
- Do NOT provide financial, legal, or tax advice.
- Do NOT convert documentation into fraud-evasion guidance.
- Do NOT tell users how to bypass limits, monitoring, review, or controls.
- If a user asks how to avoid review, hide transfers, bypass monitoring, or evade fraud controls:
  - refuse that part,
  - you may still provide legitimate policy information from the retrieved docs.

STYLE
- Always answer in English.
- Quote retrieved intent in your own words; do not invent missing steps.
- Prefer:
  1. short direct answer
  2. supporting points from retrieved docs
  3. limitation if repository coverage is incomplete
`;

const string BANKING_OMNI_SYSTEM_PROMPT = string `
You are the "Banking Omni Agent", an orchestrator over specialized banking agents.

LANGUAGE RULE
- Always answer in English.

INPUT STRUCTURE
You receive:
- Original user question
- Optional sections:
  "=== Retail agent response (retail) ==="
  "=== Payments agent response (payments) ==="
  "=== Risk agent response (risk) ==="
  "=== Compliance agent response (compliance) ==="
  "=== Knowledge agent response (knowledge) ==="

TASK
- Produce one final answer in English that combines the useful information.

HARD RESTRICTIONS
- Never provide financial advice.
- Never provide investment advice.
- Never provide legal or tax advice.
- Never give instructions to evade fraud monitoring, limits, or compliance controls.
- Never claim certainty beyond explicit data or retrieved knowledge.

STYLE
- Structure:
  - short summary
  - useful details
  - next steps
- Do not invent balances, statuses, timelines, or policy text.
- If systems are unavailable, mention that limitation once.
- Include this notice when relevant:
  "Notice: this response is for informational purposes only and does not replace financial, legal, tax, or regulatory advice."
`;

const string BANKING_OVERLAY_SYSTEM_PROMPT = string `
You are the "Banking Safety Overlay Agent".

LANGUAGE RULE
- Always return the final text in English.

ROLE
- Remove any sentences that look like:
  - financial advice
  - legal advice
  - tax advice
  - investment advice
  - fraud-evasion guidance
  - instructions to bypass monitoring, limits, review, or controls
- Tone down over-promises not grounded in data.
- Always add at the very end:
  "Notice: this response is for informational purposes only and does not replace financial, legal, tax, or regulatory advice."
`;

// -----------------------------------------------------------------------------
// Public agent instances
// -----------------------------------------------------------------------------

public final ai:Agent retailAgent;
public final ai:Agent paymentsAgent;
public final ai:Agent riskAgent;
public final ai:Agent complianceAgent;
public final ai:Agent knowledgeAgent;
public final ai:Agent omniAgent;
public final ai:Agent overlayAgent;

const int AGENT_MEMORY_SIZE = 15;

final ai:OpenAiProvider llmProvider = USE_WSO2_AI_GATEWAY_FOR_LLM
    ? checkpanic new (
        AI_GATEWAY_LLM_ACCESS_TOKEN,
        modelType = OPENAI_MODEL,
        serviceUrl = AI_GATEWAY_LLM_SERVICE_URL
      )
    : checkpanic new (
        OPENAI_API_KEY,
        modelType = OPENAI_MODEL
      );
// -----------------------------------------------------------------------------
// Module init
// -----------------------------------------------------------------------------

function init() {
    log:printInfo("Initializing Banking Agentic APIs (LLM + tools)");
   
    log:printInfo("LLM provider mode selected",
        'value = {
            "mode": USE_WSO2_AI_GATEWAY_FOR_LLM ? "WSO2_AI_GATEWAY" : "DIRECT_VENDOR",
            "serviceUrl": USE_WSO2_AI_GATEWAY_FOR_LLM ? AI_GATEWAY_LLM_SERVICE_URL : "DIRECT_OPENAI"
        }
    );

    ai:ToolConfig[] retailTools = ai:getToolConfigs([
        retailGetCustomerProfileTool,
        retailGetAccountBalanceTool,
        retailGetCardStatusTool
    ]);

    ai:ToolConfig[] paymentsTools = ai:getToolConfigs([
        paymentsSubmitPixPaymentTool,
        paymentsGetPaymentStatusTool,
        paymentsGetTransferStatusTool
    ]);

    ai:ToolConfig[] riskTools = ai:getToolConfigs([
        riskGetCardStatusTool,
        riskGetPaymentStatusTool,
        riskGetTransferStatusTool
    ]);

    ai:ToolConfig[] complianceTools = ai:getToolConfigs([
        complianceGetCustomerProfileTool,
        complianceCreateAuditEventTool
    ]);

    ai:ToolConfig[] knowledgeTools = ai:getToolConfigs([
        knowledgeSearchRagTool
    ]);

    retailAgent = checkpanic new (
        systemPrompt = {
            role: BANKING_RETAIL_AGENT_NAME,
            instructions: BANKING_RETAIL_SYSTEM_PROMPT
        },
        model = llmProvider,
        tools = retailTools,
        memory = new ai:MessageWindowChatMemory(AGENT_MEMORY_SIZE)
    );

    paymentsAgent = checkpanic new (
        systemPrompt = {
            role: BANKING_PAYMENTS_AGENT_NAME,
            instructions: BANKING_PAYMENTS_SYSTEM_PROMPT
        },
        model = llmProvider,
        tools = paymentsTools,
        memory = new ai:MessageWindowChatMemory(AGENT_MEMORY_SIZE)
    );

    riskAgent = checkpanic new (
        systemPrompt = {
            role: BANKING_RISK_AGENT_NAME,
            instructions: BANKING_RISK_SYSTEM_PROMPT
        },
        model = llmProvider,
        tools = riskTools,
        memory = new ai:MessageWindowChatMemory(AGENT_MEMORY_SIZE)
    );

    complianceAgent = checkpanic new (
        systemPrompt = {
            role: BANKING_COMPLIANCE_AGENT_NAME,
            instructions: BANKING_COMPLIANCE_SYSTEM_PROMPT
        },
        model = llmProvider,
        tools = complianceTools,
        memory = new ai:MessageWindowChatMemory(AGENT_MEMORY_SIZE)
    );

    knowledgeAgent = checkpanic new (
        systemPrompt = {
            role: BANKING_KNOWLEDGE_AGENT_NAME,
            instructions: BANKING_KNOWLEDGE_SYSTEM_PROMPT
        },
        model = llmProvider,
        tools = knowledgeTools,
        memory = new ai:MessageWindowChatMemory(AGENT_MEMORY_SIZE)
    );

    omniAgent = checkpanic new (
        systemPrompt = {
            role: BANKING_OMNI_AGENT_NAME,
            instructions: BANKING_OMNI_SYSTEM_PROMPT
        },
        model = llmProvider,
        tools = [],
        memory = new ai:MessageWindowChatMemory(AGENT_MEMORY_SIZE)
    );

    overlayAgent = checkpanic new (
        systemPrompt = {
            role: BANKING_OVERLAY_AGENT_NAME,
            instructions: BANKING_OVERLAY_SYSTEM_PROMPT
        },
        model = llmProvider,
        tools = [],
        memory = new ai:MessageWindowChatMemory(AGENT_MEMORY_SIZE)
    );

    initializeRagRepository();

    log:printInfo("Banking Agentic APIs initialized successfully",
        'value = {
            "retailTools": [
                "RetailGetCustomerProfileTool",
                "RetailGetAccountBalanceTool",
                "RetailGetCardStatusTool"
            ],
            "paymentsTools": [
                "PaymentsSubmitPixPaymentTool",
                "PaymentsGetPaymentStatusTool",
                "PaymentsGetTransferStatusTool"
            ],
            "riskTools": [
                "RiskGetCardStatusTool",
                "RiskGetPaymentStatusTool",
                "RiskGetTransferStatusTool"
            ],
            "complianceTools": [
                "ComplianceGetCustomerProfileTool",
                "ComplianceCreateAuditEventTool"
            ],
            "knowledgeTools": [
                "KnowledgeSearchRagTool"
            ],
            "interceptionMode": "AGENT_SPECIFIC_TOOL_IDENTITY_ENABLED",
            "ragSeedDocuments": ragRepository.length()
        }
    );
}