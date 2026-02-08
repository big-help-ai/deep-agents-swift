import Foundation

/// Central configuration and access point for DeepAgentsUI.
/// Call `DeepAgentsUI.configure(...)` in your app's initialization to set up the library.
public final class DeepAgentsUI: @unchecked Sendable {
    /// Shared instance
    public static let shared = DeepAgentsUI()

    private var _configuration: (any DeepAgentsConfiguration)?
    private var _authProvider: (any AuthTokenProvider)?
    private var _secureStorage: (any SecureStorage)?
    private var _callTokenProvider: (any CallTokenProvider)?
    private weak var _eventHandler: (any DeepAgentsEventHandler)?

    private let lock = NSLock()

    private init() {}

    // MARK: - Configuration

    /// Configure DeepAgentsUI with the required providers.
    /// Call this during app initialization before using any DeepAgentsUI features.
    ///
    /// - Parameters:
    ///   - configuration: Configuration settings for the library
    ///   - authProvider: Provider for authentication tokens
    ///   - secureStorage: Provider for secure storage (e.g., Keychain)
    ///   - callTokenProvider: Optional provider for LiveKit room tokens
    ///   - eventHandler: Handler for events emitted by the library
    public static func configure(
        configuration: any DeepAgentsConfiguration,
        authProvider: any AuthTokenProvider,
        secureStorage: any SecureStorage,
        callTokenProvider: (any CallTokenProvider)? = nil,
        eventHandler: (any DeepAgentsEventHandler)? = nil
    ) {
        shared.lock.lock()
        defer { shared.lock.unlock() }

        shared._configuration = configuration
        shared._authProvider = authProvider
        shared._secureStorage = secureStorage
        shared._callTokenProvider = callTokenProvider
        shared._eventHandler = eventHandler
    }

    // MARK: - Accessors

    /// The current configuration.
    /// - Throws: `DeepAgentsUIError.notConfigured` if the library hasn't been configured.
    public static var configuration: any DeepAgentsConfiguration {
        get throws {
            shared.lock.lock()
            defer { shared.lock.unlock() }
            guard let config = shared._configuration else {
                throw DeepAgentsUIError.notConfigured
            }
            return config
        }
    }

    /// The authentication provider.
    /// - Throws: `DeepAgentsUIError.notConfigured` if the library hasn't been configured.
    public static var authProvider: any AuthTokenProvider {
        get throws {
            shared.lock.lock()
            defer { shared.lock.unlock() }
            guard let provider = shared._authProvider else {
                throw DeepAgentsUIError.notConfigured
            }
            return provider
        }
    }

    /// The secure storage provider.
    /// - Throws: `DeepAgentsUIError.notConfigured` if the library hasn't been configured.
    public static var secureStorage: any SecureStorage {
        get throws {
            shared.lock.lock()
            defer { shared.lock.unlock() }
            guard let storage = shared._secureStorage else {
                throw DeepAgentsUIError.notConfigured
            }
            return storage
        }
    }

    /// The call token provider, if configured.
    public static var callTokenProvider: (any CallTokenProvider)? {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._callTokenProvider
    }

    /// Whether the library has been configured.
    public static var isConfigured: Bool {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._configuration != nil
    }

    /// Whether calling features are enabled.
    public static var isCallingEnabled: Bool {
        shared.lock.lock()
        defer { shared.lock.unlock() }
        return shared._callTokenProvider != nil && shared._configuration?.liveKitServerUrl != nil
    }

    // MARK: - Event Emission

    /// Emit an event to the event handler.
    /// This should be called from the main actor.
    @MainActor
    public static func emit(_ event: DeepAgentsEvent) {
        shared.lock.lock()
        let handler = shared._eventHandler
        shared.lock.unlock()

        handler?.handleEvent(event)
    }

    // MARK: - Standalone Config

    /// Save standalone configuration to UserDefaults.
    /// Used by the standalone DeepAgentsApp.
    public static func saveConfig(_ config: StandaloneConfig) {
        ConfigManager.shared.saveConfig(config)
    }

    // MARK: - LangGraph Client

    /// Create a LangGraphClient configured with the current settings.
    /// - Throws: `DeepAgentsUIError.notConfigured` if the library hasn't been configured.
    public static func createLangGraphClient() throws -> LangGraphClient {
        let config = try configuration
        return LangGraphClient(
            apiUrl: config.langGraphDeploymentUrl,
            apiKey: config.langGraphApiKey
        )
    }
}

// MARK: - Errors

public enum DeepAgentsUIError: Error, LocalizedError {
    case notConfigured

    public var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "DeepAgentsUI has not been configured. Call DeepAgentsUI.configure(...) during app initialization."
        }
    }
}
