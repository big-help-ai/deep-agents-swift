import SwiftUI

// MARK: - Thread List View

public struct ThreadListView: View {
    @Environment(ThreadService.self) private var threadService

    let onThreadSelect: (String) -> Void
    let onClose: () -> Void

    @State private var selectedThreadId: String?
    @State private var statusFilter: ThreadStatus?

    public init(
        onThreadSelect: @escaping (String) -> Void,
        onClose: @escaping () -> Void = {}
    ) {
        self.onThreadSelect = onThreadSelect
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Thread list
            if threadService.isLoading && threadService.threads.isEmpty {
                loadingView
            } else if threadService.threads.isEmpty {
                emptyView
            } else {
                threadListContent
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                filterMenu
            }
        }
        .task {
            if threadService.threads.isEmpty {
                await threadService.refresh()
            }
        }
    }

    // MARK: - Filter Menu

    private var filterMenu: some View {
        Menu {
            Button("All") {
                statusFilter = nil
                threadService.setStatusFilter(nil)
            }
            Button("Idle") {
                statusFilter = .idle
                threadService.setStatusFilter(.idle)
            }
            Button("Busy") {
                statusFilter = .busy
                threadService.setStatusFilter(.busy)
            }
            Button("Interrupted") {
                statusFilter = .interrupted
                threadService.setStatusFilter(.interrupted)
            }
            Button("Error") {
                statusFilter = .error
                threadService.setStatusFilter(.error)
            }
        } label: {
            HStack(spacing: 4) {
                Text(statusFilterLabel)
                Image(systemName: "chevron.down")
                    .font(.caption)
            }
            .font(.headline)
        }
    }

    private var statusFilterLabel: String {
        guard let filter = statusFilter else { return "All Threads" }
        switch filter {
        case .all: return "All Threads"
        case .idle: return "Idle"
        case .busy: return "Busy"
        case .interrupted: return "Interrupted"
        case .error: return "Error"
        case .humanResponseNeeded: return "Human Response Needed"
        }
    }

    // MARK: - Thread List Content

    private var threadListContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(threadService.groupedThreads, id: \.0) { group, threads in
                    Section {
                        ForEach(threads) { thread in
                            threadRow(thread)
                        }
                    } header: {
                        Text(group)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                    }
                }

                // Load more
                if threadService.hasMore {
                    Button {
                        Task {
                            await threadService.loadMore()
                        }
                    } label: {
                        HStack {
                            Spacer()
                            if threadService.isLoading {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Load More")
                            }
                            Spacer()
                        }
                        .padding()
                    }
                }
            }
        }
        .refreshable {
            await threadService.refresh()
        }
    }

    private func threadRow(_ thread: ThreadItem) -> some View {
        Button {
            selectedThreadId = thread.id
            onThreadSelect(thread.id)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(thread.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .lineLimit(1)

                        statusBadge(for: thread.status)
                    }

                    if !thread.description.isEmpty {
                        Text(thread.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Text(formatRelativeDate(thread.updatedAt))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                if selectedThreadId == thread.id {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(selectedThreadId == thread.id ? Color.blue.opacity(0.1) : Color.clear)
    }

    @ViewBuilder
    private func statusBadge(for status: ThreadStatus) -> some View {
        switch status {
        case .interrupted:
            Text("Interrupted")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red)
                .foregroundStyle(.white)
                .clipShape(Capsule())

        case .busy:
            Text("Busy")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange)
                .foregroundStyle(.white)
                .clipShape(Capsule())

        case .error:
            Text("Error")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.red.opacity(0.7))
                .foregroundStyle(.white)
                .clipShape(Capsule())

        case .humanResponseNeeded:
            Text("Response Needed")
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.purple)
                .foregroundStyle(.white)
                .clipShape(Capsule())

        case .idle, .all:
            EmptyView()
        }
    }

    // MARK: - Loading & Empty Views

    private var loadingView: some View {
        VStack {
            Spacer()
            ProgressView()
            Spacer()
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "message")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No threads yet")
                .font(.headline)
            Text("Start a new conversation")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}
