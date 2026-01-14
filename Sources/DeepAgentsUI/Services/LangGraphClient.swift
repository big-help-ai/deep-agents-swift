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

    private func buildRequest(
        path: String,
        method: String = "GET",
        body: JSON? = nil,
        queryParams: [String: String]? = nil
    ) -> URLRequest {
        var urlComponents = URLComponents(string: "\(apiUrl)\(path)")!

        if let queryParams = queryParams {
            urlComponents.queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
        }

        var request = URLRequest(url: urlComponents.url!)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey = apiKey, !apiKey.isEmpty {
            request.setValue(apiKey, forHTTPHeaderField: "X-Api-Key")
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

            if let status = status {
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

                        guard let httpResponse = response as? HTTPURLResponse,
                              (200...299).contains(httpResponse.statusCode) else {
                            throw LangGraphError.streamError("Invalid response")
                        }

                        var buffer = ""

                        for try await byte in bytes {
                            let char = Character(UnicodeScalar(byte))
                            buffer.append(char)

                            // SSE format: "event: <type>\ndata: <json>\n\n"
                            if buffer.hasSuffix("\n\n") {
                                let event = parseSSEEvent(buffer)
                                if let event = event {
                                    continuation.yield(event)
                                    if event.type == .end {
                                        break
                                    }
                                }
                                buffer = ""
                            }
                        }

                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
            }
        }

        private func parseSSEEvent(_ text: String) -> StreamEvent? {
            let lines = text.components(separatedBy: "\n")
            var eventType: String?
            var dataLine: String?

            for line in lines {
                if line.hasPrefix("event:") {
                    eventType = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                } else if line.hasPrefix("data:") {
                    dataLine = String(line.dropFirst(5))
                }
            }

            guard let eventType = eventType,
                  let dataLine = dataLine,
                  let type = StreamEventType(rawValue: eventType) else {
                return nil
            }

            let data = JSON(parseJSON: dataLine)
            return StreamEvent(type: type, data: data)
        }

        public func cancel(threadId: String, runId: String) async throws {
            let request = await client.buildRequest(
                path: "/threads/\(threadId)/runs/\(runId)/cancel",
                method: "POST"
            )

            _ = try await client.performRequest(request)
        }
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
