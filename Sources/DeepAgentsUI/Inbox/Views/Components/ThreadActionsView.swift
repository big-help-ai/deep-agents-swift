import SwiftUI
import SwiftyJSON

/// View for thread actions and response input.
public struct ThreadActionsView: View {
    let threadData: ThreadData
    let showState: Bool
    let showDescription: Bool
    let onToggleSidePanel: (Bool, Bool) -> Void
    @Bindable var threadsViewModel: ThreadsViewModel

    @State private var actionsViewModel: InterruptedActionsViewModel?

    public init(
        threadData: ThreadData,
        showState: Bool,
        showDescription: Bool,
        onToggleSidePanel: @escaping (Bool, Bool) -> Void,
        threadsViewModel: ThreadsViewModel
    ) {
        self.threadData = threadData
        self.showState = showState
        self.showDescription = showDescription
        self.onToggleSidePanel = onToggleSidePanel
        self.threadsViewModel = threadsViewModel
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Header with thread info
                    ThreadHeaderView(threadData: threadData)

                    Divider()

                    // Content based on thread state
                    if let vm = actionsViewModel {
                        if threadData.invalidSchema {
                            InvalidSchemaView(
                                onIgnore: { Task { await vm.handleIgnore() } },
                                loading: vm.loading
                            )
                        } else if threadData.isInterrupted {
                            InterruptedContentView(actionsViewModel: vm, scrollProxy: proxy)
                        } else {
                            NonInterruptedContentView(threadData: threadData, threadsViewModel: threadsViewModel)
                        }
                    } else {
                        ProgressView()
                    }
                }
                .padding()
            }
        }
        .onAppear {
            actionsViewModel = InterruptedActionsViewModel(
                threadData: threadData,
                threadsViewModel: threadsViewModel
            )
        }
    }
}

/// Thread header with ID and dates.
struct ThreadHeaderView: View {
    let threadData: ThreadData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Thread ID row
            HStack {
                Label {
                    Text(threadData.thread.threadId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                } icon: {
                    Image(systemName: "number")
                }

                Spacer()

                Button {
                    UIPasteboard.general.string = threadData.thread.threadId
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.borderless)
            }

            // Status and dates
            HStack(spacing: 16) {
                InboxStatusBadge(status: threadData.status)

                Text("Created: \(formatInboxDate(threadData.thread.createdAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("Updated: \(formatInboxDate(threadData.thread.updatedAt))")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

/// View for invalid schema threads.
struct InvalidSchemaView: View {
    let onIgnore: () -> Void
    let loading: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Warning banner
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.yellow)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Invalid Interrupt Schema")
                        .font(.headline)
                    Text("This thread is interrupted, but the required action data is missing or invalid. Standard interrupt actions cannot be performed.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .cornerRadius(12)

            // Ignore button
            Button(action: onIgnore) {
                HStack {
                    if loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text("Ignore Thread")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(loading)
        }
    }
}

/// Content for interrupted threads with valid schema.
struct InterruptedContentView: View {
    @Bindable var actionsViewModel: InterruptedActionsViewModel
    let scrollProxy: ScrollViewProxy

    private var isRespondMode: Bool {
        actionsViewModel.selectedSubmitType == .response
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Action request details
            if let interrupt = actionsViewModel.threadData.firstInterrupt {
                ActionRequestCard(interrupt: interrupt)
            }

            // Show either approval buttons OR response input (not both)
            if isRespondMode {
                // Response mode: text field + send button
                ResponseInputView(actionsViewModel: actionsViewModel, scrollProxy: scrollProxy)
            } else {
                // Approval mode: approve/cancel buttons
                ApprovalButtonsView(actionsViewModel: actionsViewModel)
            }

            // Error message
            if let error = actionsViewModel.errorMessage {
                InboxErrorBanner(message: error)
            }
        }
    }
}

/// Reject input with feedback textbox and send button.
struct ResponseInputView: View {
    @Bindable var actionsViewModel: InterruptedActionsViewModel
    let scrollProxy: ScrollViewProxy
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rejection Feedback")
                    .font(.caption)
                    .foregroundColor(.secondary)

                TextEditor(text: Binding(
                    get: {
                        if let response = actionsViewModel.humanResponse.first(where: { $0.type == .response }),
                           case .string(let str) = response.args {
                            return str
                        }
                        return ""
                    },
                    set: { actionsViewModel.updateResponseText($0) }
                ))
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
                .focused($isTextFieldFocused)
            }

            // Send Reject button
            Button {
                Task { await actionsViewModel.handleSubmit() }
            } label: {
                HStack {
                    if actionsViewModel.loading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "xmark.circle.fill")
                    }
                    Text("Send Reject")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .disabled(actionsViewModel.loading)

            // Back button
            Button {
                actionsViewModel.selectSubmitType(.accept)
            } label: {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.subheadline)
            }
            .buttonStyle(.borderless)

            // Spacer to allow scrolling past keyboard
            Spacer()
                .frame(height: 300)
                .id("scrollAnchor")
        }
        .onAppear {
            isTextFieldFocused = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    scrollProxy.scrollTo("scrollAnchor", anchor: .bottom)
                }
            }
        }
    }
}

