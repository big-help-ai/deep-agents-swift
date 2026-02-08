import Foundation

/// Protocol for secure storage of sensitive data (e.g., API keys, tokens).
/// Implement this in your app using Keychain or another secure storage mechanism.
public protocol SecureStorage: Sendable {
    /// Save a value to secure storage.
    /// - Parameters:
    ///   - key: The key to store the value under
    ///   - value: The value to store
    func save(key: String, value: String) throws

    /// Read a value from secure storage.
    /// - Parameter key: The key to read
    /// - Returns: The stored value, or nil if not found
    func read(key: String) -> String?

    /// Delete a value from secure storage.
    /// - Parameter key: The key to delete
    func delete(key: String)
}
