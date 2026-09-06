# Config Linking

Creates symlinks from target locations to tracked config files in this repository.

## Location

`new-machine-setup/link-configs.sh`

## Symlink Categories

### Shell Configs

| Target | Source |
|--------|--------|
| `~/.zshrc` | `zsh/.zshrc` |
| `~/.tmux.conf` | `tmux/tmux.conf` |

### Scripts (`~/.local/bin/`)

| Script | Purpose |
|--------|---------|
| `toggle-theme` | Dark/light theme switching |
| `focus-toggle` | Notification suppression |
| `lid-suspend-toggle` | Laptop lid behavior |
| `lid-suspend-sync` | Sync polybar lid icon on startup |
| `screen-record-toggle` | Start/stop screen recording |
| `voice-dictation` | Voice input recording |
| `voice-dictation-transcribe` | Background transcription worker |
| `backup` | Interactive backup menu |
| `backup-repos` | Repository backup to cloud |
| `backup-bitwarden` | Vault export and sync |
| `backup-reminder` | Overdue-backup nag |
| `lock` | Screen lock (kills picom) |
| `speedread-*` | Speed reading utilities |
| `ralf` | ClawdBot CLI wrapper |
| `tmux-sessionizer` | Project session manager |

### Desktop Files (`~/.local/share/applications/`)

Custom `.desktop` files for applications that need special launch parameters or integrations.

## Symlink Behavior

The script checks before creating symlinks:

```bash
# Only creates if not already linked correctly
if [ ! -L "$target" ] || [ "$(readlink "$target")" != "$source" ]; then
    ln -sf "$source" "$target"
fi
```

This ensures:
- Existing correct symlinks are skipped
- Broken symlinks are replaced
- Wrong targets are corrected
- Safe to re-run

## Adding New Symlinks

1. Add the config file to appropriate directory in repo
2. Add symlink creation to `link-configs.sh`:

```bash
ln -sf "$CONFIG_DIR/myapp/config" "$HOME/.config/myapp/config"
```

3. Whitelist in `.gitignore` if needed

## Troubleshooting

**Symlink exists but points wrong place:**
```bash
./link-configs.sh  # Will fix automatically
```

**File exists instead of symlink:**
```bash
rm ~/.zshrc
./link-configs.sh
```

**Check all symlinks:**
```bash
./verify.sh  # Reports broken symlinks
```
