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

function buildJsonResponse(int statusCode, json body, string correlationId = "")
        returns http:Response {
    http:Response res = new;
    res.statusCode = statusCode;
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
        return buildErrorResponse(http:STATUS_BAD_REQUEST, badReqBody, correlationId);
    }

    if req.message.trim().length() == 0 {
        ErrorBody badReqBody = {
            message: "Agent execution failed.",
            details: "Message must not be empty."
        };
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
    boolean needsKnowledge = false;

    foreach BankingDomain d in domains {
        if d == "RETAIL" {
            needsRetail = true;
        } else if d == "PAYMENTS" {
            needsPayments = true;
        } else if d == "RISK" {
            needsRisk = true;
        } else if d == "COMPLIANCE" {
            needsCompliance = true;
        } else if d == "KNOWLEDGE" {
            needsKnowledge = true;
        }
    }

    string omniInput = string `
Original user question:

${userMessage}
`;

    if needsRetail {
        beforeAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_RETAIL_AGENT_NAME,
            "RETAIL",
            sessionId,
            userMessage,
            correlationId
        );

        string|ai:Error retailResult = retailAgent->run(userMessage, sessionId = sessionId);
        if retailResult is ai:Error && isTransientLLMError(retailResult) {
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

        omniInput += string `

=== Retail agent response (retail) ===

${materializeSubAgentAnswer("retailAgent", retailResult)}
`;
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

        string|ai:Error paymentsResult = paymentsAgent->run(userMessage, sessionId = sessionId);
        if paymentsResult is ai:Error && isTransientLLMError(paymentsResult) {
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

        omniInput += string `

=== Payments agent response (payments) ===

${materializeSubAgentAnswer("paymentsAgent", paymentsResult)}
`;
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

        string|ai:Error riskResult = riskAgent->run(userMessage, sessionId = sessionId);
        if riskResult is ai:Error && isTransientLLMError(riskResult) {
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

        omniInput += string `

=== Risk agent response (risk) ===

${materializeSubAgentAnswer("riskAgent", riskResult)}
`;
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

        string|ai:Error complianceResult = complianceAgent->run(userMessage, sessionId = sessionId);
        if complianceResult is ai:Error && isTransientLLMError(complianceResult) {
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

        omniInput += string `

=== Compliance agent response (compliance) ===

${materializeSubAgentAnswer("complianceAgent", complianceResult)}
`;
    }

    if needsKnowledge {
        beforeAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_KNOWLEDGE_AGENT_NAME,
            "KNOWLEDGE",
            sessionId,
            userMessage,
            correlationId
        );

        string|ai:Error knowledgeResult = knowledgeAgent->run(userMessage, sessionId = sessionId);
        if knowledgeResult is ai:Error && isTransientLLMError(knowledgeResult) {
            knowledgeResult = knowledgeAgent->run(userMessage, sessionId = sessionId);
        }

        afterAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            BANKING_KNOWLEDGE_AGENT_NAME,
            "KNOWLEDGE",
            sessionId,
            userMessage,
            correlationId,
            knowledgeResult is string ? "SUCCESS" : "ERROR"
        );

        omniInput += string `

=== Knowledge agent response (knowledge) ===

${materializeSubAgentAnswer("knowledgeAgent", knowledgeResult)}
`;
    }

    string|ai:Error omniResult = omniAgent->run(omniInput, sessionId = sessionId);
    if omniResult is ai:Error && isTransientLLMError(omniResult) {
        omniResult = omniAgent->run(omniInput, sessionId = sessionId);
    }

    string synthesizedAnswer = omniResult is string ? omniResult : omniInput;

    string|ai:Error overlayResult = overlayAgent->run(synthesizedAnswer, sessionId = sessionId);
    if overlayResult is ai:Error && isTransientLLMError(overlayResult) {
        overlayResult = overlayAgent->run(synthesizedAnswer, sessionId = sessionId);
    }

    string finalMessage = overlayResult is string ? overlayResult : synthesizedAnswer;

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
        allowHeaders: ["content-type", "x-correlation-id", "x-session-id"],
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

    resource function post knowledge/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestSimple(
            knowledgeAgent,
            BANKING_KNOWLEDGE_AGENT_NAME,
            BANKING_KNOWLEDGE_PROMPT_VERSION,
            req,
            correlationId,
            "/v1/knowledge/chat"
        );
    }
    resource function post omni_a2a/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);

        if !ENABLE_GATEWAY_A2A_DEMO {
            return buildErrorResponse(http:STATUS_NOT_IMPLEMENTED, {
                message: "Gateway-routed A2A demo is disabled",
                details: "Set ENABLE_GATEWAY_A2A_DEMO=true to enable this endpoint"
            }, correlationId);
        }

        return handleOmniA2ARequest(req, correlationId);
    }

    resource function post omni/chat(
        @http:Payload AgentRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleOmniRequest(req, correlationId);
    }

    // -------------------------------------------------------------------------
    // RAG admin endpoints
    // -------------------------------------------------------------------------

    resource function get rag/documents(
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        readonly & RagDocument[] docs = listRagDocuments();

        return buildJsonResponse(http:STATUS_OK, {
            totalDocuments: docs.length(),
            documents: docs
        }, correlationId);
    }

    resource function post rag/documents(
        @http:Payload RagDocumentUpsertRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);

        if req.docId.trim().length() == 0 || req.title.trim().length() == 0 ||
           req.category.trim().length() == 0 || req.docSource.trim().length() == 0 ||
           req.text.trim().length() == 0 {
            return buildErrorResponse(http:STATUS_BAD_REQUEST, {
                message: "Invalid request",
                details: "docId, title, category, docSource, and text must not be empty"
            }, correlationId);
        }

        readonly & RagDocument stored = upsertRagDocument(req);
        return buildJsonResponse(http:STATUS_CREATED, stored, correlationId);
    }

    resource function post rag/search(
        @http:Payload RagSearchRequest req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);

        if req.query.trim().length() == 0 {
            return buildErrorResponse(http:STATUS_BAD_REQUEST, {
                message: "Invalid request",
                details: "query must not be empty"
            }, correlationId);
        }

        int maxResults = 4;
        int? maybeMaxResults = req["maxResults"];
        if maybeMaxResults is int {
            maxResults = maybeMaxResults;
        }

        readonly & RagSearchHit[] hits = searchRagDocuments(req.query, maxResults);

        return buildJsonResponse(http:STATUS_OK, {
            query: req.query,
            totalMatches: hits.length(),
            hits: hits
        }, correlationId);
    }

    resource function post rag/reset(
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        readonly & RagDocument[] docs = resetRagRepository();

        return buildJsonResponse(http:STATUS_OK, {
            status: "RESET",
            totalDocuments: docs.length(),
            documents: docs
        }, correlationId);
    }

        // -------------------------------------------------------------------------
    // OpenAI-compatible AI adapter endpoints for APIM AI APIs
    // -------------------------------------------------------------------------

    resource function post ai/retail/chat/completions(
        @http:Payload json req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader,
        @http:Header {name: "X-Session-Id"} string? sessionIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestOpenAiCompat(
            retailAgent,
            BANKING_RETAIL_AGENT_NAME,
            BANKING_RETAIL_PROMPT_VERSION,
            "banking-retail-ai",
            req,
            correlationId,
            "/v1/ai/retail/chat/completions",
            sessionIdHeader
        );
    }

    resource function post ai/payments/chat/completions(
        @http:Payload json req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader,
        @http:Header {name: "X-Session-Id"} string? sessionIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestOpenAiCompat(
            paymentsAgent,
            BANKING_PAYMENTS_AGENT_NAME,
            BANKING_PAYMENTS_PROMPT_VERSION,
            "banking-payments-ai",
            req,
            correlationId,
            "/v1/ai/payments/chat/completions",
            sessionIdHeader
        );
    }

    resource function post ai/risk/chat/completions(
        @http:Payload json req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader,
        @http:Header {name: "X-Session-Id"} string? sessionIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestOpenAiCompat(
            riskAgent,
            BANKING_RISK_AGENT_NAME,
            BANKING_RISK_PROMPT_VERSION,
            "banking-risk-ai",
            req,
            correlationId,
            "/v1/ai/risk/chat/completions",
            sessionIdHeader
        );
    }

    resource function post ai/compliance/chat/completions(
        @http:Payload json req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader,
        @http:Header {name: "X-Session-Id"} string? sessionIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestOpenAiCompat(
            complianceAgent,
            BANKING_COMPLIANCE_AGENT_NAME,
            BANKING_COMPLIANCE_PROMPT_VERSION,
            "banking-compliance-ai",
            req,
            correlationId,
            "/v1/ai/compliance/chat/completions",
            sessionIdHeader
        );
    }

    resource function post ai/omni_a2a/chat/completions(
        @http:Payload json req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader,
        @http:Header {name: "X-Session-Id"} string? sessionIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);

        if !ENABLE_GATEWAY_A2A_DEMO {
            return buildOpenAiCompletionErrorResponse(
                http:STATUS_NOT_IMPLEMENTED,
                "Gateway-routed A2A demo is disabled",
                correlationId
            );
        }

        return handleOmniA2ARequestOpenAiCompat(
            req,
            correlationId,
            sessionIdHeader
        );
    }
    resource function post ai/knowledge/chat/completions(
        @http:Payload json req,
        @http:Header {name: "X-Correlation-Id"} string? correlationIdHeader,
        @http:Header {name: "X-Session-Id"} string? sessionIdHeader
    ) returns http:Response {
        string correlationId = getOrGenerateCorrelationId(correlationIdHeader);
        return handleAgentRequestOpenAiCompat(
            knowledgeAgent,
            BANKING_KNOWLEDGE_AGENT_NAME,
            BANKING_KNOWLEDGE_PROMPT_VERSION,
            "banking-knowledge-ai",
            req,
            correlationId,
            "/v1/ai/knowledge/chat/completions",
            sessionIdHeader
        );
    }
}