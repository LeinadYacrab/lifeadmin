# Learnings

Lessons learned during development of LifeAdmin. Reference this file to avoid repeating mistakes.

## Data Persistence

### Recordings are permanent records
**Date:** 2025-02-05

**Mistake:** Added auto-cleanup that deleted synced recordings from Watch after 7 days.

**Correction:** Recordings should persist indefinitely unless manually deleted by the user. This app is meant to be a permanent record of voice notes.

**Rule:** Never auto-delete user recordings. The only acceptable deletion is:
- Manual deletion by the user
- Transfer from Watch to iPhone (Watch copy can be removed after successful sync)
- Future: Transfer from iPhone to cloud storage (local copy management TBD)

The iPhone (and eventually cloud) is the permanent store. Watch storage is temporary only because of device constraints, not because recordings should expire.

**Current behavior:** Watch keeps recordings even after syncing to iPhone. User can manually delete from Watch if storage becomes an issue. This is the safest approach until we confirm cloud backup is reliable.
