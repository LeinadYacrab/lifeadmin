//
//  SyncMessageTests.swift
//  LifeAdminTests
//
//  Tests for SyncMessage model
//

import XCTest
@testable import LifeAdmin

final class SyncMessageTests: XCTestCase {

    // MARK: - Initialization Tests

    func testDefaultInitialization() {
        let message = SyncMessage(type: .audioFile)

        XCTAssertEqual(message.type, .audioFile)
        XCTAssertTrue(message.payload.isEmpty)
        XCTAssertNotNil(message.timestamp)
    }

    func testInitializationWithPayload() {
        let payload = ["key1": "value1", "key2": "value2"]
        let message = SyncMessage(type: .statusUpdate, payload: payload)

        XCTAssertEqual(message.type, .statusUpdate)
        XCTAssertEqual(message.payload["key1"], "value1")
        XCTAssertEqual(message.payload["key2"], "value2")
    }

    // MARK: - Message Type Tests

    func testAllMessageTypes() {
        let types: [SyncMessageType] = [.audioFile, .statusUpdate, .recordingComplete, .error]

        for type in types {
            let message = SyncMessage(type: type)
            XCTAssertEqual(message.type, type)
        }
    }

    func testMessageTypeRawValues() {
        XCTAssertEqual(SyncMessageType.audioFile.rawValue, "audioFile")
        XCTAssertEqual(SyncMessageType.statusUpdate.rawValue, "statusUpdate")
        XCTAssertEqual(SyncMessageType.recordingComplete.rawValue, "recordingComplete")
        XCTAssertEqual(SyncMessageType.error.rawValue, "error")
    }

    // MARK: - Codable Tests

    func testEncodingDecoding() throws {
        let payload = ["filename": "test.m4a", "status": "completed"]
        let original = SyncMessage(type: .recordingComplete, payload: payload)

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(SyncMessage.self, from: data)

        XCTAssertEqual(original.type, decoded.type)
        XCTAssertEqual(original.payload, decoded.payload)
        // Timestamps might have slight precision differences, so check they're close
        XCTAssertEqual(
            original.timestamp.timeIntervalSince1970,
            decoded.timestamp.timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testDecodingFromJSON() throws {
        let json = """
        {
            "type": "error",
            "timestamp": 1000.0,
            "payload": {"errorMessage": "Something went wrong"}
        }
        """

        let data = json.data(using: .utf8)!
        let decoder = JSONDecoder()
        let message = try decoder.decode(SyncMessage.self, from: data)

        XCTAssertEqual(message.type, .error)
        XCTAssertEqual(message.payload["errorMessage"], "Something went wrong")
    }

    // MARK: - Payload Key Tests

    func testSyncPayloadKeys() {
        XCTAssertEqual(SyncPayloadKey.recordingId.rawValue, "recordingId")
        XCTAssertEqual(SyncPayloadKey.filename.rawValue, "filename")
        XCTAssertEqual(SyncPayloadKey.errorMessage.rawValue, "errorMessage")
        XCTAssertEqual(SyncPayloadKey.status.rawValue, "status")
    }

    func testPayloadWithSyncPayloadKeys() {
        let payload: [String: String] = [
            SyncPayloadKey.recordingId.rawValue: "123",
            SyncPayloadKey.filename.rawValue: "test.m4a"
        ]

        let message = SyncMessage(type: .audioFile, payload: payload)

        XCTAssertEqual(message.payload[SyncPayloadKey.recordingId.rawValue], "123")
        XCTAssertEqual(message.payload[SyncPayloadKey.filename.rawValue], "test.m4a")
    }

    // MARK: - Timestamp Tests

    func testTimestampIsRecent() {
        let beforeCreation = Date()
        let message = SyncMessage(type: .statusUpdate)
        let afterCreation = Date()

        XCTAssertGreaterThanOrEqual(message.timestamp, beforeCreation)
        XCTAssertLessThanOrEqual(message.timestamp, afterCreation)
    }
}
