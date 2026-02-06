//
//  FileChecksumTests.swift
//  LifeAdminTests
//
//  Tests for FileChecksum utility
//

import XCTest
@testable import LifeAdmin

final class FileChecksumTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        tempDirectory = TestHelpers.createTemporaryDirectory()
    }

    override func tearDown() {
        TestHelpers.removeTemporaryDirectory(tempDirectory)
        super.tearDown()
    }

    // MARK: - SHA256 Data Tests

    func testSHA256OfEmptyData() {
        let data = Data()
        let hash = FileChecksum.sha256(of: data)

        // SHA256 of empty data is a known constant
        XCTAssertEqual(hash, "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855")
    }

    func testSHA256OfKnownData() {
        let data = "Hello, World!".data(using: .utf8)!
        let hash = FileChecksum.sha256(of: data)

        // Known SHA256 hash for "Hello, World!"
        XCTAssertEqual(hash, "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
    }

    func testSHA256ProducesSameHashForSameData() {
        let data = "Test data for hashing".data(using: .utf8)!

        let hash1 = FileChecksum.sha256(of: data)
        let hash2 = FileChecksum.sha256(of: data)

        XCTAssertEqual(hash1, hash2)
    }

    func testSHA256ProducesDifferentHashForDifferentData() {
        let data1 = "First string".data(using: .utf8)!
        let data2 = "Second string".data(using: .utf8)!

        let hash1 = FileChecksum.sha256(of: data1)
        let hash2 = FileChecksum.sha256(of: data2)

        XCTAssertNotEqual(hash1, hash2)
    }

    // MARK: - SHA256 File Tests

    func testSHA256OfFile() throws {
        let fileURL = tempDirectory.appendingPathComponent("test.txt")
        let content = "File content for testing"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let hash = FileChecksum.sha256(of: fileURL)

        XCTAssertNotNil(hash)
        // Hash should match the hash of the same content as Data
        XCTAssertEqual(hash, FileChecksum.sha256(of: content.data(using: .utf8)!))
    }

    func testSHA256OfNonexistentFile() {
        let fileURL = tempDirectory.appendingPathComponent("nonexistent.txt")

        let hash = FileChecksum.sha256(of: fileURL)

        XCTAssertNil(hash)
    }

    // MARK: - Verify Tests

    func testVerifyWithMatchingChecksum() throws {
        let fileURL = tempDirectory.appendingPathComponent("verify.txt")
        let content = "Content to verify"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let checksum = FileChecksum.sha256(of: fileURL)!

        XCTAssertTrue(FileChecksum.verify(url: fileURL, expectedChecksum: checksum))
    }

    func testVerifyWithMismatchedChecksum() throws {
        let fileURL = tempDirectory.appendingPathComponent("verify.txt")
        let content = "Content to verify"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let wrongChecksum = "0000000000000000000000000000000000000000000000000000000000000000"

        XCTAssertFalse(FileChecksum.verify(url: fileURL, expectedChecksum: wrongChecksum))
    }

    func testVerifyWithNonexistentFile() {
        let fileURL = tempDirectory.appendingPathComponent("nonexistent.txt")
        let anyChecksum = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

        XCTAssertFalse(FileChecksum.verify(url: fileURL, expectedChecksum: anyChecksum))
    }

    func testVerifyIsCaseInsensitive() throws {
        let fileURL = tempDirectory.appendingPathComponent("case.txt")
        let content = "Case test"
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        let checksum = FileChecksum.sha256(of: fileURL)!
        let upperChecksum = checksum.uppercased()
        let lowerChecksum = checksum.lowercased()

        XCTAssertTrue(FileChecksum.verify(url: fileURL, expectedChecksum: upperChecksum))
        XCTAssertTrue(FileChecksum.verify(url: fileURL, expectedChecksum: lowerChecksum))
    }

    // MARK: - Consistency Tests

    func testChecksumConsistentAcrossFileRewrite() throws {
        let fileURL = tempDirectory.appendingPathComponent("rewrite.txt")
        let content = "Original content"

        // Write file first time
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        let hash1 = FileChecksum.sha256(of: fileURL)

        // Delete and rewrite with same content
        try FileManager.default.removeItem(at: fileURL)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        let hash2 = FileChecksum.sha256(of: fileURL)

        XCTAssertEqual(hash1, hash2)
    }
}
