import ballerina/http;
import ballerina/log;
import ballerinax/ai;

listener http:Listener httpListener = new (HTTP_LISTENER_PORT);

// -----------------------------------------------------------------------------
// Helper response builders
// -----------------------------------------------------------------------------

function buildErrorResponse(int statusCode, ErrorBody body, string correlationId)
        returns http:Response {

    http:Response res = new;
    res.statusCode = statusCode;
    _ = res.setJsonPayload(body);

    if correlationId != "" {
        res.setHeader("X-Correlation-Id", correlationId);
    }
    return res;
}

function buildSuccessResponse(AgentResponse body, string correlationId)
        returns http:Response {

    http:Response res = new;
    res.statusCode = http:STATUS_OK;
    _ = res.setJsonPayload(body);

    if correlationId != "" {
        res.setHeader("X-Correlation-Id", correlationId);
    }
    return res;
}

function getOrGenerateCorrelationId(string? headerVal) returns string {
    if headerVal is string {
        string trimmed = headerVal.trim();
        if trimmed.length() > 0 {
            return trimmed;
        }
    }
    return generateCorrelationId();
}

// -----------------------------------------------------------------------------
// Generic single-agent handler
// -----------------------------------------------------------------------------

function handleAgentRequestSimple(
        ai:Agent agent,
        string agentName,
        string promptVersion,
        AgentRequest req,
        string correlationId,
        string endpointPath
) returns http:Response {

    if req.sessionId.trim().length() == 0 {
        ErrorBody badReqBody = {
            message: "Invalid request",
            details: "sessionId must not be empty"
        };
        log:printError("Agent request rejected: empty sessionId",
            'error = error("BAD_REQUEST"),
            'value = {
                "agentName": agentName,
                "endpointPath": endpointPath,
                "correlationId": correlationId
            });
        return buildErrorResponse(http:STATUS_BAD_REQUEST, badReqBody, correlationId);
    }

    if req.message.trim().length() == 0 {
        ErrorBody badReqBody = {
            message: "Agent execution failed.",
            details: "Message must not be empty."
        };

        log:printError("Agent request rejected: empty message",
            'error = error("BAD_REQUEST"),
            'value = {
                "agentName": agentName,
                "sessionId": req.sessionId,
                "endpointPath": endpointPath,
                "correlationId": correlationId
            });
        return buildErrorResponse(http:STATUS_BAD_REQUEST, badReqBody, correlationId);
    }

    string sessionId = req.sessionId;
    string message = req.message;

    log:printInfo("Banking agent IN",
        'value = {
            "sessionId": sessionId,
            "userMessage": safeTruncate(message, 250),
            "agentName": agentName,
            "promptVersion": promptVersion,
            "endpointPath": endpointPath,
            "correlationId": correlationId
        }
    );

    string|ai:Error result = agent->run(message, sessionId = sessionId);

    if result is ai:Error && isTransientLLMError(result) {
        log:printWarn("Transient LLM error detected, retrying once",
            'value = {
                "agentName": agentName,
                "sessionId": sessionId,
                "endpointPath": endpointPath,
                "correlationId": correlationId,
                "error": result.message()
            });
        result = agent->run(message, sessionId = sessionId);
    }

    if result is string {
        log:printInfo("Banking agent OUT",
            'value = {
                "sessionId": sessionId,
                "agentName": agentName,
                "promptVersion": promptVersion,
                "endpointPath": endpointPath,
                "correlationId": correlationId,
                "httpStatus": http:STATUS_OK
            }
        );

        LlmUsage llmUsage = buildLlmUsage(
            OPENAI_MODEL.toString(),
            message,
            result
        );

        AgentResponse resp = {
            sessionId: sessionId,
            agentName: agentName,
            promptVersion: promptVersion,
            message: result,
            llm: llmUsage
        };
        return buildSuccessResponse(resp, correlationId);
    }

    log:printError("Banking agent execution failed",
        'error = result,
        'value = {
            "agentName": agentName,
            "sessionId": sessionId,
            "endpointPath": endpointPath,
            "correlationId": correlationId,
            "httpStatus": http:STATUS_INTERNAL_SERVER_ERROR
        });

    ErrorBody body = {
        message: "Agent execution failed",
        details: result.message()
    };

    return buildErrorResponse(http:STATUS_INTERNAL_SERVER_ERROR, body, correlationId);
}

