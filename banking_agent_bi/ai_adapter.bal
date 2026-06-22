import ballerina/http;
import ballerina/log;
import ballerina/regex;
import ballerinax/ai;

// -----------------------------------------------------------------------------
// OpenAI-compatible adapter helpers for exposing BI agents as AI backends
// -----------------------------------------------------------------------------

function extractSessionIdFromOpenAiRequest(json aiReq, string? sessionHeader) returns string {
    if sessionHeader is string {
        string trimmed = sessionHeader.trim();
        if trimmed.length() > 0 {
            return trimmed;
        }
    }

    if aiReq is map<anydata> {
        anydata? maybeMetadata = aiReq["metadata"];
        if maybeMetadata is map<anydata> {
            anydata? maybeSessionId = maybeMetadata["sessionId"];
            if maybeSessionId is string {
                string trimmed = maybeSessionId.trim();
                if trimmed.length() > 0 {
                    return trimmed;
                }
            }
        }

        anydata? maybeSessionIdTop = aiReq["sessionId"];
        if maybeSessionIdTop is string {
            string trimmed = maybeSessionIdTop.trim();
            if trimmed.length() > 0 {
                return trimmed;
            }
        }
    }

    return generateCorrelationId();
}

function extractLatestUserMessageFromOpenAiRequest(json aiReq) returns string|error {
    if aiReq is map<anydata> {
        anydata? maybeMessages = aiReq["messages"];
        if maybeMessages is json[] {
            int i = maybeMessages.length();
            while i > 0 {
                i -= 1;
                json msg = maybeMessages[i];

                if msg is map<anydata> {
                    anydata? maybeRole = msg["role"];
                    anydata? maybeContent = msg["content"];

                    if maybeRole is string && maybeRole == "user" &&
                        maybeContent is string && maybeContent.trim().length() > 0 {
                        return maybeContent;
                    }
                }
            }
        }
    }

    return error("messages must contain at least one user message with non-empty string content");
}

function buildOpenAiCompletionSuccessResponse(
    string assistantMessage,
    string modelName,
    LlmUsage llmUsage,
    string correlationId
) returns http:Response {
    http:Response res = new;
    res.statusCode = http:STATUS_OK;

    json body = {
        id: string `chatcmpl-${correlationId}`,
        'object: "chat.completion",
        created: 0,
        model: modelName,
        choices: [
            {
                index: 0,
                message: {
                    role: "assistant",
                    content: assistantMessage
                },
                finish_reason: "stop"
            }
        ],
        usage: {
            prompt_tokens: llmUsage.promptTokenCount,
            completion_tokens: llmUsage.completionTokenCount,
            total_tokens: llmUsage.totalTokenCount
        }
    };

    checkpanic res.setJsonPayload(body);
    checkpanic res.setHeader("X-Correlation-Id", correlationId);
    return res;
}

function buildOpenAiCompletionErrorResponse(
    int statusCode,
    string message,
    string correlationId
) returns http:Response {
    http:Response res = new;
    res.statusCode = statusCode;

    string errType = statusCode == http:STATUS_BAD_REQUEST ? "invalid_request_error" : "server_error";
    string errCode = statusCode == http:STATUS_BAD_REQUEST ? "invalid_request" : "agent_execution_failed";

    json body = {
        'error: {
            message: message,
            'type: errType,
            code: errCode
        }
    };

    checkpanic res.setJsonPayload(body);
    checkpanic res.setHeader("X-Correlation-Id", correlationId);
    return res;
}

