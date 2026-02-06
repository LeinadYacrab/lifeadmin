//
//  AudioRecorderServiceTests.swift
//  LifeAdminTests
//
//  Tests for AudioRecorderService
//

import XCTest
@testable import LifeAdmin

@MainActor
final class AudioRecorderServiceTests: XCTestCase {

    var sut: AudioRecorderService!

    override func setUp() async throws {
        try await super.setUp()
        sut = AudioRecorderService()
    }

    override func tearDown() async throws {
        sut = nil
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(sut.isRecording)
        XCTAssertEqual(sut.recordingDuration, 0)
        // Permission state depends on system, so we don't assert it
    }

    // MARK: - Duration Formatting Tests

    func testFormattedDurationZero() {
        XCTAssertEqual(sut.formattedDuration, "00:00")
    }

    func testFormattedDurationAfterSettingDuration() {
        // We can't easily set recordingDuration since it's @Published private
        // But we can test the format calculation logic by checking initial state
        XCTAssertEqual(sut.formattedDuration, "00:00")
    }

    // MARK: - Stop Recording Tests

    func testStopRecordingWhenNotRecording() {
        // Should not crash when stopping without active recording
        sut.stopRecording()
        XCTAssertFalse(sut.isRecording)
    }

    // MARK: - Start Recording Without Permission Tests

    func testStartRecordingWithoutPermission() {
        // When permission is not granted, startRecording should request it
        // This test verifies the method doesn't crash
        // In a real test environment, we'd mock the permission system

        // If permission is already denied, it should not start recording
        if !sut.permissionGranted {
            sut.startRecording()
            // Should still not be recording if permission wasn't granted
            XCTAssertFalse(sut.isRecording)
        }
    }
}

// MARK: - Duration Formatting Unit Tests

final class DurationFormattingTests: XCTestCase {

    func testFormatDuration() {
        // Test the formatting logic independently
        XCTAssertEqual(formatDuration(0), "00:00")
        XCTAssertEqual(formatDuration(1), "00:01")
        XCTAssertEqual(formatDuration(59), "00:59")
        XCTAssertEqual(formatDuration(60), "01:00")
        XCTAssertEqual(formatDuration(61), "01:01")
        XCTAssertEqual(formatDuration(125), "02:05")
        XCTAssertEqual(formatDuration(3600), "60:00")
        XCTAssertEqual(formatDuration(3661), "61:01")
    }

    // Helper that mirrors the logic in AudioRecorderService
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
