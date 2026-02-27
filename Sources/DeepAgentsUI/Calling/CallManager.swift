/*
 * Based on LiveKit example code
 * Licensed under the Apache License, Version 2.0
 */

import LiveKit
import AVFoundation
import Combine
import Logging
import CallKit
import PushKit
import LiveKitWebRTC
import SwiftUI

/// Manages voice/video calling functionality using LiveKit and CallKit.
/// Uses the CallTokenProvider protocol for token fetching to allow customization.
@MainActor
public final class CallManager: NSObject, ObservableObject {
    private let logger = Logger(label: "DeepAgentsUI.CallManager")

    // MARK: - Published State

    @Published public var callState: CallState = .idle
    @Published public var voipToken: String?
    @Published public var activeCallUUID: UUID?
    @Published public var currentRoomName: String?
    @Published public var isMuted: Bool = false
    @Published public var selectedGraphName: String = ""
    @Published public var livekitDispatchAgentName: String = ""
    @Published public var threadId: String?

    /// Audio level of the remote agent participant (0.0–1.0).
    @Published public var remoteAudioLevel: Float = 0
    /// Audio level of the local participant (0.0–1.0).
    @Published public var localAudioLevel: Float = 0

    /// When true, prevents auto-unmuting (e.g. while coding sessions are active).
    /// Only suppresses unmuting; setting this while already unmuted won't mute the user.
    public var suppressAutoUnmute: Bool = false {
        didSet {
            guard oldValue != suppressAutoUnmute else { return }
            evaluateMuteState()
        }
    }
    private var agentIsBusy: Bool = false

    // MARK: - Audio Level Polling

    private var audioLevelTimer: Timer?

    // MARK: - LiveKit

    private var livekitToken: String?
    public let room = Room()

    // MARK: - CallKit

    private let callController = CXCallController()
    private let provider: CXProvider

    // MARK: - PushKit

    private let pushRegistry = PKPushRegistry(queue: nil)

    // MARK: - Computed Properties

    public var hasActiveCall: Bool {
        callState.isActive
    }

    public var availableGraphs: [String] {
        (try? DeepAgentsUI.configuration.availableGraphs) ?? []
    }

    // MARK: - Initialization

    public override init() {
        // Setup CallKit
        let configuration = CXProviderConfiguration()
        configuration.supportedHandleTypes = [.generic]
        configuration.maximumCallsPerCallGroup = 1
        configuration.maximumCallGroups = 1
        configuration.supportsVideo = false
        provider = CXProvider(configuration: configuration)

        // Setup PushKit
        pushRegistry.desiredPushTypes = [.voIP]

        super.init()

        provider.setDelegate(self, queue: .global(qos: .default))
        pushRegistry.delegate = self
        room.add(delegate: self)

        // Set audio session auto-config off
        AudioManager.shared.audioSession.isAutomaticConfigurationEnabled = false

        // Set audio engine off
        do {
            try AudioManager.shared.setEngineAvailability(.none)
        } catch {
            logger.critical("Failed to set audio engine availability")
        }

        // Set default graph name
        if let first = availableGraphs.first {
            selectedGraphName = first
        }
    }

    // MARK: - Call Control

    public func startCall(handle: String, threadId: String? = nil) async {
        print("[CallManager] startCall: threadId = \(threadId ?? "nil")")
        self.threadId = threadId
        let callUUID = UUID()

        let handle = CXHandle(type: .generic, value: handle)
        let startCallAction = CXStartCallAction(call: callUUID, handle: handle)
        let transaction = CXTransaction(action: startCallAction)

        do {
            try await callController.request(transaction)
            logger.debug("Started call")
            activeCallUUID = callUUID
        } catch {
            print("[CallManager] Failed to start call: \(error)")
            logger.critical("Failed to start call: \(error)")
            callState = .errored(error)
        }
    }

    public func endCall() async {
        guard let callUUID = activeCallUUID else { return }

        let endCallAction = CXEndCallAction(call: callUUID)
        let transaction = CXTransaction(action: endCallAction)

        do {
            try await callController.request(transaction)
            logger.debug("Ended call")
        } catch {
            logger.critical("Failed to end call: \(error)")
        }
    }

