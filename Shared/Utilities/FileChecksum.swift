//
//  FileChecksum.swift
//  Shared
//
//  Provides SHA256 checksum computation for file verification during sync.
//

import Foundation
import CryptoKit

/// Utility for computing file checksums to verify data integrity during sync
public enum FileChecksum {

    /// Computes SHA256 hash of file at the given URL
    /// - Parameter url: File URL to hash
    /// - Returns: Hex-encoded SHA256 hash string, or nil if file cannot be read
    public static func sha256(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        return sha256(of: data)
    }

    /// Computes SHA256 hash of the given data
    /// - Parameter data: Data to hash
    /// - Returns: Hex-encoded SHA256 hash string
    public static func sha256(of data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    /// Verifies that a file matches the expected checksum
    /// - Parameters:
    ///   - url: File URL to verify
    ///   - expectedChecksum: Expected SHA256 hash string
    /// - Returns: True if checksums match, false otherwise
    public static func verify(url: URL, expectedChecksum: String) -> Bool {
        guard let actualChecksum = sha256(of: url) else {
            return false
        }
        return actualChecksum.lowercased() == expectedChecksum.lowercased()
    }
}
