import Foundation
import SwiftyJSON

/// Configuration for a human interrupt, specifying what actions are allowed.
public struct HumanInterruptConfig: Equatable, Sendable {
    public let allowIgnore: Bool
    public let allowRespond: Bool
    public let allowEdit: Bool
    public let allowAccept: Bool

    public init(
        allowIgnore: Bool = false,
        allowRespond: Bool = false,
        allowEdit: Bool = false,
        allowAccept: Bool = false
    ) {
        self.allowIgnore = allowIgnore
        self.allowRespond = allowRespond
        self.allowEdit = allowEdit
        self.allowAccept = allowAccept
    }

    public init(json: JSON) {
        self.allowIgnore = json["allow_ignore"].boolValue
        self.allowRespond = json["allow_respond"].boolValue
        self.allowEdit = json["allow_edit"].boolValue
        self.allowAccept = json["allow_accept"].boolValue
    }

    public func toJSON() -> JSON {
        return JSON([
            "allow_ignore": allowIgnore,
            "allow_respond": allowRespond,
            "allow_edit": allowEdit,
            "allow_accept": allowAccept
        ])
    }

    /// Default config for improper schema
    public static let improperSchemaDefault = HumanInterruptConfig(
        allowIgnore: true,
        allowRespond: false,
        allowEdit: false,
        allowAccept: false
    )
}

/// Action request from the agent to the human (inbox-specific version).
public struct InboxActionRequest: Equatable, Sendable {
    public let action: String
    public var args: JSON

    public init(action: String, args: JSON = JSON([:])) {
        self.action = action
        self.args = args
    }

    public init(json: JSON) {
        self.action = json["action"].stringValue
        self.args = json["args"]
    }

    public func toJSON() -> JSON {
        return JSON([
            "action": action,
            "args": args.object
        ])
    }

    public static func == (lhs: InboxActionRequest, rhs: InboxActionRequest) -> Bool {
        lhs.action == rhs.action && lhs.args == rhs.args
    }
}

/// Represents a human interrupt in the agent flow.
public struct HumanInterrupt: Identifiable, Equatable, Sendable {
    public var id: String { actionRequest.action + UUID().uuidString }
    public let actionRequest: InboxActionRequest
    public let config: HumanInterruptConfig
    public let description: String?

    public init(actionRequest: InboxActionRequest, config: HumanInterruptConfig, description: String? = nil) {
        self.actionRequest = actionRequest
        self.config = config
        self.description = description
    }

    public init(json: JSON) {
        self.actionRequest = InboxActionRequest(json: json["action_request"])
        self.config = HumanInterruptConfig(json: json["config"])
        self.description = json["description"].string
    }

    public func toJSON() -> JSON {
        var dict: [String: Any] = [
            "action_request": actionRequest.toJSON().object,
            "config": config.toJSON().object
        ]
        if let description = description {
            dict["description"] = description
        }
        return JSON(dict)
    }

    /// Create an improper schema interrupt
    public static func improperSchema() -> HumanInterrupt {
        return HumanInterrupt(
            actionRequest: InboxActionRequest(action: InboxConstants.improperSchema, args: JSON([:])),
            config: .improperSchemaDefault,
            description: nil
        )
    }

    public static func == (lhs: HumanInterrupt, rhs: HumanInterrupt) -> Bool {
        lhs.actionRequest == rhs.actionRequest && lhs.config == rhs.config
    }
}

/// Human response to an agent interrupt.
public struct HumanResponse: Equatable, Sendable {
    public let type: HumanResponseType
    public var args: HumanResponseArgs

    public enum HumanResponseArgs: Equatable, Sendable {
        case null
        case string(String)
        case actionRequest(InboxActionRequest)

        public func toJSON() -> Any {
            switch self {
            case .null:
                return NSNull()
            case .string(let str):
                return str
            case .actionRequest(let request):
                return request.toJSON().object
            }
        }
    }

    public init(type: HumanResponseType, args: HumanResponseArgs = .null) {
        self.type = type
        self.args = args
    }

    public func toJSON() -> JSON {
        return JSON([
            "type": type.rawValue,
            "args": args.toJSON()
        ])
    }
}

/// Extended human response type with additional properties for tracking edit status.
public struct HumanResponseWithEdits: Identifiable, Equatable, Sendable {
    public var id: String { "\(type.rawValue)-\(UUID().uuidString)" }
    public let type: HumanResponseType
    public var args: HumanResponse.HumanResponseArgs
    public var acceptAllowed: Bool
    public var editsMade: Bool

    public init(
        type: HumanResponseType,
        args: HumanResponse.HumanResponseArgs = .null,
        acceptAllowed: Bool = false,
        editsMade: Bool = false
    ) {
        self.type = type
        self.args = args
        self.acceptAllowed = acceptAllowed
        self.editsMade = editsMade
    }

    public func toHumanResponse() -> HumanResponse {
        // Handle the edit case with accept allowed
        if type == .edit && acceptAllowed && !editsMade {
            return HumanResponse(type: .accept, args: args)
        }
        return HumanResponse(type: type, args: args)
    }
}
