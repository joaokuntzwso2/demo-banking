import ballerina/http;
import ballerina/log;
import ballerinax/ai;

final http:Client managedAgentGatewayClient = checkpanic new (AGENT_GATEWAY_BASE_URL, {
    timeout: 120.0,
    secureSocket: {
        enable: false
    }
});

function gatewayPathForDomain(BankingDomain domain) returns string {
    if domain == "RETAIL" {
        return RETAIL_AGENT_GATEWAY_PATH;
    }
    if domain == "PAYMENTS" {
        return PAYMENTS_AGENT_GATEWAY_PATH;
    }
    if domain == "RISK" {
        return RISK_AGENT_GATEWAY_PATH;
    }
    if domain == "COMPLIANCE" {
        return COMPLIANCE_AGENT_GATEWAY_PATH;
    }
    return KNOWLEDGE_AGENT_GATEWAY_PATH;
}

function agentNameForDomain(BankingDomain domain) returns string {
    if domain == "RETAIL" {
        return BANKING_RETAIL_AGENT_NAME;
    }
    if domain == "PAYMENTS" {
        return BANKING_PAYMENTS_AGENT_NAME;
    }
    if domain == "RISK" {
        return BANKING_RISK_AGENT_NAME;
    }
    if domain == "COMPLIANCE" {
        return BANKING_COMPLIANCE_AGENT_NAME;
    }
    return BANKING_KNOWLEDGE_AGENT_NAME;
}

function buildManagedSubAgentAiPayload(
    BankingDomain domain,
    string sessionId,
    string userMessage,
    string correlationId
) returns json {
    string logicalModel = string `banking-${domain.toLowerAscii()}-ai`;

    return {
        model: logicalModel,
        messages: [
            {
                role: "user",
                content: userMessage
            }
        ],
        metadata: {
            sessionId: sessionId,
            correlationId: correlationId,
            domain: domain
        }
    };
}

function addGatewayAuthHeader(map<string|string[]> headers) {
    if AGENT_GATEWAY_ACCESS_TOKEN.trim().length() == 0 {
        return;
    }

    string mode = AGENT_GATEWAY_AUTH_MODE.toLowerAscii();
    if mode == "bearer" {
        headers["Authorization"] = string `Bearer ${AGENT_GATEWAY_ACCESS_TOKEN}`;
        return;
    }

    headers[AGENT_GATEWAY_API_KEY_HEADER] = AGENT_GATEWAY_ACCESS_TOKEN;
}

function extractAssistantMessageFromAiResponse(json payload, string targetAgent) returns string|error {
    if payload is map<anydata> {
        anydata? maybeChoices = payload["choices"];
        if maybeChoices is json[] && maybeChoices.length() > 0 {
            json firstChoice = maybeChoices[0];
            if firstChoice is map<anydata> {
                anydata? maybeMessage = firstChoice["message"];
                if maybeMessage is map<anydata> {
                    anydata? maybeContent = maybeMessage["content"];
                    if maybeContent is string && maybeContent.trim().length() > 0 {
                        return maybeContent;
                    }
                }
            }
        }

        anydata? maybeError = payload["error"];
        if maybeError is map<anydata> {
            anydata? maybeErrorMessage = maybeError["message"];
            if maybeErrorMessage is string && maybeErrorMessage.trim().length() > 0 {
                return error(string `Managed sub-agent AI API ${targetAgent} returned error: ${maybeErrorMessage}`);
            }
        }
    }

    return error(string `Managed sub-agent AI response for ${targetAgent} did not contain choices[0].message.content`);
}

function invokeManagedSubAgent(
    BankingDomain domain,
    string sessionId,
    string userMessage,
    string correlationId
) returns string|error {

    string path = gatewayPathForDomain(domain);
    string targetAgent = agentNameForDomain(domain);

    map<string|string[]> headers = {
        "X-Correlation-Id": correlationId,
        "X-Session-Id": sessionId,
        "X-Agent-Name": BANKING_OMNI_AGENT_NAME,
        "X-Agent-Domain": "A2A",
        "X-Agent-Tool": string `ManagedSubAgentAICall:${targetAgent}`,
        "X-Agent-Intercepted": "true",
        "Content-Type": "application/json"
    };

    addGatewayAuthHeader(headers);

    json payload = buildManagedSubAgentAiPayload(domain, sessionId, userMessage, correlationId);

    http:Response|error respOrErr = managedAgentGatewayClient->post(path, payload, headers);
    if respOrErr is error {
        return respOrErr;
    }

    http:Response resp = respOrErr;
    json|error payloadOrErr = resp.getJsonPayload();
    if payloadOrErr is error {
        return payloadOrErr;
    }

    if resp.statusCode < 200 || resp.statusCode >= 300 {
        return error(string `Managed sub-agent AI invocation failed for ${targetAgent} with HTTP ${resp.statusCode}`);
    }

    return extractAssistantMessageFromAiResponse(payloadOrErr, targetAgent);
}

function materializeManagedSubAgentAnswer(
    string subAgentName,
    string|error result
) returns string {
    if result is string {
        return result;
    }

    log:printError("Managed sub-agent execution failed inside gateway-routed orchestration",
        'error = result,
        'value = {
            "subAgent": subAgentName
        });

    return string `The sub-agent ${subAgentName} had a technical problem while responding.`;
}

function handleOmniA2ARequest(
        AgentRequest req,
        string correlationId
) returns http:Response {

    if req.sessionId.trim().length() == 0 {
        return buildErrorResponse(http:STATUS_BAD_REQUEST, {
            message: "Invalid request",
            details: "sessionId must not be empty"
        }, correlationId);
    }

    if req.message.trim().length() == 0 {
        return buildErrorResponse(http:STATUS_BAD_REQUEST, {
            message: "Agent execution failed.",
            details: "Message must not be empty."
        }, correlationId);
    }

    string sessionId = req.sessionId;
    string userMessage = req.message;

    log:printInfo("Banking omni A2A agent IN",
        'value = {
            "sessionId": sessionId,
            "userMessage": safeTruncate(userMessage, 250),
            "endpointPath": "/v1/omni_a2a/chat",
            "correlationId": correlationId
        }
    );

    BankingDomain[] domains = detectBankingDomains(userMessage);

    string omniInput = string `
Original user question:

${userMessage}
`;

    foreach BankingDomain d in domains {
        string targetAgent = agentNameForDomain(d);

        beforeAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            targetAgent,
            d,
            sessionId,
            userMessage,
            correlationId
        );

        string|error subAgentResult = invokeManagedSubAgent(
            d,
            sessionId,
            userMessage,
            correlationId
        );

        afterAgentHandoff(
            BANKING_OMNI_AGENT_NAME,
            targetAgent,
            d,
            sessionId,
            userMessage,
            correlationId,
            subAgentResult is string ? "SUCCESS" : "ERROR"
        );

        omniInput += string `

=== ${targetAgent} response (${d}) ===

${materializeManagedSubAgentAnswer(targetAgent, subAgentResult)}
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