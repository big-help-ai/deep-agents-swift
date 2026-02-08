import Foundation
import SwiftyJSON

// MARK: - URL Utilities

/// Determines if a URL is a deployed (cloud) URL.
public func isDeployedUrl(_ urlString: String) -> Bool {
    guard let url = URL(string: urlString) else {
        return false
    }
    return url.scheme == "https" && !(url.host?.contains("localhost") ?? true)
}

/// Extract project ID from inbox ID (format: project_id:graphId).
public func extractProjectId(from inboxId: String) -> String? {
    guard inboxId.contains(":") else { return nil }
    let parts = inboxId.split(separator: ":")
    guard parts.count == 2 else { return nil }
    let projectId = String(parts[0])
    // Validate UUID format
    guard UUID(uuidString: projectId) != nil else { return nil }
    return projectId
}

/// Construct URL to open thread in LangSmith Studio.
public func constructOpenInStudioURL(inbox: AgentInbox, threadId: String?) -> URL? {
    let smithStudioBaseUrl = "https://smith.langchain.com/studio/thread"

    guard var urlComponents = URLComponents(string: smithStudioBaseUrl) else {
        return nil
    }

    if isDeployedUrl(inbox.deploymentUrl) {
        guard let projectId = extractProjectId(from: inbox.id),
              let tenantId = inbox.tenantId,
              let threadId = threadId else {
            return nil
        }

        urlComponents.queryItems = [
            URLQueryItem(name: "organizationId", value: tenantId),
            URLQueryItem(name: "hostProjectId", value: projectId),
            URLQueryItem(name: "threadId", value: threadId)
        ]
    } else {
        let trimmedUrl = inbox.deploymentUrl.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        var queryItems = [URLQueryItem(name: "baseUrl", value: trimmedUrl)]

        if let threadId = threadId {
            queryItems.insert(URLQueryItem(name: "threadId", value: threadId), at: 0)
        }

        urlComponents.queryItems = queryItems
    }

    return urlComponents.url
}

// MARK: - Date Formatting

/// Format date for display.
public func formatInboxDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "MM/dd/yyyy hh:mm a"
    return formatter.string(from: date)
}

// MARK: - Interrupt Parsing

/// Parse interrupts from thread data.
public func getInterruptsFromThread(_ thread: InboxThread) -> [HumanInterrupt]? {
    guard let interruptsJSON = thread.interrupts else { return nil }

    var results: [HumanInterrupt] = []

    // Handle various interrupt structures
    for (_, interrupt) in interruptsJSON.dictionaryValue {
        if let parsedInterrupts = parseInterruptValue(interrupt) {
            results.append(contentsOf: parsedInterrupts)
        }
    }

    return results.isEmpty ? nil : results
}

/// Parse interrupt value from JSON.
public func parseInterruptValue(_ json: JSON) -> [HumanInterrupt]? {
    // Case 1: Direct array of interrupts
    if json.array != nil {
        return parseInterruptArray(json)
    }

    // Case 2: Object with value property
    if let value = json["value"].exists() ? json["value"] : nil {
        return parseInterruptValue(value)
    }

    // Case 3: Direct interrupt object
    if isValidInterrupt(json) {
        return [HumanInterrupt(json: json)]
    }

    return nil
}

