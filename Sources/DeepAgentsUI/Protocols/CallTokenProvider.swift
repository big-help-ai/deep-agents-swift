import Foundation

/// Protocol for fetching LiveKit room tokens.
/// Implement this in your app to provide tokens from your backend.
public protocol CallTokenProvider: Sendable {
    /// Fetch a room token for connecting to a LiveKit room.
    /// - Parameters:
    ///   - roomName: The name of the room to join
    ///   - graphName: The name of the LangGraph graph to use for the call
    /// - Returns: A LiveKit access token for the room
    func fetchRoomToken(roomName: String, graphName: String) async throws -> String
}
