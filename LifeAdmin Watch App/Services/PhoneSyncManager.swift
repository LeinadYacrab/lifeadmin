//
//  PhoneSyncManager.swift
//  LifeAdmin Watch App
//
//  Manages WatchConnectivity session for sending audio files to iPhone
//

import Foundation
import WatchConnectivity

@MainActor
class PhoneSyncManager: NSObject, ObservableObject {
    static let shared = PhoneSyncManager()

    @Published var isPhoneReachable = false
    @Published var pendingTransfers: Int = 0

    private var session: WCSession?

    /// Maps recordingId to expected checksum for pending transfers
    private var pendingChecksums: [String: String] = [:] {
        didSet { savePendingChecksums() }
    }

    private var pendingChecksumsFileURL: URL {
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("pendingChecksums.json")
    }

    override init() {
        super.init()
        loadPendingChecksums()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    private func loadPendingChecksums() {
        guard let data = try? Data(contentsOf: pendingChecksumsFileURL),
              let checksums = try? JSONDecoder().decode([String: String].self, from: data) else {
            return
        }
        pendingChecksums = checksums
    }

    private func savePendingChecksums() {
        if let data = try? JSONEncoder().encode(pendingChecksums) {
            try? data.write(to: pendingChecksumsFileURL)
        }
    }

    func sendAudioFile(url: URL, recordingId: String) {
        guard let session = session, session.activationState == .activated else {
            print("WCSession not activated")
            return
        }

        // Compute checksum before sending
        guard let checksum = FileChecksum.sha256(of: url) else {
            print("Failed to compute checksum for file: \(url)")
            return
        }

        // Store expected checksum for verification when iPhone confirms
        pendingChecksums[recordingId] = checksum

        pendingTransfers += 1

        let metadata: [String: Any] = [
            WatchConnectivityConstants.FileMetadataKey.type.rawValue: WatchConnectivityConstants.FileType.audioRecording.rawValue,
            WatchConnectivityConstants.FileMetadataKey.timestamp.rawValue: Date().timeIntervalSince1970,
            WatchConnectivityConstants.FileMetadataKey.recordingId.rawValue: recordingId,
            WatchConnectivityConstants.FileMetadataKey.checksum.rawValue: checksum
        ]

        session.transferFile(url, metadata: metadata)
    }

    /// Handles sync confirmation from iPhone
    func handleSyncConfirmation(recordingId: String, verifiedChecksum: String) {
        guard let expectedChecksum = pendingChecksums[recordingId] else {
            print("Received confirmation for unknown recordingId: \(recordingId)")
            return
        }

        if expectedChecksum.lowercased() == verifiedChecksum.lowercased() {
            // Checksum matches - safe to mark as synced
            pendingChecksums.removeValue(forKey: recordingId)
            WatchRecordingsStore.shared.markAsSyncedById(recordingId)
            print("Recording \(recordingId) verified and marked as synced")
        } else {
            print("Checksum mismatch for recording \(recordingId): expected \(expectedChecksum), got \(verifiedChecksum)")
            // Don't mark as synced - file will be retried
        }
    }

    /// Handles sync failure from iPhone
    func handleSyncFailure(recordingId: String, errorMessage: String) {
        print("Sync failed for recording \(recordingId): \(errorMessage)")
        pendingChecksums.removeValue(forKey: recordingId)
        // File remains in pending state and will be retried
    }
}

// MARK: - WCSessionDelegate
extension PhoneSyncManager: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            self.isPhoneReachable = session.isReachable
        }
    }

    nonisolated func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        Task { @MainActor in
            self.pendingTransfers = max(0, self.pendingTransfers - 1)

            if let error = error {
                print("File transfer failed: \(error)")
                // Keep the file for retry - it remains in pending state
            }
            // NOTE: We intentionally do NOT mark as synced here.
            // didFinish only means the OS accepted the file for transfer.
            // We wait for iPhone's confirmation message with verified checksum
            // before marking as synced. This prevents data loss if the transfer
            // fails silently or the file is corrupted in transit.
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(message)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        Task { @MainActor in
            handleIncomingMessage(message)
            replyHandler([:])
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            handleIncomingMessage(applicationContext)
        }
    }

    private func handleIncomingMessage(_ message: [String: Any]) {
        guard let messageTypeRaw = message[WatchConnectivityConstants.MessageKey.messageType.rawValue] as? String else {
            print("Received message without messageType")
            return
        }

        guard let recordingId = message[WatchConnectivityConstants.MessageKey.recordingId.rawValue] as? String else {
            print("Received message without recordingId")
            return
        }

        switch messageTypeRaw {
        case WatchConnectivityConstants.MessageType.syncConfirmation.rawValue:
            if let checksum = message[WatchConnectivityConstants.MessageKey.checksum.rawValue] as? String {
                handleSyncConfirmation(recordingId: recordingId, verifiedChecksum: checksum)
            }

        case WatchConnectivityConstants.MessageType.syncFailure.rawValue:
            let errorMessage = message[WatchConnectivityConstants.MessageKey.errorMessage.rawValue] as? String ?? "Unknown error"
            handleSyncFailure(recordingId: recordingId, errorMessage: errorMessage)

        default:
            print("Unknown message type: \(messageTypeRaw)")
        }
    }

    /// Retries syncing all pending recordings
    func retrySyncPendingRecordings() {
        WatchRecordingsStore.shared.syncPendingRecordings()
    }
}
