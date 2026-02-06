# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Important:** Check `LEARNINGS.md` for quick-hit lessons and gotchas before making changes.

## Project Overview

LifeAdmin is an iOS + watchOS app for voice-driven life administration. The app serves as a portal to life management through AI, working primarily through unstructured voice notes and voice chat interactions that fan out to backend services (todo-list, personal CRM, etc.).

Users record audio clips via the Apple Watch (including via the action button) or iPhone, which sync to a central store for AI-powered task management, contact management, and other life admin tasks.

## Development Roadmap

### Phase 1: Voice Recording Foundation (Current)
Build a simple iPhone + Apple Watch app that records and syncs voice notes:
- Record voice notes on both iPhone and Apple Watch
- Display a synchronized list of recordings on both devices
- iPhone stores recordings (single source of truth)
- Watch can record offline when phone is unavailable, syncs later
- Default UI is a record interface; secondary UI shows the list of recordings

**Do not proceed to Phase 2 until Phase 1 is signed off.**

### Phase 2: Cloud Backend
Move audio storage from local iPhone storage to a cloud backend:
- Preferred: Google Drive with folder-level permissions (if possible without full Drive access)
- Alternative: Another suitable cloud storage provider

### Phase 3: Transcription
Integrate a transcription backend for voice notes.

### Phase 4: AI Analysis & Workflows
Build the AI-powered features: task extraction, contact management, and other life admin workflows.

## Current Phase

**Phase 1: Voice Recording Foundation**

Acceptance criteria:
- [ ] Both apps can record voice notes
- [ ] Both apps display a synchronized list of recordings
- [ ] iPhone is the single source of truth for storage
- [ ] Watch can record when phone is unavailable and sync later
- [ ] Default UI on both platforms is a simple record interface
- [ ] Secondary UI allows navigating through the list of recordings

## Build & Run Commands

### Quick Commands (use these)
```bash
# Run all tests (39 tests)
./scripts/run-tests.sh

# Build iOS and watchOS
./scripts/build.sh

# Build iOS only
./scripts/build.sh ios

# Build watchOS only
./scripts/build.sh watch

# Regenerate Xcode project from project.yml
xcodegen generate

# Open project in Xcode
open LifeAdmin.xcodeproj
```

### Manual xcodebuild Commands
```bash
# Build iOS app
xcodebuild -scheme "LifeAdmin" -destination "platform=iOS Simulator,name=iPhone 14 Pro Max" build

# Build Watch app
xcodebuild -scheme "LifeAdmin Watch App" -destination "generic/platform=watchOS Simulator" CODE_SIGNING_ALLOWED=NO build

# Run tests
xcodebuild -scheme "LifeAdmin" -destination "platform=iOS Simulator,name=iPhone 14 Pro Max" test
```

**Note:** For unprivileged users, set `DEVELOPER_DIR` first:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

## Architecture

```
LifeAdmin/
├── LifeAdmin/                    # iOS app
│   ├── App/                      # App entry point, ContentView
│   ├── Features/
│   │   ├── Recording/            # iPhone recording UI
│   │   ├── Recordings/           # Recordings list view
│   │   └── AudioSync/            # Watch connection status
│   ├── Services/                 # Audio recording, playback, WatchConnectivity
│   └── Models/                   # Data models
├── LifeAdmin Watch App/          # watchOS app
│   ├── App/                      # Watch app entry point, main navigation
│   ├── Features/
│   │   ├── AudioRecording/       # Voice recording feature
│   │   └── Recordings/           # Watch recordings list
│   ├── Intents/                  # App Intents for Action Button
│   └── Services/                 # Phone sync, recordings store
├── Shared/                       # Code shared between iOS and watchOS
│   ├── Models/                   # Shared data models
│   └── WatchConnectivity/        # Shared connectivity protocols
├── LifeAdminTests/               # Unit tests (39 tests)
│   ├── Models/                   # Model tests
│   ├── Services/                 # Service tests
│   └── Mocks/                    # Mock objects for testing
├── scripts/                      # Build and test scripts
│   ├── run-tests.sh              # Run all unit tests
│   └── build.sh                  # Build iOS/watchOS
└── project.yml                   # XcodeGen project definition
```

## Key Technologies

- **SwiftUI**: UI framework for both iOS and watchOS
- **WatchConnectivity**: Syncs audio files from Watch to iPhone
- **AVFoundation**: Audio recording on both platforms
- **WKExtendedRuntimeSession**: Keeps Watch app running during recording
- **App Intents**: Action Button integration for Watch Ultra

## Xcode Project Setup

When creating the Xcode project, configure the following:

### iOS App (LifeAdmin)
1. Create new iOS App project with SwiftUI
2. Bundle ID: `com.yourcompany.LifeAdmin`
3. Deployment target: iOS 17.0+
4. **Capabilities required:**
   - Microphone usage (add `NSMicrophoneUsageDescription` to Info.plist)
   - Background Modes: Audio (for playback)

### Watch App (LifeAdmin Watch App)
1. Add watchOS target to the project
2. Bundle ID: `com.yourcompany.LifeAdmin.watchkitapp`
3. Deployment target: watchOS 10.0+
4. **Capabilities required:**
   - Microphone usage (add `NSMicrophoneUsageDescription` to Info.plist)
   - Background Modes: Audio, Extended Runtime Session
5. **Info.plist additions for Action Button:**
   ```xml
   <key>WKSupportsActionButton</key>
   <true/>
   ```

### Shared Code
- Add files from `Shared/` folder to both iOS and Watch targets
- Ensure WatchConnectivity framework is linked to both targets

## Development Notes

- Watch app requires paired iPhone app for full functionality
- Audio files transfer via `WCSession.transferFile()` for background reliability
- Action Button configured via App Intents in `LifeAdmin Watch App/Intents/`
- Test Watch connectivity using paired simulators (Xcode > Window > Devices and Simulators)
- Watch stores recordings locally with pending sync tracking for offline support
- Once synced to iPhone, Watch copies can be removed (iPhone is source of truth)
- **Recordings are permanent** - never auto-delete user data (see LEARNINGS.md)
- **Commit and push regularly** - don't let work pile up locally

## Version Control

**Commit early and often.** Push to remote regularly to avoid losing work.

```bash
# Standard commit workflow
git add -A
git commit -m "Your commit message"
git push
```

Design decisions should be documented in `docs/PRD.md`.
