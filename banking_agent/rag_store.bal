import ballerina/lang.'string;
import ballerina/time;

// -----------------------------------------------------------------------------
// In-memory RAG repository for banking knowledge
// -----------------------------------------------------------------------------

isolated RagDocument[] ragRepository = [];

// Initialize once at service startup.
public isolated function initializeRagRepository() {
    lock {
        if ragRepository.length() == 0 {
            ragRepository = buildDefaultRagSeed();
        }
    }
}

// Reset to seed documents.
public isolated function resetRagRepository() returns readonly & RagDocument[] {
    lock {
        ragRepository = buildDefaultRagSeed();
        return ragRepository.cloneReadOnly();
    }
}

// List all RAG documents.
public isolated function listRagDocuments() returns readonly & RagDocument[] {
    lock {
        return ragRepository.cloneReadOnly();
    }
}

// Upsert a document by docId.
public isolated function upsertRagDocument(RagDocumentUpsertRequest req) returns readonly & RagDocument {
    string docId = req.docId;
    string title = req.title;
    string category = req.category;
    string docSource = req.docSource;
    readonly & string[] tags = req.tags.cloneReadOnly();
    string text = req.text;
    string updatedAt = time:utcNow().toString();

    lock {
        RagDocument doc = {
            docId: docId,
            title: title,
            category: category,
            docSource: docSource,
            tags: tags,
            text: text,
            updatedAt: updatedAt
        };

        int i = 0;
        while i < ragRepository.length() {
            if ragRepository[i].docId == docId {
                ragRepository[i] = doc;
                return doc.cloneReadOnly();
            }
            i += 1;
        }

        ragRepository.push(doc);
        return doc.cloneReadOnly();
    }
}

// Search repository with simple case-insensitive token matching.
public isolated function searchRagDocuments(string query, int maxResults = 4) returns readonly & RagSearchHit[] {
    readonly & RagDocument[] snapshot;

    lock {
        snapshot = ragRepository.cloneReadOnly();
    }

    string[] queryTokens = tokenize(query);
    RagSearchHit[] hits = [];

    foreach RagDocument doc in snapshot {
        int score = scoreDocument(queryTokens, doc);
        if score > 0 {
            hits.push({
                docId: doc.docId,
                title: doc.title,
                category: doc.category,
                docSource: doc.docSource,
                tags: doc.tags,
                score: score,
                excerpt: buildExcerpt(doc.text)
            });
        }
    }

    int n = hits.length();
    int i = 0;
    while i < n {
        int j = 0;
        while j < n - i - 1 {
            if hits[j].score < hits[j + 1].score {
                RagSearchHit tmp = hits[j];
                hits[j] = hits[j + 1];
                hits[j + 1] = tmp;
            }
            j += 1;
        }
        i += 1;
    }

    if maxResults <= 0 {
        RagSearchHit[] empty = [];
        return empty.cloneReadOnly();
    }

    if hits.length() <= maxResults {
        return hits.cloneReadOnly();
    }

    RagSearchHit[] top = [];
    int k = 0;
    while k < maxResults {
        top.push(hits[k]);
        k += 1;
    }

    return top.cloneReadOnly();
}

// -----------------------------------------------------------------------------
// Helpers
// -----------------------------------------------------------------------------

