import Foundation
import SwiftyJSON

// MARK: - LangGraph Client

public actor LangGraphClient {
    private let apiUrl: String
    private let apiKey: String?
    private let session: URLSession

    public init(apiUrl: String, apiKey: String? = nil) {
        self.apiUrl = apiUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        self.apiKey = apiKey

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
    }

    // MARK: - Request Building

    private func authProviderToken() async -> String? {
        guard apiKey == nil || apiKey?.isEmpty == true else {
            return nil
        }
        guard let authProvider = try? DeepAgentsUI.authProvider else {
            return nil
        }
        guard let token = await authProvider.sessionToken, !token.isEmpty else {
            return nil
        }
        return token
    }

    private func buildRequest(
        path: String,
        method: String = "GET",
        body: JSON? = nil,
        queryParams: [String: String]? = nil
    ) async -> URLRequest {
        var urlComponents = URLComponents(string: "\(apiUrl)\(path)")!

        if let queryParams = queryParams {
            urlComponents.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
        } else if let token = await authProviderToken() {
            if token.lowercased().hasPrefix("bearer ") {
                request.setValue(token, forHTTPHeaderField: "Authorization")
            } else {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }

        if let body = body {
            request.httpBody = try? body.rawData()
        }

        return request
    }

    private func performRequest(_ request: URLRequest) async throws -> JSON {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LangGraphError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LangGraphError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }

        return try JSON(data: data)
    }

    // MARK: - Threads API

    public var threads: ThreadsAPI {
        ThreadsAPI(client: self)
    }

    public struct ThreadsAPI: Sendable {
        let client: LangGraphClient

        public func search(
            limit: Int = 20,
            offset: Int = 0,
            status: ThreadStatus? = nil,
            metadata: [String: String]? = nil,
            sortBy: String = "updated_at",
            sortOrder: String = "desc"
        ) async throws -> [JSON] {
            var body: [String: Any] = [
                "limit": limit,
                "offset": offset,
                "sort_by": sortBy,
                "sort_order": sortOrder
            ]

            // Don't include status filter when .all is specified (returns all threads)
            if let status = status, status != .all {
                body["status"] = status.rawValue
            }

            if let metadata = metadata {
                body["metadata"] = metadata
            }

            let request = await client.buildRequest(
                path: "/threads/search",
                method: "POST",
                body: JSON(body)
            )

            let result = try await client.performRequest(request)
            return result.arrayValue
        }

        public func create(
            threadId: String? = nil,
            metadata: [String: Any]? = nil
        ) async throws -> JSON {
            var body: [String: Any] = [:]

            if let threadId = threadId {
                body["thread_id"] = threadId
            }

            if let metadata = metadata {
                body["metadata"] = metadata
            }

            let request = await client.buildRequest(
                path: "/threads",
                method: "POST",
                body: JSON(body)
            )

            return try await client.performRequest(request)
        }

        public func get(threadId: String) async throws -> JSON {
            let request = await client.buildRequest(
                path: "/threads/\(threadId)"
            )

            return try await client.performRequest(request)
        }

        public func getState(threadId: String) async throws -> JSON {
            let request = await client.buildRequest(
                path: "/threads/\(threadId)/state"
            )

            return try await client.performRequest(request)
        }

        public func getHistory(threadId: String, limit: Int = 10) async throws -> [JSON] {
            let request = await client.buildRequest(
                path: "/threads/\(threadId)/history",
                queryParams: ["limit": String(limit)]
            )

            let result = try await client.performRequest(request)
            return result.arrayValue
        }

        public func updateState(
            threadId: String,
            values: JSON,
            asNode: String? = nil
        ) async throws -> JSON {
            var body: [String: Any] = [
                "values": values.object
            ]

            if let asNode = asNode {
                body["as_node"] = asNode
            }

            let request = await client.buildRequest(
                path: "/threads/\(threadId)/state",
                method: "POST",
                body: JSON(body)
            )

            return try await client.performRequest(request)
        }
    }

    // MARK: - Assistants API

    public var assistants: AssistantsAPI {
        AssistantsAPI(client: self)
    }

    public struct AssistantsAPI: Sendable {
        let client: LangGraphClient

        public func get(assistantId: String) async throws -> Assistant {
            let request = await client.buildRequest(
                path: "/assistants/\(assistantId)"
            )

            let result = try await client.performRequest(request)
            return Assistant(json: result)
        }

        public func search(
            graphId: String? = nil,
            limit: Int = 100,
            offset: Int = 0,
            metadata: [String: String]? = nil
        ) async throws -> [Assistant] {
            var body: [String: Any] = [
                "limit": limit,
                "offset": offset
            ]

            if let graphId = graphId {
                body["graph_id"] = graphId
            }

            if let metadata = metadata {
                body["metadata"] = metadata
            }

            let request = await client.buildRequest(
                path: "/assistants/search",
                method: "POST",
                body: JSON(body)
            )

            let result = try await client.performRequest(request)
            return result.arrayValue.map { Assistant(json: $0) }
        }
    }

    // MARK: - Runs API

    public var runs: RunsAPI {
        RunsAPI(client: self)
    }

    public struct RunsAPI: Sendable {
        let client: LangGraphClient

        public func stream(
            threadId: String,
            assistantId: String,
            input: JSON? = nil,
            config: JSON? = nil,
            command: JSON? = nil,
            checkpoint: Checkpoint? = nil,
            interruptBefore: [String]? = nil,
            interruptAfter: [String]? = nil,
            streamMode: [String] = ["values", "messages-tuple"],
            metadata: [String: Any]? = nil,
            multitaskStrategy: String? = nil,
            onDisconnect: String = "cancel"
        ) -> AsyncThrowingStream<StreamEvent, Error> {
            AsyncThrowingStream { continuation in
                Task {
                    do {
                        var body: [String: Any] = [
                            "assistant_id": assistantId,
                            "stream_mode": streamMode,
                            "on_disconnect": onDisconnect
                        ]

                        if let input = input {
                            body["input"] = input.object
                        }

                        if let config = config {
                            body["config"] = config.object
                        }

                        if let command = command {
                            body["command"] = command.object
                        }

                        if let checkpoint = checkpoint {
                            body["checkpoint"] = [
                                "checkpoint_id": checkpoint.checkpointId
                            ]
                        }

                        if let interruptBefore = interruptBefore {
                            body["interrupt_before"] = interruptBefore
                        }

                        if let interruptAfter = interruptAfter {
                            body["interrupt_after"] = interruptAfter
                        }

                        if let metadata = metadata {
                            body["metadata"] = metadata
                        }

                        if let multitaskStrategy = multitaskStrategy {
                            body["multitask_strategy"] = multitaskStrategy
                        }

                        let request = await client.buildRequest(
                            path: "/threads/\(threadId)/runs/stream",
                            method: "POST",
                            body: JSON(body)
                        )

                        let (bytes, response) = try await client.session.bytes(for: request)

                        guard let httpResponse = response as? HTTPURLResponse else {
                            throw LangGraphError.streamError("Invalid response - not HTTP")
                        }


                        guard (200...299).contains(httpResponse.statusCode) else {
                            throw LangGraphError.streamError("HTTP error: \(httpResponse.statusCode)")
                        }

                        var lineBuffer = Data()
                        var eventLines: [String] = []
                        var lastWasCR = false

                        for try await byte in bytes {
                            // Handle \r\n sequences - skip \n after \r
                            if byte == 0x0D { // \r
                                lastWasCR = true
                                continue
                            }

                            if byte == 0x0A { // \n
                                // End of line - decode the line buffer as UTF-8
                                let line = String(data: lineBuffer, encoding: .utf8) ?? ""
                                lineBuffer = Data()
                                lastWasCR = false

                                if line.isEmpty {
                                    // Blank line = end of event
                                    if !eventLines.isEmpty {
                                        let event = parseSSELines(eventLines)
                                        if let event = event {
                                            continuation.yield(event)
                                            if event.type == .end {
                                                break
                                            }
                                        }
                                        eventLines = []
                                    }
                                } else {
                                    // Non-empty line - accumulate
                                    eventLines.append(line)
                                }
                            } else {
                                // If we had a \r without \n, treat it as line ending
                                if lastWasCR {
                                    let line = String(data: lineBuffer, encoding: .utf8) ?? ""
                                    lineBuffer = Data()
                                    if line.isEmpty {
                                        if !eventLines.isEmpty {
                                            let event = parseSSELines(eventLines)
                                            if let event = event {
                                                continuation.yield(event)
                                                if event.type == .end {
                                                    break
                                                }
                                            }
                                            eventLines = []
                                        }
                                    } else {
                                        eventLines.append(line)
                                    }
                                }
                                lastWasCR = false
                                lineBuffer.append(byte)
                            }
                        }

                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }

        private func parseSSELines(_ lines: [String]) -> StreamEvent? {
            var eventType: String?
            var dataLines: [String] = []

            for line in lines {
                if line.hasPrefix("event:") {
                    eventType = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    // Accumulate all data lines (SSE can have multiple data: lines)
                    let dataContent = String(line.dropFirst(5))
                    // Trim leading space if present (standard SSE format is "data: value")
                    dataLines.append(dataContent.hasPrefix(" ") ? String(dataContent.dropFirst()) : dataContent)
                }
                // Ignore other fields like "id:" and "retry:" for now
            }

            // Default event type is "message" per SSE spec
            let effectiveEventType = eventType ?? "message"

            // Use .unknown for unrecognized event types instead of failing
            let type = StreamEventType(rawValue: effectiveEventType) ?? .unknown

            // Concatenate all data lines
            let dataString = dataLines.joined()
            let data = JSON(parseJSON: dataString)

            return StreamEvent(type: type, data: data)
        }

        public func cancel(threadId: String, runId: String) async throws {
            let request = await client.buildRequest(
                path: "/threads/\(threadId)/runs/\(runId)/cancel",
                method: "POST"
            )

            _ = try await client.performRequest(request)
        }

        /// Create a non-streaming run
        public func create(
            threadId: String,
            assistantId: String,
            input: JSON? = nil,
            command: [String: Any]? = nil,
            config: JSON? = nil,
            interruptBefore: [String]? = nil,
            interruptAfter: [String]? = nil,
            metadata: [String: Any]? = nil,
            multitaskStrategy: String? = nil
        ) async throws -> Run {
            var body: [String: Any] = [
                "assistant_id": assistantId
            ]

            if let input = input {
                body["input"] = input.object
            }

            if let command = command {
                body["command"] = command
            }

            if let config = config {
                body["config"] = config.object
            }

            if let interruptBefore = interruptBefore {
                body["interrupt_before"] = interruptBefore
            }

            if let interruptAfter = interruptAfter {
                body["interrupt_after"] = interruptAfter
            }

            if let metadata = metadata {
                body["metadata"] = metadata
            }

            if let multitaskStrategy = multitaskStrategy {
                body["multitask_strategy"] = multitaskStrategy
            }

            let request = await client.buildRequest(
                path: "/threads/\(threadId)/runs",
                method: "POST",
                body: JSON(body)
            )

            let result = try await client.performRequest(request)
            return Run(json: result)
        }
    }

    // MARK: - Deployment Info

    /// Fetch deployment info from the /info endpoint
    public func fetchDeploymentInfo() async throws -> DeploymentInfoResponse {
        let request = await buildRequest(path: "/info")
        let result = try await performRequest(request)
        return DeploymentInfoResponse(json: result)
    }

    // MARK: - Store API

    public var store: StoreAPI {
        StoreAPI(client: self)
    }

    public struct StoreAPI: Sendable {
        let client: LangGraphClient

        /// List namespaces with optional prefix filter
        public func listNamespaces(
            prefix: [String]? = nil,
            suffix: [String]? = nil,
            maxDepth: Int? = nil,
            limit: Int = 100,
            offset: Int = 0
        ) async throws -> [[String]] {
            var body: [String: Any] = [
                "limit": limit,
                "offset": offset
            ]

            if let prefix = prefix {
                body["prefix"] = prefix
            }

            if let suffix = suffix {
                body["suffix"] = suffix
            }

            if let maxDepth = maxDepth {
                body["max_depth"] = maxDepth
            }

            let request = await client.buildRequest(
                path: "/store/namespaces",
                method: "POST",
                body: JSON(body)
            )

            let result = try await client.performRequest(request)
            return result.arrayValue.map { $0.arrayValue.map { $0.stringValue } }
        }

        /// Search for items in the store
        public func searchItems(
            namespacePrefix: [String],
            filter: [String: Any]? = nil,
            limit: Int = 100,
            offset: Int = 0
        ) async throws -> [StoreItem] {
            var body: [String: Any] = [
                "namespace_prefix": namespacePrefix,
                "limit": limit,
                "offset": offset
            ]

            if let filter = filter {
                body["filter"] = filter
            }

            let request = await client.buildRequest(
                path: "/store/items/search",
                method: "POST",
                body: JSON(body)
            )

            let result = try await client.performRequest(request)
            return result["items"].arrayValue.map { StoreItem(json: $0) }
        }

        /// Get a specific item by namespace and key
        public func getItem(namespace: [String], key: String) async throws -> StoreItem? {
            let request = await client.buildRequest(
                path: "/store/items",
                queryParams: [
                    "namespace": namespace.joined(separator: ","),
                    "key": key
                ]
            )

            let result = try await client.performRequest(request)
            guard result.exists() && result != JSON.null else { return nil }
            return StoreItem(json: result)
        }
    }
}

// MARK: - Store Item

public struct StoreItem: Identifiable, Sendable {
    public let namespace: [String]
    public let key: String
    public let value: JSON
    public let createdAt: Date?
    public let updatedAt: Date?

    public var id: String {
        (namespace + [key]).joined(separator: "/")
    }

    public init(json: JSON) {
        self.namespace = json["namespace"].arrayValue.map { $0.stringValue }
        self.key = json["key"].stringValue
        self.value = json["value"]
        self.createdAt = ISO8601DateFormatter().date(from: json["created_at"].stringValue)
        self.updatedAt = ISO8601DateFormatter().date(from: json["updated_at"].stringValue)
    }
}

// MARK: - Errors

public enum LangGraphError: Error, LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case streamError(String)
    case decodingError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode, let message):
            return "HTTP error \(statusCode): \(message)"
        case .streamError(let message):
            return "Stream error: \(message)"
        case .decodingError(let message):
            return "Decoding error: \(message)"
        }
    }
}
