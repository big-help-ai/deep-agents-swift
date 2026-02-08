import Foundation

/// Constants used throughout the inbox module.
public enum InboxConstants {
    // Query/Navigation Parameters
    public static let viewStateThreadQueryParam = "view_state_thread_id"
    public static let agentInboxesStorageKey = "inbox:agent_inboxes"
    public static let langchainApiKeyStorageKey = "inbox:langchain_api_key"
    public static let offsetParam = "offset"
    public static let limitParam = "limit"
    public static let inboxParam = "inbox"
    public static let agentInboxParam = "agent_inbox"
    public static let noInboxesFoundParam = "no_inboxes_found"
    public static let improperSchema = "improper_schema"

    // Default pagination
    public static let defaultLimit = 10
    public static let defaultOffset = 0
}

// MARK: - Submit Type

/// Type of submission for a human response.
public enum SubmitType: String, Codable, Sendable {
    case accept
    case response
    case edit
}

// MARK: - Human Response Type

/// Type of human response to an interrupt.
public enum HumanResponseType: String, Codable, Sendable {
    case accept
    case ignore
    case response
    case edit
}
