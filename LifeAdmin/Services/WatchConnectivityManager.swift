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
        // Extract metadata
        let metadata = file.metadata ?? [:]
        let recordingId = metadata[WatchConnectivityConstants.FileMetadataKey.recordingId.rawValue] as? String
        let expectedChecksum = metadata[WatchConnectivityConstants.FileMetadataKey.checksum.rawValue] as? String

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

            // Verify checksum if provided
            if let expectedChecksum = expectedChecksum, let recordingId = recordingId {
                if let actualChecksum = FileChecksum.sha256(of: destinationURL) {
                    if actualChecksum.lowercased() == expectedChecksum.lowercased() {
                        // Checksum verified - send confirmation
                        sendSyncConfirmation(session: session, recordingId: recordingId, checksum: actualChecksum)
                        Task { @MainActor in
                            self.receivedAudioFiles.insert(destinationURL, at: 0)
                        }
                    } else {
                        // Checksum mismatch - delete corrupted file and notify Watch
                        try? FileManager.default.removeItem(at: destinationURL)
                        sendSyncFailure(session: session, recordingId: recordingId, error: "Checksum mismatch: expected \(expectedChecksum), got \(actualChecksum)")
                    }
                } else {
                    // Couldn't compute checksum - delete and notify
                    try? FileManager.default.removeItem(at: destinationURL)
                    sendSyncFailure(session: session, recordingId: recordingId, error: "Failed to compute checksum of received file")
                }
            } else {
                // Legacy transfer without checksum - accept but log warning
                print("Warning: Received file without checksum verification")
                Task { @MainActor in
                    self.receivedAudioFiles.insert(destinationURL, at: 0)
                }
            }
        } catch {
            print("Error saving received audio file: \(error)")
            if let recordingId = recordingId {
                sendSyncFailure(session: session, recordingId: recordingId, error: error.localizedDescription)
            }
        }
    }

    /// Sends sync confirmation to Watch with verified checksum
    private nonisolated func sendSyncConfirmation(session: WCSession, recordingId: String, checksum: String) {
        let message: [String: Any] = [
            WatchConnectivityConstants.MessageKey.messageType.rawValue: WatchConnectivityConstants.MessageType.syncConfirmation.rawValue,
            WatchConnectivityConstants.MessageKey.recordingId.rawValue: recordingId,
            WatchConnectivityConstants.MessageKey.checksum.rawValue: checksum
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send sync confirmation: \(error)")
            }
        } else {
            // Queue message for later delivery via application context
            try? session.updateApplicationContext(message)
        }
    }

    /// Sends sync failure notification to Watch
    private nonisolated func sendSyncFailure(session: WCSession, recordingId: String, error: String) {
        let message: [String: Any] = [
            WatchConnectivityConstants.MessageKey.messageType.rawValue: WatchConnectivityConstants.MessageType.syncFailure.rawValue,
            WatchConnectivityConstants.MessageKey.recordingId.rawValue: recordingId,
            WatchConnectivityConstants.MessageKey.errorMessage.rawValue: error
        ]

        if session.isReachable {
            session.sendMessage(message, replyHandler: nil) { error in
                print("Failed to send sync failure: \(error)")
            }
        } else {
            try? session.updateApplicationContext(message)
        }
    }
}
