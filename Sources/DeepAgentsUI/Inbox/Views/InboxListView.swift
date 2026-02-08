import SwiftUI

/// List view showing all threads in the inbox.
public struct InboxListView: View {
    @Bindable var threadsViewModel: ThreadsViewModel

    public init(threadsViewModel: ThreadsViewModel) {
        self.threadsViewModel = threadsViewModel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Status filter tabs
            InboxTabsView(threadsViewModel: threadsViewModel)

            // Thread list
            if threadsViewModel.loading {
                Spacer()
                ProgressView()
                Spacer()
            } else if threadsViewModel.threadData.isEmpty {
                EmptyInboxView()
            } else {
                InboxThreadListView(threadsViewModel: threadsViewModel)
            }

            // Pagination
            InboxPaginationView(threadsViewModel: threadsViewModel)
        }
        .task {
            if threadsViewModel.threadData.isEmpty {
                await threadsViewModel.fetchThreads()
            }
        }
    }
}

/// Tab buttons for filtering by thread status.
struct InboxTabsView: View {
    @Bindable var threadsViewModel: ThreadsViewModel

    private let tabs: [ThreadStatus] = [.interrupted, .idle, .busy, .error, .all]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(tabs, id: \.rawValue) { status in
                    InboxTabButton(
                        title: status.displayName,
                        isSelected: threadsViewModel.selectedInbox == status
                    ) {
                        Task {
                            await threadsViewModel.selectInbox(status)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .background(Color(.systemBackground))
    }
}

struct InboxTabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

/// List of threads.
struct InboxThreadListView: View {
    @Bindable var threadsViewModel: ThreadsViewModel

    var body: some View {
        List {
            ForEach(filteredThreads) { threadData in
                InboxItemView(threadData: threadData, threadsViewModel: threadsViewModel)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.visible)
            }
        }
        .listStyle(.plain)
        .refreshable {
            await threadsViewModel.fetchThreads()
        }
    }

    private var filteredThreads: [ThreadData] {
        if threadsViewModel.selectedInbox == .all {
            return threadsViewModel.threadData
        }
        return threadsViewModel.threadData.filter { $0.status == threadsViewModel.selectedInbox }
    }
}

/// Empty state view.
struct EmptyInboxView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No threads found")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Pagination controls.
struct InboxPaginationView: View {
    @Bindable var threadsViewModel: ThreadsViewModel

    var body: some View {
        HStack {
            Button {
                Task {
                    await threadsViewModel.previousPage()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
            }
            .disabled(threadsViewModel.offset == 0)

            Spacer()

            Text("Page \(currentPage)")
                .foregroundColor(.secondary)
                .font(.subheadline)

            Spacer()

            Button {
                Task {
                    await threadsViewModel.nextPage()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Next")
                    Image(systemName: "chevron.right")
                }
            }
            .disabled(!threadsViewModel.hasMoreThreads)
        }
        .padding()
        .background(Color(.systemBackground))
    }

    private var currentPage: Int {
        (threadsViewModel.offset / threadsViewModel.limit) + 1
    }
}
