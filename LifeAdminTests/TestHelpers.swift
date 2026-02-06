//
//  TestHelpers.swift
//  LifeAdminTests
//
//  Shared test utilities and helpers
//

import Foundation
import XCTest

// MARK: - Test File Helpers

enum TestHelpers {
    /// Creates a temporary directory for test files
    static func createTemporaryDirectory() -> URL {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        return tempDir
    }

    /// Removes a temporary directory and its contents
    static func removeTemporaryDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    /// Creates a dummy audio file for testing
    static func createDummyAudioFile(in directory: URL, named filename: String = "test.m4a") -> URL {
        let fileURL = directory.appendingPathComponent(filename)
        let dummyData = Data(repeating: 0, count: 1024) // 1KB of zeros
        try? dummyData.write(to: fileURL)
        return fileURL
    }

    /// Creates multiple dummy audio files
    static func createDummyAudioFiles(in directory: URL, count: Int) -> [URL] {
        return (0..<count).map { index in
            createDummyAudioFile(in: directory, named: "recording_\(index).m4a")
        }
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    /// Waits for async operations with a timeout
    func waitForAsync(timeout: TimeInterval = 1.0, execute: @escaping () async -> Void) {
        let expectation = expectation(description: "Async operation")

        Task {
            await execute()
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: timeout)
    }

    /// Asserts that two dates are approximately equal (within a tolerance)
    func assertDatesApproximatelyEqual(_ date1: Date, _ date2: Date, tolerance: TimeInterval = 1.0, file: StaticString = #file, line: UInt = #line) {
        let difference = abs(date1.timeIntervalSince(date2))
        XCTAssertLessThanOrEqual(difference, tolerance, "Dates differ by \(difference) seconds", file: file, line: line)
    }
}

// MARK: - Mock Notification Center

class MockNotificationCenter {
    var postedNotifications: [(name: Notification.Name, object: Any?, userInfo: [AnyHashable: Any]?)] = []

    func post(name: Notification.Name, object: Any?, userInfo: [AnyHashable: Any]?) {
        postedNotifications.append((name: name, object: object, userInfo: userInfo))
    }

    func reset() {
        postedNotifications.removeAll()
    }

    func wasNotificationPosted(named name: Notification.Name) -> Bool {
        return postedNotifications.contains { $0.name == name }
    }
}
