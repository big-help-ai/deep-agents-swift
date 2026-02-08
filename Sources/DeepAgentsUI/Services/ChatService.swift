import Foundation
import SwiftyJSON

// MARK: - Chat Service

@Observable
@MainActor
public final class ChatService {
    // MARK: - Properties

    @ObservationIgnored
    private var _streamManager: StreamManager

    @ObservationIgnored
    public private(set) var client: LangGraphClient

    // Stored properties that mirror StreamManager state for proper observation
    public private(set) var messages: [Message] = []
    public private(set) var todos: [TodoItem] = []
    public private(set) var files: [String: String] = [:]
    public private(set) var email: JSON?
    public private(set) var ui: JSON?
    public private(set) var isLoading: Bool = false
    public private(set) var isThreadLoading: Bool = false
    public private(set) var interrupt: InterruptData?
    public private(set) var error: Error?

    public var threadId: String?
    public var assistant: Assistant?

    public var streamManager: StreamManager { _streamManager }

    // MARK: - Callbacks

    public var onHistoryRevalidate: (() -> Void)?

    // MARK: - Sync Timer

    @ObservationIgnored
    private var syncTimer: Timer?

    // MARK: - Initialization

    public init(deploymentUrl: String, apiKey: String?, assistantId: String) {
        let langGraphClient = LangGraphClient(apiUrl: deploymentUrl, apiKey: apiKey)
        self.client = langGraphClient
        self._streamManager = StreamManager(client: langGraphClient, assistantId: assistantId)

        setupCallbacks()
        startSyncTimer()
    }

    deinit {
        syncTimer?.invalidate()
    }

    private func setupCallbacks() {
        _streamManager.onThreadIdChange = { [weak self] id in
            self?.threadId = id
        }

        _streamManager.onFinish = { [weak self] in
            self?.syncFromStreamManager()
            self?.onHistoryRevalidate?()
        }

        _streamManager.onError = { [weak self] _ in
            self?.syncFromStreamManager()
            self?.onHistoryRevalidate?()
        }

        _streamManager.onCreated = { [weak self] in
            self?.syncFromStreamManager()
            self?.onHistoryRevalidate?()
        }

        // Sync immediately when StreamManager state changes
        _streamManager.onStateChange = { [weak self] in
            self?.syncFromStreamManager()
        }
    }

