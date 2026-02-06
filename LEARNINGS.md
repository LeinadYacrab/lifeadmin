# Learnings

Lessons learned during development of LifeAdmin. Reference this file to avoid repeating mistakes.

## Data Persistence

### Recordings are permanent records
Never auto-delete user recordings. This app is a permanent record. Only delete via: user action, Watch→iPhone sync (Watch copy only), or future cloud migration.

## Environment Setup

### Unprivileged Homebrew installation
Standard Homebrew install requires sudo. For non-admin users, use "untar anywhere" method:
```bash
mkdir ~/.homebrew && curl -L https://github.com/Homebrew/brew/tarball/master | tar xz --strip-components 1 -C ~/.homebrew
echo 'export PATH="$HOME/.homebrew/bin:$PATH"' >> ~/.zshrc
```

### Xcode without sudo
Use `DEVELOPER_DIR` env var instead of `sudo xcode-select -s`:
```bash
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
```

### Shell RC files and non-interactive shells
Bash tool runs non-interactive shells that don't auto-source `.zshrc`. Use `source ~/.zshrc && command` or set PATH inline.

## Sync Safety

### Never delete Watch recordings until iPhone confirms receipt
The `WCSessionFileTransfer.didFinish` delegate callback only means the OS accepted the file for transfer - NOT that iPhone received it. Watch must wait for explicit confirmation from iPhone before marking a recording as synced.

### Always verify transfers with checksums
When syncing files between devices:
1. Sender computes SHA256 checksum before sending, includes in metadata
2. Receiver computes checksum after copying, compares to expected
3. Receiver sends confirmation message with verified checksum
4. Sender only marks as synced after receiving confirmation with matching checksum

This prevents data loss from:
- Silent transfer failures
- File corruption during transfer
- Network interruptions

## Version Control

### Commit and push regularly
Don't let work pile up locally. Commit after completing each logical unit of work and push to remote. This prevents losing work and makes it easier to review changes.
