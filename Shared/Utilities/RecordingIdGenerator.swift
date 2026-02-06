//
//  RecordingIdGenerator.swift
//  Shared
//
//  Generates globally unique recording identifiers across all devices.
//  Uses UUID v4 with device prefix to ensure no collisions even when
//  devices are offline and cannot coordinate.
//

import Foundation

/// Device types that can create recordings
public enum RecordingDevice: String {
    case watch = "watch"
    case iphone = "iphone"
}

/// Generates unique recording identifiers
public enum RecordingIdGenerator {

    /// Generates a new unique recording ID for the specified device
    /// - Parameter device: The device creating the recording
    /// - Returns: A unique identifier string (e.g., "watch_550e8400-e29b-41d4-a716-446655440000")
    public static func generateId(for device: RecordingDevice) -> String {
        let uuid = UUID().uuidString.lowercased()
        return "\(device.rawValue)_\(uuid)"
    }

    /// Generates a filename for a new recording
    /// - Parameter device: The device creating the recording
    /// - Returns: A unique filename with .m4a extension
    public static func generateFilename(for device: RecordingDevice) -> String {
        return "\(generateId(for: device)).m4a"
    }

    /// Extracts the recording ID from a filename (removes extension)
    /// - Parameter filename: The filename (with or without path)
    /// - Returns: The recording ID
    public static func extractId(from filename: String) -> String {
        let name = (filename as NSString).lastPathComponent
        if name.hasSuffix(".m4a") {
            return String(name.dropLast(4))
        }
        return name
    }

    /// Extracts the recording ID from a URL
    /// - Parameter url: The file URL
    /// - Returns: The recording ID
    public static func extractId(from url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }

    /// Determines which device created a recording based on its ID
    /// - Parameter recordingId: The recording ID
    /// - Returns: The device type, or nil if the ID format is unrecognized
    public static func device(for recordingId: String) -> RecordingDevice? {
        if recordingId.hasPrefix("watch_") {
            return .watch
        } else if recordingId.hasPrefix("iphone_") {
            return .iphone
        }
        return nil
    }

    /// Validates that a recording ID has the expected format
    /// - Parameter recordingId: The recording ID to validate
    /// - Returns: True if the ID is valid
    public static func isValid(_ recordingId: String) -> Bool {
        // Expected format: {device}_{uuid}
        // UUID format: 8-4-4-4-12 lowercase hex characters
        let pattern = "^(watch|iphone)_[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
        return recordingId.range(of: pattern, options: .regularExpression) != nil
    }
}
