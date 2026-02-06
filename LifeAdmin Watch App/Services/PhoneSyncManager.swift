//
//  PhoneSyncManager.swift
//  LifeAdmin Watch App
//
//  Manages WatchConnectivity session for sending audio files to iPhone
//
//  ## Auto-Sync Protocol
//
//  This manager implements an efficient, event-driven sync protocol:
//
//  ### Trigger Events (not polling):
//  1. `sessionReachabilityDidChange` - when phone becomes reachable
//  2. `activationDidCompleteWith` - when app starts and session activates
//
//  ### Efficiency Measures:
//  - **No polling**: Purely event-driven, only syncs on connectivity events
//  - **No duplicates**: Checks `outstandingFileTransfers` before queuing
//  - **Debounced**: 0.5s delay coalesces rapid reconnect events
//  - **Background-reliable**: Uses `transferFile` which the OS retries automatically
//
//  ### Why transferFile (not sendMessage):
//  - `sendMessage` requires both devices to be active simultaneously
//  - `transferFile` queues transfers and delivers in background
//  - OS handles network-level retries transparently
//  - Survives app suspension (but not termination, hence auto-retry on activate)
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

    /// Tracks whether we've already scheduled an auto-sync (for debouncing)
    private var autoSyncScheduled = false

    /// Minimum delay between auto-sync attempts (debounce)
    private let autoSyncDebounceInterval: TimeInterval = 0.5

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

            // Auto-sync on app startup if session activated successfully
            if activationState == .activated {
                print("AutoSync: Session activated, scheduling sync")
                self.scheduleAutoSync()
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor in
            let wasReachable = self.isPhoneReachable
            self.isPhoneReachable = session.isReachable

            // Auto-sync when phone becomes reachable (transition from unreachable to reachable)
            if !wasReachable && session.isReachable {
                print("AutoSync: Phone became reachable, scheduling sync")
                self.scheduleAutoSync()
            }
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

    /// Retries syncing all pending recordings that aren't already in-flight
    func retrySyncPendingRecordings() {
        guard let session = session, session.activationState == .activated else {
            print("AutoSync: Session not activated, skipping")
            return
        }

        // Get IDs of recordings already being transferred
        let inFlightIds = Set(session.outstandingFileTransfers.compactMap { transfer -> String? in
            transfer.file.metadata?[WatchConnectivityConstants.FileMetadataKey.recordingId.rawValue] as? String
        })

        let pendingRecordings = WatchRecordingsStore.shared.pendingSync
        var syncedCount = 0

        for url in pendingRecordings {
            let recordingId = WatchRecordingsStore.shared.recordingIdFromURL(url)

            // Skip if already in-flight
            if inFlightIds.contains(recordingId) {
                print("AutoSync: \(recordingId) already in-flight, skipping")
                continue
            }

            // Skip if file doesn't exist (was deleted)
            guard FileManager.default.fileExists(atPath: url.path) else {
                print("AutoSync: \(recordingId) file missing, removing from pending")
                WatchRecordingsStore.shared.markAsSynced(url: url)
                continue
            }

            sendAudioFile(url: url, recordingId: recordingId)
            syncedCount += 1
        }

        if syncedCount > 0 {
            print("AutoSync: Queued \(syncedCount) recording(s) for sync")
        }
    }

    /// Schedules an auto-sync with debouncing to prevent rapid-fire retries
    private func scheduleAutoSync() {
        guard !autoSyncScheduled else { return }
        autoSyncScheduled = true

        Task {
            try? await Task.sleep(nanoseconds: UInt64(autoSyncDebounceInterval * 1_000_000_000))
            await MainActor.run {
                self.autoSyncScheduled = false
                self.retrySyncPendingRecordings()
            }
        }
    }
}
