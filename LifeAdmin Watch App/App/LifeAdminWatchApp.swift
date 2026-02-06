//
//  LifeAdminWatchApp.swift
//  LifeAdmin Watch App
//
//  watchOS App Entry Point
//

import SwiftUI

@main
struct LifeAdminWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var audioRecorder = AudioRecorderManager()
    @StateObject private var phoneSyncManager = PhoneSyncManager.shared
    @StateObject private var recordingsStore = WatchRecordingsStore.shared

    var body: some Scene {
        WindowGroup {
            WatchMainView()
                .environmentObject(audioRecorder)
                .environmentObject(phoneSyncManager)
                .environmentObject(recordingsStore)
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    if newPhase == .active {
                        // App came to foreground - trigger sync check
                        phoneSyncManager.onAppForeground()
                    }
                }
        }
    }
}
