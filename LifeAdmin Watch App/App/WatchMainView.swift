//
//  WatchMainView.swift
//  LifeAdmin Watch App
//
//  Main navigation view for Apple Watch with tab-based interface
//

import SwiftUI

struct WatchMainView: View {
    @EnvironmentObject var audioRecorder: AudioRecorderManager
    @EnvironmentObject var phoneSyncManager: PhoneSyncManager
    @EnvironmentObject var recordingsStore: WatchRecordingsStore

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Record tab (default)
            RecordingView()
                .tag(0)

            // Recordings list tab
            NavigationStack {
                WatchRecordingsListView()
            }
            .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
}

#Preview {
    WatchMainView()
        .environmentObject(AudioRecorderManager())
        .environmentObject(PhoneSyncManager.shared)
        .environmentObject(WatchRecordingsStore.shared)
}
