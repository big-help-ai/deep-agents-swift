import Foundation

// MARK: - Standalone Config

public struct StandaloneConfig: Codable, Sendable {
    public var deploymentUrl: String
    public var assistantId: String
    public var langsmithApiKey: String?

    public init(deploymentUrl: String, assistantId: String, langsmithApiKey: String? = nil) {
        self.deploymentUrl = deploymentUrl
        self.assistantId = assistantId
        self.langsmithApiKey = langsmithApiKey
    }
}

// MARK: - Config Manager

public final class ConfigManager: @unchecked Sendable {
    public static let shared = ConfigManager()

    private let configKey = "deep-agent-config"
    private let defaults = UserDefaults.standard

    private init() {}

    public func getConfig() -> StandaloneConfig? {
        guard let data = defaults.data(forKey: configKey) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(StandaloneConfig.self, from: data)
        } catch {
            return nil
        }
    }

    public func saveConfig(_ config: StandaloneConfig) {
        do {
            let data = try JSONEncoder().encode(config)
            defaults.set(data, forKey: configKey)
        } catch {
            print("Failed to save config: \(error)")
        }
    }

    public func clearConfig() {
        defaults.removeObject(forKey: configKey)
    }
}

// MARK: - Convenience functions

public func getConfig() -> StandaloneConfig? {
    ConfigManager.shared.getConfig()
}

public func saveConfig(_ config: StandaloneConfig) {
    ConfigManager.shared.saveConfig(config)
}