function handleAgentRequestOpenAiCompat(
    ai:Agent agent,
    string agentName,
    string promptVersion,
    string adapterModelName,
    json aiReq,
    string correlationId,
    string endpointPath,
    string? sessionIdHeader
) returns http:Response {

    string sessionId = extractSessionIdFromOpenAiRequest(aiReq, sessionIdHeader);
    string|error userMessageOrErr = extractLatestUserMessageFromOpenAiRequest(aiReq);

    if userMessageOrErr is error {
        return buildOpenAiCompletionErrorResponse(
            http:STATUS_BAD_REQUEST,
            userMessageOrErr.message(),
            correlationId
        );
    }

    string userMessage = userMessageOrErr;

    log:printInfo("Banking AI-adapter IN",
        'value = {
            "sessionId": sessionId,
            "userMessage": safeTruncate(userMessage, 250),
            "agentName": agentName,
            "promptVersion": promptVersion,
            "endpointPath": endpointPath,
            "correlationId": correlationId
        }
    );

    string|ai:Error result = agent->run(userMessage, sessionId = sessionId);

    if result is ai:Error && isTransientLLMError(result) {
        log:printWarn("Transient LLM error detected in AI adapter, retrying once",
            'value = {
                "agentName": agentName,
                "sessionId": sessionId,
                "endpointPath": endpointPath,
                "correlationId": correlationId,
                "error": result.message()
            });
        result = agent->run(userMessage, sessionId = sessionId);
    }

    if result is string {
        LlmUsage llmUsage = buildLlmUsage(
            OPENAI_MODEL.toString(),
            userMessage,
            result
        );

        log:printInfo("Banking AI-adapter OUT",
            'value = {
                "sessionId": sessionId,
                "agentName": agentName,
                "promptVersion": promptVersion,
                "endpointPath": endpointPath,
                "correlationId": correlationId,
                "httpStatus": http:STATUS_OK
            }
        );

        return buildOpenAiCompletionSuccessResponse(
            result,
            adapterModelName,
            llmUsage,
            correlationId
        );
    }

    log:printError("Banking AI-adapter execution failed",
        'error = result,
        'value = {
            "agentName": agentName,
            "sessionId": sessionId,
            "endpointPath": endpointPath,
            "correlationId": correlationId,
            "httpStatus": http:STATUS_INTERNAL_SERVER_ERROR
        });

    return buildOpenAiCompletionErrorResponse(
        http:STATUS_INTERNAL_SERVER_ERROR,
        result.message(),
        correlationId
    );
}

// -----------------------------------------------------------------------------
// Omni A2A OpenAI-compatible adapter
// -----------------------------------------------------------------------------

function containsString(string[] values, string target) returns boolean {
    foreach string value in values {
        if value == target {
            return true;
        }
    }
    return false;
}

function appendUniqueString(string[] values, string value) returns string[] {
    string trimmed = value.trim();
    if trimmed.length() == 0 {
        return values;
    }

    if !containsString(values, trimmed) {
        values.push(trimmed);
    }

    return values;
}

function appendUniqueStrings(string[] values, string[] additions) returns string[] {
    string[] result = [];

    foreach string existing in values {
        result.push(existing);
    }

    foreach string value in additions {
        result = appendUniqueString(result, value);
    }

    return result;
}

function parseSpaceSeparatedScopes(string scopeText) returns string[] {
    string[] scopes = [];

    string trimmedText = scopeText.trim();
    if trimmedText.length() == 0 {
        return scopes;
    }

    foreach string rawScope in regex:split(trimmedText, "[\\s,]+") {
        scopes = appendUniqueString(scopes, rawScope);
    }

    return scopes;
}

function stringArrayFromAny(anydata? value) returns string[] {
    string[] values = [];

    if value is string {
        string trimmedValue = value.trim();
        if trimmedValue.length() == 0 {
            return values;
        }

        foreach string item in regex:split(trimmedValue, "[\\s,]+") {
            values = appendUniqueString(values, item);
        }

        return values;
    }

    if value is anydata[] {
        foreach anydata item in value {
            if item is string {
                values = appendUniqueString(values, item);
            }
        }
    }

    return values;
}

function extractOpenAiMetadata(json aiReq) returns map<anydata>? {
    if aiReq is map<anydata> {
        anydata? maybeMetadata = aiReq["metadata"];
        if maybeMetadata is map<anydata> {
            return maybeMetadata;
        }
    }

    return ();
}

function extractOboUserScopes(json aiReq) returns string[] {
    string[] scopes = [];

    map<anydata>? metadata = extractOpenAiMetadata(aiReq);
    if metadata is map<anydata> {
        scopes = appendUniqueStrings(scopes, stringArrayFromAny(metadata["scopes"]));
        scopes = appendUniqueStrings(scopes, stringArrayFromAny(metadata["user_scopes"]));

        anydata? maybeObo = metadata["obo"];
        if maybeObo is map<anydata> {
            scopes = appendUniqueStrings(scopes, stringArrayFromAny(maybeObo["user_scopes"]));

            anydata? maybeUser = maybeObo["user"];
            if maybeUser is map<anydata> {
                scopes = appendUniqueStrings(scopes, stringArrayFromAny(maybeUser["scopes"]));
            }
        }
    }

    return scopes;
}