    /// Start a timer to sync state from StreamManager
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.syncFromStreamManager()
            }
        }
    }

    /// Sync stored properties from StreamManager for proper observation
    private func syncFromStreamManager() {
        // Sync messages - only update when count or IDs change, not on content changes
        // This avoids re-rendering during streaming (content updates don't trigger re-render)
        // The final .values event will sync the complete messages at the end
        let streamMessages = _streamManager.messages
        let needsUpdate = messages.count != streamMessages.count ||
           !messages.elementsEqual(streamMessages, by: { $0.id == $1.id })

        if needsUpdate {
            messages = streamMessages
        }

        let streamTodos = _streamManager.values.todos
        if todos.count != streamTodos.count {
            todos = streamTodos
        }

        if files != _streamManager.values.files {
            files = _streamManager.values.files
        }

        email = _streamManager.values.email
        ui = _streamManager.values.ui

        if isLoading != _streamManager.isLoading {
            isLoading = _streamManager.isLoading
        }
        if isThreadLoading != _streamManager.isThreadLoading {
            isThreadLoading = _streamManager.isThreadLoading
        }

        interrupt = _streamManager.interrupt
        error = _streamManager.error
    }

    // MARK: - Configuration

    public func configure(deploymentUrl: String, apiKey: String?, assistantId: String) {
        client = LangGraphClient(apiUrl: deploymentUrl, apiKey: apiKey)
        _streamManager = StreamManager(client: client, assistantId: assistantId)
        setupCallbacks()
    }

    public func setThreadId(_ id: String?) {
        threadId = id
        _streamManager.setThreadId(id)
        syncFromStreamManager()
    }

    public func setAssistant(_ assistant: Assistant?) {
        self.assistant = assistant
        if let assistantId = assistant?.assistantId {
            _streamManager.setAssistantId(assistantId)
        }
    }

    // MARK: - Message Operations

    public func sendMessage(_ content: String) {
        let newMessage = Message(
            id: UUID().uuidString,
            type: .human,
            content: JSON(content)
        )

        let input = JSON([
            "messages": [
                [
                    "id": newMessage.id,
                    "type": "human",
                    "content": content
                ]
            ]
        ])

        var config = assistant?.config ?? JSON([:])
        config["recursion_limit"] = 100

        _streamManager.submit(
            input: input,
            optimisticValues: { prev in
                var updated = prev
                updated.messages.append(newMessage)
                return updated
            },
            config: config
        )

        // Sync immediately after submitting
        syncFromStreamManager()
        onHistoryRevalidate?()
    }

    public func runSingleStep(
        messages: [Message],
        checkpoint: Checkpoint? = nil,
        isRerunningSubagent: Bool = false,
        optimisticMessages: [Message]? = nil
    ) {
        let config = assistant?.config

        if let checkpoint = checkpoint {
            _streamManager.submit(
                input: nil,
                optimisticValues: optimisticMessages != nil ? { prev in
                    var updated = prev
                    updated.messages = optimisticMessages!
                    return updated
                } : nil,
                config: config,
                checkpoint: checkpoint,
                interruptBefore: isRerunningSubagent ? nil : ["tools"],
                interruptAfter: isRerunningSubagent ? ["tools"] : nil
            )
        } else {
            let input = JSON([
                "messages": messages.map { msg in
                    [
                        "id": msg.id,
                        "type": msg.type.rawValue,
                        "content": msg.content.object
                    ] as [String: Any]
                }
            ])

            _streamManager.submit(
                input: input,
                config: config,
                interruptBefore: ["tools"]
            )
        }
        syncFromStreamManager()
    }

    public func continueStream(hasTaskToolCall: Bool = false) {
        var config = assistant?.config ?? JSON([:])
        config["recursion_limit"] = 100

        _streamManager.submit(
            input: nil,
            config: config,
            interruptBefore: hasTaskToolCall ? nil : ["tools"],
            interruptAfter: hasTaskToolCall ? ["tools"] : nil
        )

        syncFromStreamManager()
        onHistoryRevalidate?()
    }

    public func stopStream() {
        _streamManager.stop()
        syncFromStreamManager()
    }

    public func resumeInterrupt(value: JSON) {
        let command = JSON([
            "resume": value.object
        ])

        _streamManager.submit(
            input: nil,
            command: command
        )

        syncFromStreamManager()
        onHistoryRevalidate?()
    }

    public func markCurrentThreadAsResolved() {
        let command = JSON([
            "goto": "__end__",
            "update": NSNull()
        ])

        _streamManager.submit(
            input: nil,
            command: command
        )

        syncFromStreamManager()
        onHistoryRevalidate?()
    }

    // MARK: - File Operations

    public func setFiles(_ files: [String: String]) async {
        guard let threadId = threadId else { return }

        do {
            _ = try await client.threads.updateState(
                threadId: threadId,
                values: JSON(["files": files])
            )
        } catch {
            print("Failed to update files: \(error)")
        }
    }

    // MARK: - Assistant Operations

    public func fetchAssistant(assistantId: String) async {
        let isUUID = isValidUUID(assistantId)

        if isUUID {
            do {
                let fetchedAssistant = try await client.assistants.get(assistantId: assistantId)
                assistant = fetchedAssistant
            } catch {
                // Create a fallback assistant
                assistant = Assistant(
                    id: assistantId,
                    graphId: assistantId,
                    name: "Assistant",
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        } else {
            do {
                let assistants = try await client.assistants.search(
                    graphId: assistantId,
                    limit: 100
                )

                let defaultAssistant = assistants.first { assistant in
                    assistant.metadata["created_by"].string == "system"
                }

                if let defaultAssistant = defaultAssistant {
                    assistant = defaultAssistant
                } else {
                    // Create a fallback assistant
                    assistant = Assistant(
                        id: assistantId,
                        graphId: assistantId,
                        name: assistantId,
                        createdAt: Date(),
                        updatedAt: Date()
                    )
                }
            } catch {
                // Create a fallback assistant
                assistant = Assistant(
                    id: assistantId,
                    graphId: assistantId,
                    name: assistantId,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        }

        if let assistant = assistant {
            _streamManager.setAssistantId(assistant.assistantId)
        }
    }
}
