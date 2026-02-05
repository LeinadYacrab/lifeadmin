//
//  WatchRecordingsListView.swift
//  LifeAdmin Watch App
//
//  Displays recordings list on Apple Watch
//

import SwiftUI

struct WatchRecordingsListView: View {
    @EnvironmentObject var audioRecorder: AudioRecorderManager
    @EnvironmentObject var phoneSyncManager: PhoneSyncManager
    @StateObject private var recordingsStore = WatchRecordingsStore.shared

    var body: some View {
        Group {
            if recordingsStore.recordings.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text("No recordings")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(recordingsStore.recordings, id: \.self) { fileURL in
                        WatchRecordingRow(
                            fileURL: fileURL,
                            isSynced: !recordingsStore.pendingSync.contains(fileURL)
                        )
                    }
                    .onDelete(perform: deleteRecordings)
                }
            }
        }
        .navigationTitle("Recordings")
    }

    private func deleteRecordings(at offsets: IndexSet) {
        for index in offsets {
            let fileURL = recordingsStore.recordings[index]
            recordingsStore.deleteRecording(url: fileURL)
        }
    }
}

struct WatchRecordingRow: View {
    let fileURL: URL
    let isSynced: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(displayName)
                    .font(.caption)
                    .lineLimit(1)

                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Sync status indicator
            if isSynced {
                Image(systemName: "checkmark.circle.fill")
                    .font(.caption2)
                    .foregroundStyle(.green)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var displayName: String {
        let filename = fileURL.deletingPathExtension().lastPathComponent
        if filename.hasPrefix("recording_"),
           let timestampString = filename.split(separator: "_").last,
           let timestamp = Double(timestampString) {
            let date = Date(timeIntervalSince1970: timestamp)
            return date.formatted(date: .omitted, time: .shortened)
        }
        return filename
    }

    private var formattedDate: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let date = attributes[.creationDate] as? Date else {
            return ""
        }
        return date.formatted(date: .abbreviated, time: .omitted)
    }
}

#Preview {
    NavigationStack {
        WatchRecordingsListView()
            .environmentObject(AudioRecorderManager())
            .environmentObject(PhoneSyncManager.shared)
    }
}
