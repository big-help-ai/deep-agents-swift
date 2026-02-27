import SwiftUI
import LiveKit

/// A unified chat + voice call view. Chat is the default mode; tapping the phone button
/// transitions to an in-call UI sharing the same LangGraph thread.
public struct ChatCallView: View {
    @Environment(ChatService.self) private var chatService
    @Environment(ThreadService.self) private var threadService
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    let assistantId: String
    @ObservedObject var callManager: CallManager

    @State private var showThreadList = false
    @State private var columnVisibility: NavigationSplitViewVisibility = .detailOnly
    @State private var hasInitialized = false
    @State private var callThreadId: String?
    @State private var errorMessage: String?

    public init(assistantId: String, callManager: CallManager) {
        self.assistantId = assistantId
        self.callManager = callManager
    }

    public var body: some View {
        Group {
            if callManager.callState.isActive {
                callModeView
            } else if horizontalSizeClass == .compact {
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
        .onChange(of: callManager.callState.isActive) { wasActive, isActive in
            if wasActive && !isActive, let threadId = callThreadId {
                // Call just ended — force reload thread to show voice messages
                // Toggle threadId off/on to force StreamManager to re-fetch
                chatService.setThreadId(nil)
                chatService.setThreadId(threadId)
                callThreadId = nil
            }
        }
        .onChange(of: callManager.callState.errorMessage) { _, message in
            if let message {
                errorMessage = message
            }
        }
        .alert("Call Failed", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil; callManager.callState = .idle } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Call Mode

    private var callModeView: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 16) {
                callStatusIcon
                callStatusText
            }

            Spacer()

            HStack(spacing: 40) {
                // Mute button
                Button {
                    let newMuted = !callManager.isMuted
                    callManager.isMuted = newMuted
                    Task {
                        try? await callManager.room.localParticipant.setMicrophone(enabled: !newMuted)
                    }
                } label: {
                    Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                        .font(.title)
                        .foregroundStyle(callManager.isMuted ? .red : .white)
                        .frame(width: 60, height: 60)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Circle())
                }

                // Hangup button
                Button {
                    Task {
                        await callManager.endCall()
                    }
                } label: {
                    Image(systemName: "phone.down.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Color.red)
                        .clipShape(Circle())
                }
            }
            .padding(.bottom, 60)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
    }

    private var callStatusIcon: some View {
        Group {
            switch callManager.callState {
            case .connected:
                AudioWaveformView(level: callManager.remoteAudioLevel)
            case .activeOutgoing:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
            case .errored:
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
            default:
                Image(systemName: "phone.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.white)
            }
        }
    }

    private var callStatusText: some View {
        Group {
            switch callManager.callState {
            case .connected:
                Text("Connected")
                    .foregroundStyle(.green)
            case .activeOutgoing:
                Text("Connecting...")
                    .foregroundStyle(.white.opacity(0.7))
            case .errored(let error):
                Text("Error: \(error.localizedDescription)")
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            default:
                Text("Call")
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .font(.title3)
    }

    // MARK: - Phone Button Action

    private func startCallFromChat() {
        Task {
            do {
                // Ensure a thread exists
                var currentThreadId = chatService.threadId
                print("[ChatCallView] startCallFromChat: chatService.threadId = \(currentThreadId ?? "nil")")
                if currentThreadId == nil {
                    print("[ChatCallView] No thread exists, creating new one...")
                    let thread = try await chatService.client.threads.create()
                    currentThreadId = thread["thread_id"].stringValue
                    print("[ChatCallView] Created thread: \(currentThreadId ?? "nil")")
                    chatService.setThreadId(currentThreadId)
                } else {
                    print("[ChatCallView] Reusing existing thread: \(currentThreadId!)")
                }

                // Track for reload after call ends
                callThreadId = currentThreadId

                print("[ChatCallView] Starting call with threadId: \(currentThreadId ?? "nil"), graphName: \(assistantId)")
                callManager.selectedGraphName = assistantId
                await callManager.startCall(handle: "user1", threadId: currentThreadId)
            } catch {
                print("[ChatCallView] startCallFromChat failed: \(error)")
                callManager.callState = .errored(error)
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

            // Phone button
            Button {
                startCallFromChat()
            } label: {
                Image(systemName: "phone.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            Button {
                chatService.setThreadId(nil)
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.title2)
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

            // Phone button
            Button {
                startCallFromChat()
            } label: {
                Image(systemName: "phone.fill")
                    .font(.title2)
            }
            .buttonStyle(.plain)

            Button {
                chatService.setThreadId(nil)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "square.and.pencil")
                        .font(.title2)
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
