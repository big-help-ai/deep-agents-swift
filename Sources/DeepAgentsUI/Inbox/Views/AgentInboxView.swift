import SwiftUI

/// Main inbox view that routes between list and detail views.
public struct AgentInboxView: View {
    @Bindable var threadsViewModel: ThreadsViewModel

    public init(threadsViewModel: ThreadsViewModel) {
        self.threadsViewModel = threadsViewModel
    }

    public var body: some View {
        Group {
            if let threadId = threadsViewModel.selectedThreadId,
               let threadData = threadsViewModel.threadData.first(where: { $0.thread.threadId == threadId }) {
                ThreadDetailView(threadData: threadData, threadsViewModel: threadsViewModel, inboxManager: threadsViewModel.inboxesManager)
            } else {
                InboxListView(threadsViewModel: threadsViewModel)
            }
        }
    }
}