function containsAnyTerm(string text, string[] terms) returns boolean {
    foreach string term in terms {
        if text.includes(term) {
            return true;
        }
    }

    return false;
}

function detectRequiredOboScopes(string userMessage) returns string[] {
    string lower = userMessage.toLowerAscii();
    string[] requiredScopes = [];

    boolean createIntent = containsAnyTerm(lower, [
        "create",
        "submit",
        "initiate",
        "send",
        "execute",
        "process",
        "make"
    ]);

    if createIntent && containsAnyTerm(lower, ["pix", "payment", "pay"]) {
        requiredScopes = appendUniqueString(requiredScopes, SCOPE_PAYMENTS_CREATE);
    }

    if createIntent && containsAnyTerm(lower, ["ted", "transfer"]) {
        requiredScopes = appendUniqueString(requiredScopes, SCOPE_TRANSFERS_CREATE);
    }

    if containsAnyTerm(lower, ["create audit", "write audit", "record audit", "submit audit", "create compliance", "write compliance"]) {
        requiredScopes = appendUniqueString(requiredScopes, SCOPE_COMPLIANCE_WRITE);
    }

    if containsAnyTerm(lower, ["create fraud", "write fraud", "record fraud", "submit fraud", "create alert", "fraud alert"]) {
        requiredScopes = appendUniqueString(requiredScopes, SCOPE_FRAUD_WRITE);
    }

    return requiredScopes;
}

function buildOboDeniedMessage(
    string requiredScope,
    boolean userHasScope,
    boolean agentHasScope,
    string correlationId
) returns string {
    string userStatus = userHasScope ? "present" : "missing";
    string agentStatus = agentHasScope ? "present" : "missing";

    return string `OBO authorization denied.

The requested banking operation requires ${requiredScope}.

OBO policy requires BOTH identities to be authorized:

- User delegated permission: ${userStatus}
- Banking Omni Agent permission: ${agentStatus}

The Banking Omni Agent may have permission, but the signed-in user must also be allowed to delegate this operation in On-Behalf-Of mode.

No PIX, TED, audit, fraud, or banking write operation was executed.

Correlation ID: ${correlationId}`;
}

function buildOboAllowedPrefix(string[] requiredScopes, string correlationId) returns string {
    string scopeList = "";

    foreach string scope in requiredScopes {
        if scopeList.length() > 0 {
            scopeList += ", ";
        }
        scopeList += scope;
    }

    return string `OBO authorization pre-check passed.

Required scope(s): ${scopeList}
Decision: allowed because both the signed-in user and the Banking Omni Agent identity have the required permission(s).
Correlation ID: ${correlationId}

When answering, explain that this action passed On-Behalf-Of authorization.

Original user request:
`;
}

function evaluateOboAuthorization(
    json aiReq,
    string userMessage,
    string correlationId
) returns string? {
    if !ENABLE_OBO_AUTHORIZATION {
        return ();
    }

    string[] requiredScopes = detectRequiredOboScopes(userMessage);
    if requiredScopes.length() == 0 {
        return ();
    }

    string[] userScopes = extractOboUserScopes(aiReq);
    string[] agentScopes = parseSpaceSeparatedScopes(AGENT_ALLOWED_SCOPES);

    foreach string requiredScope in requiredScopes {
        boolean userHasScope = containsString(userScopes, requiredScope);
        boolean agentHasScope = containsString(agentScopes, requiredScope);

        if !userHasScope || !agentHasScope {
            log:printWarn("OBO authorization denied",
                'value = {
                    "correlationId": correlationId,
                    "requiredScope": requiredScope,
                    "userHasScope": userHasScope,
                    "agentHasScope": agentHasScope
                }
            );

            return buildOboDeniedMessage(
                requiredScope,
                userHasScope,
                agentHasScope,
                correlationId
            );
        }
    }

    log:printInfo("OBO authorization allowed",
        'value = {
            "correlationId": correlationId,
            "requiredScopes": requiredScopes
        }
    );

    return ();
}

function enrichUserMessageWithOboContext(
    json aiReq,
    string userMessage,
    string correlationId
) returns string {
    if !ENABLE_OBO_AUTHORIZATION {
        return userMessage;
    }

    string[] requiredScopes = detectRequiredOboScopes(userMessage);
    if requiredScopes.length() == 0 {
        return userMessage;
    }

    return buildOboAllowedPrefix(requiredScopes, correlationId) + userMessage;
}

