//
//  AudioPlayerServiceTests.swift
//  LifeAdminTests
//
//  Tests for AudioPlayerService
//

import XCTest
@testable import LifeAdmin

@MainActor
final class AudioPlayerServiceTests: XCTestCase {

    var sut: AudioPlayerService!
    var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        sut = AudioPlayerService()
        tempDirectory = TestHelpers.createTemporaryDirectory()
    }

    override func tearDown() async throws {
        sut.stop()
        sut = nil
        TestHelpers.removeTemporaryDirectory(tempDirectory)
        try await super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialState() {
        XCTAssertFalse(sut.isPlaying)
        XCTAssertNil(sut.currentlyPlaying)
        XCTAssertEqual(sut.currentTime, 0)
        XCTAssertEqual(sut.duration, 0)
    }

    // MARK: - Time Formatting Tests

    func testFormattedCurrentTimeZero() {
        XCTAssertEqual(sut.formattedCurrentTime, "0:00")
    }

    func testFormattedDurationZero() {
        XCTAssertEqual(sut.formattedDuration, "0:00")
    }

    // MARK: - Stop Tests

    func testStopResetsState() {
        // Given: some state (we can't easily set isPlaying without actual playback)
        // When
        sut.stop()

        // Then
        XCTAssertFalse(sut.isPlaying)
        XCTAssertNil(sut.currentlyPlaying)
        XCTAssertEqual(sut.currentTime, 0)
    }

    // MARK: - Play with Invalid File Tests

    func testPlayInvalidFileDoesNotCrash() {
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.m4a")

        // Should not crash, just fail silently
        sut.play(url: invalidURL)

        // Player should not be in playing state with invalid file
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - Pause/Resume State Tests

    func testPauseSetsIsPlayingFalse() {
        sut.pause()
        XCTAssertFalse(sut.isPlaying)
    }

    // MARK: - Seek Tests

    func testSeekUpdatesCurrentTime() {
        let targetTime: TimeInterval = 30.0
        sut.seek(to: targetTime)
        XCTAssertEqual(sut.currentTime, targetTime)
    }
}
