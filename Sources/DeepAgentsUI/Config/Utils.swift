import Foundation
import SwiftyJSON

// MARK: - Message Content Extraction

public func extractStringFromMessageContent(_ message: Message) -> String {
    if let str = message.content.string {
        return str
    }

    if let array = message.content.array {
        return array
            .compactMap { item -> String? in
                if let str = item.string {
                    return str
                }
                if item["type"].stringValue == "text" {
                    return item["text"].string
                }
                return nil
            }
            .joined()
    }

    return ""
}

// MARK: - Sub Agent Content Extraction

public func extractSubAgentContent(_ data: JSON) -> String {
    if let str = data.string {
        return str
    }

    if data.type == .dictionary {
        // Try to extract description first
        if let description = data["description"].string {
            return description
        }

        // Then try prompt
        if let prompt = data["prompt"].string {
            return prompt
        }

        // For output objects, try result
        if let result = data["result"].string {
            return result
        }

        // Fallback to JSON stringification
        if let rawString = data.rawString(.utf8, options: [.prettyPrinted, .sortedKeys]) {
            return rawString
        }
    }

    // Fallback for any other type
    return data.rawString() ?? ""
}

// MARK: - Task Tool Detection

public func isPreparingToCallTaskTool(_ messages: [Message]) -> Bool {
    guard let lastMessage = messages.last else { return false }

    if lastMessage.type == .ai {
        if let toolCalls = lastMessage.toolCalls {
            return toolCalls.contains { call in
                call["name"].stringValue == "task"
            }
        }
    }

    return false
}

// MARK: - Message Formatting for LLM

public func formatMessageForLLM(_ message: Message) -> String {
    var role: String

    switch message.type {
    case .human:
        role = "Human"
    case .ai:
        role = "Assistant"
    case .tool:
        role = "Tool Result"
    case .system:
        role = "System"
    }

    let timestamp = !message.id.isEmpty ? " (\(String(message.id.prefix(8))))" : ""

    var contentText = ""

    // Extract content text
    if let str = message.content.string {
        contentText = str
    } else if let array = message.content.array {
        let textParts = array.compactMap { part -> String? in
            if let str = part.string {
                return str
            }
            if part["type"].stringValue == "text" {
                return part["text"].string
            }
            return nil
        }
        contentText = textParts.joined(separator: "\n\n").trimmingCharacters(in: .whitespaces)
    }

    // For tool messages, include additional tool metadata
    if message.type == .tool {
        let toolName = message.content["name"].string ?? "unknown_tool"
        let toolCallId = message.toolCallId ?? ""
        role = "Tool Result [\(toolName)]"
        if !toolCallId.isEmpty {
            role += " (call_id: \(String(toolCallId.prefix(8))))"
        }
    }

    // Handle tool calls from .tool_calls property (for AI messages)
    var toolCallsText: [String] = []
    if message.type == .ai, let toolCalls = message.toolCalls, !toolCalls.isEmpty {
        for call in toolCalls {
            let toolName = call["name"].string ?? "unknown_tool"
            let toolArgs = call["args"].rawString(.utf8, options: [.prettyPrinted]) ?? "{}"
            toolCallsText.append("[Tool Call: \(toolName)]\nArguments: \(toolArgs)")
        }
    }

    // Combine content and tool calls
    var parts: [String] = []
    if !contentText.isEmpty {
        parts.append(contentText)
    }
    parts.append(contentsOf: toolCallsText)

    if parts.isEmpty {
        return "\(role)\(timestamp): [Empty message]"
    }

    if parts.count == 1 {
        return "\(role)\(timestamp): \(parts[0])"
    }

    return "\(role)\(timestamp):\n\(parts.joined(separator: "\n\n"))"
}

// MARK: - Conversation Formatting

public func formatConversationForLLM(_ messages: [Message]) -> String {
    let formattedMessages = messages.map { formatMessageForLLM($0) }
    return formattedMessages.joined(separator: "\n\n---\n\n")
}

// MARK: - Date Formatting

public func formatRelativeDate(_ date: Date) -> String {
    let now = Date()
    let calendar = Calendar.current

    if calendar.isDateInToday(date) {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }

    if calendar.isDateInYesterday(date) {
        return "Yesterday"
    }

    let weekAgo = calendar.date(byAdding: .day, value: -7, to: now)!
    if date > weekAgo {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }

    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d, yyyy"
    return formatter.string(from: date)
}

// MARK: - UUID Validation

public func isValidUUID(_ string: String) -> Bool {
    let uuidRegex = try? NSRegularExpression(
        pattern: "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$",
        options: .caseInsensitive
    )
    let range = NSRange(string.startIndex..., in: string)
    return uuidRegex?.firstMatch(in: string, options: [], range: range) != nil
}

// MARK: - File Extension Detection

public func getFileExtension(_ path: String) -> String {
    let url = URL(fileURLWithPath: path)
    return url.pathExtension.lowercased()
}

public func getLanguageFromExtension(_ ext: String) -> String {
    switch ext {
    case "swift":
        return "swift"
    case "js", "jsx":
        return "javascript"
    case "ts", "tsx":
        return "typescript"
    case "py":
        return "python"
    case "rb":
        return "ruby"
    case "go":
        return "go"
    case "rs":
        return "rust"
    case "java":
        return "java"
    case "kt", "kts":
        return "kotlin"
    case "c", "h":
        return "c"
    case "cpp", "cc", "cxx", "hpp":
        return "cpp"
    case "cs":
        return "csharp"
    case "php":
        return "php"
    case "html", "htm":
        return "html"
    case "css":
        return "css"
    case "scss", "sass":
        return "scss"
    case "json":
        return "json"
    case "yaml", "yml":
        return "yaml"
    case "xml":
        return "xml"
    case "md", "markdown":
        return "markdown"
    case "sql":
        return "sql"
    case "sh", "bash", "zsh":
        return "bash"
    default:
        return "plaintext"
    }
}
