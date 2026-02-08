import Foundation

/// Represents the current state of a call.
public enum CallState: Sendable {
    case idle
    case errored(Error)
    case activeIncoming
    case activeOutgoing
    case connected

    public var isActive: Bool {
        switch self {
        case .activeIncoming, .activeOutgoing, .connected:
            return true
        default:
            return false
        }
    }
}

// Implement Equatable manually since Error doesn't conform
extension CallState: Equatable {
    public static func == (lhs: CallState, rhs: CallState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle):
            return true
        case (.errored, .errored):
            return true  // Compare by case only, not error details
        case (.activeIncoming, .activeIncoming):
            return true
        case (.activeOutgoing, .activeOutgoing):
            return true
        case (.connected, .connected):
            return true
        default:
            return false
        }
    }
}

/// Errors that can occur during call management.
public enum CallManagerError: LocalizedError, Sendable {
    case tokenFetchFailed(String)
    case notAuthenticated
    case notConfigured
    case liveKitNotAvailable

    public var errorDescription: String? {
        switch self {
        case let .tokenFetchFailed(message):
            return "Failed to fetch token: \(message)"
        case .notAuthenticated:
            return "You must be logged in to start a call"
        case .notConfigured:
            return "Call functionality is not configured"
        case .liveKitNotAvailable:
            return "LiveKit server URL is not configured"
        }
    }
}
