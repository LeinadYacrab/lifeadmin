//
//  LifeAdminApp.swift
//  LifeAdmin
//
//  iOS App Entry Point
//

import SwiftUI

@main
struct LifeAdminApp: App {
    @StateObject private var watchConnectivityManager = WatchConnectivityManager.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(watchConnectivityManager)
        }
    }
}