isolated function buildDefaultRagSeed() returns RagDocument[] {
    string now = time:utcNow().toString();

    return [
        {
            docId: "kb-pix-limits-001",
            title: "PIX Limits and Review Policy",
            category: "PAYMENTS_POLICY",
            docSource: "BANKING_KB",
            tags: ["pix", "limits", "review", "payments"].cloneReadOnly(),
            text: "PIX payments may be completed immediately, rejected, or placed under review depending on available balance, configured limits, and review signals. Agents must not provide advice on how to avoid review or monitoring.",
            updatedAt: now
        },
        {
            docId: "kb-ted-cutoff-001",
            title: "TED Transfer Operational Guidance",
            category: "PAYMENTS_POLICY",
            docSource: "BANKING_KB",
            tags: ["ted", "transfer", "cutoff", "operations"].cloneReadOnly(),
            text: "TED transfers are operational bank transfers that may have processing windows, review rules, and downstream settlement dependencies. Exact settlement timing should not be guaranteed unless explicitly confirmed by system status.",
            updatedAt: now
        },
        {
            docId: "kb-card-status-001",
            title: "Card Block and Review Status Guide",
            category: "CARDS_POLICY",
            docSource: "BANKING_KB",
            tags: ["card", "blocked", "review", "risk"].cloneReadOnly(),
            text: "Card status may appear as ACTIVE, BLOCKED, UNDER_REVIEW, or EXPIRED. A blocked or under-review status should be described operationally. Agents must not tell users how to bypass card controls or monitoring.",
            updatedAt: now
        },
        {
            docId: "kb-kyc-001",
            title: "KYC and Customer Review Guidance",
            category: "COMPLIANCE_POLICY",
            docSource: "BANKING_KB",
            tags: ["kyc", "compliance", "customer", "review"].cloneReadOnly(),
            text: "KYC workflows support customer verification and review. Agents may explain that KYC-related status is present in system data, but must not provide legal conclusions or certify compliance beyond the returned data.",
            updatedAt: now
        },
        {
            docId: "kb-aml-audit-001",
            title: "AML Review and Audit Event Guidance",
            category: "COMPLIANCE_POLICY",
            docSource: "BANKING_KB",
            tags: ["aml", "audit", "compliance", "event"].cloneReadOnly(),
            text: "AML review and audit events record operational compliance actions and observations. Agents may explain what an audit event appears to record, but must not provide legal or regulatory advice.",
            updatedAt: now
        },
        {
            docId: "kb-fraud-safe-001",
            title: "Fraud Response Safety Guidance",
            category: "RISK_POLICY",
            docSource: "BANKING_KB",
            tags: ["fraud", "risk", "alerts", "safety"].cloneReadOnly(),
            text: "Agents must not provide instructions for evading fraud controls, transaction monitoring, or review logic. They may explain risk-related states already visible in system data and recommend official bank support channels where appropriate.",
            updatedAt: now
        }
    ];
}

isolated function tokenize(string value) returns string[] {
    string lowered = value.toLowerAscii();
    string current = "";
    string[] tokens = [];

    int[] cps = lowered.toCodePointInts();
    foreach int cp in cps {
        string|error chOrErr = string:fromCodePointInt(cp);
        if chOrErr is error {
            continue;
        }

        string ch = chOrErr;
        boolean isAlphaNum = false;

        if (ch >= "a" && ch <= "z") {
            isAlphaNum = true;
        } else if (ch >= "0" && ch <= "9") {
            isAlphaNum = true;
        }

        if isAlphaNum {
            current = current + ch;
        } else {
            if current.length() > 1 {
                tokens.push(current);
            }
            current = "";
        }
    }

    if current.length() > 1 {
        tokens.push(current);
    }

    return tokens;
}

isolated function containsToken(string[] values, string token) returns boolean {
    foreach string value in values {
        if value == token {
            return true;
        }
    }
    return false;
}

isolated function scoreDocument(string[] queryTokens, RagDocument doc) returns int {
    string[] docTokens = tokenize(
        doc.title + " " +
        doc.category + " " +
        doc.docSource + " " +
        tagsToText(doc.tags) + " " +
        doc.text
    );

    int score = 0;
    foreach string token in queryTokens {
        if containsToken(docTokens, token) {
            score += 10;
        }
    }

    return score;
}

isolated function tagsToText(readonly & string[] tags) returns string {
    string out = "";
    foreach string tag in tags {
        if out.length() == 0 {
            out = tag;
        } else {
            out = out + " " + tag;
        }
    }
    return out;
}

isolated function buildExcerpt(string text) returns string {
    if text.length() <= 220 {
        return text;
    }
    return text.substring(0, 220) + "...";
}