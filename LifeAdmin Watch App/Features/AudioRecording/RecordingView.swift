//
//  RecordingView.swift
//  LifeAdmin Watch App
//
//  Main recording interface for Apple Watch
//

import SwiftUI

struct RecordingView: View {
    @EnvironmentObject var audioRecorder: AudioRecorderManager
    @EnvironmentObject var phoneSyncManager: PhoneSyncManager

    var body: some View {
        VStack(spacing: 16) {
            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(phoneSyncManager.isPhoneReachable ? .green : .orange)
                    .frame(width: 8, height: 8)
                Text(phoneSyncManager.isPhoneReachable ? "Synced" : "Offline")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Recording visualization
            ZStack {
                Circle()
                    .stroke(audioRecorder.isRecording ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 4)
                    .frame(width: 100, height: 100)

                if audioRecorder.isRecording {
                    // Pulsing animation when recording
                    Circle()
                        .fill(Color.red.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .scaleEffect(audioRecorder.isRecording ? 1.2 : 1.0)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: audioRecorder.isRecording)
                }

                Image(systemName: audioRecorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(audioRecorder.isRecording ? .red : .blue)
            }

            // Recording duration
            if audioRecorder.isRecording {
                Text(audioRecorder.formattedDuration)
                    .font(.title3)
                    .monospacedDigit()
            }

            Spacer()

            // Record button
            Button(action: toggleRecording) {
                Text(audioRecorder.isRecording ? "Stop" : "Record")
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(audioRecorder.isRecording ? .red : .blue)
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: .startRecordingFromIntent)) { _ in
            if !audioRecorder.isRecording {
                audioRecorder.startRecording()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleRecordingFromIntent)) { _ in
            toggleRecording()
        }
    }

    private func toggleRecording() {
        if audioRecorder.isRecording {
            audioRecorder.stopRecording()
        } else {
            audioRecorder.startRecording()
        }
    }
}

#Preview {
    RecordingView()
        .environmentObject(AudioRecorderManager())
        .environmentObject(PhoneSyncManager.shared)
}
