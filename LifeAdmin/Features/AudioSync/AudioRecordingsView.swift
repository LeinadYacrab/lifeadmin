//
//  AudioRecordingsView.swift
//  LifeAdmin
//
//  Displays audio recordings received from Watch
//

import SwiftUI

struct AudioRecordingsView: View {
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recordings")
                .font(.headline)

            if watchConnectivityManager.receivedAudioFiles.isEmpty {
                ContentUnavailableView(
                    "No Recordings",
                    systemImage: "waveform",
                    description: Text("Record audio using your Apple Watch action button")
                )
                .frame(height: 200)
            } else {
                List(watchConnectivityManager.receivedAudioFiles, id: \.self) { fileURL in
                    AudioRecordingRow(fileURL: fileURL)
                }
                .listStyle(.plain)
                .frame(height: 300)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AudioRecordingRow: View {
    let fileURL: URL

    var body: some View {
        HStack {
            Image(systemName: "waveform")
                .foregroundStyle(.blue)

            VStack(alignment: .leading) {
                Text(fileURL.lastPathComponent)
                    .font(.subheadline)

                Text(formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                // TODO: Play audio
            }) {
                Image(systemName: "play.circle.fill")
                    .font(.title2)
            }
        }
    }

    private var formattedDate: String {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              let date = attributes[.creationDate] as? Date else {
            return "Unknown date"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    AudioRecordingsView()
        .environmentObject(WatchConnectivityManager.shared)
}
