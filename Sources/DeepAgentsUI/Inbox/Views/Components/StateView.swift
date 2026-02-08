import SwiftUI
import SwiftyJSON

/// Side panel view showing thread state or description.
public struct StateView: View {
    let threadData: ThreadData
    let showState: Bool
    let onClose: () -> Void

    public init(threadData: ThreadData, showState: Bool, onClose: @escaping () -> Void) {
        self.threadData = threadData
        self.showState = showState
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text(showState ? "Thread State" : "Description")
                    .font(.headline)

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))

            Divider()

            // Content
            ScrollView {
                if showState {
                    ThreadStateView(threadData: threadData)
                } else {
                    DescriptionView(threadData: threadData)
                }
            }
        }
        .background(Color(.systemBackground))
    }
}

/// View showing thread state JSON.
struct ThreadStateView: View {
    let threadData: ThreadData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Interrupt details if available
            if let interrupt = threadData.firstInterrupt {
                InterruptDetailsSection(interrupt: interrupt)
            }

            Divider()

            // Thread values
            ValuesSection(values: threadData.thread.values)

            // Metadata
            if threadData.thread.metadata.exists() {
                Divider()
                MetadataSection(metadata: threadData.thread.metadata)
            }
        }
        .padding()
    }
}

/// Interrupt details section.
struct InterruptDetailsSection: View {
    let interrupt: HumanInterrupt
    @State private var expandedArgs = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Interrupt")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)

            // Action
            LabeledContent("Action") {
                Text(interrupt.actionRequest.action.prettified)
                    .font(.subheadline)
            }

            // Config badges
            HStack(spacing: 8) {
                if interrupt.config.allowAccept {
                    InboxConfigBadge(text: "Accept", color: .green)
                }
                if interrupt.config.allowEdit {
                    InboxConfigBadge(text: "Edit", color: .blue)
                }
                if interrupt.config.allowRespond {
                    InboxConfigBadge(text: "Respond", color: .purple)
                }
                if interrupt.config.allowIgnore {
                    InboxConfigBadge(text: "Ignore", color: .gray)
                }
            }

            // Arguments (collapsible)
            DisclosureGroup("Arguments", isExpanded: $expandedArgs) {
                InboxJSONView(json: interrupt.actionRequest.args)
                    .padding(.top, 8)
            }
        }
    }
}

/// Values section.
struct ValuesSection: View {
    let values: JSON
    @State private var expanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("Values", isExpanded: $expanded) {
                InboxJSONView(json: values)
                    .padding(.top, 8)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
        }
    }
}

/// Metadata section.
struct MetadataSection: View {
    let metadata: JSON
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("Metadata", isExpanded: $expanded) {
                InboxJSONView(json: metadata)
                    .padding(.top, 8)
            }
            .font(.subheadline)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)
        }
    }
}

/// Simple JSON viewer.
public struct InboxJSONView: View {
    let json: JSON

    public init(json: JSON) {
        self.json = json
    }

    public var body: some View {
        if let dict = json.dictionary {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(dict.keys.sorted()), id: \.self) { key in
                    InboxJSONKeyValueRow(key: key, value: dict[key]!)
                }
            }
        } else if let array = json.array {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(array.enumerated()), id: \.offset) { index, value in
                    InboxJSONKeyValueRow(key: "[\(index)]", value: value)
                }
            }
        } else {
            Text(json.stringValue)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

struct InboxJSONKeyValueRow: View {
    let key: String
    let value: JSON

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)

            if value.type == .dictionary || value.type == .array {
                InboxJSONView(json: value)
                    .padding(.leading, 12)
            } else {
                Text(valueString)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .padding(.leading, 12)
            }
        }
    }

    private var valueString: String {
        if let str = value.string {
            return "\"\(str)\""
        } else if let num = value.number {
            return num.stringValue
        } else if let bool = value.bool {
            return bool ? "true" : "false"
        } else if value.null != nil {
            return "null"
        }
        return value.rawString() ?? ""
    }
}

/// Description view.
struct DescriptionView: View {
    let threadData: ThreadData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if threadData.isInterrupted, let interrupt = threadData.firstInterrupt {
                // Interrupted thread with description
                InterruptedDescriptionView(interrupt: interrupt)
            } else {
                // Non-interrupted or no description
                NonInterruptedDescriptionView(threadData: threadData)
            }
        }
        .padding()
    }
}

/// Description for interrupted threads.
struct InterruptedDescriptionView: View {
    let interrupt: HumanInterrupt

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Action name
            HStack {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)
                Text(interrupt.actionRequest.action.prettified)
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            // Description
            if let description = interrupt.description {
                Text(description)
                    .font(.body)
            }

            // Action request preview
            VStack(alignment: .leading, spacing: 8) {
                Text("Requested Action")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                ForEach(Array(interrupt.actionRequest.args.dictionaryValue.keys.sorted()), id: \.self) { key in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(key.prettified)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        let value = interrupt.actionRequest.args[key]
                        Text(value.stringValue.isEmpty ? value.rawString() ?? "" : value.stringValue)
                            .font(.subheadline)
                            .lineLimit(5)
                    }
                    .padding(.vertical, 4)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }
}

/// Description for non-interrupted threads.
struct NonInterruptedDescriptionView: View {
    let threadData: ThreadData

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Status info
            HStack {
                statusIcon
                Text("Thread Status: \(threadData.status.displayName)")
                    .font(.title3)
                    .fontWeight(.semibold)
            }

            // Description based on status
            switch threadData.status {
            case .idle:
                Text("This thread is idle and waiting for input or events.")
                    .font(.body)
                    .foregroundColor(.secondary)

            case .busy:
                Text("This thread is currently being processed.")
                    .font(.body)
                    .foregroundColor(.secondary)

            case .error:
                VStack(alignment: .leading, spacing: 8) {
                    Text("This thread encountered an error during execution.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    Text("Check the State tab for more details about the error.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

            default:
                Text("View the State tab for detailed information about this thread.")
                    .font(.body)
                    .foregroundColor(.secondary)
            }

            // Basic thread info
            VStack(alignment: .leading, spacing: 8) {
                Text("Thread Information")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                LabeledContent("ID") {
                    Text(threadData.thread.threadId)
                        .font(.caption)
                        .lineLimit(1)
                }

                LabeledContent("Created") {
                    Text(formatInboxDate(threadData.thread.createdAt))
                        .font(.caption)
                }

                LabeledContent("Updated") {
                    Text(formatInboxDate(threadData.thread.updatedAt))
                        .font(.caption)
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
    }

    private var statusIcon: some View {
        Group {
            switch threadData.status {
            case .idle:
                Image(systemName: "clock")
                    .foregroundColor(.gray)
            case .busy:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.blue)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            default:
                Image(systemName: "circle")
                    .foregroundColor(.gray)
            }
        }
    }
}
