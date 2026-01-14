import Foundation
import SwiftyJSON

// MARK: - Chat Service

@Observable
@MainActor
public final class ChatService {
    // MARK: - Properties

    public private(set) var streamManager: StreamManager
    public private(set) var client: LangGraphClient

    public var messages: [Message] { streamManager.messages }
    public var todos: [TodoItem] { streamManager.values.todos }
    public var files: [String: String] { streamManager.values.files }
    public var email: JSON? { streamManager.values.email }
    public var ui: JSON? { streamManager.values.ui }
    public var isLoading: Bool { streamManager.isLoading }
    public var isThreadLoading: Bool { streamManager.isThreadLoading }
    public var interrupt: InterruptData? { streamManager.interrupt }
    public var error: Error? { streamManager.error }

    public var threadId: String?
    public var assistant: Assistant?

    // MARK: - Callbacks

    public var onHistoryRevalidate: (() -> Void)?

    // MARK: - Initialization

    public init(deploymentUrl: String, apiKey: String?, assistantId: String) {
        self.client = LangGraphClient(apiUrl: deploymentUrl, apiKey: apiKey)
        self.streamManager = StreamManager(client: client, assistantId: assistantId)

        setupCallbacks()
    }

    private func setupCallbacks() {
        streamManager.onThreadIdChange = { [weak self] id in
            self?.threadId = id
        }

        streamManager.onFinish = { [weak self] in
            self?.onHistoryRevalidate?()
        }

        streamManager.onError = { [weak self] _ in
            self?.onHistoryRevalidate?()
        }

        streamManager.onCreated = { [weak self] in
            self?.onHistoryRevalidate?()
        }
    }

    // MARK: - Configuration

    public func configure(deploymentUrl: String, apiKey: String?, assistantId: String) {
        client = LangGraphClient(apiUrl: deploymentUrl, apiKey: apiKey)
        streamManager = StreamManager(client: client, assistantId: assistantId)
        setupCallbacks()
    }

    public func setThreadId(_ id: String?) {
        threadId = id
        streamManager.setThreadId(id)
    }

    public func setAssistant(_ assistant: Assistant?) {
        self.assistant = assistant
        if let assistantId = assistant?.assistantId {
            streamManager.setAssistantId(assistantId)
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

        streamManager.submit(
            input: input,
            optimisticValues: { prev in
                var updated = prev
                updated.messages.append(newMessage)
                return updated
            },
            config: config
        )

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
            streamManager.submit(
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

            streamManager.submit(
                input: input,
                config: config,
                interruptBefore: ["tools"]
            )
        }
    }

    public func continueStream(hasTaskToolCall: Bool = false) {
        var config = assistant?.config ?? JSON([:])
        config["recursion_limit"] = 100

        streamManager.submit(
            input: nil,
            config: config,
            interruptBefore: hasTaskToolCall ? nil : ["tools"],
            interruptAfter: hasTaskToolCall ? ["tools"] : nil
        )

        onHistoryRevalidate?()
    }

    public func stopStream() {
        streamManager.stop()
    }

    public func resumeInterrupt(value: JSON) {
        let command = JSON([
            "resume": value.object
        ])

        streamManager.submit(
            input: nil,
            command: command
        )

        onHistoryRevalidate?()
    }

    public func markCurrentThreadAsResolved() {
        let command = JSON([
            "goto": "__end__",
            "update": NSNull()
        ])

        streamManager.submit(
            input: nil,
            command: command
        )

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
            streamManager.setAssistantId(assistant.assistantId)
        }
    }
}
