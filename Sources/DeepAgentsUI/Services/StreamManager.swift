import Foundation
import SwiftyJSON

// MARK: - Stream Manager

@Observable
@MainActor
public final class StreamManager {
    // MARK: - Properties

    public private(set) var values: StateType = StateType()
    public private(set) var messages: [Message] = []
    public private(set) var isLoading: Bool = false
    public private(set) var isThreadLoading: Bool = false
    public private(set) var error: Error?
    public private(set) var interrupt: InterruptData?

    private let client: LangGraphClient
    private var currentTask: Task<Void, Never>?
    private var threadId: String?
    private var assistantId: String

    // MARK: - Callbacks

    public var onThreadIdChange: ((String?) -> Void)?
    public var onFinish: (() -> Void)?
    public var onError: ((Error) -> Void)?
    public var onCreated: (() -> Void)?

    // MARK: - Initialization

    public init(client: LangGraphClient, assistantId: String) {
        self.client = client
        self.assistantId = assistantId
    }

    // MARK: - Public Methods

    public func setThreadId(_ id: String?) {
        if threadId != id {
            threadId = id
            clear()
            if let id = id {
                Task {
                    await fetchThreadState(threadId: id)
                }
            }
        }
    }

    public func setAssistantId(_ id: String) {
        assistantId = id
    }

    public func submit(
        input: JSON?,
        optimisticValues: ((StateType) -> StateType)? = nil,
        config: JSON? = nil,
        command: JSON? = nil,
        checkpoint: Checkpoint? = nil,
        interruptBefore: [String]? = nil,
        interruptAfter: [String]? = nil
    ) {
        // Cancel any existing task
        stop()

        // Apply optimistic update if provided
        if let optimisticValues = optimisticValues {
            values = optimisticValues(values)
            messages = values.messages
        }

        currentTask = Task { [weak self] in
            guard let self = self else { return }

            await MainActor.run {
                self.isLoading = true
                self.error = nil
            }

            do {
                // Create thread if needed
                var currentThreadId = await MainActor.run { self.threadId }

                if currentThreadId == nil {
                    let thread = try await client.threads.create()
                    currentThreadId = thread["thread_id"].stringValue

                    await MainActor.run {
                        self.threadId = currentThreadId
                        self.onThreadIdChange?(currentThreadId)
                        self.onCreated?()
                    }
                }

                guard let threadId = currentThreadId else {
                    throw LangGraphError.streamError("Failed to obtain thread ID")
                }

                // Start streaming
                let stream = await client.runs.stream(
                    threadId: threadId,
                    assistantId: assistantId,
                    input: input,
                    config: config,
                    command: command,
                    checkpoint: checkpoint,
                    interruptBefore: interruptBefore,
                    interruptAfter: interruptAfter
                )

                for try await event in stream {
                    if Task.isCancelled { break }

                    await MainActor.run {
                        self.processEvent(event)
                    }
                }

                await MainActor.run {
                    self.isLoading = false
                    self.onFinish?()
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        self.error = error
                        self.isLoading = false
                        self.onError?(error)
                    }
                }
            }
        }
    }

    public func stop() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
    }

    public func clear() {
        stop()
        values = StateType()
        messages = []
        error = nil
        interrupt = nil
    }

    // MARK: - Private Methods

    private func fetchThreadState(threadId: String) async {
        isThreadLoading = true

        do {
            let states = try await client.threads.getHistory(threadId: threadId, limit: 10)

            if let latestState = states.first {
                let stateValues = latestState["values"]
                values = StateType(json: stateValues)
                messages = values.messages

                // Check for interrupt
                if let interruptArray = stateValues["__interrupt__"].array, !interruptArray.isEmpty {
                    interrupt = InterruptData(json: interruptArray[0])
                }
            }
        } catch {
            self.error = error
            onError?(error)
        }

        isThreadLoading = false
    }

    private func processEvent(_ event: StreamEvent) {
        switch event.type {
        case .values:
            let newValues = StateType(json: event.data)
            values = newValues
            messages = newValues.messages

            // Check for interrupt in values
            if let interruptArray = event.data["__interrupt__"].array, !interruptArray.isEmpty {
                interrupt = InterruptData(json: interruptArray[0])
            } else {
                interrupt = nil
            }

        case .updates:
            // Apply incremental updates
            if let newMessages = event.data["messages"].array {
                for msgJson in newMessages {
                    let msg = Message(json: msgJson)
                    if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                        messages[idx] = msg
                    } else {
                        messages.append(msg)
                    }
                }
                values.messages = messages
            }

            if let newTodos = event.data["todos"].array {
                values.todos = newTodos.map { TodoItem(json: $0) }
            }

            if let newFiles = event.data["files"].dictionary {
                values.files = newFiles.mapValues { $0.stringValue }
            }

        case .messages, .messagesTuple:
            // Handle message updates
            if let msgArray = event.data.array {
                for msgJson in msgArray {
                    let msg = Message(json: msgJson)
                    if let idx = messages.firstIndex(where: { $0.id == msg.id }) {
                        messages[idx] = msg
                    } else {
                        messages.append(msg)
                    }
                }
                values.messages = messages
            }

        case .custom:
            // Handle custom events (e.g., UI updates)
            if let ui = event.data["ui"].exists() ? event.data["ui"] : nil {
                values.ui = ui
            }

        case .error:
            let errorMessage = event.data["message"].string ?? "Unknown error"
            error = LangGraphError.streamError(errorMessage)

        case .end:
            // Stream ended
            break
        }
    }
}

// MARK: - Submit Options

public struct SubmitOptions {
    public var optimisticValues: ((StateType) -> StateType)?
    public var config: JSON?
    public var command: JSON?
    public var checkpoint: Checkpoint?
    public var interruptBefore: [String]?
    public var interruptAfter: [String]?
    public var threadId: String?
    public var metadata: [String: Any]?

    public init(
        optimisticValues: ((StateType) -> StateType)? = nil,
        config: JSON? = nil,
        command: JSON? = nil,
        checkpoint: Checkpoint? = nil,
        interruptBefore: [String]? = nil,
        interruptAfter: [String]? = nil,
        threadId: String? = nil,
        metadata: [String: Any]? = nil
    ) {
        self.optimisticValues = optimisticValues
        self.config = config
        self.command = command
        self.checkpoint = checkpoint
        self.interruptBefore = interruptBefore
        self.interruptAfter = interruptAfter
        self.threadId = threadId
        self.metadata = metadata
    }
}
