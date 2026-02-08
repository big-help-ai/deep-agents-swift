import SwiftUI
import SwiftyJSON

// MARK: - Chat Interface View

public struct ChatInterfaceView: View {
    @Environment(ChatService.self) private var chatService

    @State private var inputText = ""
    @State private var metaOpen: MetaSection? = nil
    @State private var showFilesPopover = false

    private enum MetaSection {
        case tasks
        case files
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Messages area
            messagesView

            // Input area
            inputAreaView
        }
    }

    // MARK: - Messages View

    private var messagesView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    if chatService.isThreadLoading {
                        loadingView
                    } else {
                        ForEach(processedMessages) { item in
                            ChatMessageView(
                                message: item.message,
                                toolCalls: item.toolCalls,
                                isLoading: chatService.isLoading,
                                actionRequestsMap: item.isLastMessage ? actionRequestsMap : [:],
                                reviewConfigsMap: item.isLastMessage ? reviewConfigsMap : [:],
                                onResumeInterrupt: { value in
                                    chatService.resumeInterrupt(value: value)
                                }
                            )
                            .id(item.message.id)
                        }
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .onTapGesture {
                hideKeyboard()
            }
            .onChange(of: chatService.messages.count) { _, _ in
                // Scroll to last processed message (not raw message, which might be a tool message)
                if let lastProcessed = processedMessages.last {
                    withAnimation {
                        proxy.scrollTo(lastProcessed.message.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var loadingView: some View {
        HStack {
            Spacer()
            ProgressView()
                .padding()
            Spacer()
        }
    }

    // MARK: - Input Area View

    private var inputAreaView: some View {
        VStack(spacing: 0) {
            // Tasks/Files section
            if hasTasks || hasFiles {
                tasksFilesSection
            }

            // Text input
            HStack(alignment: .bottom, spacing: 12) {
                TextField("Write your message...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .lineLimit(1...10)
                    .disabled(chatService.isLoading)
                    .onSubmit {
                        sendMessage()
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                        }
                    }

                Button {
                    if chatService.isLoading {
                        chatService.stopStream()
                    } else {
                        sendMessage()
                    }
                } label: {
                    Image(systemName: chatService.isLoading ? "stop.fill" : "arrow.up")
                        .frame(width: 20, height: 20)
                        .padding(.vertical, 5)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(chatService.isLoading ? .red : .blue)
                .disabled(!chatService.isLoading && (submitDisabled || inputText.trimmingCharacters(in: .whitespaces).isEmpty))
            }
            .padding()
        }
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Tasks/Files Section

    private var tasksFilesSection: some View {
        VStack(spacing: 0) {
            if metaOpen == nil {
                // Collapsed view
                HStack {
                    if hasTasks {
                        tasksSummaryButton
                    }
                    if hasFiles {
                        filesSummaryButton
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            } else {
                // Expanded view
                VStack(alignment: .leading, spacing: 0) {
                    // Tab header
                    HStack {
                        if hasTasks {
                            Button {
                                metaOpen = metaOpen == .tasks ? nil : .tasks
                            } label: {
                                Text("Tasks")
                                    .fontWeight(metaOpen == .tasks ? .semibold : .regular)
                            }
                            .buttonStyle(.plain)
                        }

                        if hasFiles {
                            Button {
                                metaOpen = metaOpen == .files ? nil : .files
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Files (State)")
                                    Text("\(chatService.files.count)")
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 2)
                                        .background(Color(red: 0.18, green: 0.41, blue: 0.41))
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .fontWeight(metaOpen == .files ? .semibold : .regular)
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer()

                        Button {
                            metaOpen = nil
                        } label: {
                            Image(systemName: "xmark")
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)

                    Divider()

                    // Content
                    ScrollView {
                        if metaOpen == .tasks {
                            tasksContent
                        } else if metaOpen == .files {
                            filesContent
                        }
                    }
                    .frame(maxHeight: 200)
                }
            }

            Divider()
        }
        .background(Color(uiColor: .secondarySystemBackground))
    }

    private var tasksSummaryButton: some View {
        Button {
            metaOpen = metaOpen == .tasks ? nil : .tasks
        } label: {
            HStack(spacing: 8) {
                statusIcon(for: activeTask?.status ?? .pending)

                if isAllCompleted {
                    Text("All tasks completed")
                        .font(.subheadline)
                } else if let activeTask = activeTask {
                    Text("Task \(completedCount) of \(totalTasks)")
                        .font(.subheadline)
                    Text(activeTask.content)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text("Task \(completedCount) of \(totalTasks)")
                        .font(.subheadline)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var filesSummaryButton: some View {
        Button {
            metaOpen = metaOpen == .files ? nil : .files
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc")
                Text("Files (State)")
                    .font(.subheadline)
                Text("\(chatService.files.count)")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color(red: 0.18, green: 0.41, blue: 0.41))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private var tasksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(groupedTodosArray, id: \.0) { status, items in
                VStack(alignment: .leading, spacing: 8) {
                    Text(statusLabel(for: status))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(items) { todo in
                        HStack(alignment: .top, spacing: 8) {
                            statusIcon(for: todo.status)
                            Text(todo.content)
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .padding()
    }

    private var filesContent: some View {
        TasksFilesSidebarView(
            files: chatService.files,
            setFiles: { newFiles in
                Task {
                    await chatService.setFiles(newFiles)
                }
            },
            editDisabled: chatService.isLoading || chatService.interrupt != nil
        )
        .padding()
    }

    // MARK: - Helpers

    private var submitDisabled: Bool {
        chatService.isLoading
    }

    private var hasTasks: Bool {
        !chatService.todos.isEmpty
    }

    private var hasFiles: Bool {
        !chatService.files.isEmpty
    }

    private var activeTask: TodoItem? {
        chatService.todos.first { $0.status == .inProgress }
    }

    private var totalTasks: Int {
        chatService.todos.count
    }

    private var completedCount: Int {
        totalTasks - chatService.todos.filter { $0.status == .pending }.count
    }

    private var isAllCompleted: Bool {
        totalTasks > 0 && totalTasks == completedCount
    }

    private var groupedTodosArray: [(TodoStatus, [TodoItem])] {
        let order: [TodoStatus] = [.inProgress, .pending, .completed]
        return order.compactMap { status -> (TodoStatus, [TodoItem])? in
            let items = chatService.todos.filter { $0.status == status }
            return items.isEmpty ? nil : (status, items)
        }
    }

    private func statusLabel(for status: TodoStatus) -> String {
        switch status {
        case .pending: return "Pending"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        }
    }

    @ViewBuilder
    private func statusIcon(for status: TodoStatus) -> some View {
        switch status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .inProgress:
            Image(systemName: "clock.fill")
                .foregroundStyle(.orange)
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        chatService.sendMessage(text)
        inputText = ""
    }

    // MARK: - Processed Messages

    private var processedMessages: [ProcessedMessage] {
        var messageMap: [String: ProcessedMessage] = [:]
        var orderedIds: [String] = []

        for message in chatService.messages {
            if message.type == .ai {
                var toolCallsDict: [String: ToolCall] = [:]

                // Extract tool calls from additional_kwargs
                if let additionalKwargs = message.additionalKwargs,
                   let calls = additionalKwargs["tool_calls"].array {
                    for call in calls {
                        let id = call["id"].stringValue
                        if !id.isEmpty && toolCallsDict[id] == nil {
                            let toolCall = ToolCall(
                                id: id,
                                name: call["function"]["name"].stringValue,
                                args: call["function"]["arguments"],
                                status: chatService.interrupt != nil ? .interrupted : .pending
                            )
                            toolCallsDict[id] = toolCall
                        }
                    }
                }

                // Extract tool calls from tool_calls property
                if let calls = message.toolCalls {
                    for call in calls where call["name"].stringValue != "" {
                        let id = call["id"].stringValue
                        if !id.isEmpty && toolCallsDict[id] == nil {
                            let toolCall = ToolCall(
                                id: id,
                                name: call["name"].stringValue,
                                args: call["args"],
                                status: chatService.interrupt != nil ? .interrupted : .pending
                            )
                            toolCallsDict[id] = toolCall
                        }
                    }
                }

                // Extract tool_use blocks from content array
                if let contentArray = message.content.array {
                    for block in contentArray where block["type"].stringValue == "tool_use" {
                        let id = block["id"].stringValue
                        if !id.isEmpty && toolCallsDict[id] == nil {
                            let toolCall = ToolCall(
                                id: id,
                                name: block["name"].stringValue,
                                args: block["input"],
                                status: chatService.interrupt != nil ? .interrupted : .pending
                            )
                            toolCallsDict[id] = toolCall
                        }
                    }
                }

                let toolCalls = Array(toolCallsDict.values)

                messageMap[message.id] = ProcessedMessage(
                    message: message,
                    toolCalls: toolCalls,
                    isLastMessage: false
                )
                orderedIds.append(message.id)

            } else if message.type == .tool {
                guard let toolCallId = message.toolCallId else { continue }

                // Find the AI message that has this tool call
                for id in orderedIds {
                    if var processed = messageMap[id] {
                        if let idx = processed.toolCalls.firstIndex(where: { $0.id == toolCallId }) {
                            processed.toolCalls[idx].status = .completed
                            processed.toolCalls[idx].result = extractStringFromMessageContent(message)
                            messageMap[id] = processed
                            break
                        }
                    }
                }

            } else if message.type == .human {
                messageMap[message.id] = ProcessedMessage(
                    message: message,
                    toolCalls: [],
                    isLastMessage: false
                )
                orderedIds.append(message.id)
            }
        }

        // Mark the last message
        if let lastId = orderedIds.last, var lastMessage = messageMap[lastId] {
            lastMessage.isLastMessage = true
            messageMap[lastId] = lastMessage
        }

        return orderedIds.compactMap { messageMap[$0] }
    }

    private var actionRequestsMap: [String: ActionRequest] {
        guard let interrupt = chatService.interrupt,
              let actionRequests = interrupt.value["action_requests"].array else {
            return [:]
        }

        var map: [String: ActionRequest] = [:]
        for ar in actionRequests {
            let request = ActionRequest(json: ar)
            map[request.name] = request
        }
        return map
    }

    private var reviewConfigsMap: [String: ReviewConfig] {
        guard let interrupt = chatService.interrupt,
              let reviewConfigs = interrupt.value["review_configs"].array else {
            return [:]
        }

        var map: [String: ReviewConfig] = [:]
        for rc in reviewConfigs {
            let config = ReviewConfig(json: rc)
            map[config.actionName] = config
        }
        return map
    }
}

// MARK: - Processed Message

private struct ProcessedMessage: Identifiable {
    let message: Message
    var toolCalls: [ToolCall]
    var isLastMessage: Bool

    var id: String { message.id }
}
