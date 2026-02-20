import SwiftUI

// MARK: - Agent Chat View

public struct AgentChatView: View {
    @Environment(ChatService.self) private var chatService
    @Environment(ThreadService.self) private var threadService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let assistantId: String

    @State private var showThreadList = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var hasInitialized = false

    public init(assistantId: String) {
        self.assistantId = assistantId
    }

    public var body: some View {
        Group {
            if horizontalSizeClass == .compact {
                compactLayout
            } else {
                regularLayout
            }
        }
        .task {
            guard !hasInitialized else { return }
            hasInitialized = true

            await chatService.fetchAssistant(assistantId: assistantId)
            await threadService.refresh()

            chatService.onHistoryRevalidate = {
                Task {
                    await threadService.refresh()
                }
            }
        }
    }

    // MARK: - Compact Layout (iPhone)

    private var compactLayout: some View {
        NavigationStack {
            VStack(spacing: 0) {
                compactHeaderView
                ChatInterfaceView()
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showThreadList) {
            NavigationStack {
                ThreadListView(
                    onThreadSelect: { threadId in
                        chatService.setThreadId(threadId)
                        showThreadList = false
                    },
                    onClose: {
                        showThreadList = false
                    }
                )
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            showThreadList = false
                        }
                    }
                }
            }
            .environment(threadService)
        }
    }

    private var compactHeaderView: some View {
        HStack {
            Button {
                showThreadList = true
            } label: {
                HStack(spacing: 4) {
                    Text("Threads")
                    if threadService.interruptCount > 0 {
                        Text("\(threadService.interruptCount)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.red)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    Image(systemName: "chevron.down")
                        .font(.caption)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                chatService.setThreadId(nil)
            } label: {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(.plain)
            .disabled(chatService.threadId == nil)
            .opacity(chatService.threadId == nil ? 0.3 : 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Regular Layout (iPad)

    private var regularLayout: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ThreadListView(
                onThreadSelect: { threadId in
                    chatService.setThreadId(threadId)
                    columnVisibility = .detailOnly
                },
                onClose: {
                    columnVisibility = .detailOnly
                }
            )
            .navigationTitle("Threads")
        } detail: {
            VStack(spacing: 0) {
                regularHeaderView
                ChatInterfaceView()
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private var regularHeaderView: some View {
        HStack {
            if columnVisibility == .detailOnly {
                Button {
                    columnVisibility = .all
                } label: {
                    HStack(spacing: 4) {
                        Text("Threads")
                        if threadService.interruptCount > 0 {
                            Text("\(threadService.interruptCount)")
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(.red)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                        }
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button {
                chatService.setThreadId(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                    Text("New Thread")
                }
            }
            .buttonStyle(.plain)
            .disabled(chatService.threadId == nil)
            .opacity(chatService.threadId == nil ? 0.3 : 1)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
