import ballerina/http;
import ballerina/log;
import ballerina/time;
import ballerina/uuid;
import ballerina/lang.'string as string;
import ballerinax/ai;

// -----------------------------------------------------------------------------
// Correlation IDs & safe logging helpers
// -----------------------------------------------------------------------------

public isolated function generateCorrelationId() returns string {
    return "corr-" + uuid:createType4AsString();
}

public isolated function generateCorrelationIdForTool(string toolName) returns string {
    return string `corr-${toolName}-${uuid:createType4AsString()}`;
}

public isolated function safeTruncate(string value, int maxLen) returns string {
    if maxLen <= 0 {
        return "";
    }

    if value.length() <= maxLen {
        return value;
    }
    return value.substring(0, maxLen);
}

// Masking helpers.
public isolated function maskCustomerId(string customerId) returns string {
    return safeTruncate(customerId, 14);
}

public isolated function maskAccountId(string accountId) returns string {
    return safeTruncate(accountId, 16);
}

public isolated function maskCardId(string cardId) returns string {
    return safeTruncate(cardId, 16);
}

public isolated function maskPaymentId(string paymentId) returns string {
    return safeTruncate(paymentId, 18);
}

public isolated function maskTransferId(string transferId) returns string {
    return safeTruncate(transferId, 18);
}

// -----------------------------------------------------------------------------
// Agent-to-agent handoff interception
// -----------------------------------------------------------------------------

function nowUtcIsoString() returns string {
    return time:utcNow().toString();
}

function buildAgentHandoffEvent(
    string fromAgent,
    string toAgent,
    string domain,
    string sessionId,
    string message,
    string correlationId,
    string stage,
    string outcome
) returns AgentHandoffEvent {
    return {
        eventType: "AGENT_HANDOFF_INTERCEPTED",
        correlationId: correlationId,
        fromAgent: fromAgent,
        toAgent: toAgent,
        domain: domain,
        stage: stage,
        sessionId: sessionId,
        messagePreview: safeTruncate(message, 180),
        outcome: outcome,
        timestamp: nowUtcIsoString()
    };
}

function dispatchAgentHandoffWebhook(AgentHandoffEvent evt) {
    if !ENABLE_AGENT_HANDOFF_WEBHOOK {
        return;
    }

    string url = AGENT_HANDOFF_WEBHOOK_URL.trim();
    if url.length() == 0 {
        log:printWarn("Agent handoff webhook dispatch skipped: empty webhook URL",
            'value = {
                "correlationId": evt.correlationId,
                "fromAgent": evt.fromAgent,
                "toAgent": evt.toAgent,
                "stage": evt.stage
            });
        return;
    }

    http:Client webhookClient = checkpanic new (url, {
        timeout: 2.0,
        secureSocket: {
            enable: false
        }
    });

    json payload = {
        eventType: evt.eventType,
        correlationId: evt.correlationId,
        fromAgent: evt.fromAgent,
        toAgent: evt.toAgent,
        domain: evt.domain,
        stage: evt.stage,
        sessionId: evt.sessionId,
        messagePreview: evt.messagePreview,
        outcome: evt.outcome,
        timestamp: evt.timestamp
    };

    http:Response|error respOrErr = webhookClient->post("", payload);

    if respOrErr is error {
        log:printWarn("Agent handoff webhook dispatch failed",
            'value = {
                "correlationId": evt.correlationId,
                "fromAgent": evt.fromAgent,
                "toAgent": evt.toAgent,
                "domain": evt.domain,
                "stage": evt.stage,
                "webhookUrl": url,
                "error": respOrErr.message()
            });
        return;
    }

    log:printInfo("Agent handoff webhook dispatched",
        'value = {
            "correlationId": evt.correlationId,
            "fromAgent": evt.fromAgent,
            "toAgent": evt.toAgent,
            "domain": evt.domain,
            "stage": evt.stage,
            "webhookUrl": url,
            "statusCode": respOrErr.statusCode
        });
}

public function beforeAgentHandoff(
    string fromAgent,
    string toAgent,
    string domain,
    string sessionId,
    string message,
    string correlationId
) {
    if !ENABLE_AGENT_HANDOFF_INTERCEPTOR {
        return;
    }

    AgentHandoffEvent evt = buildAgentHandoffEvent(
        fromAgent,
        toAgent,
        domain,
        sessionId,
        message,
        correlationId,
        "BEFORE",
        "PENDING"
    );

    log:printInfo("AGENT_HANDOFF_INTERCEPTED", 'value = evt);

    if ENABLE_AGENT_HANDOFF_VERBOSE_LOG {
        log:printInfo("Demo action executed on agent-to-agent interception",
            'value = {
                "correlationId": correlationId,
                "fromAgent": fromAgent,
                "toAgent": toAgent,
                "domain": domain,
                "stage": "BEFORE",
                "action": "CUSTOM_HOOK_EXECUTED"
            });
    }

    dispatchAgentHandoffWebhook(evt);
}

