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

**Requirement:** Pending recordings must sync automatically when connectivity is restored, without polling or manual intervention.

**Rationale:**
- Users shouldn't need to manually trigger sync
- Polling would drain Watch battery
- Must handle app restarts gracefully (pending state persisted to disk)

**Protocol Design - Event-Driven, Not Polling:**

| Trigger Event | When It Fires | Action |
|---------------|---------------|--------|
| `activationDidCompleteWith` | App starts, session activates | Schedule auto-sync |
| `sessionReachabilityDidChange` | Phone becomes reachable | Schedule auto-sync (if transition from unreachable→reachable) |

**Why These Events:**
- `activationDidCompleteWith`: Handles app restart case. If app was terminated with pending syncs, this re-queues them.
- `sessionReachabilityDidChange`: Handles connectivity restoration. When Watch regains contact with iPhone, pending syncs resume.

**Efficiency Measures:**

1. **No Polling**: Purely event-driven. No timers, no periodic checks.

2. **Debouncing** (0.5s): Rapid reconnect events are coalesced. If connectivity flaps, we don't spam sync attempts.

3. **Duplicate Prevention**: Before queuing a transfer, we check `WCSession.outstandingFileTransfers` to see if that recording is already in-flight. Avoids re-sending files the OS is already transferring.

4. **Background-Reliable Transfers**: Uses `transferFile()` instead of `sendMessage()`:
   - `sendMessage()` requires both apps active simultaneously
   - `transferFile()` queues transfers for background delivery
   - OS handles network-level retries automatically
   - Survives app suspension (but not termination)

**Why Not Use `sendMessage()`:**
- Requires iPhone app to be reachable at the exact moment of send
- Watch app may be suspended before delivery completes
- Not suitable for large audio files

**Key Files:**
- `LifeAdmin Watch App/Services/PhoneSyncManager.swift` - Auto-sync implementation

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
*Version: 1.1 - Added auto-sync protocol documentation*