// -----------------------------------------------------------------------------
// Omni orchestration + overlay
// -----------------------------------------------------------------------------

function materializeSubAgentAnswer(
        string subAgentName,
        string|ai:Error result
) returns string {

    if result is string {
        return result;
    }

    log:printError("Sub-agent execution failed inside omni orchestration",
        'error = result,
        'value = {
            "subAgent": subAgentName
        });

    return string `The sub-agent ${subAgentName} had a technical problem while responding.`;
}

function handleOmniRequest(
        AgentRequest req,
        string correlationId
) returns http:Response {

    if req.sessionId.trim().length() == 0 {
        ErrorBody badReqBody = {
            message: "Invalid request",
            details: "sessionId must not be empty"
        };
        log:printError("Omni agent request rejected: empty sessionId",
            'error = error("BAD_REQUEST"),
            'value = {
                "endpointPath": "/v1/omni/chat",
                "correlationId": correlationId
            });
        return buildErrorResponse(http:STATUS_BAD_REQUEST, badReqBody, correlationId);
    }

    if req.message.trim().length() == 0 {
        ErrorBody badReqBody = {
            message: "Agent execution failed.",
            details: "Message must not be empty."
        };

        log:printError("Omni agent request rejected: empty message",
            'error = error("BAD_REQUEST"),
            'value = {
                "sessionId": req.sessionId,
                "endpointPath": "/v1/omni/chat",
                "correlationId": correlationId
            });
        return buildErrorResponse(http:STATUS_BAD_REQUEST, badReqBody, correlationId);
    }

    string sessionId = req.sessionId;
    string userMessage = req.message;

    log:printInfo("Banking omni agent IN",
        'value = {
            "sessionId": sessionId,
            "userMessage": safeTruncate(userMessage, 250),
            "endpointPath": "/v1/omni/chat",
            "correlationId": correlationId
        }
    );

    BankingDomain[] domains = detectBankingDomains(userMessage);

    boolean needsRetail = false;
    boolean needsPayments = false;
    boolean needsRisk = false;
    boolean needsCompliance = false;

    foreach BankingDomain d in domains {
        if d == "RETAIL" {
            needsRetail = true;
        } else if d == "PAYMENTS" {
            needsPayments = true;
        } else if d == "RISK" {
            needsRisk = true;
        } else if d == "COMPLIANCE" {
            needsCompliance = true;
        }
    }

    future<string|ai:Error>? retailFuture = ();
    future<string|ai:Error>? paymentsFuture = ();
    future<string|ai:Error>? riskFuture = ();
    future<string|ai:Error>? complianceFuture = ();

    if needsRetail {
        beforeAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_RETAIL_AGENT_NAME,
            "RETAIL",
            sessionId,
            userMessage,
            correlationId
        );
        retailFuture = start retailAgent->run(userMessage, sessionId = sessionId);
    }

    if needsPayments {
        beforeAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_PAYMENTS_AGENT_NAME,
            "PAYMENTS",
            sessionId,
            userMessage,
            correlationId
        );
        paymentsFuture = start paymentsAgent->run(userMessage, sessionId = sessionId);
    }

    if needsRisk {
        beforeAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_RISK_AGENT_NAME,
            "RISK",
            sessionId,
            userMessage,
            correlationId
        );
        riskFuture = start riskAgent->run(userMessage, sessionId = sessionId);
    }

    if needsCompliance {
        beforeAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_COMPLIANCE_AGENT_NAME,
            "COMPLIANCE",
            sessionId,
            userMessage,
            correlationId
        );
        complianceFuture = start complianceAgent->run(userMessage, sessionId = sessionId);
    }

    string? retailAnswer = ();
    string? paymentsAnswer = ();
    string? riskAnswer = ();
    string? complianceAnswer = ();

    if retailFuture is future<string|ai:Error> {
        string|ai:Error retailResult = wait retailFuture;
        if retailResult is ai:Error && isTransientLLMError(retailResult) {
            log:printWarn("Transient LLM error in retailAgent (omni), retrying once",
                'value = {
                    "agentName": BANKING_RETAIL_AGENT_NAME,
                    "sessionId": sessionId,
                    "endpointPath": "/v1/omni/chat",
                    "correlationId": correlationId,
                    "error": retailResult.message()
                });
            retailResult = retailAgent->run(userMessage, sessionId = sessionId);
        }

        afterAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_RETAIL_AGENT_NAME,
            "RETAIL",
            sessionId,
            userMessage,
            correlationId,
            retailResult is string ? "SUCCESS" : "ERROR"
        );

        retailAnswer = materializeSubAgentAnswer("retailAgent", retailResult);
    }

    if paymentsFuture is future<string|ai:Error> {
        string|ai:Error paymentsResult = wait paymentsFuture;
        if paymentsResult is ai:Error && isTransientLLMError(paymentsResult) {
            log:printWarn("Transient LLM error in paymentsAgent (omni), retrying once",
                'value = {
                    "agentName": BANKING_PAYMENTS_AGENT_NAME,
                    "sessionId": sessionId,
                    "endpointPath": "/v1/omni/chat",
                    "correlationId": correlationId,
                    "error": paymentsResult.message()
                });
            paymentsResult = paymentsAgent->run(userMessage, sessionId = sessionId);
        }

        afterAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_PAYMENTS_AGENT_NAME,
            "PAYMENTS",
            sessionId,
            userMessage,
            correlationId,
            paymentsResult is string ? "SUCCESS" : "ERROR"
        );

        paymentsAnswer = materializeSubAgentAnswer("paymentsAgent", paymentsResult);
    }

    if riskFuture is future<string|ai:Error> {
        string|ai:Error riskResult = wait riskFuture;
        if riskResult is ai:Error && isTransientLLMError(riskResult) {
            log:printWarn("Transient LLM error in riskAgent (omni), retrying once",
                'value = {
                    "agentName": BANKING_RISK_AGENT_NAME,
                    "sessionId": sessionId,
                    "endpointPath": "/v1/omni/chat",
                    "correlationId": correlationId,
                    "error": riskResult.message()
                });
            riskResult = riskAgent->run(userMessage, sessionId = sessionId);
        }

        afterAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_RISK_AGENT_NAME,
            "RISK",
            sessionId,
            userMessage,
            correlationId,
            riskResult is string ? "SUCCESS" : "ERROR"
        );

        riskAnswer = materializeSubAgentAnswer("riskAgent", riskResult);
    }

    if complianceFuture is future<string|ai:Error> {
        string|ai:Error complianceResult = wait complianceFuture;
        if complianceResult is ai:Error && isTransientLLMError(complianceResult) {
            log:printWarn("Transient LLM error in complianceAgent (omni), retrying once",
                'value = {
                    "agentName": BANKING_COMPLIANCE_AGENT_NAME,
                    "sessionId": sessionId,
                    "endpointPath": "/v1/omni/chat",
                    "correlationId": correlationId,
                    "error": complianceResult.message()
                });
            complianceResult = complianceAgent->run(userMessage, sessionId = sessionId);
        }

        afterAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_COMPLIANCE_AGENT_NAME,
            "COMPLIANCE",
            sessionId,
            userMessage,
            correlationId,
            complianceResult is string ? "SUCCESS" : "ERROR"
        );

        complianceAnswer = materializeSubAgentAnswer("complianceAgent", complianceResult);
    }

    string omniInput = string `
Original user question:

${userMessage}
`;

    if retailAnswer is string && needsRetail {
        omniInput = omniInput + string `

=== Retail agent response (retail) ===

${retailAnswer}
`;
    }

    if paymentsAnswer is string && needsPayments {
        omniInput = omniInput + string `

=== Payments agent response (payments) ===

${paymentsAnswer}
`;
    }

    if riskAnswer is string && needsRisk {
        omniInput = omniInput + string `

=== Risk agent response (risk) ===

${riskAnswer}
`;
    }

    if complianceAnswer is string && needsCompliance {
        omniInput = omniInput + string `

=== Compliance agent response (compliance) ===

${complianceAnswer}
`;
    }

    string|ai:Error omniResult = omniAgent->run(omniInput, sessionId = sessionId);

    if omniResult is ai:Error && isTransientLLMError(omniResult) {
        log:printWarn("Transient LLM error detected in omniAgent, retrying once",
            'value = {
                "agentName": BANKING_OMNI_AGENT_NAME,
                "sessionId": sessionId,
                "endpointPath": "/v1/omni/chat",
                "correlationId": correlationId,
                "error": omniResult.message()
            });
        omniResult = omniAgent->run(omniInput, sessionId = sessionId);
    }

    string synthesizedAnswer;

    if omniResult is string {
        synthesizedAnswer = omniResult;
    } else {
        log:printError("Omni agent execution failed, falling back to combined raw view",
            'error = omniResult,
            'value = {
                "sessionId": sessionId,
                "endpointPath": "/v1/omni/chat",
                "correlationId": correlationId
            });

        synthesizedAnswer = string `
Below is the combined view from the sub-agents:

=== Retail view ===

${retailAnswer is string ? retailAnswer : ""}

=== Payments view ===

${paymentsAnswer is string ? paymentsAnswer : ""}

=== Risk view ===

${riskAnswer is string ? riskAnswer : ""}

=== Compliance view ===

${complianceAnswer is string ? complianceAnswer : ""}
`;
    }

    string|ai:Error overlayResult = overlayAgent->run(
        synthesizedAnswer,
        sessionId = sessionId
    );

    if overlayResult is ai:Error && isTransientLLMError(overlayResult) {
        log:printWarn("Transient LLM error detected in overlayAgent, retrying once",
            'value = {
                "agentName": BANKING_OVERLAY_AGENT_NAME,
                "sessionId": sessionId,
                "endpointPath": "/v1/omni/chat",
                "correlationId": correlationId,
                "error": overlayResult.message()
            });
        overlayResult = overlayAgent->run(synthesizedAnswer, sessionId = sessionId);
    }

    string finalMessage;

    if overlayResult is string {
        finalMessage = overlayResult;
    } else {
        log:printError("Overlay agent failed, returning synthesized answer without overlay",
            'error = overlayResult,
            'value = {
                "sessionId": sessionId,
                "endpointPath": "/v1/omni/chat",
                "correlationId": correlationId
            });
        finalMessage = synthesizedAnswer;
    }

    log:printInfo("Banking omni agent OUT",
        'value = {
            "sessionId": sessionId,
            "endpointPath": "/v1/omni/chat",
            "correlationId": correlationId,
            "httpStatus": http:STATUS_OK,
            "domains": domains
        }
    );

    LlmUsage llmUsage = buildLlmUsage(
        OPENAI_MODEL.toString(),
        userMessage,
        finalMessage
    );

    AgentResponse resp = {
        sessionId: sessionId,
        agentName: BANKING_OMNI_AGENT_NAME,
        promptVersion: BANKING_OMNI_PROMPT_VERSION,
        message: finalMessage,
        llm: llmUsage
    };

    return buildSuccessResponse(resp, correlationId);
}

