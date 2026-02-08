import SwiftUI

/// Detail view for a single thread.
public struct ThreadDetailView: View {
    let threadData: ThreadData
    @Bindable var threadsViewModel: ThreadsViewModel
    let inboxManager: InboxManager

    @State private var showDescription = true
    @State private var showState = false

    public init(threadData: ThreadData, threadsViewModel: ThreadsViewModel, inboxManager: InboxManager) {
        self.threadData = threadData
        self.threadsViewModel = threadsViewModel
        self.inboxManager = inboxManager
    }

    public var body: some View {
        GeometryReader { geometry in
            if geometry.size.width > 700 {
                // iPad / large screen: side-by-side layout
                HStack(spacing: 0) {
                    // Main content
                    ThreadActionsView(
                        threadData: threadData,
                        showState: showState,
                        showDescription: showDescription,
                        onToggleSidePanel: toggleSidePanel,
                        threadsViewModel: threadsViewModel
                    )
                    .frame(maxWidth: .infinity)

                    // Side panel
                    if showDescription || showState {
                        Divider()
                        StateView(
                            threadData: threadData,
                            showState: showState,
                            onClose: { toggleSidePanel(state: false, description: false) }
                        )
                        .frame(width: min(400, geometry.size.width * 0.4))
                    }
                }
            } else {
                // iPhone: stacked layout with navigation
                ThreadActionsView(
                    threadData: threadData,
                    showState: showState,
                    showDescription: showDescription,
                    onToggleSidePanel: toggleSidePanel,
                    threadsViewModel: threadsViewModel
                )
            }
        }
        .navigationTitle(threadData.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    threadsViewModel.selectedThreadId = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Inbox")
                    }
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        toggleSidePanel(state: true, description: false)
                    } label: {
                        Label("Show State", systemImage: showState ? "checkmark" : "")
                    }

                    Button {
                        toggleSidePanel(state: false, description: true)
                    } label: {
                        Label("Show Description", systemImage: showDescription ? "checkmark" : "")
                    }

                    Divider()

                    if let inbox = inboxManager.selectedInbox,
                       let studioURL = constructOpenInStudioURL(
                        inbox: inbox,
                        threadId: threadData.thread.threadId
                    ) {
                        Link(destination: studioURL) {
                            Label("Open in Studio", systemImage: "arrow.up.right.square")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .onAppear {
            setupInitialView()
        }
    }

    private func setupInitialView() {
        if let description = threadData.firstInterrupt?.description, !description.isEmpty {
            showDescription = true
            showState = false
        } else {
            showState = true
            showDescription = false
        }
    }

    private func toggleSidePanel(state: Bool, description: Bool) {
        withAnimation {
            showState = state
            showDescription = description
        }
    }
}
