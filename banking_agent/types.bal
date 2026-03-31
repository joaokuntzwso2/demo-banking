// -----------------------------------------------------------------------------
// Domain primitives
// -----------------------------------------------------------------------------

public type BankingDomain "RETAIL"|"PAYMENTS"|"RISK"|"COMPLIANCE";

// -----------------------------------------------------------------------------
// HTTP request/response shapes
// -----------------------------------------------------------------------------

public type AgentRequest record {|
    string sessionId;
    string message;
|};

public type AgentResponse record {|
    string sessionId;
    string agentName;
    string promptVersion;
    string message;
    LlmUsage? llm?;
|};

public type ErrorBody record {|
    string message;
    string? details?;
|};

// -----------------------------------------------------------------------------
// Tool inputs
// -----------------------------------------------------------------------------

public type CustomerProfileInput record {|
    string customerId;
|};

public type AccountBalanceInput record {|
    string accountId;
|};

public type CardStatusInput record {|
    string cardId;
|};

public type PaymentStatusInput record {|
    string paymentId;
|};

public type TransferStatusInput record {|
    string transferId;
|};

public type PixPaymentInput record {|
    string accountId;
    string beneficiaryName;
    string beneficiaryBank;
    decimal amountBr;
|};

public type ComplianceAuditInput record {|
    string eventType;
    string severity;
    string customerId;
    string details;
|};

// -----------------------------------------------------------------------------
// LLM usage metadata
// -----------------------------------------------------------------------------

public type LlmUsage record {|
    string responseModel;
    int promptTokenCount;
    int completionTokenCount;
    int totalTokenCount;
    int? remainingTokenCount?;
|};

public type AgentHandoffEvent record {|
    string eventType;
    string correlationId;
    string fromAgent;
    string toAgent;
    string domain;
    string stage;
    string sessionId;
    string messagePreview;
    string outcome;
    string timestamp;
|};