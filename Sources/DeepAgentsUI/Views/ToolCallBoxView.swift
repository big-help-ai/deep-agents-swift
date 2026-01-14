import SwiftUI
import SwiftyJSON

// MARK: - Tool Call Box View

public struct ToolCallBoxView: View {
    let toolCall: ToolCall
    let actionRequest: ActionRequest?
    let reviewConfig: ReviewConfig?
    let onResume: (JSON) -> Void
    let isLoading: Bool

    @State private var isExpanded = false
    @State private var showArgs = false

    public init(
        toolCall: ToolCall,
        actionRequest: ActionRequest? = nil,
        reviewConfig: ReviewConfig? = nil,
        onResume: @escaping (JSON) -> Void = { _ in },
        isLoading: Bool = false
    ) {
        self.toolCall = toolCall
        self.actionRequest = actionRequest
        self.reviewConfig = reviewConfig
        self.onResume = onResume
        self.isLoading = isLoading
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    statusIcon

                    Text(toolCall.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    // Arguments section
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            showArgs.toggle()
                        } label: {
                            HStack {
                                Text("Arguments")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .rotationEffect(.degrees(showArgs ? 90 : 0))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)

                        if showArgs {
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(toolCall.args.rawString(.utf8, options: [.prettyPrinted]) ?? "{}")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(8)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // Result section
                    if let result = toolCall.result, !result.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Result")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            ScrollView {
                                Text(result)
                                    .font(.system(.caption, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                            .padding(8)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // Approval section
                    if toolCall.status == .interrupted, actionRequest != nil {
                        ToolApprovalInterruptView(
                            actionRequest: actionRequest!,
                            reviewConfig: reviewConfig,
                            onResume: onResume,
                            isLoading: isLoading
                        )
                    }
                }
                .padding(12)
            }
        }
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch toolCall.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .pending:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.orange)
        case .interrupted:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
        }
    }
}
