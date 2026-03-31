import ballerina/http;
import ballerinax/ai;

// -----------------------------------------------------------------------------
// HTTP client to MI/APIM
// -----------------------------------------------------------------------------

final http:Client backendClient = checkpanic new (BACKEND_BASE_URL, {
    timeout: BACKEND_HTTP_TIMEOUT_SECONDS,
    retryConfig: {
        count: BACKEND_HTTP_MAX_RETRIES,
        interval: BACKEND_HTTP_RETRY_INTERVAL_SECONDS,
        backOffFactor: BACKEND_HTTP_RETRY_BACKOFF_FACTOR,
        maxWaitInterval: BACKEND_HTTP_RETRY_MAX_WAIT_SECONDS,
        statusCodes: BACKEND_HTTP_RETRY_STATUS_CODES
    },
    secureSocket: {
        enable: false
    }
});

// -----------------------------------------------------------------------------
// Standardized envelope builder for tools
// -----------------------------------------------------------------------------

isolated function buildBackendSuccessEnvelope(
    string toolName,
    int httpStatus,
    json result,
    string correlationId
) returns json {
    return {
        tool: toolName,
        status: "SUCCESS",
        errorCode: "",
        httpStatus: httpStatus,
        safeToRetry: false,
        message: "",
        result: result,
        correlationId: correlationId
    };
}

isolated function buildBackendErrorEnvelope(
    string toolName,
    string errorCode,
    int httpStatus,
    string message,
    boolean safeToRetry,
    string correlationId
) returns json {
    return {
        tool: toolName,
        status: "ERROR",
        errorCode: errorCode,
        httpStatus: httpStatus,
        safeToRetry: safeToRetry,
        message: message,
        result: (),
        correlationId: correlationId
    };
}

public isolated function buildClientErrorEnvelope(
    string toolName,
    error err,
    string correlationId
) returns json {
    return buildBackendErrorEnvelope(
        toolName,
        "BACKEND_CLIENT_ERROR",
        500,
        err.message(),
        false,
        correlationId
    );
}

isolated function buildBackendHeaders(
    string corrId,
    string agentName,
    string agentDomain,
    string agentTool
) returns map<string|string[]> {
    map<string|string[]> headers = {
        "X-Correlation-Id": corrId,
        "x-fapi-interaction-id": corrId,
        "X-Agent-Name": agentName,
        "X-Agent-Domain": agentDomain,
        "X-Agent-Tool": agentTool,
        "X-Agent-Intercepted": "true"
    };

    if BACKEND_ACCESS_TOKEN != "" {
        headers["Authorization"] = string `Bearer ${BACKEND_ACCESS_TOKEN}`;
    }
    return headers;
}

isolated function isRetryableStatusCode(int statusCode) returns boolean {
    return statusCode == 502 || statusCode == 503 || statusCode == 504;
}

isolated function tryGetJson(http:Response resp) returns json? {
    json|error payloadOrErr = resp.getJsonPayload();
    if payloadOrErr is error {
        return ();
    }
    return payloadOrErr;
}

isolated function classifyHttpErrorCode(int statusCode) returns string {
    if isRetryableStatusCode(statusCode) {
        return "BACKEND_UNAVAILABLE";
    }
    if statusCode == 404 {
        return "NOT_FOUND";
    }
    return "BACKEND_HTTP_ERROR";
}

isolated function buildHttpErrorEnvelope(
    string toolName,
    int statusCode,
    string correlationId,
    json? payload = ()
) returns json {

    boolean safeToRetry = isRetryableStatusCode(statusCode);
    string msg = "Backend returned HTTP status " + statusCode.toString();

    if payload is map<anydata> {
        anydata? maybeMsg = payload["message"];
        if maybeMsg is string {
            string trimmed = maybeMsg.trim();
            if trimmed.length() > 0 {
                msg = trimmed;
            }
        }
    }

    return buildBackendErrorEnvelope(
        toolName,
        classifyHttpErrorCode(statusCode),
        statusCode,
        msg,
        safeToRetry,
        correlationId
    );
}

