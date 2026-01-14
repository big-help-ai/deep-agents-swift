import SwiftUI

// MARK: - Home View

public struct HomeView: View {
    @Environment(ChatService.self) private var chatService
    @Environment(ThreadService.self) private var threadService

    let config: StandaloneConfig
    @Binding var showConfigDialog: Bool
    let onSaveConfig: (StandaloneConfig) -> Void

    @State private var showSidebar = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly

    public init(
        config: StandaloneConfig,
        showConfigDialog: Binding<Bool>,
        onSaveConfig: @escaping (StandaloneConfig) -> Void
    ) {
        self.config = config
        self._showConfigDialog = showConfigDialog
        self.onSaveConfig = onSaveConfig
    }

    public var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            ThreadListView(
                onThreadSelect: { threadId in
                    chatService.setThreadId(threadId)
                },
                onClose: {
                    columnVisibility = .detailOnly
                }
            )
            .navigationTitle("Threads")
        } detail: {
            VStack(spacing: 0) {
                // Header
                headerView

                // Chat Interface
                ChatInterfaceView()
            }
        }
        .navigationSplitViewStyle(.balanced)
        .task {
            await chatService.fetchAssistant(assistantId: config.assistantId)
            await threadService.refresh()

            // Set up revalidation callback
            chatService.onHistoryRevalidate = {
                Task {
                    await threadService.refresh()
                }
            }
        }
    }

    private var headerView: some View {
        HStack {
            Text("Deep Agent UI")
                .font(.headline)

            if columnVisibility == .detailOnly {
                Button {
                    columnVisibility = .all
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "message.fill")
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
                    }
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            HStack(spacing: 8) {
                Text("Assistant: \(config.assistantId)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Button {
                    showConfigDialog = true
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.bordered)

                Button {
                    chatService.setThreadId(nil)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                        Text("New Thread")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(red: 0.18, green: 0.41, blue: 0.41))
                .disabled(chatService.threadId == nil)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }
}
