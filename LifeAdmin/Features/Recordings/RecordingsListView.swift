//
//  RecordingsListView.swift
//  LifeAdmin
//
//  Displays all audio recordings with playback controls
//

import SwiftUI
import AVFoundation

struct RecordingsListView: View {
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
    @StateObject private var audioPlayer = AudioPlayerService.shared

    var body: some View {
        Group {
            if watchConnectivityManager.receivedAudioFiles.isEmpty {
                ContentUnavailableView(
                    "No Recordings",
                    systemImage: "waveform",
                    description: Text("Record audio using the Record tab or your Apple Watch")
                )
            } else {
                List {
                    ForEach(watchConnectivityManager.receivedAudioFiles, id: \.self) { fileURL in
                        RecordingRowView(
                            fileURL: fileURL,
                            isPlaying: audioPlayer.currentlyPlaying == fileURL,
                            onPlay: {
                                if audioPlayer.currentlyPlaying == fileURL {
                                    audioPlayer.stop()
                                } else {
                                    audioPlayer.play(url: fileURL)
                                }
                            }
                        )
                    }
                    .onDelete(perform: deleteRecordings)
                }
                .listStyle(.insetGrouped)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newRecordingAvailable)) { notification in
            if let url = notification.userInfo?["url"] as? URL {
                watchConnectivityManager.addLocalRecording(url: url)
            }
        }
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let fileURL = watchConnectivityManager.receivedAudioFiles[index]
            try? FileManager.default.removeItem(at: fileURL)
        }
        watchConnectivityManager.receivedAudioFiles.remove(atOffsets: offsets)
    }
}

struct RecordingRowView: View {
    let fileURL: URL
    let isPlaying: Bool
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Play button
            Button(action: onPlay) {
                Image(systemName: isPlaying ? "stop.circle.fill" : "play.circle.fill")
                    .font(.title)
                    .foregroundStyle(isPlaying ? .red : .blue)
            }
            .buttonStyle(.plain)

            // Recording info
            VStack(alignment: .leading, spacing: 4) {
                Text(displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 8) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let duration = audioDuration {
                        Text("•")
                            .foregroundStyle(.secondary)
                        Text(duration)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("•")
                        .foregroundStyle(.secondary)
                    Text(formattedFileSize)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Source indicator
            Image(systemName: isFromWatch ? "applewatch" : "iphone")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private var displayName: String {
        let filename = fileURL.deletingPathExtension().lastPathComponent
        // Extract timestamp from filename like "recording_1234567890.123"
        if filename.hasPrefix("recording_"),
           let timestampString = filename.split(separator: "_").last,
           let timestamp = Double(timestampString) {
            let date = Date(timeIntervalSince1970: timestamp)
            return date.formatted(date: .abbreviated, time: .shortened)
        }
        return filename
    }

    private var formattedDate: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let date = attributes[.creationDate] as? Date else {
            return "Unknown date"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private var formattedFileSize: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let size = attributes[.size] as? Int64 else {
            return ""
        }
        return ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }

    private var audioDuration: String? {
        let asset = AVURLAsset(url: fileURL)
        let duration = CMTimeGetSeconds(asset.duration)
        guard duration.isFinite && duration > 0 else { return nil }

        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private var isFromWatch: Bool {
        // Files from Watch are transferred, local recordings are created directly
        // This is a heuristic - could be improved with metadata
        return true // For now, assume all are from Watch; will refine later
    }
}

#Preview {
    NavigationStack {
        RecordingsListView()
            .navigationTitle("Recordings")
    }
    .environmentObject(WatchConnectivityManager.shared)
}
