import Foundation
import SwiftyJSON

/// Human response to an agent interrupt.
public struct HumanResponse: Equatable, Sendable {
    public let type: HumanResponseType
    public var args: HumanResponseArgs

    public enum HumanResponseArgs: Equatable, Sendable {
        case null
        case string(String)
        case actionRequest(ActionRequest)

        public func toJSON() -> Any {
            switch self {
            case .null:
                return NSNull()
            case .string(let str):
                return str
            case .actionRequest(let request):
                return request.toJSON().object ?? [:]
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
    public let id: String
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
        self.id = "\(type.rawValue)-\(UUID().uuidString)"
        self.type = type
        self.args = args
        self.acceptAllowed = acceptAllowed
        self.editsMade = editsMade
    }

    public func toHumanResponse() -> HumanResponse {
        if type == .edit && acceptAllowed && !editsMade {
            return HumanResponse(type: .accept, args: args)
        }
        return HumanResponse(type: type, args: args)
    }
}