// -----------------------------------------------------------------------------
// Service endpoints
// -----------------------------------------------------------------------------

@http:ServiceConfig {
    cors: {
        allowOrigins: ["*"],
        allowHeaders: ["content-type", "x-correlation-id"],
        allowMethods: ["POST", "GET", "OPTIONS"]
    }
}
service /v1 on httpListener {

    resource function post retail/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {

        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestSimple(
            retailAgent,
            BANKING_RETAIL_AGENT_NAME,
            BANKING_RETAIL_PROMPT_VERSION,
            req,
            correlationId,
            "/v1/retail/chat"
        );
    }

    resource function post payments/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {

        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestSimple(
            paymentsAgent,
            BANKING_PAYMENTS_AGENT_NAME,
            BANKING_PAYMENTS_PROMPT_VERSION,
            req,
            correlationId,
            "/v1/payments/chat"
        );
    }

    resource function post risk/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {

        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestSimple(
            riskAgent,
            BANKING_RISK_AGENT_NAME,
            BANKING_RISK_PROMPT_VERSION,
            req,
            correlationId,
            "/v1/risk/chat"
        );
    }

    resource function post compliance/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {

        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestSimple(
            complianceAgent,
            BANKING_COMPLIANCE_AGENT_NAME,
            BANKING_COMPLIANCE_PROMPT_VERSION,
            req,
            correlationId,
            "/v1/compliance/chat"
        );
    }

    resource function post omni/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {

        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleOmniRequest(req, correlationId);
    }

    resource function get health() returns http:Response {
        http:Response res = new;
        res.statusCode = http:STATUS_OK;
        _ = res.setJsonPayload({ status: "UP", component: "Banking-BI-Agents" });
        return res;
    }

    resource function get health/ready() returns http:Response {
        http:Response res = new;
        _ = res.setJsonPayload({
            status: "UP",
            component: "Banking-BI-Agents",
            dependencies: ["OpenAI", "MI/APIM-Backend"]
        });
        res.statusCode = http:STATUS_OK;
        return res;
    }
}