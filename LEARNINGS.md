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
