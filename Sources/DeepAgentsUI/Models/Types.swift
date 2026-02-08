import Foundation
import SwiftyJSON

// MARK: - Tool Call

public enum ToolCallStatus: String, Sendable {
    case pending
    case completed
    case error
    case interrupted
}

public struct ToolCall: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let args: JSON
    public var result: String?
    public var status: ToolCallStatus

    public init(id: String, name: String, args: JSON, result: String? = nil, status: ToolCallStatus = .pending) {
        self.id = id
        self.name = name
        self.args = args
        self.result = result
        self.status = status
    }

    public init(json: JSON) {
        self.id = json["id"].stringValue
        self.name = json["name"].stringValue
        self.args = json["args"]
        self.result = json["result"].string
        self.status = ToolCallStatus(rawValue: json["status"].stringValue) ?? .pending
    }
}

// MARK: - Sub Agent

public enum SubAgentStatus: String, Sendable {
    case pending
    case active
    case completed
    case error
}

public struct SubAgent: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let subAgentName: String
    public let input: JSON
    public var output: JSON?
    public var status: SubAgentStatus

    public init(id: String, name: String, subAgentName: String, input: JSON, output: JSON? = nil, status: SubAgentStatus = .pending) {
        self.id = id
        self.name = name
        self.subAgentName = subAgentName
        self.input = input
        self.output = output
        self.status = status
    }

    public init(json: JSON) {
        self.id = json["id"].stringValue
        self.name = json["name"].stringValue
        self.subAgentName = json["subAgentName"].stringValue
        self.input = json["input"]
        self.output = json["output"].exists() ? json["output"] : nil
        self.status = SubAgentStatus(rawValue: json["status"].stringValue) ?? .pending
    }
}

// MARK: - File Item

public struct FileItem: Identifiable, Sendable {
    public var id: String { path }
    public let path: String
    public var content: String

    public init(path: String, content: String) {
        self.path = path
        self.content = content
    }

    public init(json: JSON) {
        self.path = json["path"].stringValue
        self.content = json["content"].stringValue
    }
}

// MARK: - Todo Item

public enum TodoStatus: String, Sendable {
    case pending
    case inProgress = "in_progress"
    case completed
}

public struct TodoItem: Identifiable, Sendable {
    public let id: String
    public let content: String
    public var status: TodoStatus
    public var updatedAt: Date?

    public init(id: String, content: String, status: TodoStatus = .pending, updatedAt: Date? = nil) {
        self.id = id
        self.content = content
        self.status = status
        self.updatedAt = updatedAt
    }

    public init(json: JSON) {
        self.id = json["id"].stringValue
        self.content = json["content"].stringValue
        self.status = TodoStatus(rawValue: json["status"].stringValue) ?? .pending
        if let timestamp = json["updatedAt"].double {
            self.updatedAt = Date(timeIntervalSince1970: timestamp / 1000)
        } else {
            self.updatedAt = nil
        }
    }
}

// MARK: - Thread

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

public struct Thread: Identifiable, Sendable {
    public let id: String
    public var title: String
    public let createdAt: Date
    public var updatedAt: Date
    public var status: ThreadStatus

    public init(id: String, title: String, createdAt: Date, updatedAt: Date, status: ThreadStatus = .idle) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
    }

    public init(json: JSON) {
        self.id = json["thread_id"].stringValue
        self.title = json["title"].string ?? "Untitled Thread"
        self.createdAt = ISO8601DateFormatter().date(from: json["created_at"].stringValue) ?? Date()
        self.updatedAt = ISO8601DateFormatter().date(from: json["updated_at"].stringValue) ?? Date()
        self.status = ThreadStatus(rawValue: json["status"].stringValue) ?? .idle
    }
}

// MARK: - Thread Item (for list display)

public struct ThreadItem: Identifiable, Sendable {
    public let id: String
    public let updatedAt: Date
    public let status: ThreadStatus
    public var title: String
    public var description: String
    public var assistantId: String?

    public init(id: String, updatedAt: Date, status: ThreadStatus, title: String, description: String = "", assistantId: String? = nil) {
        self.id = id
        self.updatedAt = updatedAt
        self.status = status
        self.title = title
        self.description = description
        self.assistantId = assistantId
    }
}

// MARK: - Interrupt Data

