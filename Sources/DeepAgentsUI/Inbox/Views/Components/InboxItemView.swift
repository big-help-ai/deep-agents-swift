import SwiftUI

/// Individual inbox item view.
public struct InboxItemView: View {
    let threadData: ThreadData
    @Bindable var threadsViewModel: ThreadsViewModel

    public init(threadData: ThreadData, threadsViewModel: ThreadsViewModel) {
        self.threadData = threadData
        self.threadsViewModel = threadsViewModel
    }

    public var body: some View {
        Button {
            threadsViewModel.selectedThreadId = threadData.thread.threadId
        } label: {
            if threadData.isInterrupted {
                InterruptedInboxItemContent(threadData: threadData)
            } else {
                GenericInboxItemContent(threadData: threadData)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Content for interrupted inbox items.
struct InterruptedInboxItemContent: View {
    let threadData: ThreadData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header row
            HStack {
                // Status icon
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundColor(.orange)

                // Action name
                Text(threadData.displayTitle)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Date
                Text(formatInboxDate(threadData.thread.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Description or email preview
            if let description = threadData.firstInterrupt?.description {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            } else if let email = extractEmail(from: threadData) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(email.subject)
                        .font(.subheadline)
                        .lineLimit(1)
                    Text(email.pageContent)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Config badges
            if let config = threadData.firstInterrupt?.config {
                HStack(spacing: 8) {
                    if config.allowAccept {
                        InboxConfigBadge(text: "Accept", color: .green)
                    }
                    if config.allowEdit {
                        InboxConfigBadge(text: "Edit", color: .blue)
                    }
                    if config.allowRespond {
                        InboxConfigBadge(text: "Respond", color: .purple)
                    }
                    if config.allowIgnore {
                        InboxConfigBadge(text: "Ignore", color: .gray)
                    }
                }
            }
        }
        .padding()
        .contentShape(Rectangle())
    }

    private func extractEmail(from threadData: ThreadData) -> InboxEmail? {
        let email = threadData.thread.values["email"]
        guard email.exists() else { return nil }
        return InboxEmail(json: email)
    }
}

/// Content for non-interrupted inbox items.
struct GenericInboxItemContent: View {
    let threadData: ThreadData

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status icon
                statusIcon
                    .foregroundColor(statusColor)

                // Thread ID
                Text("Thread: \(threadData.thread.threadId.prefix(8))...")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                // Status badge
                InboxStatusBadge(status: threadData.status)

                // Date
                Text(formatInboxDate(threadData.thread.createdAt))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }

            // Thread info
            HStack(spacing: 16) {
                Label("Created: \(formatInboxDate(threadData.thread.createdAt))", systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .contentShape(Rectangle())
    }

    private var statusIcon: some View {
        switch threadData.status {
        case .idle:
            return Image(systemName: "clock")
        case .busy:
            return Image(systemName: "arrow.triangle.2.circlepath")
        case .error:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .interrupted:
            return Image(systemName: "exclamationmark.circle.fill")
        default:
            return Image(systemName: "circle")
        }
    }

    private var statusColor: Color {
        switch threadData.status {
        case .idle:
            return .gray
        case .busy:
            return .blue
        case .error:
            return .red
        case .interrupted:
            return .orange
        default:
            return .gray
        }
    }
}

/// Small badge for config options.
public struct InboxConfigBadge: View {
    let text: String
    let color: Color

    public init(text: String, color: Color) {
        self.text = text
        self.color = color
    }

    public var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .cornerRadius(4)
    }
}

/// Status badge.
public struct InboxStatusBadge: View {
    let status: ThreadStatus

    public init(status: ThreadStatus) {
        self.status = status
    }

    public var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor.opacity(0.15))
            .foregroundColor(backgroundColor)
            .cornerRadius(4)
    }

    private var backgroundColor: Color {
        switch status {
        case .idle:
            return .gray
        case .busy:
            return .blue
        case .error:
            return .red
        case .interrupted:
            return .orange
        case .humanResponseNeeded:
            return .purple
        case .all:
            return .gray
        }
    }
}
