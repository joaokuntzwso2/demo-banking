import ballerina/http;
import ballerina/log;
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

    AgentRequest req = {
        sessionId: sessionId,
        message: userMessage
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