function handleOmniA2ARequestOpenAiCompat(
    json aiReq,
    string correlationId,
    string? sessionIdHeader
) returns http:Response {

    string sessionId = extractSessionIdFromOpenAiRequest(aiReq, sessionIdHeader);
    string|error userMessageOrErr = extractLatestUserMessageFromOpenAiRequest(aiReq);

    if userMessageOrErr is error {
        return buildOpenAiCompletionErrorResponse(
            http:STATUS_BAD_REQUEST,
            userMessageOrErr.message(),
            correlationId
        );
    }

    string userMessage = userMessageOrErr;

    string? oboDeniedMessage = evaluateOboAuthorization(
        aiReq,
        userMessage,
        correlationId
    );

    if oboDeniedMessage is string {
        LlmUsage deniedUsage = buildLlmUsage(
            OPENAI_MODEL.toString(),
            userMessage,
            oboDeniedMessage
        );

        return buildOpenAiCompletionSuccessResponse(
            oboDeniedMessage,
            "banking-omni-a2a-ai",
            deniedUsage,
            correlationId
        );
    }

    string effectiveUserMessage = enrichUserMessageWithOboContext(
        aiReq,
        userMessage,
        correlationId
    );

    AgentRequest req = {
        sessionId: sessionId,
        message: effectiveUserMessage
    };

    http:Response omniResp = handleOmniA2ARequest(req, correlationId);

    json|error payloadOrErr = omniResp.getJsonPayload();
    if payloadOrErr is error {
        return buildOpenAiCompletionErrorResponse(
            http:STATUS_INTERNAL_SERVER_ERROR,
            "Unable to parse omni A2A response payload",
            correlationId
        );
    }

    if omniResp.statusCode < 200 || omniResp.statusCode >= 300 {
        if payloadOrErr is map<anydata> {
            anydata? maybeMessage = payloadOrErr["message"];
            if maybeMessage is string && maybeMessage.trim().length() > 0 {
                return buildOpenAiCompletionErrorResponse(
                    omniResp.statusCode,
                    maybeMessage,
                    correlationId
                );
            }
        }

        return buildOpenAiCompletionErrorResponse(
            omniResp.statusCode,
            string `Omni A2A execution failed with HTTP ${omniResp.statusCode}`,
            correlationId
        );
    }

    if payloadOrErr is map<anydata> {
        anydata? maybeMessage = payloadOrErr["message"];
        anydata? maybeLlm = payloadOrErr["llm"];

        if maybeMessage is string {
            LlmUsage llmUsage = {
                responseModel: OPENAI_MODEL.toString(),
                promptTokenCount: 0,
                completionTokenCount: 0,
                totalTokenCount: 0
            };

            if maybeLlm is map<anydata> {
                anydata? maybeResponseModel = maybeLlm["responseModel"];
                anydata? maybePromptTokens = maybeLlm["promptTokenCount"];
                anydata? maybeCompletionTokens = maybeLlm["completionTokenCount"];
                anydata? maybeTotalTokens = maybeLlm["totalTokenCount"];
                anydata? maybeRemainingTokens = maybeLlm["remainingTokenCount"];

                llmUsage = {
                    responseModel: maybeResponseModel is string ? maybeResponseModel : OPENAI_MODEL.toString(),
                    promptTokenCount: maybePromptTokens is int ? maybePromptTokens : 0,
                    completionTokenCount: maybeCompletionTokens is int ? maybeCompletionTokens : 0,
                    totalTokenCount: maybeTotalTokens is int ? maybeTotalTokens : 0,
                    remainingTokenCount: maybeRemainingTokens is int ? maybeRemainingTokens : ()
                };
            } else {
                llmUsage = buildLlmUsage(
                    OPENAI_MODEL.toString(),
                    userMessage,
                    maybeMessage
                );
            }

            return buildOpenAiCompletionSuccessResponse(
                maybeMessage,
                "banking-omni-a2a-ai",
                llmUsage,
                correlationId
            );
        }
    }

    return buildOpenAiCompletionErrorResponse(
        http:STATUS_INTERNAL_SERVER_ERROR,
        "Omni A2A response did not contain a message field",
        correlationId
    );
}