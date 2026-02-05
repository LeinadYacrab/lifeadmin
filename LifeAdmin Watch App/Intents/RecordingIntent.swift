//
//  RecordingIntent.swift
//  LifeAdmin Watch App
//
//  App Intent for Action Button integration on Apple Watch Ultra
//

import AppIntents
import SwiftUI

/// Intent that starts a voice recording when triggered by the Action Button
@available(watchOS 10.0, *)
struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start recording a voice note")

    /// This intent opens the app when performed
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Post notification to start recording
        NotificationCenter.default.post(name: .startRecordingFromIntent, object: nil)
        return .result()
    }
}

/// Intent that toggles recording (start if stopped, stop if recording)
@available(watchOS 10.0, *)
struct ToggleRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Recording"
    static var description = IntentDescription("Start or stop a voice recording")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .toggleRecordingFromIntent, object: nil)
        return .result()
    }
}

// MARK: - App Shortcuts Provider

@available(watchOS 10.0, *)
struct LifeAdminShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Record with \(.applicationName)",
                "Start recording in \(.applicationName)",
                "New voice note in \(.applicationName)"
            ],
            shortTitle: "Record",
            systemImageName: "mic.fill"
        )
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingFromIntent = Notification.Name("startRecordingFromIntent")
    static let toggleRecordingFromIntent = Notification.Name("toggleRecordingFromIntent")
}
