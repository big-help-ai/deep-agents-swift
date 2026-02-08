import Foundation
import SwiftyJSON

/// Wrapper for thread data with interrupt information.
/// Similar to React's discriminated union pattern.
public struct ThreadData: Identifiable, Equatable, Sendable {
    public var id: String { thread.threadId }
    public let thread: InboxThread
    public let status: ThreadStatus
    public let interrupts: [HumanInterrupt]?
    public let invalidSchema: Bool

    public init(
        thread: InboxThread,
        status: ThreadStatus,
        interrupts: [HumanInterrupt]? = nil,
        invalidSchema: Bool = false
    ) {
        self.thread = thread
        self.status = status
        self.interrupts = interrupts
        self.invalidSchema = invalidSchema
    }

    /// Whether this is an interrupted thread with valid interrupts
    public var isInterrupted: Bool {
        status == .interrupted && interrupts != nil && !interrupts!.isEmpty && !invalidSchema
    }

    /// Whether this thread has an interrupted status
    public var hasInterruptedStatus: Bool {
        status == .interrupted
    }

    /// The first interrupt if available
    public var firstInterrupt: HumanInterrupt? {
        interrupts?.first
    }

    /// The action name from the first interrupt
    public var actionName: String? {
        guard let action = firstInterrupt?.actionRequest.action,
              action != InboxConstants.improperSchema else {
            return nil
        }
        return action
    }

    /// Title for display
    public var displayTitle: String {
        if let actionName = actionName {
            return actionName.prettified
        }
        return "Thread: \(thread.threadId.prefix(6))..."
    }

    public static func == (lhs: ThreadData, rhs: ThreadData) -> Bool {
        lhs.thread.threadId == rhs.thread.threadId && lhs.status == rhs.status
    }
}

// MARK: - String Extension for Prettifying

extension String {
    /// Converts snake_case or camelCase to a prettier display format.
    var prettified: String {
        // Replace underscores with spaces
        var result = self.replacingOccurrences(of: "_", with: " ")
        // Add spaces before capital letters (for camelCase)
        result = result.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        // Capitalize first letter of each word
        return result.capitalized
    }
}

// MARK: - Email Model (for thread values)

/// Email data structure used in thread values.
public struct InboxEmail: Sendable {
    public let id: String
    public let threadId: String
    public let fromEmail: String
    public let toEmail: String
    public let subject: String
    public let pageContent: String
    public let sendTime: String?
    public let read: Bool
    public let status: String?

    public init(
        id: String,
        threadId: String,
        fromEmail: String,
        toEmail: String,
        subject: String,
        pageContent: String,
        sendTime: String? = nil,
        read: Bool = false,
        status: String? = nil
    ) {
        self.id = id
        self.threadId = threadId
        self.fromEmail = fromEmail
        self.toEmail = toEmail
        self.subject = subject
        self.pageContent = pageContent
        self.sendTime = sendTime
        self.read = read
        self.status = status
    }

    public init(json: JSON) {
        self.id = json["id"].stringValue
        self.threadId = json["thread_id"].stringValue
        self.fromEmail = json["from_email"].stringValue
        self.toEmail = json["to_email"].stringValue
        self.subject = json["subject"].stringValue
        self.pageContent = json["page_content"].stringValue
        self.sendTime = json["send_time"].string
        self.read = json["read"].boolValue
        self.status = json["status"].string
    }
}
