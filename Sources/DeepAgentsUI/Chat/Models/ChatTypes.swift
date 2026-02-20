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

// MARK: - Thread (Chat)

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

// MARK: - Message

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