    public func reportIncomingCallAsync(from callerId: String, callerName: String) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            reportIncomingCallSync(from: callerId, callerName: callerName) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // NOTE: Using sync version for background mode compatibility
    // This must be nonisolated to be called from PKPushRegistryDelegate
    nonisolated public func reportIncomingCallSync(from callerId: String, callerName: String, completion: @escaping @Sendable ((any Error)?) -> Void) {
        // Access provider via MainActor.assumeIsolated since CXProvider is thread-safe
        // and this method is designed to be called from the main thread via PKPushRegistry
        MainActor.assumeIsolated {
            logger.debug("Incoming call")

            let callUUID = UUID()
            let callUpdate = CXCallUpdate()
            callUpdate.remoteHandle = CXHandle(type: .generic, value: callerId)
            callUpdate.hasVideo = false
            callUpdate.localizedCallerName = callerName

            provider.reportNewIncomingCall(with: callUUID, update: callUpdate, completion: completion)

            self.callState = .activeIncoming
            self.activeCallUUID = callUUID

            // Emit event to consuming app
            DeepAgentsUI.emit(.incomingCall(callerId: callerId, callerName: callerName))
        }
    }
}

// MARK: - Room Control

extension CallManager {
    /// Fetches a LiveKit room token using the configured CallTokenProvider.
    func fetchRoomToken(roomName: String, graphName: String, livekitDispatchAgentName: String, threadId: String?) async throws -> String {
        guard let tokenProvider = DeepAgentsUI.callTokenProvider else {
            throw CallManagerError.notConfigured
        }

        return try await tokenProvider.fetchRoomToken(roomName: roomName, graphName: graphName, livekitDispatchAgentName: livekitDispatchAgentName, threadId: threadId)
    }

    func connectToRoom(graphName: String, livekitDispatchAgentName: String) async throws {
        guard let config = try? DeepAgentsUI.configuration,
              let serverUrl = config.liveKitServerUrl else {
            logger.error("LiveKit server URL is nil — no host selected and no default configured")
            throw CallManagerError.liveKitNotAvailable
        }

        print("[CallManager] connectToRoom: self.threadId = \(threadId ?? "nil"), graphName = \(graphName)")

        // Generate a unique room name based on timestamp
        let roomName = "room-\(Int(Date().timeIntervalSince1970))"

        // Fetch the token from backend
        print("[CallManager] fetchRoomToken: room=\(roomName), graph=\(graphName), agent=\(livekitDispatchAgentName), threadId=\(threadId ?? "nil")")
        let token = try await fetchRoomToken(roomName: roomName, graphName: graphName, livekitDispatchAgentName: livekitDispatchAgentName, threadId: threadId)
        livekitToken = token

        currentRoomName = roomName

        // Connect to Room
        logger.info("Connecting to LiveKit room...")
        try await room.connect(url: serverUrl, token: token)

        // Publish mic
        try await room.localParticipant.setMicrophone(enabled: true)

        // Start polling audio levels
        startAudioLevelPolling()

        // Emit event
        DeepAgentsUI.emit(.callStarted(roomName: roomName))
    }

    func disconnectFromRoom() async {
        let roomName = currentRoomName

        stopAudioLevelPolling()
        await room.disconnect()

        currentRoomName = nil
        livekitToken = nil
        isMuted = false
        agentIsBusy = false
        remoteAudioLevel = 0
        localAudioLevel = 0

        if let roomName {
            DeepAgentsUI.emit(.callEnded(roomName: roomName))
        }
    }
}

// MARK: - CXProviderDelegate

extension CallManager: CXProviderDelegate {
    nonisolated public func providerDidReset(_: CXProvider) {
        Task { @MainActor in
            self.activeCallUUID = nil
            self.callState = .idle
        }
    }

    nonisolated public func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        Task { @MainActor in
            self.callState = .activeOutgoing
        }

