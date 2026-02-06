//
//  SyncStateManagerTests.swift
//  LifeAdminTests
//
//  Tests for SyncStateManager
//

import XCTest
@testable import LifeAdmin

final class SyncStateManagerTests: XCTestCase {

    var sut: SyncStateManager!

    override func setUp() {
        super.setUp()
        sut = SyncStateManager()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - Initial State Tests

    func testInitialStateIsPending() {
        let state = sut.state(for: "any_recording")

        XCTAssertEqual(state, .pending)
    }

    func testInitiallyNotInFlight() {
        XCTAssertFalse(sut.isInFlight("any_recording"))
    }

    func testInitiallyNoInFlightIds() {
        XCTAssertTrue(sut.allInFlightIds.isEmpty)
    }

    // MARK: - Mark In-Flight Tests

    func testMarkInFlight() {
        sut.markInFlight("recording_1", checksum: "abc123")

        XCTAssertTrue(sut.isInFlight("recording_1"))
        XCTAssertEqual(sut.state(for: "recording_1"), .inFlight(expectedChecksum: "abc123"))
    }

    func testMarkMultipleInFlight() {
        sut.markInFlight("recording_1", checksum: "abc123")
        sut.markInFlight("recording_2", checksum: "def456")

        XCTAssertTrue(sut.isInFlight("recording_1"))
        XCTAssertTrue(sut.isInFlight("recording_2"))
        XCTAssertEqual(sut.allInFlightIds, Set(["recording_1", "recording_2"]))
    }

    func testMarkInFlightUpdatesChecksum() {
        sut.markInFlight("recording_1", checksum: "original")
        sut.markInFlight("recording_1", checksum: "updated")

        XCTAssertEqual(sut.state(for: "recording_1"), .inFlight(expectedChecksum: "updated"))
    }

    // MARK: - Confirm Sync Tests

    func testConfirmSyncSuccess() {
        sut.markInFlight("recording_1", checksum: "abc123")

        let result = sut.confirmSync(recordingId: "recording_1", receivedChecksum: "abc123")

        XCTAssertEqual(result, .confirmed)
        XCTAssertEqual(sut.state(for: "recording_1"), .synced)
        XCTAssertFalse(sut.isInFlight("recording_1"))
    }

    func testConfirmSyncCaseInsensitive() {
        sut.markInFlight("recording_1", checksum: "ABC123")

        let result = sut.confirmSync(recordingId: "recording_1", receivedChecksum: "abc123")

        XCTAssertEqual(result, .confirmed)
    }

    func testConfirmSyncChecksumMismatch() {
        sut.markInFlight("recording_1", checksum: "abc123")

        let result = sut.confirmSync(recordingId: "recording_1", receivedChecksum: "wrong")

        XCTAssertEqual(result, .checksumMismatch(expected: "abc123", received: "wrong"))
        // Should still be in-flight after mismatch
        XCTAssertEqual(sut.state(for: "recording_1"), .inFlight(expectedChecksum: "abc123"))
    }

    func testConfirmSyncUnknownRecording() {
        let result = sut.confirmSync(recordingId: "unknown", receivedChecksum: "abc123")

        XCTAssertEqual(result, .unknownRecording)
    }

    func testConfirmSyncRemovesFromInFlight() {
        sut.markInFlight("recording_1", checksum: "abc123")
        sut.markInFlight("recording_2", checksum: "def456")

        _ = sut.confirmSync(recordingId: "recording_1", receivedChecksum: "abc123")

        XCTAssertFalse(sut.isInFlight("recording_1"))
        XCTAssertTrue(sut.isInFlight("recording_2"))
        XCTAssertEqual(sut.allInFlightIds, Set(["recording_2"]))
    }

    // MARK: - Handle Failure Tests

    func testHandleFailureRemovesFromInFlight() {
        sut.markInFlight("recording_1", checksum: "abc123")

        sut.handleFailure(recordingId: "recording_1")

        XCTAssertFalse(sut.isInFlight("recording_1"))
        XCTAssertEqual(sut.state(for: "recording_1"), .pending)
    }

    func testHandleFailureUnknownRecordingNoOp() {
        // Should not crash
        sut.handleFailure(recordingId: "unknown")

        XCTAssertEqual(sut.state(for: "unknown"), .pending)
    }

    // MARK: - Should Sync Decision Tests

    func testShouldSyncPendingRecording() {
        let decision = sut.shouldSync(
            recordingId: "recording_1",
            fileExists: true,
            isAlreadyInTransferQueue: false
        )

        XCTAssertEqual(decision, .shouldSync)
    }

    func testShouldSyncFileMissing() {
        let decision = sut.shouldSync(
            recordingId: "recording_1",
            fileExists: false,
            isAlreadyInTransferQueue: false
        )

        XCTAssertEqual(decision, .fileMissing)
    }

    func testShouldSyncAlreadyInTransferQueue() {
        let decision = sut.shouldSync(
            recordingId: "recording_1",
            fileExists: true,
            isAlreadyInTransferQueue: true
        )

        XCTAssertEqual(decision, .alreadyInFlight)
    }

    func testShouldSyncAlreadyInFlight() {
        sut.markInFlight("recording_1", checksum: "abc123")

        let decision = sut.shouldSync(
            recordingId: "recording_1",
            fileExists: true,
            isAlreadyInTransferQueue: false
        )

        XCTAssertEqual(decision, .alreadyInFlight)
    }

    func testShouldSyncAlreadySynced() {
        sut.markInFlight("recording_1", checksum: "abc123")
        _ = sut.confirmSync(recordingId: "recording_1", receivedChecksum: "abc123")

        let decision = sut.shouldSync(
            recordingId: "recording_1",
            fileExists: true,
            isAlreadyInTransferQueue: false
        )

        XCTAssertEqual(decision, .alreadySynced)
    }

    func testShouldSyncPrioritizesFileMissing() {
        // Even if in transfer queue, file missing should take priority
        let decision = sut.shouldSync(
            recordingId: "recording_1",
            fileExists: false,
            isAlreadyInTransferQueue: true
        )

        XCTAssertEqual(decision, .fileMissing)
    }

    // MARK: - Persistence Tests

    func testChecksumsToPersist() {
        sut.markInFlight("recording_1", checksum: "abc123")
        sut.markInFlight("recording_2", checksum: "def456")

        let checksums = sut.checksumsToPersist

        XCTAssertEqual(checksums["recording_1"], "abc123")
        XCTAssertEqual(checksums["recording_2"], "def456")
    }

    func testRestoreChecksums() {
        let checksums = ["recording_1": "abc123", "recording_2": "def456"]

        sut.restoreChecksums(checksums)

        XCTAssertTrue(sut.isInFlight("recording_1"))
        XCTAssertTrue(sut.isInFlight("recording_2"))
        XCTAssertEqual(sut.state(for: "recording_1"), .inFlight(expectedChecksum: "abc123"))
    }

    func testPersistenceRoundTrip() {
        sut.markInFlight("recording_1", checksum: "abc123")
        let persisted = sut.checksumsToPersist

        let newManager = SyncStateManager()
        newManager.restoreChecksums(persisted)

        XCTAssertEqual(newManager.state(for: "recording_1"), .inFlight(expectedChecksum: "abc123"))
    }

    // MARK: - Reset Tests

    func testReset() {
        sut.markInFlight("recording_1", checksum: "abc123")
        _ = sut.confirmSync(recordingId: "recording_1", receivedChecksum: "abc123")
        sut.markInFlight("recording_2", checksum: "def456")

        sut.reset()

        XCTAssertTrue(sut.allInFlightIds.isEmpty)
        XCTAssertEqual(sut.state(for: "recording_1"), .pending)
        XCTAssertEqual(sut.state(for: "recording_2"), .pending)
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() {
        let expectation = XCTestExpectation(description: "Concurrent access")
        expectation.expectedFulfillmentCount = 100

        for i in 0..<100 {
            DispatchQueue.global().async {
                let id = "recording_\(i)"
                self.sut.markInFlight(id, checksum: "checksum_\(i)")
                _ = self.sut.isInFlight(id)
                _ = self.sut.state(for: id)
                _ = self.sut.confirmSync(recordingId: id, receivedChecksum: "checksum_\(i)")
                expectation.fulfill()
            }
        }

        wait(for: [expectation], timeout: 5.0)

        // All should be synced
        for i in 0..<100 {
            XCTAssertEqual(sut.state(for: "recording_\(i)"), .synced)
        }
    }

    // MARK: - State Transition Tests

    func testFullSyncLifecycle() {
        let recordingId = "test_recording"
        let checksum = "abc123"

        // Initial state
        XCTAssertEqual(sut.state(for: recordingId), .pending)

        // Mark in-flight
        sut.markInFlight(recordingId, checksum: checksum)
        XCTAssertEqual(sut.state(for: recordingId), .inFlight(expectedChecksum: checksum))

        // Confirm sync
        let result = sut.confirmSync(recordingId: recordingId, receivedChecksum: checksum)
        XCTAssertEqual(result, .confirmed)
        XCTAssertEqual(sut.state(for: recordingId), .synced)
    }

    func testFailedSyncRetryLifecycle() {
        let recordingId = "test_recording"
        let checksum = "abc123"

        // Mark in-flight
        sut.markInFlight(recordingId, checksum: checksum)

        // Fail
        sut.handleFailure(recordingId: recordingId)
        XCTAssertEqual(sut.state(for: recordingId), .pending)

        // Retry with new checksum
        let newChecksum = "def456"
        sut.markInFlight(recordingId, checksum: newChecksum)
        XCTAssertEqual(sut.state(for: recordingId), .inFlight(expectedChecksum: newChecksum))

        // Confirm with new checksum
        let result = sut.confirmSync(recordingId: recordingId, receivedChecksum: newChecksum)
        XCTAssertEqual(result, .confirmed)
        XCTAssertEqual(sut.state(for: recordingId), .synced)
    }
}
