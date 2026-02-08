import Foundation
import SwiftyJSON
import Combine

/// View model for handling interrupted thread actions.
@MainActor
@Observable
public final class InterruptedActionsViewModel {
    // MARK: - Properties

    public var humanResponse: [HumanResponseWithEdits] = []
    public var loading = false
    public var selectedSubmitType: SubmitType?
    public var hasAddedResponse = false
    public var acceptAllowed = false
    public var errorMessage: String?

    // MARK: - Dependencies

    public let threadData: ThreadData
    private let threadsViewModel: ThreadsViewModel

    // MARK: - Computed Properties

    public var isIgnoreAllowed: Bool {
        threadData.firstInterrupt?.config.allowIgnore ?? true
    }

    public var supportsMultipleMethods: Bool {
        humanResponse.filter { [.accept, .response].contains($0.type) }.count > 1
    }

    // MARK: - Initialization

    public init(threadData: ThreadData, threadsViewModel: ThreadsViewModel) {
        self.threadData = threadData
        self.threadsViewModel = threadsViewModel

        setupInitialResponse()
    }

    private func setupInitialResponse() {
        guard let interrupts = threadData.interrupts, !interrupts.isEmpty else {
            humanResponse = [HumanResponseWithEdits(type: .ignore, args: .null)]
            return
        }

        var unusedValues: [String: String] = [:]
        let result = createDefaultHumanResponse(
            from: interrupts,
            initialValues: &unusedValues
        )

        humanResponse = result.responses
        selectedSubmitType = result.defaultSubmitType
        acceptAllowed = result.hasAccept
    }

    // MARK: - Actions

    /// Handle submit action.
    public func handleSubmit() async {
        guard let submitType = selectedSubmitType else {
            errorMessage = "Please select a response type"
            return
        }

        // Find the response matching the submit type
        guard let response = humanResponse.first(where: { $0.type.rawValue == submitType.rawValue }) else {
            errorMessage = "No response found for type \(submitType)"
            return
        }

        // Build the human response to send
        let humanResponseToSend = response.toHumanResponse()

        loading = true
        errorMessage = nil

        do {
            _ = try await threadsViewModel.sendHumanResponse(
                threadId: threadData.thread.threadId,
                responses: [humanResponseToSend]
            )

            // Success - refresh threads and go back to list
            await threadsViewModel.fetchThreads()
            threadsViewModel.selectedThreadId = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        loading = false
    }

    /// Handle ignore action.
    public func handleIgnore() async {
        loading = true
        errorMessage = nil

        let ignoreResponse = HumanResponse(type: .ignore, args: .null)

        do {
            _ = try await threadsViewModel.sendHumanResponse(
                threadId: threadData.thread.threadId,
                responses: [ignoreResponse]
            )

            await threadsViewModel.fetchThreads()
            threadsViewModel.selectedThreadId = nil
        } catch {
            errorMessage = error.localizedDescription
        }

        loading = false
    }

    // MARK: - Response Updates

    /// Update the response text for response type.
    public func updateResponseText(_ text: String) {
        if let index = humanResponse.firstIndex(where: { $0.type == .response }) {
            humanResponse[index].args = .string(text)
            hasAddedResponse = !text.isEmpty
        }
    }

    /// Select a submit type.
    public func selectSubmitType(_ type: SubmitType) {
        selectedSubmitType = type
    }
}
