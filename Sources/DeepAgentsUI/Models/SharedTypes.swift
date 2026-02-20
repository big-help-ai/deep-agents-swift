import Foundation
import SwiftyJSON

// MARK: - Thread Status

public enum ThreadStatus: String, Sendable, CaseIterable {
    case idle
    case busy
    case interrupted
    case error
    case humanResponseNeeded = "human_response_needed"
    case all // Used for filtering to show all threads

    public var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .busy: return "Busy"
        case .error: return "Error"
        case .interrupted: return "Interrupted"
        case .humanResponseNeeded: return "Human Response Needed"
        case .all: return "All"
        }
    }
}

// MARK: - Run

public struct Run: Identifiable, Sendable {
    public let id: String
    public let threadId: String
    public let assistantId: String
    public let status: String
    public let createdAt: Date?
    public let updatedAt: Date?

    public init(id: String, threadId: String, assistantId: String, status: String, createdAt: Date? = nil, updatedAt: Date? = nil) {
        self.id = id
        self.threadId = threadId
        self.assistantId = assistantId
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public init(json: JSON) {
        self.id = json["run_id"].stringValue
        self.threadId = json["thread_id"].stringValue
        self.assistantId = json["assistant_id"].stringValue
        self.status = json["status"].stringValue
        self.createdAt = ISO8601DateFormatter().date(from: json["created_at"].stringValue)
        self.updatedAt = ISO8601DateFormatter().date(from: json["updated_at"].stringValue)
    }
}

// MARK: - Assistant

public struct Assistant: Identifiable, Sendable {
    public let id: String
    public var assistantId: String { id }
    public let graphId: String
    public let name: String
    public let createdAt: Date
    public var updatedAt: Date
    public var config: JSON
    public var metadata: JSON
    public let version: Int

    public init(id: String, graphId: String, name: String, createdAt: Date, updatedAt: Date, config: JSON = JSON([]), metadata: JSON = JSON([]), version: Int = 1) {
        self.id = id
        self.graphId = graphId
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.config = config
        self.metadata = metadata
        self.version = version
    }

    public init(json: JSON) {
        self.id = json["assistant_id"].stringValue
        self.graphId = json["graph_id"].stringValue
        self.name = json["name"].string ?? "Assistant"
        self.createdAt = ISO8601DateFormatter().date(from: json["created_at"].stringValue) ?? Date()
        self.updatedAt = ISO8601DateFormatter().date(from: json["updated_at"].stringValue) ?? Date()
        self.config = json["config"]
        self.metadata = json["metadata"]
        self.version = json["version"].intValue
    }
}

// MARK: - Checkpoint

public struct Checkpoint: Sendable {
    public let checkpointId: String
    public let threadId: String?

    public init(checkpointId: String, threadId: String? = nil) {
        self.checkpointId = checkpointId
        self.threadId = threadId
    }

    public init(json: JSON) {
        self.checkpointId = json["checkpoint_id"].stringValue
        self.threadId = json["thread_id"].string
    }
}

// MARK: - Stream Event

public enum StreamEventType: String, Sendable {
    case values
    case updates
    case messages
    case messagesTuple = "messages-tuple"
    case custom
    case error
    case end
    case metadata
    case debug
    case pending
    case message // Default SSE event type
    case unknown // For unrecognized event types
}

public struct StreamEvent: Sendable {
    public let type: StreamEventType
    public let data: JSON

    public init(type: StreamEventType, data: JSON) {
        self.type = type
        self.data = data
    }
}

// MARK: - Deployment Info

public struct DeploymentInfoResponse: Sendable {
    public struct Flags: Sendable {
        public let assistants: Bool
        public let crons: Bool
        public let langsmith: Bool

        public init(assistants: Bool, crons: Bool, langsmith: Bool) {
            self.assistants = assistants
            self.crons = crons
            self.langsmith = langsmith
        }

        public init(json: JSON) {
            self.assistants = json["assistants"].boolValue
            self.crons = json["crons"].boolValue
            self.langsmith = json["langsmith"].boolValue
        }
    }

    public struct Host: Sendable {
        public let kind: String
        public let projectId: String?
        public let revisionId: String
        public let tenantId: String?

        public init(kind: String, projectId: String?, revisionId: String, tenantId: String?) {
            self.kind = kind
            self.projectId = projectId
            self.revisionId = revisionId
            self.tenantId = tenantId
        }

        public init(json: JSON) {
            self.kind = json["kind"].stringValue
            self.projectId = json["project_id"].string
            self.revisionId = json["revision_id"].stringValue
            self.tenantId = json["tenant_id"].string
        }
    }

    public let flags: Flags
    public let host: Host

    public init(flags: Flags, host: Host) {
        self.flags = flags
        self.host = host
    }

    public init(json: JSON) {
        self.flags = Flags(json: json["flags"])
        self.host = Host(json: json["host"])
    }
}
