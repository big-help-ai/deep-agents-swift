import Foundation

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
