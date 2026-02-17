/*
 * Based on LiveKit example code
 * Licensed under the Apache License, Version 2.0
 */

import LiveKit
import Logging
import SwiftUI

/// View for managing voice calls.
public struct CallView: View {
    @ObservedObject var callManager: CallManager
    @ObservedObject var room: Room

    public init(callManager: CallManager) {
        self.callManager = callManager
        self.room = callManager.room
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("States") {
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: roomStateIcon(for: room.connectionState))
                                .foregroundColor(roomStateColor(for: room.connectionState))
                            Text("Room state")
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text(String(describing: room.connectionState))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: callStateIcon(for: callManager.callState))
                                .foregroundColor(callStateColor(for: callManager.callState))
                            Text("Call state")
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text(callStateDescription(callManager.callState))
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }

                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: "phone.circle")
                                .foregroundColor(.blue)
                            Text("Call ID")
                                .fontWeight(.medium)
                        }
                        Spacer()
                        Text((callManager.activeCallUUID != nil) ? callManager.activeCallUUID!.uuidString : "Not in a call")
                            .foregroundColor(.secondary)
                            .font(.caption)
                            .monospaced()
                    }

                    if let roomName = callManager.currentRoomName {
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "video.circle")
                                    .foregroundColor(.purple)
                                Text("Room")
                                    .fontWeight(.medium)
                            }
                            Spacer()
                            Text(roomName)
                                .foregroundColor(.secondary)
                                .font(.caption)
                                .monospaced()
                        }
                    }
                }

                if !callManager.availableGraphs.isEmpty {
                    Section("Graph") {
                        Picker("Graph", selection: $callManager.selectedGraphName) {
                            ForEach(callManager.availableGraphs, id: \.self) { graph in
                                Text(graph).tag(graph)
                            }
                        }
                        .disabled(callManager.hasActiveCall)
                    }
                }

                Section("Call") {
                    if callManager.hasActiveCall {
                        Button {
                            let newMuted = !callManager.isMuted
                            callManager.isMuted = newMuted
                            Task {
                                try? await room.localParticipant.setMicrophone(enabled: !newMuted)
                            }
                        } label: {
                            HStack {
                                Image(systemName: callManager.isMuted ? "mic.slash.fill" : "mic.fill")
                                    .foregroundColor(callManager.isMuted ? .red : .green)
                                Text(callManager.isMuted ? "Unmute" : "Mute")
                            }
                        }

                        Button("End call") {
                            Task {
                                await callManager.endCall()
                            }
                        }
                    } else {
                        Button("Start call") {
                            Task {
                                await callManager.startCall(handle: "user1")
                            }
                        }
                    }
                }
            }
            .navigationTitle("Call")
        }
    }

    private func roomStateIcon(for state: ConnectionState) -> String {
        switch state {
        case .disconnected:
            return "network.slash"
        case .connecting:
            return "bolt"
        case .connected:
            return "network"
        case .reconnecting:
            return "arrow.triangle.2.circlepath"
        case .disconnecting:
            return "arrow.down.circle"
        @unknown default:
            return "questionmark.circle"
        }
    }

    private func roomStateColor(for state: ConnectionState) -> Color {
        switch state {
        case .disconnected:
            return .red
        case .connecting:
            return .orange
        case .connected:
            return .green
        case .reconnecting:
            return .blue
        case .disconnecting:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private func callStateIcon(for state: CallState) -> String {
        switch state {
        case .idle:
            "phone"
        case .errored:
            "phone.badge.exclamationmark"
        case .activeIncoming:
            "phone.arrow.down.left"
        case .activeOutgoing:
            "phone.arrow.up.right"
        case .connected:
            "phone.connection"
        }
    }

    private func callStateColor(for state: CallState) -> Color {
        switch state {
        case .idle:
            .gray
        case .errored:
            .red
        case .activeIncoming:
            .blue
        case .activeOutgoing:
            .orange
        case .connected:
            .green
        }
    }

    private func callStateDescription(_ state: CallState) -> String {
        switch state {
        case .idle:
            return "Idle"
        case .errored(let error):
            return "Error: \(error.localizedDescription)"
        case .activeIncoming:
            return "Incoming"
        case .activeOutgoing:
            return "Outgoing"
        case .connected:
            return "Connected"
        }
    }
}
