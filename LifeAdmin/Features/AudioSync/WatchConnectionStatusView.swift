//
//  WatchConnectionStatusView.swift
//  LifeAdmin
//
//  Shows the connection status with Apple Watch
//

import SwiftUI

struct WatchConnectionStatusView: View {
    @EnvironmentObject var watchConnectivityManager: WatchConnectivityManager

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)

            Text(statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }

    private var statusColor: Color {
        watchConnectivityManager.isWatchConnected ? .green : .orange
    }

    private var statusText: String {
        watchConnectivityManager.isWatchConnected ? "Watch Connected" : "Watch Not Connected"
    }
}

#Preview {
    WatchConnectionStatusView()
        .environmentObject(WatchConnectivityManager.shared)
}
