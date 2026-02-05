//
//  WatchConnectivityManager.swift
//  LifeAdmin
//
//  Manages WatchConnectivity session for receiving audio files from Watch
//

import Foundation
import WatchConnectivity

@MainActor
class WatchConnectivityManager: NSObject, ObservableObject {
    static let shared = WatchConnectivityManager()

    @Published var isWatchConnected = false
    @Published var receivedAudioFiles: [URL] = []

    private var session: WCSession?

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }

        loadExistingAudioFiles()
    }

    private func loadExistingAudioFiles() {
        let audioDirectory = getAudioDirectory()
        do {
            let files = try FileManager.default.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: [.creationDateKey])
            receivedAudioFiles = files.filter { $0.pathExtension == "m4a" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            print("Error loading audio files: \(error)")
        }
    }

    /// Adds a locally recorded file to the list (for iPhone recordings)
    func addLocalRecording(url: URL) {
        // Insert at the beginning (most recent first)
        if !receivedAudioFiles.contains(url) {
            receivedAudioFiles.insert(url, at: 0)
        }
    }

    /// Refreshes the audio files list from disk
    func refreshAudioFiles() {
        loadExistingAudioFiles()
    }

    private func getAudioDirectory() -> URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let audioDirectory = documentsDirectory.appendingPathComponent("AudioRecordings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }

        return audioDirectory
    }
}

// MARK: - WCSessionDelegate
extension WatchConnectivityManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isWatchConnected = session.isReachable
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {
        // Handle session becoming inactive
    }

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Reactivate the session
        session.activate()
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isWatchConnected = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        // Handle received audio file from Watch
        let audioDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("AudioRecordings", isDirectory: true)

        if !FileManager.default.fileExists(atPath: audioDirectory.path) {
            try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        }

        let destinationURL = audioDirectory.appendingPathComponent(file.fileURL.lastPathComponent)

        do {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.copyItem(at: file.fileURL, to: destinationURL)

            Task { @MainActor in
                self.receivedAudioFiles.insert(destinationURL, at: 0)
            }
        } catch {
            print("Error saving received audio file: \(error)")
        }
    }
}
