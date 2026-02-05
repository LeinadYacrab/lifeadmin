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

    override init() {
        super.init()

        if WCSession.isSupported() {
            session = WCSession.default
            session?.delegate = self
            session?.activate()
        }
    }

    func sendAudioFile(url: URL) {
        guard let session = session, session.activationState == .activated else {
            print("WCSession not activated")
            return
        }

        pendingTransfers += 1

        session.transferFile(url, metadata: [
            "timestamp": Date().timeIntervalSince1970,
            "type": "audioRecording"
        ])
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
                // Keep the file for retry - it's already in pendingSync
            } else {
                // Mark as synced in the recordings store
                WatchRecordingsStore.shared.markAsSynced(url: fileTransfer.file.fileURL)
            }
        }
    }

    /// Retries syncing all pending recordings
    func retrySyncPendingRecordings() {
        WatchRecordingsStore.shared.syncPendingRecordings()
    }
}