        Task { @MainActor in
            let graphName = self.selectedGraphName
            let agentName = self.livekitDispatchAgentName

            do {
                provider.reportOutgoingCall(with: action.callUUID, connectedAt: Date())
                try await connectToRoom(graphName: graphName, livekitDispatchAgentName: agentName)

                self.callState = .connected
                action.fulfill()
            } catch {
                self.callState = .errored(error)
                self.activeCallUUID = nil
                action.fail()
            }
        }
    }

    nonisolated public func provider(_: CXProvider, perform action: CXAnswerCallAction) {
        Task { @MainActor in
            let graphName = self.selectedGraphName
            let agentName = self.livekitDispatchAgentName

            do {
                try await connectToRoom(graphName: graphName, livekitDispatchAgentName: agentName)
                self.callState = .connected
                action.fulfill()
            } catch {
                self.callState = .errored(error)
                action.fail()
            }
        }
    }

    nonisolated public func provider(_: CXProvider, perform action: CXEndCallAction) {
        Task { @MainActor in
            await disconnectFromRoom()
            action.fulfill()

            self.activeCallUUID = nil

            if case .errored = self.callState {
                // Keep the errored state for failed incoming cases.
            } else {
                self.callState = .idle
            }
        }
    }

    nonisolated public func provider(_: CXProvider, perform action: CXSetMutedCallAction) {
        Task { @MainActor in
            do {
                try await room.localParticipant.setMicrophone(enabled: !action.isMuted)
                action.fulfill()
            } catch {
                action.fail()
            }
        }
    }

    nonisolated public func provider(_: CXProvider, didActivate session: AVAudioSession) {
        do {
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP])
            try AudioManager.shared.setEngineAvailability(.default)
        } catch {
            // Log error
        }
    }

    nonisolated public func provider(_: CXProvider, didDeactivate _: AVAudioSession) {
        do {
            try AudioManager.shared.setEngineAvailability(.none)
        } catch {
            // Log error
        }
    }
}

// MARK: - Audio Level Polling

extension CallManager {
    func startAudioLevelPolling() {
        stopAudioLevelPolling()
        // Poll at ~20Hz for responsive visualization
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollAudioLevels()
            }
        }
    }

    func stopAudioLevelPolling() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
    }

    private func pollAudioLevels() {
        var newRemoteLevel: Float = 0
        var newLocalLevel: Float = 0

        for (_, participant) in room.remoteParticipants {
            newRemoteLevel = max(newRemoteLevel, participant.audioLevel)
        }
        newLocalLevel = room.localParticipant.audioLevel

        remoteAudioLevel = newRemoteLevel
        localAudioLevel = newLocalLevel
    }
}

// MARK: - RoomDelegate

extension CallManager: RoomDelegate {
    nonisolated public func room(_ room: Room, participant: Participant, didUpdateAttributes _: [String: String]) {
        if let remoteParticipant = participant as? RemoteParticipant,
           remoteParticipant.kind == .agent
        {
            let agentState = remoteParticipant.agentState
            let isBusy = (agentState == .thinking || agentState == .speaking)
            Task { @MainActor in
                self.agentIsBusy = isBusy
                self.evaluateMuteState()
            }
        }
    }
}

// MARK: - Auto-Mute Logic

extension CallManager {
    /// Evaluates whether to mute/unmute based on agent state and active coding sessions.
    private func evaluateMuteState() {
        if agentIsBusy {
            guard !isMuted else { return }
            isMuted = true
            Task {
                try? await room.localParticipant.setMicrophone(enabled: false)
            }
        } else if !suppressAutoUnmute {
            guard isMuted else { return }
            isMuted = false
            Task {
                try? await room.localParticipant.setMicrophone(enabled: true)
            }
        }
        // else: agent idle but sessions still running — stay in current mute state
    }
}

// MARK: - PKPushRegistryDelegate

extension CallManager: PKPushRegistryDelegate {
    nonisolated public func pushRegistry(_: PKPushRegistry, didUpdate pushCredentials: PKPushCredentials, for type: PKPushType) {
        guard type == .voIP else { return }
        let token = pushCredentials.token.map { String(format: "%02x", $0) }.joined()

        Task { @MainActor in
            self.voipToken = token
            DeepAgentsUI.emit(.voipTokenUpdated(token: token))
        }
    }

    nonisolated public func pushRegistry(_: PKPushRegistry, didInvalidatePushTokenFor type: PKPushType) {
        guard type == .voIP else { return }

        Task { @MainActor in
            self.voipToken = nil
        }
    }

    nonisolated public func pushRegistry(_: PKPushRegistry, didReceiveIncomingPushWith payload: PKPushPayload, for type: PKPushType, completion: @escaping () -> Void) {
        guard type == .voIP else {
            completion()
            return
        }

        /// NOTE: Setting .playAndRecord here for background mode compatibility
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .voiceChat, options: [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP])
        } catch {
            // Log error
        }

        // Extract caller information from payload
        let callerId = payload.dictionaryPayload["callerId"] as? String ?? UUID().uuidString
        let callerName = payload.dictionaryPayload["callerName"] as? String ?? "Unknown Caller"

        reportIncomingCallSync(from: callerId, callerName: callerName) { error in
            completion()
        }
    }
}
