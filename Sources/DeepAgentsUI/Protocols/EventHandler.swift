import Foundation

/// Events emitted by DeepAgentsUI that the consuming app should handle.
/// These enable the library to request navigation and notify about call events
/// without having direct access to the app's navigation system.
public enum DeepAgentsEvent: Sendable {
    /// Request navigation to a specific thread.
    /// The app should present the thread detail view.
    case navigateToThread(threadId: String)

    /// Request navigation to the inbox.
    /// The app should switch to or present the inbox view.
    case navigateToInbox

    /// An incoming call was received.
    /// The app should handle the incoming call UI/notification.
    case incomingCall(callerId: String, callerName: String)

    /// The VoIP push token was updated.
    /// The app should send this token to the backend for push notifications.
    case voipTokenUpdated(token: String)

    /// A call was started successfully.
    case callStarted(roomName: String)

    /// A call was ended.
    case callEnded(roomName: String)

    /// An error occurred.
    case error(message: String)
}

/// Protocol for handling events from DeepAgentsUI.
/// Implement this in your app to respond to navigation requests and call events.
public protocol DeepAgentsEventHandler: AnyObject, Sendable {
    /// Handle an event from DeepAgentsUI.
    /// This method is called on the main actor.
    @MainActor
    func handleEvent(_ event: DeepAgentsEvent)
}
