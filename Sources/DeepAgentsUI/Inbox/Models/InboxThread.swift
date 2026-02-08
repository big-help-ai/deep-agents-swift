import Foundation
import SwiftyJSON

/// Represents a LangGraph thread with inbox-specific fields.
public struct InboxThread: Identifiable, Equatable, Sendable {
    public var id: String { threadId }
    public let threadId: String
    public let createdAt: Date
    public let updatedAt: Date
    public let status: ThreadStatus
    public let metadata: JSON
    public let values: JSON
    public let interrupts: JSON?

    public init(
        threadId: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        status: ThreadStatus = .idle,
        metadata: JSON = JSON([:]),
        values: JSON = JSON([:]),
        interrupts: JSON? = nil
    ) {
        self.threadId = threadId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.status = status
        self.metadata = metadata
        self.values = values
        self.interrupts = interrupts
    }

    public init(json: JSON) {
        self.threadId = json["thread_id"].stringValue
        self.createdAt = Self.parseDate(json["created_at"].stringValue) ?? Date()
        self.updatedAt = Self.parseDate(json["updated_at"].stringValue) ?? Date()
        self.status = ThreadStatus(rawValue: json["status"].stringValue) ?? .idle
        self.metadata = json["metadata"]
        self.values = json["values"]
        self.interrupts = json["interrupts"].exists() ? json["interrupts"] : nil
    }

    private static func parseDate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) {
            return date
        }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    public static func == (lhs: InboxThread, rhs: InboxThread) -> Bool {
        lhs.threadId == rhs.threadId
    }
}

/// Thread state from LangGraph.
public struct InboxThreadState: Sendable {
    public let values: JSON
    public let next: [String]
    public let tasks: [InboxThreadTask]
    public let metadata: JSON
    public let createdAt: Date?
    public let parentConfigurable: JSON?

    public init(
        values: JSON = JSON([:]),
        next: [String] = [],
        tasks: [InboxThreadTask] = [],
        metadata: JSON = JSON([:]),
        createdAt: Date? = nil,
        parentConfigurable: JSON? = nil
    ) {
        self.values = values
        self.next = next
        self.tasks = tasks
        self.metadata = metadata
        self.createdAt = createdAt
        self.parentConfigurable = parentConfigurable
    }

    public init(json: JSON) {
        self.values = json["values"]
        self.next = json["next"].arrayValue.map { $0.stringValue }
        self.tasks = json["tasks"].arrayValue.map { InboxThreadTask(json: $0) }
        self.metadata = json["metadata"]
        self.createdAt = nil // Parse if needed
        self.parentConfigurable = json["parent_configurable"]
    }
}

/// A task within a thread.
public struct InboxThreadTask: Sendable {
    public let id: String
    public let name: String
    public let interrupts: [InboxTaskInterrupt]

    public init(id: String, name: String, interrupts: [InboxTaskInterrupt] = []) {
        self.id = id
        self.name = name
        self.interrupts = interrupts
    }

    public init(json: JSON) {
        self.id = json["id"].stringValue
        self.name = json["name"].stringValue
        self.interrupts = json["interrupts"].arrayValue.map { InboxTaskInterrupt(json: $0) }
    }
}

/// An interrupt within a task.
public struct InboxTaskInterrupt: Sendable {
    public let value: JSON
    public let resumable: Bool
    public let ns: [String]?

    public init(value: JSON, resumable: Bool = true, ns: [String]? = nil) {
        self.value = value
        self.resumable = resumable
        self.ns = ns
    }

    public init(json: JSON) {
        self.value = json["value"]
        self.resumable = json["resumable"].boolValue
        self.ns = json["ns"].array?.map { $0.stringValue }
    }
}
