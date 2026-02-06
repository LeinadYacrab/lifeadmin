//
//  AudioRecordingTests.swift
//  LifeAdminTests
//
//  Tests for AudioRecording model
//

import XCTest
@testable import LifeAdmin

final class AudioRecordingTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let recording = AudioRecording(filename: "test.m4a")

        XCTAssertFalse(recording.id.uuidString.isEmpty)
        XCTAssertEqual(recording.filename, "test.m4a")
        XCTAssertEqual(recording.duration, 0)
        XCTAssertEqual(recording.fileSize, 0)
        XCTAssertEqual(recording.status, .pending)
    }

    func testCustomInitialization() {
        let id = UUID()
        let date = Date(timeIntervalSince1970: 1000)

        let recording = AudioRecording(
            id: id,
            filename: "custom.m4a",
            createdAt: date,
            duration: 120,
            fileSize: 1024,
            status: .completed
        )

        XCTAssertEqual(recording.id, id)
        XCTAssertEqual(recording.filename, "custom.m4a")
        XCTAssertEqual(recording.createdAt, date)
        XCTAssertEqual(recording.duration, 120)
        XCTAssertEqual(recording.fileSize, 1024)
        XCTAssertEqual(recording.status, .completed)
    }

    // MARK: - Formatting Tests

    func testFormattedDurationZero() {
        let recording = AudioRecording(filename: "test.m4a", duration: 0)
        XCTAssertEqual(recording.formattedDuration, "0:00")
    }

    func testFormattedDurationSeconds() {
        let recording = AudioRecording(filename: "test.m4a", duration: 45)
        XCTAssertEqual(recording.formattedDuration, "0:45")
    }

    func testFormattedDurationMinutesAndSeconds() {
        let recording = AudioRecording(filename: "test.m4a", duration: 125)
        XCTAssertEqual(recording.formattedDuration, "2:05")
    }

    func testFormattedDurationLong() {
        let recording = AudioRecording(filename: "test.m4a", duration: 3661) // 1 hour, 1 minute, 1 second
        XCTAssertEqual(recording.formattedDuration, "61:01")
    }

    func testFormattedFileSize() {
        let recording = AudioRecording(filename: "test.m4a", fileSize: 1024 * 1024) // 1 MB
        XCTAssertTrue(recording.formattedFileSize.contains("MB") || recording.formattedFileSize.contains("1"))
    }

    func testFormattedFileSizeZero() {
        let recording = AudioRecording(filename: "test.m4a", fileSize: 0)
        XCTAssertEqual(recording.formattedFileSize, "Zero KB")
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        let original = AudioRecording(
            filename: "test.m4a",
            createdAt: Date(timeIntervalSince1970: 1000),
            duration: 60,
            fileSize: 2048,
            status: .transcribing
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(AudioRecording.self, from: data)

        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.filename, decoded.filename)
        XCTAssertEqual(original.createdAt, decoded.createdAt)
        XCTAssertEqual(original.duration, decoded.duration)
        XCTAssertEqual(original.fileSize, decoded.fileSize)
        XCTAssertEqual(original.status, decoded.status)
    }

    // MARK: - Hashable Tests

    func testHashable() {
        let recording1 = AudioRecording(filename: "test1.m4a")
        let recording2 = AudioRecording(filename: "test2.m4a")

        var set = Set<AudioRecording>()
        set.insert(recording1)
        set.insert(recording2)
        set.insert(recording1) // Duplicate

        XCTAssertEqual(set.count, 2)
    }

    // MARK: - Status Tests

    func testAllProcessingStatuses() {
        let statuses: [ProcessingStatus] = [.pending, .transcribing, .processing, .completed, .failed]

        for status in statuses {
            let recording = AudioRecording(filename: "test.m4a", status: status)
            XCTAssertEqual(recording.status, status)
        }
    }

    func testStatusRawValues() {
        XCTAssertEqual(ProcessingStatus.pending.rawValue, "pending")
        XCTAssertEqual(ProcessingStatus.transcribing.rawValue, "transcribing")
        XCTAssertEqual(ProcessingStatus.processing.rawValue, "processing")
        XCTAssertEqual(ProcessingStatus.completed.rawValue, "completed")
        XCTAssertEqual(ProcessingStatus.failed.rawValue, "failed")
    }
}
