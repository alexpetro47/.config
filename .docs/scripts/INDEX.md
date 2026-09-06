# Scripts Documentation

Utility scripts provided by this repository. All scripts are in `new-machine-setup/` and symlinked to `~/.local/bin/`.

## Contents

| File | Description |
|------|-------------|
| [toggles.md](toggles.md) | System toggle scripts: theme, focus, lid suspend, screen recording, polybar. |
| [voice.md](voice.md) | Voice dictation scripts: recording controller and transcription worker. |
| [media.md](media.md) | Speed reading utilities and media processing tools. |
| [system.md](system.md) | System utilities: lock screen, tmux sessionizer, ralf CLI. |

## Script Locations

| Location | Purpose |
|----------|---------|
| `new-machine-setup/` | Source files |
| `~/.local/bin/` | Symlinks (in PATH) |

Scripts are never written directly to `~/.local/bin/`. They live in git-tracked directories and are symlinked for access.

## Adding New Scripts

1. Create script in `new-machine-setup/`:
   ```bash
   nvim ~/.config/new-machine-setup/my-script
   chmod +x ~/.config/new-machine-setup/my-script
   ```

2. Add symlink in `link-configs.sh`:
   ```bash
   ln -sf "$CONFIG_DIR/new-machine-setup/my-script" "$HOME/.local/bin/my-script"
   ```

3. Run link script:
   ```bash
   ./new-machine-setup/link-configs.sh
   ```

4. Add i3 keybinding if needed:
   ```
   bindsym $mod+x exec --no-startup-id my-script
   ```

## Script Categories

### Toggles

State-based scripts that turn features on/off:
- `toggle-theme` - Dark/light theme
- `focus-toggle` - Notification suppression
- `lid-suspend-toggle` - Laptop lid behavior
- `screen-record-toggle` - Screen capture

### Backup

Cloud sync utilities:
- `backup` - Interactive menu
- `backup-repos` - Repository sync
- `backup-bitwarden` - Vault export

See [features/backup.md](../features/backup.md) for the full system.

### Voice

Audio input and transcription:
- `voice-dictation` - Recording controller
- `voice-dictation-transcribe` - Background worker

### Media

Content consumption tools:
- `speedread-clipboard` - RSVP clipboard reader
- `speedread-tui` - Terminal UI reader
- `speedread-popup` - Popup window reader
- `speedread-keys` - Keyboard-controlled reader

### System

General utilities:
- `lock` - Screen lock
- `tmux-sessionizer` - Project session manager
- `ralf` - ClawdBot CLI wrapper
- `lid-suspend-sync` - Startup state sync

## Common Patterns

### Toggle Pattern

```bash
#!/bin/bash
STATE_FILE="/tmp/my-feature-state"

if [ -f "$STATE_FILE" ]; then
    # Turn off
    rm "$STATE_FILE"
else
    # Turn on
    touch "$STATE_FILE"
fi
```

### Polybar IPC Update

```bash
# Update polybar module
polybar-msg action module-name hook 0  # Off state
polybar-msg action module-name hook 1  # On state
```

### Notification

```bash
notify-send "Title" "Message"
```
