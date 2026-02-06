//
//  SyncStateManager.swift
//  Shared
//
//  Manages the state of recordings during sync.
//  Pure state logic with no I/O - easily testable.
//

import Foundation

/// Represents the sync state of a recording
enum RecordingSyncState: Equatable {
    /// Recording exists locally, not yet sent
    case pending

    /// Transfer initiated, waiting for confirmation
    case inFlight(expectedChecksum: String)

    /// Successfully synced and confirmed
    case synced
}

/// Result of attempting to confirm a sync
enum SyncConfirmationResult: Equatable {
    /// Checksum matched, recording confirmed synced
    case confirmed

    /// Checksum didn't match, needs retry
    case checksumMismatch(expected: String, received: String)

    /// No pending confirmation for this recording
    case unknownRecording
}

/// Result of checking if a recording should be synced
enum SyncDecision: Equatable {
    /// Should sync this recording
    case shouldSync

    /// Already in flight, skip
    case alreadyInFlight

    /// Already synced, skip
    case alreadySynced

    /// File doesn't exist, remove from pending
    case fileMissing
}

/// Manages sync state for recordings. Pure state logic, no I/O.
/// Thread-safe operations for use from any context.
final class SyncStateManager {

    /// Checksums for recordings that are in-flight (sent but not confirmed)
    private var inFlightChecksums: [String: String] = [:]

    /// Set of recording IDs that have been confirmed synced
    private var syncedRecordings: Set<String> = []

    /// Lock for thread-safe access
    private let lock = NSLock()

    init() {}

    // MARK: - State Queries

    /// Gets the current sync state of a recording
    func state(for recordingId: String) -> RecordingSyncState {
        lock.lock()
        defer { lock.unlock() }

        if syncedRecordings.contains(recordingId) {
            return .synced
        }
        if let checksum = inFlightChecksums[recordingId] {
            return .inFlight(expectedChecksum: checksum)
        }
        return .pending
    }

    /// Checks if a recording is currently in-flight
    func isInFlight(_ recordingId: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return inFlightChecksums[recordingId] != nil
    }

    /// Gets all in-flight recording IDs
    var allInFlightIds: Set<String> {
        lock.lock()
        defer { lock.unlock() }
        return Set(inFlightChecksums.keys)
    }

    // MARK: - State Transitions

    /// Marks a recording as in-flight with its expected checksum
    /// - Parameters:
    ///   - recordingId: The recording being sent
    ///   - checksum: Expected SHA256 checksum
    func markInFlight(_ recordingId: String, checksum: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlightChecksums[recordingId] = checksum
    }

    /// Attempts to confirm a sync with the received checksum
    /// - Parameters:
    ///   - recordingId: The recording to confirm
    ///   - receivedChecksum: Checksum from iPhone's confirmation
    /// - Returns: Result of the confirmation attempt
    func confirmSync(recordingId: String, receivedChecksum: String) -> SyncConfirmationResult {
        lock.lock()
        defer { lock.unlock() }

        guard let expectedChecksum = inFlightChecksums[recordingId] else {
            return .unknownRecording
        }

        if expectedChecksum.lowercased() == receivedChecksum.lowercased() {
            inFlightChecksums.removeValue(forKey: recordingId)
            syncedRecordings.insert(recordingId)
            return .confirmed
        } else {
            return .checksumMismatch(expected: expectedChecksum, received: receivedChecksum)
        }
    }

    /// Handles a sync failure - removes from in-flight so it can be retried
    /// - Parameter recordingId: The recording that failed
    func handleFailure(recordingId: String) {
        lock.lock()
        defer { lock.unlock() }
        inFlightChecksums.removeValue(forKey: recordingId)
    }

    /// Decides whether a recording should be synced
    /// - Parameters:
    ///   - recordingId: The recording to check
    ///   - fileExists: Whether the file exists on disk
    ///   - isAlreadyInTransferQueue: Whether it's in WCSession's outstanding transfers
    /// - Returns: Decision on whether to sync
    func shouldSync(
        recordingId: String,
        fileExists: Bool,
        isAlreadyInTransferQueue: Bool
    ) -> SyncDecision {
        lock.lock()
        defer { lock.unlock() }

        if !fileExists {
            return .fileMissing
        }

        if syncedRecordings.contains(recordingId) {
            return .alreadySynced
        }

        if isAlreadyInTransferQueue || inFlightChecksums[recordingId] != nil {
            return .alreadyInFlight
        }

        return .shouldSync
    }

    // MARK: - Persistence Support

    /// Returns current in-flight checksums for persistence
    var checksumsToPersist: [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return inFlightChecksums
    }

    /// Restores in-flight checksums from persistence
    func restoreChecksums(_ checksums: [String: String]) {
        lock.lock()
        defer { lock.unlock() }
        inFlightChecksums = checksums
    }

    /// Clears synced state (for testing or reset)
    func reset() {
        lock.lock()
        defer { lock.unlock() }
        inFlightChecksums.removeAll()
        syncedRecordings.removeAll()
    }
}
