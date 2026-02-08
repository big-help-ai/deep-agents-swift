import Foundation
import SwiftyJSON
import Combine

/// Main view model for managing threads.
@MainActor
@Observable
public final class ThreadsViewModel {
    // MARK: - Properties

    public var loading = false
    public var threadData: [ThreadData] = []
    public var hasMoreThreads = true
    public var selectedThreadId: String?
    public var selectedInbox: ThreadStatus = .interrupted
    public var offset = 0
    public var limit = 10
    public var errorMessage: String?

    // MARK: - Dependencies

    public private(set) var inboxesManager: InboxManager

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    public init(inboxesManager: InboxManager) {
        self.inboxesManager = inboxesManager
    }

    /// Update the inboxes manager.
    public func updateInboxManager(_ manager: InboxManager) {
        self.inboxesManager = manager
        cancellables.removeAll()
    }

    // MARK: - Thread Fetching

    /// Fetch threads from the API.
    public func fetchThreads() async {
        guard let client = try? inboxesManager.createClient() else {
            errorMessage = "No inbox selected or API key required"
            return
        }

        guard let inbox = inboxesManager.selectedInbox else {
            return
        }

        loading = true
        errorMessage = nil

        do {
            // Build metadata filter
            let metadata = getThreadFilterMetadata(for: inbox)

            // Fetch threads
            let status = selectedInbox != .all ? selectedInbox : nil
            let threads = try await client.threads.search(
                limit: limit,
                offset: offset,
                status: status,
                metadata: metadata
            )

            // Process threads
            var processedData: [ThreadData] = []

            for threadJSON in threads {
                let thread = InboxThread(json: threadJSON)
                let threadData = await processThread(thread, client: client)
                processedData.append(threadData)
            }

            // Sort by creation date (newest first)
            processedData.sort { $0.thread.createdAt > $1.thread.createdAt }

            self.threadData = processedData
            self.hasMoreThreads = threads.count == limit

        } catch {
            print("Failed to fetch threads: \(error)")
            errorMessage = error.localizedDescription
        }

        loading = false
    }

    /// Process a single thread to extract interrupt data.
    private func processThread(_ thread: InboxThread, client: LangGraphClient) async -> ThreadData {
        // Handle special status for human_response_needed inbox
        if selectedInbox == .humanResponseNeeded && thread.status != .interrupted {
            return ThreadData(
                thread: thread,
                status: .humanResponseNeeded,
                interrupts: nil,
                invalidSchema: false
            )
        }

        // Handle interrupted threads
        if thread.status == .interrupted {
            // Try to get interrupts from thread data first
            if let interrupts = getInterruptsFromThread(thread), !interrupts.isEmpty {
                let hasInvalidSchema = interrupts.contains {
                    $0.actionRequest.action == InboxConstants.improperSchema || $0.actionRequest.action.isEmpty
                }
                return ThreadData(
                    thread: thread,
                    status: .interrupted,
                    interrupts: interrupts,
                    invalidSchema: hasInvalidSchema
                )
            }

            // If no interrupts found, try fetching state
            do {
                let stateJSON = try await client.threads.getState(threadId: thread.threadId)
                let state = InboxThreadState(json: stateJSON)
                if let lastTask = state.tasks.last,
                   let lastInterrupt = lastTask.interrupts.last {
                    let interrupts = parseInterruptValue(lastInterrupt.value)
                    return ThreadData(
                        thread: thread,
                        status: .interrupted,
                        interrupts: interrupts,
                        invalidSchema: interrupts == nil
                    )
                }
            } catch {
                print("Failed to get thread state: \(error)")
            }

            // Fallback: interrupted with invalid schema
            return ThreadData(
                thread: thread,
                status: .interrupted,
                interrupts: nil,
                invalidSchema: true
            )
        }

        // Non-interrupted thread
        return ThreadData(
            thread: thread,
            status: thread.status,
            interrupts: nil,
            invalidSchema: false
        )
    }

    /// Fetch a single thread by ID.
    public func fetchSingleThread(threadId: String) async -> ThreadData? {
        guard let client = try? inboxesManager.createClient() else {
            return nil
        }

        do {
            let threadJSON = try await client.threads.get(threadId: threadId)
            let thread = InboxThread(json: threadJSON)
            return await processThread(thread, client: client)
        } catch {
            print("Failed to fetch thread \(threadId): \(error)")
            return nil
        }
    }

    // MARK: - Thread Actions

    /// Ignore a thread (mark as resolved).
    public func ignoreThread(threadId: String) async throws {
        guard let client = try? inboxesManager.createClient() else {
            throw InboxManager.InboxError.noInboxSelected
        }

        _ = try await client.threads.updateState(
            threadId: threadId,
            values: JSON.null,
            asNode: "__end__"
        )

        // Remove from local state
        threadData.removeAll { $0.thread.threadId == threadId }
    }

    /// Send a human response to a thread.
    public func sendHumanResponse(
        threadId: String,
        responses: [HumanResponse]
    ) async throws -> Run {
        guard let client = try? inboxesManager.createClient(),
              let inbox = inboxesManager.selectedInbox else {
            throw InboxManager.InboxError.noInboxSelected
        }

        let command: [String: Any] = [
            "resume": responses.map { $0.toJSON().object }
        ]

        return try await client.runs.create(
            threadId: threadId,
            assistantId: inbox.graphId,
            command: command
        )
    }

    /// Send a human response with streaming.
    public func sendHumanResponseStreaming(
        threadId: String,
        responses: [HumanResponse],
        onNode: @escaping (String) -> Void,
        onError: @escaping (Error) -> Void,
        onComplete: @escaping () -> Void
    ) async {
        guard let client = try? inboxesManager.createClient(),
              let inbox = inboxesManager.selectedInbox else {
            onError(InboxManager.InboxError.noInboxSelected)
            return
        }

        let command: [String: Any] = [
            "resume": responses.map { $0.toJSON().object }
        ]

        do {
            let stream = await client.runs.stream(
                threadId: threadId,
                assistantId: inbox.graphId,
                command: JSON(command)
            )

            for try await event in stream {
                if event.type == .error {
                    onError(LangGraphError.streamError(event.data.rawString() ?? "Unknown error"))
                    return
                }

                // Check for chain start event with node info
                if event.data["event"].stringValue == "on_chain_start",
                   let node = event.data["metadata"]["langgraph_node"].string {
                    onNode(node)
                }
            }

            onComplete()
        } catch {
            onError(error)
        }
    }

    // MARK: - Pagination

    /// Go to next page.
    public func nextPage() async {
        offset += limit
        await fetchThreads()
    }

    /// Go to previous page.
    public func previousPage() async {
        offset = max(0, offset - limit)
        await fetchThreads()
    }

    /// Reset to first page.
    public func resetPagination() {
        offset = 0
    }

    // MARK: - Inbox Selection

    /// Change the selected inbox filter.
    public func selectInbox(_ inbox: ThreadStatus) async {
        selectedInbox = inbox
        offset = 0
        await fetchThreads()
    }

    /// Clear thread data.
    public func clearThreadData() {
        threadData = []
    }
}
