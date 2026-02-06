//
//  SyncMessageParserTests.swift
//  LifeAdminTests
//
//  Tests for SyncMessageParser
//

import XCTest
@testable import LifeAdmin

final class SyncMessageParserTests: XCTestCase {

    // MARK: - Parse Sync Confirmation Tests

    func testParseSyncConfirmation() {
        let message: [String: Any] = [
            "messageType": "syncConfirmation",
            "recordingId": "watch_abc123",
            "checksum": "def456"
        ]

        let result = SyncMessageParser.parse(message)

        XCTAssertEqual(result, .syncConfirmation(recordingId: "watch_abc123", checksum: "def456"))
    }

    func testParseSyncConfirmationMissingChecksum() {
        let message: [String: Any] = [
            "messageType": "syncConfirmation",
            "recordingId": "watch_abc123"
            // Missing checksum
        ]

        let result = SyncMessageParser.parse(message)

        if case .invalid(let reason) = result {
            XCTAssertTrue(reason.contains("checksum"))
        } else {
            XCTFail("Expected invalid result")
        }
    }

    // MARK: - Parse Sync Failure Tests

    func testParseSyncFailure() {
        let message: [String: Any] = [
            "messageType": "syncFailure",
            "recordingId": "watch_abc123",
            "errorMessage": "Checksum mismatch"
        ]

        let result = SyncMessageParser.parse(message)

        XCTAssertEqual(result, .syncFailure(recordingId: "watch_abc123", errorMessage: "Checksum mismatch"))
    }

    func testParseSyncFailureDefaultsErrorMessage() {
        let message: [String: Any] = [
            "messageType": "syncFailure",
            "recordingId": "watch_abc123"
            // Missing errorMessage - should default
        ]

        let result = SyncMessageParser.parse(message)

        XCTAssertEqual(result, .syncFailure(recordingId: "watch_abc123", errorMessage: "Unknown error"))
    }

    // MARK: - Parse Invalid Messages Tests

    func testParseMissingMessageType() {
        let message: [String: Any] = [
            "recordingId": "watch_abc123"
        ]

        let result = SyncMessageParser.parse(message)

        if case .invalid(let reason) = result {
            XCTAssertTrue(reason.contains("messageType"))
        } else {
            XCTFail("Expected invalid result")
        }
    }

    func testParseMissingRecordingId() {
        let message: [String: Any] = [
            "messageType": "syncConfirmation",
            "checksum": "abc123"
        ]

        let result = SyncMessageParser.parse(message)

        if case .invalid(let reason) = result {
            XCTAssertTrue(reason.contains("recordingId"))
        } else {
            XCTFail("Expected invalid result")
        }
    }

    func testParseUnknownMessageType() {
        let message: [String: Any] = [
            "messageType": "unknownType",
            "recordingId": "watch_abc123"
        ]

        let result = SyncMessageParser.parse(message)

        if case .invalid(let reason) = result {
            XCTAssertTrue(reason.contains("Unknown"))
        } else {
            XCTFail("Expected invalid result")
        }
    }

    func testParseEmptyMessage() {
        let message: [String: Any] = [:]

        let result = SyncMessageParser.parse(message)

        if case .invalid = result {
            // Expected
        } else {
            XCTFail("Expected invalid result")
        }
    }

    // MARK: - Create Confirmation Message Tests

    func testCreateConfirmationMessage() {
        let message = SyncMessageParser.createConfirmationMessage(
            recordingId: "watch_abc123",
            checksum: "def456"
        )

        XCTAssertEqual(message["messageType"] as? String, "syncConfirmation")
        XCTAssertEqual(message["recordingId"] as? String, "watch_abc123")
        XCTAssertEqual(message["checksum"] as? String, "def456")
    }

    func testCreateConfirmationMessageRoundTrip() {
        let original = SyncMessageParser.createConfirmationMessage(
            recordingId: "test_id",
            checksum: "test_checksum"
        )

        let parsed = SyncMessageParser.parse(original)

        XCTAssertEqual(parsed, .syncConfirmation(recordingId: "test_id", checksum: "test_checksum"))
    }

    // MARK: - Create Failure Message Tests

    func testCreateFailureMessage() {
        let message = SyncMessageParser.createFailureMessage(
            recordingId: "watch_abc123",
            error: "Something went wrong"
        )

        XCTAssertEqual(message["messageType"] as? String, "syncFailure")
        XCTAssertEqual(message["recordingId"] as? String, "watch_abc123")
        XCTAssertEqual(message["errorMessage"] as? String, "Something went wrong")
    }

    func testCreateFailureMessageRoundTrip() {
        let original = SyncMessageParser.createFailureMessage(
            recordingId: "test_id",
            error: "Test error"
        )

        let parsed = SyncMessageParser.parse(original)

        XCTAssertEqual(parsed, .syncFailure(recordingId: "test_id", errorMessage: "Test error"))
    }

    // MARK: - Transfer Metadata Tests

    func testCreateTransferMetadata() {
        let metadata = SyncMessageParser.createTransferMetadata(
            recordingId: "watch_abc123",
            checksum: "sha256hash"
        )

        XCTAssertEqual(metadata["type"] as? String, "audioRecording")
        XCTAssertEqual(metadata["recordingId"] as? String, "watch_abc123")
        XCTAssertEqual(metadata["checksum"] as? String, "sha256hash")
        XCTAssertNotNil(metadata["timestamp"])
    }

    func testParseTransferMetadata() {
        let metadata: [String: Any] = [
            "recordingId": "watch_abc123",
            "checksum": "sha256hash",
            "type": "audioRecording"
        ]

        let result = SyncMessageParser.parseTransferMetadata(metadata)

        XCTAssertNotNil(result)
        XCTAssertEqual(result?.recordingId, "watch_abc123")
        XCTAssertEqual(result?.checksum, "sha256hash")
    }

    func testParseTransferMetadataMissingRecordingId() {
        let metadata: [String: Any] = [
            "checksum": "sha256hash"
        ]

        let result = SyncMessageParser.parseTransferMetadata(metadata)

        XCTAssertNil(result)
    }

    func testParseTransferMetadataMissingChecksum() {
        let metadata: [String: Any] = [
            "recordingId": "watch_abc123"
        ]

        let result = SyncMessageParser.parseTransferMetadata(metadata)

        XCTAssertNil(result)
    }

    func testParseTransferMetadataNil() {
        let result = SyncMessageParser.parseTransferMetadata(nil)

        XCTAssertNil(result)
    }

    func testTransferMetadataRoundTrip() {
        let original = SyncMessageParser.createTransferMetadata(
            recordingId: "test_recording",
            checksum: "test_checksum"
        )

        let parsed = SyncMessageParser.parseTransferMetadata(original)

        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.recordingId, "test_recording")
        XCTAssertEqual(parsed?.checksum, "test_checksum")
    }
}
