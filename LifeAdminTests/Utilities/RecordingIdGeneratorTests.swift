//
//  RecordingIdGeneratorTests.swift
//  LifeAdminTests
//
//  Tests for RecordingIdGenerator
//

import XCTest
@testable import LifeAdmin

final class RecordingIdGeneratorTests: XCTestCase {

    // MARK: - ID Generation Tests

    func testGenerateIdForWatch() {
        let id = RecordingIdGenerator.generateId(for: .watch)

        XCTAssertTrue(id.hasPrefix("watch_"))
        XCTAssertTrue(RecordingIdGenerator.isValid(id))
    }

    func testGenerateIdForIphone() {
        let id = RecordingIdGenerator.generateId(for: .iphone)

        XCTAssertTrue(id.hasPrefix("iphone_"))
        XCTAssertTrue(RecordingIdGenerator.isValid(id))
    }

    func testGenerateFilename() {
        let filename = RecordingIdGenerator.generateFilename(for: .watch)

        XCTAssertTrue(filename.hasPrefix("watch_"))
        XCTAssertTrue(filename.hasSuffix(".m4a"))
    }

    // MARK: - Uniqueness Tests

    func testGeneratedIdsAreUnique() {
        var ids = Set<String>()
        let count = 10000

        for _ in 0..<count {
            let id = RecordingIdGenerator.generateId(for: .watch)
            ids.insert(id)
        }

        XCTAssertEqual(ids.count, count, "Generated \(count - ids.count) duplicate IDs out of \(count)")
    }

    func testWatchAndIphoneIdsNeverCollide() {
        // Generate many IDs from both devices and ensure no collisions
        var allIds = Set<String>()
        let countPerDevice = 5000

        for _ in 0..<countPerDevice {
            let watchId = RecordingIdGenerator.generateId(for: .watch)
            let iphoneId = RecordingIdGenerator.generateId(for: .iphone)
            allIds.insert(watchId)
            allIds.insert(iphoneId)
        }

        let expectedCount = countPerDevice * 2
        XCTAssertEqual(allIds.count, expectedCount, "Found \(expectedCount - allIds.count) collisions")
    }

    func testConcurrentIdGeneration() {
        // Test thread safety by generating IDs concurrently
        let count = 1000
        var ids = [String]()
        let lock = NSLock()
        let group = DispatchGroup()

        for _ in 0..<count {
            group.enter()
            DispatchQueue.global().async {
                let id = RecordingIdGenerator.generateId(for: .watch)
                lock.lock()
                ids.append(id)
                lock.unlock()
                group.leave()
            }
        }

        group.wait()

        let uniqueIds = Set(ids)
        XCTAssertEqual(uniqueIds.count, count, "Concurrent generation produced \(count - uniqueIds.count) duplicates")
    }

    // MARK: - ID Extraction Tests

    func testExtractIdFromFilename() {
        let id = RecordingIdGenerator.extractId(from: "watch_550e8400-e29b-41d4-a716-446655440000.m4a")
        XCTAssertEqual(id, "watch_550e8400-e29b-41d4-a716-446655440000")
    }

    func testExtractIdFromFilenameWithoutExtension() {
        let id = RecordingIdGenerator.extractId(from: "watch_550e8400-e29b-41d4-a716-446655440000")
        XCTAssertEqual(id, "watch_550e8400-e29b-41d4-a716-446655440000")
    }

    func testExtractIdFromURL() {
        let url = URL(fileURLWithPath: "/path/to/watch_550e8400-e29b-41d4-a716-446655440000.m4a")
        let id = RecordingIdGenerator.extractId(from: url)
        XCTAssertEqual(id, "watch_550e8400-e29b-41d4-a716-446655440000")
    }

    // MARK: - Device Detection Tests

    func testDeviceForWatchId() {
        let id = "watch_550e8400-e29b-41d4-a716-446655440000"
        XCTAssertEqual(RecordingIdGenerator.device(for: id), .watch)
    }

    func testDeviceForIphoneId() {
        let id = "iphone_550e8400-e29b-41d4-a716-446655440000"
        XCTAssertEqual(RecordingIdGenerator.device(for: id), .iphone)
    }

    func testDeviceForUnknownId() {
        let id = "unknown_550e8400-e29b-41d4-a716-446655440000"
        XCTAssertNil(RecordingIdGenerator.device(for: id))
    }

    func testDeviceForLegacyTimestampId() {
        // Old format: recording_1234567890.123456
        let id = "recording_1234567890.123456"
        XCTAssertNil(RecordingIdGenerator.device(for: id))
    }

    // MARK: - Validation Tests

    func testIsValidWithValidWatchId() {
        let id = "watch_550e8400-e29b-41d4-a716-446655440000"
        XCTAssertTrue(RecordingIdGenerator.isValid(id))
    }

    func testIsValidWithValidIphoneId() {
        let id = "iphone_550e8400-e29b-41d4-a716-446655440000"
        XCTAssertTrue(RecordingIdGenerator.isValid(id))
    }

    func testIsValidWithInvalidPrefix() {
        let id = "android_550e8400-e29b-41d4-a716-446655440000"
        XCTAssertFalse(RecordingIdGenerator.isValid(id))
    }

    func testIsValidWithInvalidUUID() {
        let id = "watch_not-a-valid-uuid"
        XCTAssertFalse(RecordingIdGenerator.isValid(id))
    }

    func testIsValidWithUppercaseUUID() {
        // UUIDs should be lowercase
        let id = "watch_550E8400-E29B-41D4-A716-446655440000"
        XCTAssertFalse(RecordingIdGenerator.isValid(id))
    }

    func testIsValidWithLegacyTimestampFormat() {
        let id = "recording_1234567890.123456"
        XCTAssertFalse(RecordingIdGenerator.isValid(id))
    }

    // MARK: - Format Consistency Tests

    func testGeneratedIdMatchesExpectedFormat() {
        let id = RecordingIdGenerator.generateId(for: .watch)

        // Should match: watch_{uuid}
        let components = id.split(separator: "_", maxSplits: 1)
        XCTAssertEqual(components.count, 2)
        XCTAssertEqual(components[0], "watch")

        // UUID should be valid format
        let uuidPart = String(components[1])
        XCTAssertNotNil(UUID(uuidString: uuidPart))
    }

    func testRoundTripFilenameToId() {
        let originalFilename = RecordingIdGenerator.generateFilename(for: .iphone)
        let extractedId = RecordingIdGenerator.extractId(from: originalFilename)
        let reconstructedFilename = "\(extractedId).m4a"

        XCTAssertEqual(originalFilename, reconstructedFilename)
    }
}
