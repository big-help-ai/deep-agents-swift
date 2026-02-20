import SwiftUI
import SwiftyJSON

// MARK: - Tool Approval Interrupt View

public struct ToolApprovalInterruptView: View {
    let interrupt: HumanInterrupt
    let onResume: (JSON) -> Void
    let isLoading: Bool

    @State private var isEditMode = false
    @State private var editedArgs = ""
    @State private var rejectionMessage = ""
    @State private var showRejectionInput = false
    @State private var actionInProgress: ActionInProgress?

    private enum ActionInProgress {
        case approving
        case rejecting
        case saving
    }

    public init(
        interrupt: HumanInterrupt,
        onResume: @escaping (JSON) -> Void,
        isLoading: Bool = false
    ) {
        self.interrupt = interrupt
        self.onResume = onResume
        self.isLoading = isLoading
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)

                Text("Action requires approval")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            // Description
            if let description = interrupt.description {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Tool info
            HStack {
                Text("Tool:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(interrupt.actionRequest.action)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Arguments display or edit
            if isEditMode {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Edit Arguments")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextEditor(text: $editedArgs)
                        .font(.system(.caption, design: .monospaced))
                        .frame(minHeight: 100)
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Arguments")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(interrupt.actionRequest.args.rawString(.utf8, options: [.prettyPrinted]) ?? "{}")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(8)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Rejection message input
            if showRejectionInput {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rejection reason (optional)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    TextField("Enter reason...", text: $rejectionMessage)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
            }

            // Action buttons
            HStack(spacing: 12) {
                if isEditMode {
                    Button("Cancel") {
                        isEditMode = false
                        editedArgs = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    Button {
                        saveEdit()
                    } label: {
                        if actionInProgress == .saving {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Save & Approve")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading)
                } else if showRejectionInput {
                    Button("Cancel") {
                        showRejectionInput = false
                        rejectionMessage = ""
                    }
                    .buttonStyle(.bordered)
                    .disabled(isLoading)

                    Button {
                        reject()
                    } label: {
                        if actionInProgress == .rejecting {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Confirm Reject")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(isLoading)
                } else {
                    // Main action buttons
                    if interrupt.config.allowAccept {
                        Button {
                            approve()
                        } label: {
                            if actionInProgress == .approving {
                                ProgressView()
                                    .controlSize(.small)
                            } else {
                                Text("Approve")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                        .disabled(isLoading)
                    }

                    if interrupt.config.allowReject {
                        Button("Reject") {
                            showRejectionInput = true
                        }
                        .buttonStyle(.bordered)
                        .tint(.red)
                        .disabled(isLoading)
                    }

                    if interrupt.config.allowEdit {
                        Button("Edit") {
                            editedArgs = interrupt.actionRequest.args.rawString(.utf8, options: [.prettyPrinted]) ?? "{}"
                            isEditMode = true
                        }
                        .buttonStyle(.bordered)
                        .disabled(isLoading)
                    }
                }
            }
        }
        .padding(12)
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.yellow.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func approve() {
        actionInProgress = .approving

        let response = JSON([
            "action": interrupt.actionRequest.action,
            "decision": "approve"
        ])

        onResume(response)
    }

    private func reject() {
        actionInProgress = .rejecting

        var responseDict: [String: Any] = [
            "action": interrupt.actionRequest.action,
            "decision": "reject"
        ]

        if !rejectionMessage.isEmpty {
            responseDict["reason"] = rejectionMessage
        }

        let response = JSON(responseDict)
        onResume(response)
    }

    private func saveEdit() {
        actionInProgress = .saving

        let parsedArgs = JSON(parseJSON: editedArgs)

        let response = JSON([
            "action": interrupt.actionRequest.action,
            "decision": "approve",
            "args": parsedArgs.object
        ] as [String: Any])

        onResume(response)
    }
}
