//
//  MockFileManager.swift
//  LifeAdminTests
//
//  Mock FileManager for testing file operations
//

import Foundation

/// Protocol for FileManager operations to enable mocking
protocol FileManagerProtocol {
    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL]
    func fileExists(atPath path: String) -> Bool
    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws
    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL]
    func copyItem(at srcURL: URL, to dstURL: URL) throws
    func removeItem(at url: URL) throws
    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any]
}

// Make FileManager conform to our protocol
extension FileManager: FileManagerProtocol {}

/// Mock FileManager for testing
class MockFileManager: FileManagerProtocol {
    var documentsDirectory: URL = URL(fileURLWithPath: "/mock/documents")
    var existingPaths: Set<String> = []
    var directoryContents: [URL: [URL]] = [:]
    var fileAttributes: [String: [FileAttributeKey: Any]] = [:]
    var copiedFiles: [(source: URL, destination: URL)] = []
    var removedFiles: [URL] = []
    var createdDirectories: [URL] = []

    // Error simulation
    var shouldThrowOnCopy = false
    var shouldThrowOnRemove = false
    var shouldThrowOnContentsOfDirectory = false

    func urls(for directory: FileManager.SearchPathDirectory, in domainMask: FileManager.SearchPathDomainMask) -> [URL] {
        return [documentsDirectory]
    }

    func fileExists(atPath path: String) -> Bool {
        return existingPaths.contains(path)
    }

    func createDirectory(at url: URL, withIntermediateDirectories createIntermediates: Bool, attributes: [FileAttributeKey: Any]?) throws {
        createdDirectories.append(url)
        existingPaths.insert(url.path)
    }

    func contentsOfDirectory(at url: URL, includingPropertiesForKeys keys: [URLResourceKey]?, options mask: FileManager.DirectoryEnumerationOptions) throws -> [URL] {
        if shouldThrowOnContentsOfDirectory {
            throw NSError(domain: "MockFileManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Mock error"])
        }
        return directoryContents[url] ?? []
    }

    func copyItem(at srcURL: URL, to dstURL: URL) throws {
        if shouldThrowOnCopy {
            throw NSError(domain: "MockFileManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Mock copy error"])
        }
        copiedFiles.append((source: srcURL, destination: dstURL))
        existingPaths.insert(dstURL.path)
    }

    func removeItem(at url: URL) throws {
        if shouldThrowOnRemove {
            throw NSError(domain: "MockFileManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Mock remove error"])
        }
        removedFiles.append(url)
        existingPaths.remove(url.path)
    }

    func attributesOfItem(atPath path: String) throws -> [FileAttributeKey: Any] {
        return fileAttributes[path] ?? [:]
    }

    // MARK: - Test Helpers

    func reset() {
        existingPaths.removeAll()
        directoryContents.removeAll()
        fileAttributes.removeAll()
        copiedFiles.removeAll()
        removedFiles.removeAll()
        createdDirectories.removeAll()
        shouldThrowOnCopy = false
        shouldThrowOnRemove = false
        shouldThrowOnContentsOfDirectory = false
    }

    func addFile(at url: URL, creationDate: Date = Date(), size: Int64 = 1024) {
        existingPaths.insert(url.path)
        fileAttributes[url.path] = [
            .creationDate: creationDate,
            .size: size
        ]

        // Add to parent directory contents
        let parentDirectory = url.deletingLastPathComponent()
        var contents = directoryContents[parentDirectory] ?? []
        if !contents.contains(url) {
            contents.append(url)
            directoryContents[parentDirectory] = contents
        }
    }
}
