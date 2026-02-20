import SwiftUI
import SwiftyJSON

// MARK: - Chat Message View

public struct ChatMessageView: View {
    let message: Message
    let toolCalls: [ToolCall]
    let isLoading: Bool
    let interruptsMap: [String: HumanInterrupt]
    let onResumeInterrupt: (JSON) -> Void

    public init(
        message: Message,
        toolCalls: [ToolCall],
        isLoading: Bool = false,
        interruptsMap: [String: HumanInterrupt] = [:],
        onResumeInterrupt: @escaping (JSON) -> Void = { _ in }
    ) {
        self.message = message
        self.toolCalls = toolCalls
        self.isLoading = isLoading
        self.interruptsMap = interruptsMap
        self.onResumeInterrupt = onResumeInterrupt
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.type == .human {
                Spacer(minLength: 60)
                humanMessageView
            } else {
                aiMessageView
                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Human Message

    private var humanMessageView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text(message.contentString)
                .padding(12)
                .background(Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    // MARK: - AI Message

    private var aiMessageView: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Avatar
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(.purple)

                Text("Assistant")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Content
            let contentString = message.contentString
            if !contentString.isEmpty {
                MarkdownContentView(content: contentString)
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Sub-agents (task tool calls)
            ForEach(subAgents) { subAgent in
                SubAgentIndicatorView(subAgent: subAgent)
            }

            // Tool calls (excluding "task" tool)
            ForEach(nonTaskToolCalls) { toolCall in
                ToolCallBoxView(
                    toolCall: toolCall,
                    interrupt: interruptsMap[toolCall.name],
                    onResume: onResumeInterrupt,
                    isLoading: isLoading
                )
            }
        }
    }

    // MARK: - Helpers

    private var nonTaskToolCalls: [ToolCall] {
        toolCalls.filter { $0.name != "task" }
    }

    private var subAgents: [SubAgent] {
        toolCalls
            .filter { $0.name == "task" }
            .map { toolCall in
                SubAgent(
                    id: toolCall.id,
                    name: toolCall.name,
                    subAgentName: toolCall.args["name"].stringValue,
                    input: toolCall.args,
                    output: toolCall.result.map { JSON(parseJSON: $0) },
                    status: mapToolCallStatusToSubAgentStatus(toolCall.status)
                )
            }
    }

    private func mapToolCallStatusToSubAgentStatus(_ status: ToolCallStatus) -> SubAgentStatus {
        switch status {
        case .pending: return .pending
        case .completed: return .completed
        case .error: return .error
        case .interrupted: return .active
        }
    }
}