public function afterAgentHandoff(
    string fromAgent,
    string toAgent,
    string domain,
    string sessionId,
    string message,
    string correlationId,
    string outcome
) {
    if !ENABLE_AGENT_HANDOFF_INTERCEPTOR {
        return;
    }

    AgentHandoffEvent evt = buildAgentHandoffEvent(
        fromAgent,
        toAgent,
        domain,
        sessionId,
        message,
        correlationId,
        "AFTER",
        outcome
    );

    log:printInfo("AGENT_HANDOFF_INTERCEPTED", 'value = evt);

    if ENABLE_AGENT_HANDOFF_VERBOSE_LOG {
        log:printInfo("Demo action executed on agent-to-agent interception",
            'value = {
                "correlationId": correlationId,
                "fromAgent": fromAgent,
                "toAgent": toAgent,
                "domain": domain,
                "stage": "AFTER",
                "outcome": outcome,
                "action": "CUSTOM_HOOK_EXECUTED"
            });
    }

    dispatchAgentHandoffWebhook(evt);
}

// -----------------------------------------------------------------------------
// Domain routing helpers for Omni agent
// -----------------------------------------------------------------------------

function containsAnySubstringIgnoreCase(
    string sourceString,
    readonly & string[] markers
) returns boolean {
    if sourceString.length() == 0 {
        return false;
    }

    string normalized = sourceString.toLowerAscii();

    foreach string marker in markers {
        string m = marker.toLowerAscii();
        if string:includes(normalized, m) {
            return true;
        }
    }
    return false;
}

const string[] RETAIL_KEYWORDS = [
    "customer", "profile", "customer id", "customerid",
    "account", "accounts", "balance",
    "card", "cards", "debit card", "credit card",
    "cust-br", "acc-", "card-",
    "cliente", "conta", "saldo", "cartão", "cartao", "perfil"
];

const string[] PAYMENTS_KEYWORDS = [
    "pix", "payment", "payments", "pay",
    "transfer", "transfers", "ted",
    "settled", "settlement", "beneficiary",
    "paymentid", "transferid", "payment id", "transfer id",
    "pagamento", "pagamentos", "transferência", "transferencia", "beneficiário", "beneficiario"
];

const string[] RISK_KEYWORDS = [
    "risk", "fraud", "fraudulent", "suspicious",
    "review", "under review", "blocked", "monitoring", "alert",
    "risco", "fraude", "suspeito", "revisão", "revisao", "bloqueado", "alerta"
];

const string[] COMPLIANCE_KEYWORDS = [
    "compliance", "kyc", "aml", "sanction", "audit", "regulatory",
    "due diligence", "review case", "review event",
    "conformidade", "auditoria", "regulatório", "regulatorio", "aml", "kyc"
];

public function detectBankingDomains(string userMessage) returns BankingDomain[] {
    BankingDomain[] domains = [];

    if containsAnySubstringIgnoreCase(userMessage, RETAIL_KEYWORDS) {
        domains.push(<BankingDomain>"RETAIL");
    }
    if containsAnySubstringIgnoreCase(userMessage, PAYMENTS_KEYWORDS) {
        domains.push(<BankingDomain>"PAYMENTS");
    }
    if containsAnySubstringIgnoreCase(userMessage, RISK_KEYWORDS) {
        domains.push(<BankingDomain>"RISK");
    }
    if containsAnySubstringIgnoreCase(userMessage, COMPLIANCE_KEYWORDS) {
        domains.push(<BankingDomain>"COMPLIANCE");
    }

    if domains.length() == 0 {
        domains.push(<BankingDomain>"RETAIL");
    }
    return domains;
}

// -----------------------------------------------------------------------------
// Transient LLM error detection
// -----------------------------------------------------------------------------

const string[] TRANSIENT_LLM_ERROR_MARKERS = [
    "rate limit", "tpm", "rpm", "timeout", "timed out",
    "overloaded", "server error", "unavailable",
    "temporarily unavailable", "try again later", "gateway timeout"
];

public function isTransientLLMError(ai:Error err) returns boolean {
    return containsAnySubstringIgnoreCase(err.message(), TRANSIENT_LLM_ERROR_MARKERS);
}

// -----------------------------------------------------------------------------
// LLM usage estimation helpers
// -----------------------------------------------------------------------------

public isolated function estimateTokenCount(string text) returns int {
    int charLen = text.length();

    if charLen == 0 {
        return 0;
    }

    int approxCharsPerToken = 4;
    int tokens = charLen / approxCharsPerToken;
    if charLen % approxCharsPerToken != 0 {
        tokens += 1;
    }

    return tokens;
}

public isolated function buildLlmUsage(
    string responseModel,
    string promptText,
    string completionText,
    int? remainingTokenCount = ()
) returns LlmUsage {

    int promptTokens = estimateTokenCount(promptText);
    int completionTokens = estimateTokenCount(completionText);
    int totalTokens = promptTokens + completionTokens;

    if remainingTokenCount is int {
        return {
            responseModel: responseModel,
            promptTokenCount: promptTokens,
            completionTokenCount: completionTokens,
            totalTokenCount: totalTokens,
            remainingTokenCount: remainingTokenCount
        };
    }

    return {
        responseModel: responseModel,
        promptTokenCount: promptTokens,
        completionTokenCount: completionTokens,
        totalTokenCount: totalTokens
    };
}