// -----------------------------------------------------------------------------
// Shared backend execution helpers
// -----------------------------------------------------------------------------

isolated function executeBackendGet(
    string toolName,
    string agentName,
    string agentDomain,
    string path,
    string corrId
) returns json {
    map<string|string[]> headers = buildBackendHeaders(corrId, agentName, agentDomain, toolName);

    http:Response|error respOrErr = backendClient->get(path, headers);
    if respOrErr is error {
        return buildClientErrorEnvelope(toolName, respOrErr, corrId);
    }

    http:Response resp = respOrErr;

    if resp.statusCode < 200 || resp.statusCode >= 300 {
        json? errPayload = tryGetJson(resp);
        return buildHttpErrorEnvelope(toolName, resp.statusCode, corrId, errPayload);
    }

    json? payload = tryGetJson(resp);
    if payload is () {
        return buildClientErrorEnvelope(toolName, error("EMPTY_JSON_PAYLOAD"), corrId);
    }

    return buildBackendSuccessEnvelope(toolName, resp.statusCode, payload, corrId);
}

isolated function executeBackendPost(
    string toolName,
    string agentName,
    string agentDomain,
    string path,
    json body,
    string corrId
) returns json {
    map<string|string[]> headers = buildBackendHeaders(corrId, agentName, agentDomain, toolName);

    http:Response|error respOrErr = backendClient->post(path, body, headers);
    if respOrErr is error {
        return buildClientErrorEnvelope(toolName, respOrErr, corrId);
    }

    http:Response resp = respOrErr;

    if resp.statusCode < 200 || resp.statusCode >= 300 {
        json? errPayload = tryGetJson(resp);
        return buildHttpErrorEnvelope(toolName, resp.statusCode, corrId, errPayload);
    }

    json? payload = tryGetJson(resp);
    if payload is () {
        return buildClientErrorEnvelope(toolName, error("EMPTY_JSON_PAYLOAD"), corrId);
    }

    return buildBackendSuccessEnvelope(toolName, resp.statusCode, payload, corrId);
}

// -----------------------------------------------------------------------------
// Agent-specific tools
// -----------------------------------------------------------------------------

