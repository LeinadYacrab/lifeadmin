//
//  WatchConnectivityConstantsTests.swift
//  LifeAdminTests
//
//  Tests for WatchConnectivityConstants
//

import XCTest
@testable import LifeAdmin

final class WatchConnectivityConstantsTests: XCTestCase {

    // MARK: - Message Type Tests

    func testMessageTypeRawValues() {
        XCTAssertEqual(WatchConnectivityConstants.MessageType.syncConfirmation.rawValue, "syncConfirmation")
        XCTAssertEqual(WatchConnectivityConstants.MessageType.syncFailure.rawValue, "syncFailure")
    }

    // MARK: - Message Key Tests

    func testMessageKeyRawValues() {
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.messageType.rawValue, "messageType")
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.timestamp.rawValue, "timestamp")
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.recordingId.rawValue, "recordingId")
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.filename.rawValue, "filename")
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.duration.rawValue, "duration")
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.status.rawValue, "status")
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.errorMessage.rawValue, "errorMessage")
        XCTAssertEqual(WatchConnectivityConstants.MessageKey.checksum.rawValue, "checksum")
    }

    // MARK: - File Metadata Key Tests

    func testFileMetadataKeyRawValues() {
        XCTAssertEqual(WatchConnectivityConstants.FileMetadataKey.type.rawValue, "type")
        XCTAssertEqual(WatchConnectivityConstants.FileMetadataKey.timestamp.rawValue, "timestamp")
        XCTAssertEqual(WatchConnectivityConstants.FileMetadataKey.recordingId.rawValue, "recordingId")
        XCTAssertEqual(WatchConnectivityConstants.FileMetadataKey.duration.rawValue, "duration")
        XCTAssertEqual(WatchConnectivityConstants.FileMetadataKey.checksum.rawValue, "checksum")
    }

    // MARK: - File Type Tests

    func testFileTypeRawValues() {
        XCTAssertEqual(WatchConnectivityConstants.FileType.audioRecording.rawValue, "audioRecording")
    }

    // MARK: - Audio Settings Tests

    func testAudioSettings() {
        XCTAssertEqual(WatchConnectivityConstants.AudioSettings.fileExtension, "m4a")
        XCTAssertEqual(WatchConnectivityConstants.AudioSettings.sampleRate, 44100)
        XCTAssertEqual(WatchConnectivityConstants.AudioSettings.numberOfChannels, 1)
    }

    // MARK: - Consistency Tests

    func testMessageKeyAndFileMetadataKeyConsistency() {
        // Keys that appear in both enums should have the same raw values
        XCTAssertEqual(
            WatchConnectivityConstants.MessageKey.timestamp.rawValue,
            WatchConnectivityConstants.FileMetadataKey.timestamp.rawValue
        )
        XCTAssertEqual(
            WatchConnectivityConstants.MessageKey.recordingId.rawValue,
            WatchConnectivityConstants.FileMetadataKey.recordingId.rawValue
        )
        XCTAssertEqual(
            WatchConnectivityConstants.MessageKey.duration.rawValue,
            WatchConnectivityConstants.FileMetadataKey.duration.rawValue
        )
        XCTAssertEqual(
            WatchConnectivityConstants.MessageKey.checksum.rawValue,
            WatchConnectivityConstants.FileMetadataKey.checksum.rawValue
        )
    }
}
