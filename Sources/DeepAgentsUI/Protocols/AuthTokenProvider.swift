import Foundation

/// Protocol for providing authentication tokens for API requests.
/// Implement this in your app to integrate with your auth system (e.g., AllAuth).
public protocol AuthTokenProvider: Sendable {
    /// Returns the current session token, or nil if not authenticated.
    var sessionToken: String? { get async }

    /// Performs an authenticated HTTP request.
    /// - Parameters:
    ///   - method: HTTP method (GET, POST, etc.)
    ///   - url: The full URL to request
    ///   - data: Optional request body as dictionary
    /// - Returns: Response data
    func authenticatedRequest(method: String, url: String, data: [String: Any]?) async throws -> Data
}
