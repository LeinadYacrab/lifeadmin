//
//  SyncMessage.swift
//  LifeAdmin
//
//  Shared message types for Watch-iPhone communication
//

import Foundation

/// Message types for Watch-iPhone communication
enum SyncMessageType: String, Codable {
    case audioFile           // Audio file being transferred
    case statusUpdate        // Status update from iPhone to Watch
    case recordingComplete   // Notification that recording was received
    case error               // Error message
}

/// Message payload for Watch-iPhone sync
struct SyncMessage: Codable {
    let type: SyncMessageType
    let timestamp: Date
    let payload: [String: String]

    init(type: SyncMessageType, payload: [String: String] = [:]) {
        self.type = type
        self.timestamp = Date()
        self.payload = payload
    }
}

/// Keys used in sync message payloads
enum SyncPayloadKey: String {
    case recordingId
    case filename
    case errorMessage
    case status
}
