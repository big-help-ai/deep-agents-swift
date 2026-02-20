import Foundation

/// Configuration protocol for DeepAgentsUI.
/// Implement this in your app to provide environment-specific settings.
public protocol DeepAgentsConfiguration: Sendable {
    /// The base URL for the LangSmith agent server.
    /// Example: "https://api.smith.langchain.com"
    var langsmithAgentServerUrl: String { get }

    /// Optional API key for LangGraph/LangSmith.
    /// If nil, the library will rely on AuthTokenProvider for authentication.
    var langGraphApiKey: String? { get }

    /// The LiveKit server URL for voice/video calls.
    /// Example: "wss://myapp.livekit.cloud"
    /// If nil, calling features are disabled.
    var liveKitServerUrl: String? { get }

    /// List of available graph names for the user to choose from.
    /// These are displayed in the graph picker UI.
    var availableGraphs: [String] { get }
}

/// Default configuration values
public extension DeepAgentsConfiguration {
    var langGraphApiKey: String? { nil }
    var liveKitServerUrl: String? { nil }
    var availableGraphs: [String] { [] }
}
