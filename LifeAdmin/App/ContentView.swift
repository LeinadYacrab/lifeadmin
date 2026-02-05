//
//  ContentView.swift
//  LifeAdmin
//
//  Main content view for the iOS app - Tab-based navigation
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Record tab (default)
            NavigationStack {
                RecordingView()
                    .navigationTitle("Record")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            WatchConnectionStatusView()
                        }
                    }
            }
            .tabItem {
                Label("Record", systemImage: "mic.fill")
            }
            .tag(0)

            // Recordings list tab
            NavigationStack {
                RecordingsListView()
                    .navigationTitle("Recordings")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            WatchConnectionStatusView()
                        }
                    }
            }
            .tabItem {
                Label("Recordings", systemImage: "list.bullet")
            }
            .tag(1)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchConnectivityManager.shared)
}
