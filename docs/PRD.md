# LifeAdmin Product Requirements Document

This document captures key design decisions and requirements for the LifeAdmin app.

## 1. Data Integrity

### 1.1 Recording Sync Verification

**Requirement:** Recordings must never be deleted from a sending device until the receiving device has confirmed successful receipt with checksum verification.

**Rationale:** User recordings are irreplaceable data. Silent transfer failures, network interruptions, or file corruption could cause permanent data loss if we delete recordings prematurely.

**Implementation:**
1. Sender computes SHA256 checksum before initiating transfer
2. Sender includes checksum in file transfer metadata
3. Receiver copies file to permanent storage
4. Receiver computes SHA256 checksum of received file
5. Receiver compares computed checksum to expected checksum
6. On match: Receiver sends `syncConfirmation` message with verified checksum
7. On mismatch: Receiver deletes corrupted file, sends `syncFailure` message
8. Sender only marks recording as "synced" after receiving confirmation with matching checksum
9. Unconfirmed recordings remain in pending state and will be retried

**Key Files:**
- `Shared/Utilities/FileChecksum.swift` - SHA256 computation
- `LifeAdmin Watch App/Services/PhoneSyncManager.swift` - Watch-side sync with confirmation handling
- `LifeAdmin/Services/WatchConnectivityManager.swift` - iPhone-side verification and confirmation

### 1.2 Unique Recording Identifiers

**Requirement:** Recording IDs must be globally unique across all devices with extremely low collision probability, even when devices are offline and cannot coordinate.

**Rationale:**
- Watch and iPhone can both create recordings independently
- Devices may be out of contact for extended periods
- ID collisions could cause recordings to be overwritten or confused during sync
- We cannot rely on a central server for ID coordination

**Implementation:**
- Use UUID v4 (128-bit random) as the core identifier
- Prefix with device type for debugging/tracing: `watch_` or `iphone_`
- Format: `{device}_{uuid}.m4a` (e.g., `watch_550e8400-e29b-41d4-a716-446655440000.m4a`)

**Collision Probability:**
- UUID v4 uses 122 random bits
- Probability of collision after generating 1 billion IDs: ~10^-27
- This exceeds the reliability of the underlying hardware

**Key Files:**
- `Shared/Utilities/RecordingIdGenerator.swift` - Centralized ID generation
- `LifeAdmin Watch App/Features/AudioRecording/AudioRecorderManager.swift` - Watch recording creation
- `LifeAdmin/Services/AudioRecorderService.swift` - iPhone recording creation

## 2. Data Persistence

### 2.1 Recording Retention

**Requirement:** Recordings are permanent records and must never be auto-deleted.

**Rationale:** This app serves as a permanent record of voice notes. Users trust that their recordings will persist. Automatic cleanup would violate this trust and potentially delete important information.

**Allowed Deletion Scenarios:**
1. Explicit user action (delete button)
2. Watch-to-iPhone sync completion (Watch copy only, after checksum verification)
3. Future: Cloud migration (local copy after confirmed cloud upload)

**Prohibited:**
- Time-based cleanup (e.g., "delete recordings older than 7 days")
- Storage-based cleanup (e.g., "delete oldest when storage full")
- Any automatic deletion without explicit user consent

## 3. Sync Architecture

### 3.1 Source of Truth

**Requirement:** iPhone is the source of truth for all recordings.

**Rationale:**
- iPhone has more storage capacity
- iPhone is more likely to be backed up (iCloud, iTunes)
- iPhone will connect to cloud backend in future phases
- Watch storage is limited and transient

**Implications:**
- Watch recordings sync to iPhone, then Watch copy can be removed (after verification)
- iPhone recordings do not sync to Watch
- Future cloud sync will originate from iPhone

### 3.2 Offline Support

**Requirement:** Watch must support fully offline recording with eventual sync.

**Rationale:**
- Watch may be used during activities without iPhone nearby (running, swimming)
- Network connectivity is not guaranteed
- Users should never be blocked from recording

**Implementation:**
- Watch stores recordings locally in `Documents/Recordings/`
- `pendingSync` set tracks recordings awaiting iPhone confirmation
- When connectivity restored, pending recordings are automatically synced
- Recordings persist on Watch until iPhone confirms receipt

### 3.3 Auto-Sync Protocol

**Requirement:** Pending recordings must sync automatically when connectivity is restored, without manual intervention and with minimal battery impact.

**Rationale:**
- Users shouldn't need to manually trigger sync
- Constant polling would drain Watch battery
- Must handle app restarts gracefully (pending state persisted to disk)
- Must not get stuck if events fail to fire

