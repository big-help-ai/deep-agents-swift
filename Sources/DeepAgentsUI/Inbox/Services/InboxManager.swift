import Foundation
import SwiftyJSON
import Combine

/// Manages LangGraph configuration for Agent Inbox.
/// Uses protocols for authentication and secure storage to allow customization.
@MainActor
@Observable
public final class InboxManager {
    // MARK: - Properties

    public private(set) var agentInboxes: [AgentInbox] = []
    public var selectedInboxId: String?

    private let userDefaults = UserDefaults.standard

    private static let graphIdKey = "agentInbox.graphId"
    private static let assistantIdKey = "langGraph.assistantId"
    private static let apiKeyStorageKey = "com.deepagents.langsmith.apikey"

    // MARK: - Computed Properties

    /// The currently selected inbox.
    public var selectedInbox: AgentInbox? {
        agentInboxes.first { $0.selected }
    }

    /// LangSmith API key (stored securely via SecureStorage protocol).
    public var langchainApiKey: String? {
        get {
            guard let storage = try? DeepAgentsUI.secureStorage else { return nil }
            return storage.read(key: Self.apiKeyStorageKey)
        }
        set {
            guard let storage = try? DeepAgentsUI.secureStorage else { return }
            if let value = newValue, !value.isEmpty {
                try? storage.save(key: Self.apiKeyStorageKey, value: value)
            } else {
                storage.delete(key: Self.apiKeyStorageKey)
            }
            // Rebuild inbox with potentially new config
            setupInbox()
        }
    }

    /// Whether an API key is configured.
    public var hasApiKey: Bool {
        if let key = langchainApiKey, !key.isEmpty {
            return true
        }
        // Also check if configuration has API key
        if let config = try? DeepAgentsUI.configuration, let apiKey = config.langGraphApiKey, !apiKey.isEmpty {
            return true
        }
        return false
    }

    /// Graph ID (stored in UserDefaults).
    public var graphId: String {
        get {
            if let storedId = userDefaults.string(forKey: Self.graphIdKey) {
                return storedId
            }
            // Default to first available graph from configuration
            if let config = try? DeepAgentsUI.configuration, let first = config.availableGraphs.first {
                return first
            }
            return ""
        }
        set {
            userDefaults.set(newValue, forKey: Self.graphIdKey)
            // Rebuild inbox with new graph ID
            setupInbox()
        }
    }

    /// Assistant ID for Deep Agents.
    public var assistantId: String {
        get { userDefaults.string(forKey: Self.assistantIdKey) ?? "" }
        set { userDefaults.set(newValue, forKey: Self.assistantIdKey) }
    }

    // MARK: - Initialization

    public init() {
        setupInbox()
    }

    // MARK: - Setup

    /// Setup the inbox with current configuration.
    private func setupInbox() {
        guard let config = try? DeepAgentsUI.configuration else { return }

        let inbox = AgentInbox(
            graphId: graphId,
            deploymentUrl: config.langGraphDeploymentUrl,
            name: nil,
            selected: true
        )

        agentInboxes = [inbox]
        selectedInboxId = inbox.id
    }

    /// Reset graph ID to default.
    public func resetGraphId() {
        userDefaults.removeObject(forKey: Self.graphIdKey)
        setupInbox()
    }

    /// Reset assistant ID to default.
    public func resetAssistantId() {
        userDefaults.removeObject(forKey: Self.assistantIdKey)
    }

    /// Change the selected agent inbox.
    public func selectInbox(id: String) {
        for i in 0 ..< agentInboxes.count {
            agentInboxes[i].selected = agentInboxes[i].id == id
        }
        selectedInboxId = id
    }

    /// Create a LangGraphClient for the selected inbox.
    public func createClient() throws -> LangGraphClient {
        guard let inbox = selectedInbox else {
            throw InboxError.noInboxSelected
        }

        // Get API key from stored key or configuration
        var apiKey = langchainApiKey
        if apiKey == nil || apiKey!.isEmpty {
            if let config = try? DeepAgentsUI.configuration {
                apiKey = config.langGraphApiKey
            }
        }

        return LangGraphClient(
            apiUrl: inbox.deploymentUrl,
            apiKey: apiKey
        )
    }

    // MARK: - Backfill

    /// Run inbox backfill process to update IDs for deployed graphs.
    public func runBackfill() async {
        guard hasApiKey else { return }

        for i in 0 ..< agentInboxes.count {
            let inbox = agentInboxes[i]

            // Skip if not deployed or already has project ID format
            guard isDeployedUrl(inbox.deploymentUrl),
                  !inbox.id.contains(":")
            else {
                continue
            }

            do {
                let client = try createClient()
                let info = try await client.fetchDeploymentInfo()

                if let projectId = info.host.projectId {
                    // Update inbox ID to project_id:graphId format
                    agentInboxes[i].id = "\(projectId):\(inbox.graphId)"
                    agentInboxes[i].tenantId = info.host.tenantId
                }
            } catch {
                print("Failed to backfill inbox \(inbox.id): \(error)")
            }
        }
    }

    // MARK: - Errors

    public enum InboxError: LocalizedError {
        case noInboxSelected
        case apiKeyRequired

        public var errorDescription: String? {
            switch self {
            case .noInboxSelected:
                return "No agent inbox selected."
            case .apiKeyRequired:
                return "Please add your LangSmith API key in Account settings."
            }
        }
    }
}
