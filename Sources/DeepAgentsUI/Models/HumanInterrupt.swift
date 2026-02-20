import Foundation
import SwiftyJSON

// MARK: - Action Request (Unified)

/// Unified action request from the agent to the human.
/// Used by both Chat and Inbox features.
public struct ActionRequest: Codable, Equatable, Sendable {
    public let action: String
    public var args: JSON
    public let description: String?

    public init(action: String, args: JSON = JSON([:]), description: String? = nil) {
        self.action = action
        self.args = args
        self.description = description
    }

    /// Parse from Chat-style JSON (uses "name" key).
    public init(chatJSON json: JSON) {
        self.action = json["name"].stringValue
        self.args = json["args"]
        self.description = json["description"].string
    }

    /// Parse from Inbox-style JSON (uses "action" key).
    public init(json: JSON) {
        self.action = json["action"].stringValue
        self.args = json["args"]
        self.description = json["description"].string
    }

    public func toJSON() -> JSON {
        var dict: [String: Any] = [
            "action": action,
            "args": args.object ?? [:]
        ]
        if let description = description {
            dict["description"] = description
        }
        return JSON(dict)
    }

    // Codable conformance
    enum CodingKeys: String, CodingKey {
        case action, args, description
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.action = try container.decode(String.self, forKey: .action)
        let argsData = try container.decodeIfPresent(Data.self, forKey: .args)
        self.args = argsData.flatMap { try? JSON(data: $0) } ?? JSON([:])
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(action, forKey: .action)
        if let data = try? args.rawData() {
            try container.encode(data, forKey: .args)
        }
        try container.encodeIfPresent(description, forKey: .description)
    }

    public static func == (lhs: ActionRequest, rhs: ActionRequest) -> Bool {
        lhs.action == rhs.action && lhs.args == rhs.args && lhs.description == rhs.description
    }
}

// MARK: - Interrupt Config (Unified)

/// Unified configuration for a human interrupt, specifying what actions are allowed.
/// Used by both Chat and Inbox features.
public struct InterruptConfig: Codable, Equatable, Sendable {
    public let allowAccept: Bool
    public let allowReject: Bool
    public let allowEdit: Bool
    public let allowIgnore: Bool
    public let allowRespond: Bool

    public init(
        allowAccept: Bool = false,
        allowReject: Bool = false,
        allowEdit: Bool = false,
        allowIgnore: Bool = false,
        allowRespond: Bool = false
    ) {
        self.allowAccept = allowAccept
        self.allowReject = allowReject
        self.allowEdit = allowEdit
        self.allowIgnore = allowIgnore
        self.allowRespond = allowRespond
    }

    /// Parse from Inbox-style JSON.
    public init(json: JSON) {
        self.allowAccept = json["allow_accept"].boolValue
        self.allowReject = json["allow_reject"].boolValue
        self.allowEdit = json["allow_edit"].boolValue
        self.allowIgnore = json["allow_ignore"].boolValue
        self.allowRespond = json["allow_respond"].boolValue
    }

    /// Derive from Chat's ReviewConfig allowedDecisions strings.
    public init(allowedDecisions: [String]?) {
        let decisions = allowedDecisions ?? ["approve", "reject", "edit"]
        self.allowAccept = decisions.contains("approve")
        self.allowReject = decisions.contains("reject")
        self.allowEdit = decisions.contains("edit")
        self.allowIgnore = false
        self.allowRespond = false
    }

    public func toJSON() -> JSON {
        return JSON([
            "allow_accept": allowAccept,
            "allow_reject": allowReject,
            "allow_edit": allowEdit,
            "allow_ignore": allowIgnore,
            "allow_respond": allowRespond
        ])
    }

    /// Default config for improper schema.
    public static let improperSchemaDefault = InterruptConfig(
        allowIgnore: true
    )
}

// MARK: - Human Interrupt (Unified)

/// Unified human interrupt in the agent flow.
/// Used by both Chat and Inbox features.
public struct HumanInterrupt: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let actionRequest: ActionRequest
    public let config: InterruptConfig
    public let description: String?

    public init(actionRequest: ActionRequest, config: InterruptConfig, description: String? = nil) {
        self.id = actionRequest.action + UUID().uuidString
        self.actionRequest = actionRequest
        self.config = config
        self.description = description
    }

    public init(json: JSON) {
        self.actionRequest = ActionRequest(json: json["action_request"])
        self.id = self.actionRequest.action + UUID().uuidString
        self.config = InterruptConfig(json: json["config"])
        self.description = json["description"].string
    }

    public func toJSON() -> JSON {
        var dict: [String: Any] = [
            "action_request": actionRequest.toJSON().object ?? [:],
            "config": config.toJSON().object ?? [:]
        ]
        if let description = description {
            dict["description"] = description
        }
        return JSON(dict)
    }

    /// Create an improper schema interrupt.
    public static func improperSchema() -> HumanInterrupt {
        return HumanInterrupt(
            actionRequest: ActionRequest(action: InboxConstants.improperSchema),
            config: .improperSchemaDefault
        )
    }

    public static func == (lhs: HumanInterrupt, rhs: HumanInterrupt) -> Bool {
        lhs.actionRequest == rhs.actionRequest && lhs.config == rhs.config
    }
}
