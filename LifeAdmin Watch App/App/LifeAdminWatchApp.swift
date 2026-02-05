//
//  LifeAdminWatchApp.swift
//  LifeAdmin Watch App
//
//  watchOS App Entry Point
//

import SwiftUI

@main
struct LifeAdminWatchApp: App {
    @StateObject private var audioRecorder = AudioRecorderManager()
    @StateObject private var phoneSyncManager = PhoneSyncManager.shared
    @StateObject private var recordingsStore = WatchRecordingsStore.shared

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(audioRecorder)
                .environmentObject(phoneSyncManager)
                .environmentObject(recordingsStore)
        }
    }
}
