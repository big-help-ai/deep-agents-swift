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
        if let description = data["description"].string {
            return description
        }

        if let prompt = data["prompt"].string {
            return prompt
        }

        if let result = data["result"].string {
            return result
        }

        if let rawString = data.rawString(.utf8, options: [.prettyPrinted, .sortedKeys]) {
            return rawString
        }
    }

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

    if message.type == .tool {
        let toolName = message.content["name"].string ?? "unknown_tool"
        let toolCallId = message.toolCallId ?? ""
        role = "Tool Result [\(toolName)]"
        if !toolCallId.isEmpty {
            role += " (call_id: \(String(toolCallId.prefix(8))))"
        }
    }

    var toolCallsText: [String] = []
    if message.type == .ai, let toolCalls = message.toolCalls, !toolCalls.isEmpty {
        for call in toolCalls {
            let toolName = call["name"].string ?? "unknown_tool"
            let toolArgs = call["args"].rawString(.utf8, options: [.prettyPrinted]) ?? "{}"
            toolCallsText.append("[Tool Call: \(toolName)]\nArguments: \(toolArgs)")
        }
    }

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
