//
//  AudioRecording.swift
//  LifeAdmin
//
//  Shared model representing an audio recording
//

import Foundation

/// Represents an audio recording captured from the Apple Watch
struct AudioRecording: Identifiable, Codable, Hashable {
    let id: UUID
    let filename: String
    let createdAt: Date
    let duration: TimeInterval
    let fileSize: Int64

    /// Status of the recording in the processing pipeline
    var status: ProcessingStatus

    init(
        id: UUID = UUID(),
        filename: String,
        createdAt: Date = Date(),
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
        status: ProcessingStatus = .pending
    ) {
        self.id = id
        self.filename = filename
        self.createdAt = createdAt
        self.duration = duration
        self.fileSize = fileSize
        self.status = status
    }
}

/// Processing status for audio recordings
enum ProcessingStatus: String, Codable {
    case pending      // Waiting to be processed
    case transcribing // Currently being transcribed
    case processing   // AI is extracting tasks/contacts
    case completed    // Processing complete
    case failed       // Processing failed
}

// MARK: - Convenience Extensions
extension AudioRecording {
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var formattedDate: String {
        createdAt.formatted(date: .abbreviated, time: .shortened)
    }
}
