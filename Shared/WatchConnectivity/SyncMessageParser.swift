//
//  SyncMessageParser.swift
//  Shared
//
//  Parses incoming WatchConnectivity messages into typed results.
//  Pure functions with no side effects - easily testable.
//

import Foundation

/// Result of parsing an incoming sync message
enum ParsedSyncMessage: Equatable {
    /// iPhone confirmed successful sync with verified checksum
    case syncConfirmation(recordingId: String, checksum: String)

    /// iPhone reported sync failure
    case syncFailure(recordingId: String, errorMessage: String)

    /// Message could not be parsed
    case invalid(reason: String)
}

/// Parses WatchConnectivity messages into typed results
enum SyncMessageParser {

    /// Parses a raw message dictionary into a typed result
    /// - Parameter message: Raw dictionary from WCSession delegate
    /// - Returns: Parsed message or invalid with reason
    static func parse(_ message: [String: Any]) -> ParsedSyncMessage {
        // Extract message type
        guard let messageTypeRaw = message[WatchConnectivityConstants.MessageKey.messageType.rawValue] as? String else {
            return .invalid(reason: "Missing messageType")
        }

        // Extract recording ID (required for all message types)
        guard let recordingId = message[WatchConnectivityConstants.MessageKey.recordingId.rawValue] as? String else {
            return .invalid(reason: "Missing recordingId")
        }

        // Parse based on message type
        switch messageTypeRaw {
        case WatchConnectivityConstants.MessageType.syncConfirmation.rawValue:
            guard let checksum = message[WatchConnectivityConstants.MessageKey.checksum.rawValue] as? String else {
                return .invalid(reason: "syncConfirmation missing checksum")
            }
            return .syncConfirmation(recordingId: recordingId, checksum: checksum)

        case WatchConnectivityConstants.MessageType.syncFailure.rawValue:
            let errorMessage = message[WatchConnectivityConstants.MessageKey.errorMessage.rawValue] as? String ?? "Unknown error"
            return .syncFailure(recordingId: recordingId, errorMessage: errorMessage)

        default:
            return .invalid(reason: "Unknown messageType: \(messageTypeRaw)")
        }
    }

    /// Creates a sync confirmation message dictionary
    /// - Parameters:
    ///   - recordingId: The recording that was confirmed
    ///   - checksum: The verified checksum
    /// - Returns: Dictionary suitable for WCSession.sendMessage
    static func createConfirmationMessage(recordingId: String, checksum: String) -> [String: Any] {
        return [
            WatchConnectivityConstants.MessageKey.messageType.rawValue: WatchConnectivityConstants.MessageType.syncConfirmation.rawValue,
            WatchConnectivityConstants.MessageKey.recordingId.rawValue: recordingId,
            WatchConnectivityConstants.MessageKey.checksum.rawValue: checksum
        ]
    }

    /// Creates a sync failure message dictionary
    /// - Parameters:
    ///   - recordingId: The recording that failed
    ///   - error: Error description
    /// - Returns: Dictionary suitable for WCSession.sendMessage
    static func createFailureMessage(recordingId: String, error: String) -> [String: Any] {
        return [
            WatchConnectivityConstants.MessageKey.messageType.rawValue: WatchConnectivityConstants.MessageType.syncFailure.rawValue,
            WatchConnectivityConstants.MessageKey.recordingId.rawValue: recordingId,
            WatchConnectivityConstants.MessageKey.errorMessage.rawValue: error
        ]
    }

    /// Creates file transfer metadata dictionary
    /// - Parameters:
    ///   - recordingId: Unique recording identifier
    ///   - checksum: SHA256 checksum of the file
    /// - Returns: Dictionary suitable for WCSession.transferFile metadata
    static func createTransferMetadata(recordingId: String, checksum: String) -> [String: Any] {
        return [
            WatchConnectivityConstants.FileMetadataKey.type.rawValue: WatchConnectivityConstants.FileType.audioRecording.rawValue,
            WatchConnectivityConstants.FileMetadataKey.timestamp.rawValue: Date().timeIntervalSince1970,
            WatchConnectivityConstants.FileMetadataKey.recordingId.rawValue: recordingId,
            WatchConnectivityConstants.FileMetadataKey.checksum.rawValue: checksum
        ]
    }

    /// Extracts recording ID and checksum from file transfer metadata
    /// - Parameter metadata: Metadata dictionary from WCSessionFile
    /// - Returns: Tuple of (recordingId, checksum) or nil if missing
    static func parseTransferMetadata(_ metadata: [String: Any]?) -> (recordingId: String, checksum: String)? {
        guard let metadata = metadata,
              let recordingId = metadata[WatchConnectivityConstants.FileMetadataKey.recordingId.rawValue] as? String,
              let checksum = metadata[WatchConnectivityConstants.FileMetadataKey.checksum.rawValue] as? String else {
            return nil
        }
        return (recordingId, checksum)
    }
}