/// Card displaying the action request details.
struct ActionRequestCard: View {
    let interrupt: HumanInterrupt

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Action name
            HStack {
                Image(systemName: "hand.raised.fill")
                    .foregroundColor(.orange)
                Text(interrupt.actionRequest.action.prettified)
                    .font(.headline)
            }

            // Description if available
            if let description = interrupt.description, !description.isEmpty {
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // Action details (read-only)
            if !interrupt.actionRequest.args.isEmpty {
                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Details")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)

                    ForEach(Array(interrupt.actionRequest.args.dictionaryValue.keys.sorted()), id: \.self) { key in
                        HStack(alignment: .top) {
                            Text(key.prettified + ":")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 100, alignment: .leading)

                            Text(interrupt.actionRequest.args[key].stringValue)
                                .font(.subheadline)

                            Spacer()
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

/// Approval action buttons.
struct ApprovalButtonsView: View {
    @Bindable var actionsViewModel: InterruptedActionsViewModel

    private var canApprove: Bool {
        actionsViewModel.humanResponse.contains { $0.type == .accept }
    }

    private var canReject: Bool {
        actionsViewModel.humanResponse.contains { $0.type == .response }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Approve button
            if canApprove {
                Button {
                    actionsViewModel.selectSubmitType(.accept)
                    Task { await actionsViewModel.handleSubmit() }
                } label: {
                    HStack {
                        if actionsViewModel.loading && actionsViewModel.selectedSubmitType == .accept {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Approve")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
                .disabled(actionsViewModel.loading)
            }

            // Reject button - switches to response mode
            if canReject {
                Button {
                    actionsViewModel.selectSubmitType(.response)
                } label: {
                    HStack {
                        Image(systemName: "xmark.circle.fill")
                        Text("Reject")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(actionsViewModel.loading)
            }
        }
    }
}

/// Content for non-interrupted threads.
struct NonInterruptedContentView: View {
    let threadData: ThreadData
    @State private var refreshing = false
    @Bindable var threadsViewModel: ThreadsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Status-specific content
            switch threadData.status {
            case .idle, .busy:
                Button {
                    Task {
                        refreshing = true
                        _ = await threadsViewModel.fetchSingleThread(threadId: threadData.thread.threadId)
                        refreshing = false
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .rotationEffect(.degrees(refreshing ? 360 : 0))
                            .animation(refreshing ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: refreshing)
                        Text("Refresh Thread Status")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(refreshing)

            case .error:
                InboxErrorBanner(message: "This thread is in an error state. Check the logs or retry the operation.")

            default:
                EmptyView()
            }

            // Thread details card
            ThreadDetailsCard(threadData: threadData)
        }
    }
}

/// Card showing thread details.
struct ThreadDetailsCard: View {
    let threadData: ThreadData

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thread Details")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                InboxDetailRow(label: "Status", value: threadData.status.displayName)
                InboxDetailRow(label: "Created", value: formatInboxDate(threadData.thread.createdAt))
                InboxDetailRow(label: "Updated", value: formatInboxDate(threadData.thread.updatedAt))
                InboxDetailRow(label: "ID", value: String(threadData.thread.threadId.prefix(12)) + "...")
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct InboxDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
        }
    }
}

/// Error banner.
public struct InboxErrorBanner: View {
    let message: String

    public init(message: String) {
        self.message = message
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)

            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }
}