#### Sync Trigger Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│                         SYNC TRIGGERS                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  PRIMARY (Event-Driven) - No battery cost when idle             │
│  ───────────────────────────────────────────────────            │
│  1. activationDidCompleteWith  → App launched                   │
│  2. sessionReachabilityDidChange → Phone became reachable       │
│  3. scenePhase → .active       → User raised wrist/opened app   │
│                                                                 │
│  FALLBACK (Defensive Timer) - Only when pending items exist     │
│  ───────────────────────────────────────────────────────────    │
│  4. 5-minute timer             → Catches stuck states           │
│     └── Auto-stops when pendingSync becomes empty               │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

#### Trigger Details

| Trigger | Type | When It Fires | Why It's Needed |
|---------|------|---------------|-----------------|
| `activationDidCompleteWith` | Event | App starts, session activates | Recover from app termination - re-queue lost transfers |
| `sessionReachabilityDidChange` | Event | Phone becomes reachable | Resume sync after connectivity gap (user returns with phone) |
| `scenePhase → .active` | Event | App comes to foreground | Catch missed events while backgrounded |
| 5-minute timer | Fallback | Every 5 min while pending | Prevent stuck state from edge cases |

#### Why the Fallback Timer?

The primary triggers are event-driven and have zero battery cost when idle. However, edge cases exist where events don't fire:

| Edge Case | What Happens | Timer Catches It |
|-----------|--------------|------------------|
| Stale WCSession | Session stops firing delegate methods | ✓ |
| Already reachable on launch | No transition = no event | ✓ |
| Bluetooth glitch | Reachability state not updated | ✓ |
| Missed scenePhase | SwiftUI doesn't always fire | ✓ |

**Timer Efficiency:**
- ONLY runs when `pendingSync` is non-empty
- Automatically stops when all recordings sync
- 5-minute interval = max 288 checks/day (usually far fewer)
- Most syncs happen via events; timer is rarely the trigger

#### Efficiency Measures

1. **Debouncing (0.5s)**: Rapid events are coalesced. Connectivity flapping doesn't spam sync attempts.

2. **Duplicate Prevention**: Before queuing, checks `WCSession.outstandingFileTransfers`. Skips recordings already in-flight.

3. **Conditional Timer**: Fallback timer only active when needed, not constantly running.

4. **Background-Reliable Transfers**: Uses `transferFile()` not `sendMessage()`:

| Method | Requirement | Survives Suspension | Large Files |
|--------|-------------|---------------------|-------------|
| `sendMessage()` | Both apps active | No | No |
| `transferFile()` | Neither app active | Yes | Yes |

#### Sync Flow

```
Watch records audio offline
         │
         ▼
┌─────────────────────────────┐
│ Save to pendingSync (disk)  │
│ Attempt transferFile()      │──── Phone nearby? ──▶ Transfer queued
└─────────────────────────────┘                      (OS delivers in background)
         │
         │ Phone not nearby
         ▼
┌─────────────────────────────┐
│ Recording waits in          │
│ pendingSync on disk         │
│                             │
│ Fallback timer starts       │
│ (if not already running)    │
└─────────────────────────────┘
         │
         │ Later: phone comes nearby
         ▼
┌─────────────────────────────┐
│ EVENT fires:                │
│ - reachabilityDidChange, or │
│ - scenePhase → .active, or  │
│ - 5-min timer tick          │
└─────────────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ scheduleAutoSync()          │
│ - Debounce 0.5s             │
│ - Check outstandingTransfers│
│ - Queue pending recordings  │
└─────────────────────────────┘
         │
         ▼
┌─────────────────────────────┐
│ OS delivers to iPhone       │
│ iPhone verifies checksum    │
│ iPhone sends confirmation   │
│ Watch removes from pending  │
│                             │
│ If pendingSync empty:       │
│ └── Stop fallback timer     │
└─────────────────────────────┘
```

**Key Files:**
- `LifeAdmin Watch App/Services/PhoneSyncManager.swift` - All sync logic
- `LifeAdmin Watch App/App/LifeAdminWatchApp.swift` - scenePhase observer

## 4. Security Considerations

### 4.1 Local Storage

- Recordings stored in app sandbox (Documents directory)
- No encryption at rest (relies on device encryption)
- Future consideration: App-level encryption for sensitive recordings

### 4.2 Transfer Security

- WatchConnectivity uses encrypted Bluetooth/WiFi
- Checksums verify integrity, not authenticity
- Future consideration: Signed checksums for tamper detection

---

*Last updated: 2026-02-06*
*Version: 1.3 - Comprehensive auto-sync protocol documentation*
