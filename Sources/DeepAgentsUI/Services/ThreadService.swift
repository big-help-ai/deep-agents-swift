import Foundation
import SwiftyJSON

// MARK: - Thread Service

@Observable
@MainActor
public final class ThreadService {
    // MARK: - Properties

    public private(set) var threads: [ThreadItem] = []
    public private(set) var isLoading: Bool = false
    public private(set) var error: Error?
    public private(set) var hasMore: Bool = true

    private var client: LangGraphClient?
    private let pageSize: Int
    private var currentPage: Int = 0
    private var statusFilter: ThreadStatus?
    private var assistantId: String?

    // MARK: - Initialization

    public init(pageSize: Int = 20) {
        self.pageSize = pageSize
    }

    // MARK: - Configuration

    public func configure(deploymentUrl: String, apiKey: String?, assistantId: String) {
        self.client = LangGraphClient(apiUrl: deploymentUrl, apiKey: apiKey)
        self.assistantId = assistantId
        reset()
    }

    // MARK: - Filtering

    public func setStatusFilter(_ status: ThreadStatus?) {
        statusFilter = status
        reset()
        Task {
            await loadMore()
        }
    }

    // MARK: - Loading

    public func reset() {
        threads = []
        currentPage = 0
        hasMore = true
        error = nil
    }

    public func refresh() async {
        reset()
        await loadMore()
    }

    public func loadMore() async {
        guard !isLoading, hasMore, let client = client else { return }

        isLoading = true
        error = nil

        do {
            let isUUID = assistantId.map { isValidUUID($0) } ?? false

            var metadata: [String: String]? = nil
            if isUUID, let assistantId = assistantId {
                metadata = ["assistant_id": assistantId]
            }

            let results = try await client.threads.search(
                limit: pageSize,
                offset: currentPage * pageSize,
                status: statusFilter,
                metadata: metadata
            )

            let newThreads = results.map { threadJson -> ThreadItem in
                parseThreadItem(threadJson, assistantId: assistantId)
            }

            if newThreads.count < pageSize {
                hasMore = false
            }

            threads.append(contentsOf: newThreads)
            currentPage += 1
        } catch {
            self.error = error
        }

        isLoading = false
    }

    // MARK: - Thread Parsing

    private func parseThreadItem(_ json: JSON, assistantId: String?) -> ThreadItem {
        var title = "Untitled Thread"
        var description = ""

        // Try to extract title from first human message
        if let messages = json["values"]["messages"].array {
            if let firstHumanMessage = messages.first(where: { $0["type"].stringValue == "human" }) {
                let content: String
                if let str = firstHumanMessage["content"].string {
                    content = str
                } else if let textBlock = firstHumanMessage["content"].array?.first(where: { $0["type"].stringValue == "text" }) {
                    content = textBlock["text"].stringValue
                } else {
                    content = ""
                }

                if !content.isEmpty {
                    title = String(content.prefix(50))
                    if content.count > 50 {
                        title += "..."
                    }
                }
            }

            // Try to extract description from first AI message
            if let firstAIMessage = messages.first(where: { $0["type"].stringValue == "ai" }) {
                let content: String
                if let str = firstAIMessage["content"].string {
                    content = str
                } else if let textBlock = firstAIMessage["content"].array?.first(where: { $0["type"].stringValue == "text" }) {
                    content = textBlock["text"].stringValue
                } else {
                    content = ""
                }

                description = String(content.prefix(100))
            }
        }

        // Fallback title
        if title == "Untitled Thread" {
            let threadId = json["thread_id"].stringValue
            if !threadId.isEmpty {
                title = "Thread \(String(threadId.prefix(8)))"
            }
        }

        return ThreadItem(
            id: json["thread_id"].stringValue,
            updatedAt: ISO8601DateFormatter().date(from: json["updated_at"].stringValue) ?? Date(),
            status: ThreadStatus(rawValue: json["status"].stringValue) ?? .idle,
            title: title,
            description: description,
            assistantId: assistantId
        )
    }

    // MARK: - Grouping

    public var groupedThreads: [(String, [ThreadItem])] {
        let calendar = Calendar.current
        let now = Date()

        var groups: [String: [ThreadItem]] = [
            "Requiring Attention": [],
            "Today": [],
            "Yesterday": [],
            "This Week": [],
            "Older": []
        ]

        for thread in threads {
            // Interrupted threads go to "Requiring Attention"
            if thread.status == .interrupted {
                groups["Requiring Attention"]?.append(thread)
                continue
            }

            if calendar.isDateInToday(thread.updatedAt) {
                groups["Today"]?.append(thread)
            } else if calendar.isDateInYesterday(thread.updatedAt) {
                groups["Yesterday"]?.append(thread)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      thread.updatedAt > weekAgo {
                groups["This Week"]?.append(thread)
            } else {
                groups["Older"]?.append(thread)
            }
        }

        // Return in order, filtering out empty groups
        let order = ["Requiring Attention", "Today", "Yesterday", "This Week", "Older"]
        return order.compactMap { key -> (String, [ThreadItem])? in
            guard let items = groups[key], !items.isEmpty else { return nil }
            return (key, items)
        }
    }

    // MARK: - Interrupt Count

    public var interruptCount: Int {
        threads.filter { $0.status == .interrupted }.count
    }
}
