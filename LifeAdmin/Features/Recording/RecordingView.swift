//
//  RecordingView.swift
//  LifeAdmin
//
//  Main recording interface for iPhone
//

import SwiftUI

struct RecordingView: View {
    @StateObject private var recorder = AudioRecorderService.shared
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Recording visualization
            ZStack {
                // Outer ring
                Circle()
                    .stroke(recorder.isRecording ? Color.red.opacity(0.3) : Color.blue.opacity(0.3), lineWidth: 8)
                    .frame(width: 200, height: 200)

                // Pulsing animation when recording
                if recorder.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.15))
                        .frame(width: 200, height: 200)
                        .scaleEffect(recorder.isRecording ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: recorder.isRecording)
                }

                // Inner circle button
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.blue)
                    .frame(width: 160, height: 160)
                    .shadow(color: recorder.isRecording ? .red.opacity(0.4) : .blue.opacity(0.4), radius: 20)

                // Icon
                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.white)
            }
            .onTapGesture {
                if recorder.isRecording {
                    recorder.stopRecording()
                } else {
                    recorder.startRecording()
                }
            }

            // Recording duration
            if recorder.isRecording {
                VStack(spacing: 8) {
                    Text(recorder.formattedDuration)
                        .font(.system(size: 48, weight: .light, design: .monospaced))

                    Text("Recording...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Tap to record")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Permission warning
            if !recorder.permissionGranted {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Microphone access required")
                        .font(.caption)
                }
                .padding()
                .background(.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onTapGesture {
                    recorder.requestPermission()
                }
            }
        }
        .padding()
    }
}

#Preview {
    RecordingView()
        .environmentObject(WatchConnectivityManager.shared)
}
