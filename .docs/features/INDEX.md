# Features Documentation

Core system capabilities and workflows. These are the primary features that make this configuration unique.

## Contents

| File | Description |
|------|-------------|
| [theming.md](theming.md) | Centralized base16 color management via tinty. Single command updates i3, polybar, terminals, tmux, and GTK apps. |
| [backup.md](backup.md) | Versioned backup system: GitHub repos as git bundles + Bitwarden vault/secrets. Uses rclone to sync with Google Drive. |
| [voice-dictation.md](voice-dictation.md) | Non-blocking voice input with background transcription. Records via `sox`, transcribes with `whisper-ctranslate2`. |
| [toggles.md](toggles.md) | System toggles for focus mode, lid suspend, screen recording, and polybar visibility. |
| [workspace.md](workspace.md) | i3 workspace management and tmux sessionizer for fast project switching. |
| [speed-reading.md](speed-reading.md) | RSVP-based speed reading tools for clipboard text in multiple presentation modes. |

## Feature Overview

### Theming
Dark/light toggle with `Mod+Shift+t`. Updates 6+ applications simultaneously via tinty's base16 color scheme management.

### Backup
Interactive backup menu with `backup` command. Git-bundle repo mirrors and encrypted Bitwarden exports (vault + Secrets Manager).

### Voice Dictation
`Mod+v` starts recording, `Mod+v` again stops and transcribes. Output appears in the terminal where recording started. Background transcription keeps the system responsive.

### Toggles
Quick keyboard toggles for common needs:
- **Focus mode**: Suppress notifications
- **Lid suspend**: Keep laptop awake when closed
- **Screen recording**: FFmpeg-based capture
- **Polybar**: Hide/show status bar

### Workspace Management
Vim-style workspace switching (`Ctrl+j/k/l/;`) plus tmux-sessionizer for project-based terminal sessions.

### Speed Reading
RSVP (Rapid Serial Visual Presentation) tools for consuming text faster. Multiple interfaces: popup, TUI, keyboard-controlled.
