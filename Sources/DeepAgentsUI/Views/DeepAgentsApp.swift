import SwiftUI

// MARK: - Deep Agents App

@main
public struct DeepAgentsApp: App {
    @State private var chatService: ChatService?
    @State private var threadService = ThreadService()
    @State private var config: StandaloneConfig?
    @State private var showConfigDialog = false

    public init() {}

    public var body: some Scene {
        WindowGroup {
            Group {
                if let config = config, let chatService = chatService {
                    AgentChatView(
                        config: config,
                        showConfigDialog: $showConfigDialog,
                        onSaveConfig: saveConfig
                    )
                    .environment(chatService)
                    .environment(threadService)
                } else {
                    WelcomeView(
                        showConfigDialog: $showConfigDialog,
                        onSaveConfig: saveConfig
                    )
                }
            }
            .sheet(isPresented: $showConfigDialog) {
                ConfigDialogView(
                    initialConfig: config,
                    onSave: saveConfig,
                    onCancel: { showConfigDialog = false }
                )
            }
            .onAppear {
                loadConfig()
            }
        }
    }

    private func loadConfig() {
        if let savedConfig = getConfig() {
            config = savedConfig
            initializeServices(with: savedConfig)
        } else {
            showConfigDialog = true
        }
    }

    private func saveConfig(_ newConfig: StandaloneConfig) {
        DeepAgentsUI.saveConfig(newConfig)
        config = newConfig
        initializeServices(with: newConfig)
        showConfigDialog = false
    }

    private func initializeServices(with config: StandaloneConfig) {
        chatService = ChatService(
            deploymentUrl: config.deploymentUrl,
            apiKey: config.langsmithApiKey,
            assistantId: config.assistantId
        )

        threadService.configure(
            deploymentUrl: config.deploymentUrl,
            apiKey: config.langsmithApiKey,
            assistantId: config.assistantId
        )
    }
}

// MARK: - Welcome View

struct WelcomeView: View {
    @Binding var showConfigDialog: Bool
    let onSaveConfig: (StandaloneConfig) -> Void

    var body: some View {
        VStack(spacing: 20) {
            Text("Welcome to Deep Agent UI")
                .font(.title)
                .fontWeight(.bold)

            Text("Configure your deployment to get started")
                .foregroundStyle(.secondary)

            Button("Open Configuration") {
                showConfigDialog = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
