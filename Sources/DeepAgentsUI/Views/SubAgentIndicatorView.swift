import SwiftUI
import SwiftyJSON

// MARK: - Sub Agent Indicator View

public struct SubAgentIndicatorView: View {
    let subAgent: SubAgent

    @State private var isExpanded = false

    public init(subAgent: SubAgent) {
        self.subAgent = subAgent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header button
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    statusIcon

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sub-agent: \(subAgent.subAgentName)")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        if !isExpanded {
                            Text(inputSummary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }

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

                VStack(alignment: .leading, spacing: 16) {
                    // Input section
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Input")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        Text(extractSubAgentContent(subAgent.input))
                            .font(.caption)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    // Output section (if available)
                    if let output = subAgent.output {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Output")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)

                            Text(extractSubAgentContent(output))
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .tertiarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }

                    // Status section
                    HStack {
                        Text("Status:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(statusLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(12)
            }
        }
        .background(Color.purple.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Helpers

    @ViewBuilder
    private var statusIcon: some View {
        switch subAgent.status {
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .active:
            Image(systemName: "circle.dotted")
                .foregroundStyle(.orange)
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(.secondary)
        case .error:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        }
    }

    private var statusLabel: String {
        switch subAgent.status {
        case .pending: return "Pending"
        case .active: return "Running"
        case .completed: return "Completed"
        case .error: return "Error"
        }
    }

    private var inputSummary: String {
        let content = extractSubAgentContent(subAgent.input)
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count > 50 {
            return String(trimmed.prefix(50)) + "..."
        }
        return trimmed
    }
}
