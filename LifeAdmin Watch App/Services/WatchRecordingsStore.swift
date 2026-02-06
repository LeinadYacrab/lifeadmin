//
//  WatchRecordingsStore.swift
//  LifeAdmin Watch App
//
//  Manages local storage of recordings on Watch for offline support
//

import Foundation

@MainActor
class WatchRecordingsStore: ObservableObject {
    static let shared = WatchRecordingsStore()

    @Published var recordings: [URL] = []
    @Published var pendingSync: Set<URL> = []

    private let fileManager = FileManager.default

    init() {
        loadRecordings()
        loadPendingSync()
    }

    // MARK: - Storage

    private func getRecordingsDirectory() -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDirectory = documentsDirectory.appendingPathComponent("Recordings", isDirectory: true)

        if !fileManager.fileExists(atPath: recordingsDirectory.path) {
            try? fileManager.createDirectory(at: recordingsDirectory, withIntermediateDirectories: true)
        }

        return recordingsDirectory
    }

    private func getPendingSyncFile() -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent("pendingSync.json")
    }

    // MARK: - Load/Save

    func loadRecordings() {
        let directory = getRecordingsDirectory()
        do {
            let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            recordings = files.filter { $0.pathExtension == "m4a" }
                .sorted { url1, url2 in
                    let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? Date.distantPast
                    return date1 > date2
                }
        } catch {
            print("Error loading recordings: \(error)")
        }
    }

    private func loadPendingSync() {
        let file = getPendingSyncFile()
        guard let data = try? Data(contentsOf: file),
              let paths = try? JSONDecoder().decode([String].self, from: data) else {
            return
        }
        pendingSync = Set(paths.map { URL(fileURLWithPath: $0) })
    }

    private func savePendingSync() {
        let file = getPendingSyncFile()
        let paths = pendingSync.map { $0.path }
        if let data = try? JSONEncoder().encode(paths) {
            try? data.write(to: file)
        }
    }

    // MARK: - Recording Management

    /// Adds a new recording and queues it for sync
    func addRecording(from temporaryURL: URL) -> URL? {
        let directory = getRecordingsDirectory()
        let destinationURL = directory.appendingPathComponent(temporaryURL.lastPathComponent)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: temporaryURL, to: destinationURL)

            // Add to recordings list
            recordings.insert(destinationURL, at: 0)

            // Mark as pending sync
            pendingSync.insert(destinationURL)
            savePendingSync()

            return destinationURL
        } catch {
            print("Error saving recording: \(error)")
            return nil
        }
    }

    /// Marks a recording as synced (successfully transferred to iPhone)
    func markAsSynced(url: URL) {
        pendingSync.remove(url)
        savePendingSync()
    }

    /// Marks a recording as synced by its recording ID (filename without extension)
    func markAsSyncedById(_ recordingId: String) {
        if let url = findRecordingById(recordingId) {
            markAsSynced(url: url)
        }
    }

    /// Finds a recording URL by its ID (filename without extension)
    func findRecordingById(_ recordingId: String) -> URL? {
        return recordings.first { recordingIdFromURL($0) == recordingId }
    }

    /// Extracts recording ID from URL (filename without extension)
    func recordingIdFromURL(_ url: URL) -> String {
        return RecordingIdGenerator.extractId(from: url)
    }

    /// Deletes a recording
    func deleteRecording(url: URL) {
        try? fileManager.removeItem(at: url)
        recordings.removeAll { $0 == url }
        pendingSync.remove(url)
        savePendingSync()
    }

    /// Syncs all pending recordings to iPhone
    func syncPendingRecordings() {
        for url in pendingSync {
            let recordingId = recordingIdFromURL(url)
            PhoneSyncManager.shared.sendAudioFile(url: url, recordingId: recordingId)
        }
    }

}