public struct InterruptData: Sendable {
    public let value: JSON
    public let ns: [String]?
    public let scope: String?

    public init(value: JSON, ns: [String]? = nil, scope: String? = nil) {
        self.value = value
        self.ns = ns
        self.scope = scope
    }

    public init(json: JSON) {
        self.value = json["value"]
        self.ns = json["ns"].array?.compactMap { $0.string }
        self.scope = json["scope"].string
    }
}

// MARK: - Action Request

public struct ActionRequest: Sendable {
    public let name: String
    public let args: JSON
    public let description: String?

    public init(name: String, args: JSON, description: String? = nil) {
        self.name = name
        self.args = args
        self.description = description
    }

    public init(json: JSON) {
        self.name = json["name"].stringValue
        self.args = json["args"]
        self.description = json["description"].string
    }
}

// MARK: - Review Config

public struct ReviewConfig: Sendable {
    public let actionName: String
    public let allowedDecisions: [String]?

    public init(actionName: String, allowedDecisions: [String]? = nil) {
        self.actionName = actionName
        self.allowedDecisions = allowedDecisions
    }

    public init(json: JSON) {
        self.actionName = json["actionName"].stringValue
        self.allowedDecisions = json["allowedDecisions"].array?.compactMap { $0.string }
    }
}

// MARK: - Tool Approval Interrupt Data

public struct ToolApprovalInterruptData: Sendable {
    public let actionRequests: [ActionRequest]
    public let reviewConfigs: [ReviewConfig]?

    public init(actionRequests: [ActionRequest], reviewConfigs: [ReviewConfig]? = nil) {
        self.actionRequests = actionRequests
        self.reviewConfigs = reviewConfigs
    }

    public init(json: JSON) {
        self.actionRequests = json["action_requests"].arrayValue.map { ActionRequest(json: $0) }
        self.reviewConfigs = json["review_configs"].array?.map { ReviewConfig(json: $0) }
    }
}

// MARK: - Message (LangGraph SDK equivalent)

public enum MessageType: String, Sendable {
    case human
    case ai
    case tool
    case system
}

public struct Message: Identifiable, Sendable {
    public let id: String
    public let type: MessageType
    public var content: JSON
    public var toolCallId: String?
    public var toolCalls: [JSON]?
    public var additionalKwargs: JSON?

    public init(id: String, type: MessageType, content: JSON, toolCallId: String? = nil, toolCalls: [JSON]? = nil, additionalKwargs: JSON? = nil) {
        self.id = id
        self.type = type
        self.content = content
        self.toolCallId = toolCallId
        self.toolCalls = toolCalls
        self.additionalKwargs = additionalKwargs
    }

    public init(json: JSON) {
        self.id = json["id"].stringValue.isEmpty ? UUID().uuidString : json["id"].stringValue
        self.type = MessageType(rawValue: json["type"].stringValue) ?? .human
        self.content = json["content"]
        self.toolCallId = json["tool_call_id"].string
        self.toolCalls = json["tool_calls"].array
        self.additionalKwargs = json["additional_kwargs"].exists() ? json["additional_kwargs"] : nil
    }

    public var contentString: String {
        if let str = content.string {
            return str
        }
        if let array = content.array {
            return array.compactMap { block -> String? in
                if block["type"].stringValue == "text" {
                    return block["text"].string
                }
                return nil
            }.joined()
        }
        return ""
    }
}

// MARK: - Assistant (LangGraph SDK equivalent)

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

// MARK: - State Type

public struct StateType: Sendable {
    public var messages: [Message]
    public var todos: [TodoItem]
    public var files: [String: String]
    public var email: JSON?
    public var ui: JSON?

    public init(messages: [Message] = [], todos: [TodoItem] = [], files: [String: String] = [:], email: JSON? = nil, ui: JSON? = nil) {
        self.messages = messages
        self.todos = todos
        self.files = files
        self.email = email
        self.ui = ui
    }

    public init(json: JSON) {
        self.messages = json["messages"].arrayValue.map { Message(json: $0) }
        self.todos = json["todos"].arrayValue.map { TodoItem(json: $0) }
        self.files = json["files"].dictionaryValue.mapValues { $0.stringValue }
        self.email = json["email"].exists() ? json["email"] : nil
        self.ui = json["ui"].exists() ? json["ui"] : nil
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