private func parseInterruptArray(_ json: JSON) -> [HumanInterrupt]? {
    var interrupts: [HumanInterrupt] = []

    for item in json.arrayValue {
        // Check for nested array structure [0][1].value
        if item.array != nil {
            if let nestedValue = item[1]["value"].exists() ? item[1]["value"] : nil {
                if isValidInterrupt(nestedValue) {
                    interrupts.append(HumanInterrupt(json: nestedValue))
                } else if nestedValue.array != nil {
                    for subItem in nestedValue.arrayValue {
                        if isValidInterrupt(subItem) {
                            interrupts.append(HumanInterrupt(json: subItem))
                        }
                    }
                }
            } else if item[1].exists() {
                // Handle direct [0][1] structure
                if isValidInterrupt(item[1]) {
                    interrupts.append(HumanInterrupt(json: item[1]))
                }
            }
            continue
        }

        // Check for value property
        if let value = item["value"].exists() ? item["value"] : nil {
            // Handle JSON string value
            if let stringValue = value.string,
               (stringValue.hasPrefix("[") || stringValue.hasPrefix("{")),
               let data = stringValue.data(using: .utf8),
               let parsed = try? JSON(data: data) {
                if isValidInterrupt(parsed) {
                    interrupts.append(HumanInterrupt(json: parsed))
                } else if parsed.array != nil {
                    for subItem in parsed.arrayValue {
                        if isValidInterrupt(subItem) {
                            interrupts.append(HumanInterrupt(json: subItem))
                        }
                    }
                }
                continue
            }

            // Handle direct value
            if isValidInterrupt(value) {
                interrupts.append(HumanInterrupt(json: value))
            } else if value.array != nil {
                for subItem in value.arrayValue {
                    if isValidInterrupt(subItem) {
                        interrupts.append(HumanInterrupt(json: subItem))
                    }
                }
            }
            continue
        }

        // Direct interrupt object
        if isValidInterrupt(item) {
            interrupts.append(HumanInterrupt(json: item))
        }
    }

    if interrupts.isEmpty {
        // Return improper schema if we couldn't parse
        return [HumanInterrupt.improperSchema()]
    }

    return interrupts
}

private func isValidInterrupt(_ json: JSON) -> Bool {
    return json["action_request"]["action"].exists() && json["config"].exists()
}

// MARK: - Human Response Creation

/// Create default human response based on interrupt config.
public func createDefaultHumanResponse(
    from interrupts: [HumanInterrupt],
    initialValues: inout [String: String]
) -> (responses: [HumanResponseWithEdits], defaultSubmitType: SubmitType?, hasAccept: Bool) {
    guard let interrupt = interrupts.first else {
        return ([], nil, false)
    }

    var responses: [HumanResponseWithEdits] = []

    // Handle accept (Approve)
    if interrupt.config.allowAccept {
        responses.append(HumanResponseWithEdits(
            type: .accept,
            args: .actionRequest(interrupt.actionRequest),
            acceptAllowed: true
        ))
    }

    // Handle respond
    if interrupt.config.allowRespond {
        responses.append(HumanResponseWithEdits(
            type: .response,
            args: .string(""),
            acceptAllowed: false
        ))
    }

    // Handle ignore (Cancel)
    if interrupt.config.allowIgnore {
        responses.append(HumanResponseWithEdits(
            type: .ignore,
            args: .null
        ))
    }

    // Determine default submit type: accept > response
    let hasAccept = interrupt.config.allowAccept
    var defaultSubmitType: SubmitType?
    if hasAccept {
        defaultSubmitType = .accept
    } else if responses.contains(where: { $0.type == .response }) {
        defaultSubmitType = .response
    }

    return (responses, defaultSubmitType, hasAccept)
}

/// Check if args have changed from initial values.
public func haveArgsChanged(_ args: JSON, initialValues: [String: String]) -> Bool {
    for (key, value) in args.dictionaryValue {
        let currentValue: String
        if let str = value.string {
            currentValue = str
        } else if let num = value.number {
            currentValue = num.stringValue
        } else {
            currentValue = value.rawString() ?? ""
        }

        if let initialValue = initialValues[key], initialValue != currentValue {
            return true
        }
    }
    return false
}

// MARK: - Thread Filter Metadata

/// Get thread filter metadata based on graph ID format.
public func getThreadFilterMetadata(for inbox: AgentInbox) -> [String: String]? {
    let graphId = inbox.graphId
    guard !graphId.isEmpty else { return nil }

    if isValidUUID(graphId) {
        return ["assistant_id": graphId]
    } else {
        return ["graph_id": graphId]
    }
}