@ai:AgentTool {
    name: "RetailGetCustomerProfileTool",
    description: "Fetch customer profile by customerId."
}
public isolated function retailGetCustomerProfileTool(CustomerProfileInput input) returns json {
    string corrId = generateCorrelationIdForTool("RetailGetCustomerProfile");
    string path = string `/customers/1.0.0/profile/${input.customerId}`;
    return executeBackendGet(
        "RetailGetCustomerProfileTool",
        BANKING_RETAIL_AGENT_NAME,
        "RETAIL",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "RetailGetAccountBalanceTool",
    description: "Get balance for a given accountId."
}
public isolated function retailGetAccountBalanceTool(AccountBalanceInput input) returns json {
    string corrId = generateCorrelationIdForTool("RetailGetAccountBalance");
    string path = string `/accounts/1.0.0/balance/${input.accountId}`;
    return executeBackendGet(
        "RetailGetAccountBalanceTool",
        BANKING_RETAIL_AGENT_NAME,
        "RETAIL",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "RetailGetCardStatusTool",
    description: "Get card status for a given cardId."
}
public isolated function retailGetCardStatusTool(CardStatusInput input) returns json {
    string corrId = generateCorrelationIdForTool("RetailGetCardStatus");
    string path = string `/cards/1.0.0/status/${input.cardId}`;
    return executeBackendGet(
        "RetailGetCardStatusTool",
        BANKING_RETAIL_AGENT_NAME,
        "RETAIL",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "PaymentsSubmitPixPaymentTool",
    description: "Submit a PIX payment synchronously."
}
public isolated function paymentsSubmitPixPaymentTool(PixPaymentInput input) returns json {
    string corrId = generateCorrelationIdForTool("PaymentsSubmitPixPayment");

    json body = {
        accountId: input.accountId,
        beneficiaryName: input.beneficiaryName,
        beneficiaryBank: input.beneficiaryBank,
        amountBr: input.amountBr
    };

    return executeBackendPost(
        "PaymentsSubmitPixPaymentTool",
        BANKING_PAYMENTS_AGENT_NAME,
        "PAYMENTS",
        "/payments/1.0.0/pix/sync",
        body,
        corrId
    );
}

@ai:AgentTool {
    name: "PaymentsGetPaymentStatusTool",
    description: "Get PIX payment status for a given paymentId."
}
public isolated function paymentsGetPaymentStatusTool(PaymentStatusInput input) returns json {
    string corrId = generateCorrelationIdForTool("PaymentsGetPaymentStatus");
    string path = string `/payments/1.0.0?paymentId=${input.paymentId}`;
    return executeBackendGet(
        "PaymentsGetPaymentStatusTool",
        BANKING_PAYMENTS_AGENT_NAME,
        "PAYMENTS",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "PaymentsGetTransferStatusTool",
    description: "Get transfer status for a given transferId."
}
public isolated function paymentsGetTransferStatusTool(TransferStatusInput input) returns json {
    string corrId = generateCorrelationIdForTool("PaymentsGetTransferStatus");
    string path = string `/transfers/1.0.0?transferId=${input.transferId}`;
    return executeBackendGet(
        "PaymentsGetTransferStatusTool",
        BANKING_PAYMENTS_AGENT_NAME,
        "PAYMENTS",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "RiskGetCardStatusTool",
    description: "Get card status for risk-related discussions."
}
public isolated function riskGetCardStatusTool(CardStatusInput input) returns json {
    string corrId = generateCorrelationIdForTool("RiskGetCardStatus");
    string path = string `/cards/1.0.0/status/${input.cardId}`;
    return executeBackendGet(
        "RiskGetCardStatusTool",
        BANKING_RISK_AGENT_NAME,
        "RISK",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "RiskGetPaymentStatusTool",
    description: "Get payment status for risk-related discussions."
}
public isolated function riskGetPaymentStatusTool(PaymentStatusInput input) returns json {
    string corrId = generateCorrelationIdForTool("RiskGetPaymentStatus");
    string path = string `/payments/1.0.0?paymentId=${input.paymentId}`;
    return executeBackendGet(
        "RiskGetPaymentStatusTool",
        BANKING_RISK_AGENT_NAME,
        "RISK",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "RiskGetTransferStatusTool",
    description: "Get transfer status for risk-related discussions."
}
public isolated function riskGetTransferStatusTool(TransferStatusInput input) returns json {
    string corrId = generateCorrelationIdForTool("RiskGetTransferStatus");
    string path = string `/transfers/1.0.0?transferId=${input.transferId}`;
    return executeBackendGet(
        "RiskGetTransferStatusTool",
        BANKING_RISK_AGENT_NAME,
        "RISK",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "ComplianceGetCustomerProfileTool",
    description: "Fetch customer profile for KYC and compliance context."
}
public isolated function complianceGetCustomerProfileTool(CustomerProfileInput input) returns json {
    string corrId = generateCorrelationIdForTool("ComplianceGetCustomerProfile");
    string path = string `/customers/1.0.0/profile/${input.customerId}`;
    return executeBackendGet(
        "ComplianceGetCustomerProfileTool",
        BANKING_COMPLIANCE_AGENT_NAME,
        "COMPLIANCE",
        path,
        corrId
    );
}

@ai:AgentTool {
    name: "ComplianceCreateAuditEventTool",
    description: "Create a compliance audit event."
}
public isolated function complianceCreateAuditEventTool(ComplianceAuditInput input) returns json {
    string corrId = generateCorrelationIdForTool("ComplianceCreateAuditEvent");

    json body = {
        eventType: input.eventType,
        severity: input.severity,
        customerId: input.customerId,
        details: input.details
    };

    return executeBackendPost(
        "ComplianceCreateAuditEventTool",
        BANKING_COMPLIANCE_AGENT_NAME,
        "COMPLIANCE",
        "/compliance/1.0.0/audit",
        body,
        corrId
    );
}