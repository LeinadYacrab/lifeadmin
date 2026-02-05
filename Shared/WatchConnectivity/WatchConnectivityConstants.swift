//
//  WatchConnectivityConstants.swift
//  LifeAdmin
//
//  Shared constants for WatchConnectivity communication
//

import Foundation

/// Constants used for Watch-iPhone communication
enum WatchConnectivityConstants {
    /// Message keys
    enum MessageKey: String {
        case messageType = "messageType"
        case timestamp = "timestamp"
        case recordingId = "recordingId"
        case filename = "filename"
        case duration = "duration"
        case status = "status"
        case errorMessage = "errorMessage"
    }

    /// File transfer metadata keys
    enum FileMetadataKey: String {
        case type = "type"
        case timestamp = "timestamp"
        case recordingId = "recordingId"
        case duration = "duration"
    }

    /// File types
    enum FileType: String {
        case audioRecording = "audioRecording"
    }

    /// Audio file settings
    enum AudioSettings {
        static let fileExtension = "m4a"
        static let sampleRate: Double = 44100
        static let numberOfChannels = 1
    }
}
