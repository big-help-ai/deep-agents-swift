import SwiftUI

// MARK: - Config Dialog View

public struct ConfigDialogView: View {
    let initialConfig: StandaloneConfig?
    let onSave: (StandaloneConfig) -> Void
    let onCancel: () -> Void

    @State private var deploymentUrl: String = ""
    @State private var assistantId: String = ""
    @State private var langsmithApiKey: String = ""

    public init(
        initialConfig: StandaloneConfig? = nil,
        onSave: @escaping (StandaloneConfig) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.initialConfig = initialConfig
        self.onSave = onSave
        self.onCancel = onCancel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Deployment URL", text: $deploymentUrl)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    TextField("Assistant ID", text: $assistantId)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Required")
                } footer: {
                    Text("Enter your LangGraph deployment URL and assistant ID.")
                }

                Section {
                    SecureField("LangSmith API Key", text: $langsmithApiKey)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Optional")
                } footer: {
                    Text("Provide your LangSmith API key for authentication if required.")
                }
            }
            .navigationTitle("Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let config = initialConfig {
                    deploymentUrl = config.deploymentUrl
                    assistantId = config.assistantId
                    langsmithApiKey = config.langsmithApiKey ?? ""
                }
            }
        }
    }

    private var isValid: Bool {
        !deploymentUrl.trimmingCharacters(in: .whitespaces).isEmpty &&
        !assistantId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        let config = StandaloneConfig(
            deploymentUrl: deploymentUrl.trimmingCharacters(in: .whitespaces),
            assistantId: assistantId.trimmingCharacters(in: .whitespaces),
            langsmithApiKey: langsmithApiKey.isEmpty ? nil : langsmithApiKey.trimmingCharacters(in: .whitespaces)
        )
        onSave(config)
    }
}
