See `README.md` for setup instructions.

**New files**: When creating new files in this repo, ask user if they want them whitelisted in `.gitignore`.

**New tools**: When suggesting tool installations, offer both options:
1. `install-packages.sh` - automated, runs on every fresh machine
2. `additional-installs.md` - documented manual step, for optional/situational tools

**Reproducibility**: All changes must be reproducible on a fresh machine. Either:
1. Install script (`install-packages.sh`, `link-configs.sh`, `configure-system.sh`)
2. Passive config (tracked file, symlinked or in XDG path)
3. Documented manual step (`additional-installs.md`)

## Config Changes

| Change | Where |
|--------|-------|
| APT package | `install-packages.sh` → apt block |
| UV/Cargo/Go tool | `install-packages.sh` → respective section |
| Custom binary | `install-packages.sh` → `if ! installed` block |
| New config file | `.gitignore` whitelist + `link-configs.sh` symlink |
| New script | `new-machine-setup/<script>` + `.gitignore` whitelist + `link-configs.sh` symlink to `~/.local/bin/` |
| Tool substitution | install script + `.zshrc` aliases |
| Optional tool | `README.md` → Extras section |

## Idempotency

Scripts are designed for safe re-runs:
- **APT packages**: Always runs `apt install` (apt handles already-installed)
- **Custom binaries**: `if ! installed <cmd>` check before install
- **Symlinks**: Checks if already linked correctly before creating

## Keybindings

| Key | Action |
|-----|--------|
| `Alt+Shift+t` | Toggle theme (dark/light) |
| `Alt+Shift+n` | Toggle focus mode (notifications) |
| `Alt+Shift+b` | Toggle polybar |
| `Super+Ctrl+v` | Toggle screen recording (zenity setup: full screen/region via slop, fps, optional system audio; ffmpeg → ~/Downloads, polybar dot while recording) |
| `Alt+Shift+a` | Toggle lid suspend (stay awake when closed) |
| `Alt+i` | Toggle VPN (Tailscale exit node through DO droplet) |
| `Alt+Shift+p` | Toggle picom compositor |
| `Alt+Shift+s` | Toggle audio recording → split into 4 stems (Demucs) |
| `Alt+Shift+e` | Toggle real-time note/chord detector popup (taps default sink) |
| `Alt+Shift+m` | Toggle cava audio spectrum visualizer popup |
| `Alt+Shift+u` | Mount SD card / press again to eject (notifies status) |
| `Alt+Shift+x` | Capture stream → BPM/key/chord-progression/structure report popup (saved to ~/Music/analysis, opens Thunar) |
| `Alt+Shift+g` | Guitar tab popup (record a riff off the interface → guitar-tabber transcribes it into your library and opens the local web player showing notation + tab with a cursor that follows the recorded audio; Enter stops recording, keybind again to cancel) |
| `Alt+p` | Toggle desktop sprite (animated Ryu wanders/idles/attacks/somersaults plus tatsu, shoryuken, hadouken, taunt, dash, moonwalk on screen edges; superhero landing when dropped from height; drag to any edge, double-click to attack, right-click to close) |
| `Alt+Shift+h` | Toggle screen highlighter (draw over the screen with a thick green marker via gromit-mpx; right-click erases, toggle again clears and exits) |
| `Alt+Shift+j` | Start / hang up a spoken voice-chat call with a Claude agent (push-to-talk: speak, then press to send a turn; Groq Whisper STT → headless `claude -p` streaming → sentence-chunked Kokoro TTS, espeak-ng fallback; conversation remembered across turns via `--resume`, reset each call; polybar cycles mic/hourglass/speaker) |
| `Alt+Shift+k` / AirPod double-press | Send the current turn (`XF86AudioNext` sends while a call is engaged, else falls through to Spotify next-track) |
| `Alt+Ctrl+v` | Clipboard history + emoji popup (lists the last 10 clipboard entries via greenclip in a bordered table; press j/k/l/;/'/n/m/,/./ to pick a row newest-first, e to search all emojis via rofimoji; the pick auto-pastes into the window you came from - Ctrl+Shift+V into terminals, Ctrl+V elsewhere; keybind again to dismiss) |

## Theme

- `tinty apply <scheme>` - apply any base16 scheme
- `tinty list | grep <name>` - find schemes
- Config: `~/.config/theme-schemes` (dark/light toggle preferences)

## Backup

```bash
backup              # interactive menu
backup --all        # bitwarden + simplenote + repos
backup --repos      # repos only
backup --bitwarden  # passwords only
backup --simplenote # notes only
backup --dry-run    # preview repo sync
```

- All syncs are versioned: changed/deleted files go to `<name>.YYYY-MM-DD_HH-MM/`, keeps 3 most recent
- Repos: `gdrive:BACKUPS/` (versions like `.config/2025-01-03_14-30/`)
- Bitwarden: local `~/.local/share/bitwarden-backup/` (keeps 7 exports), remote `gdrive:BACKUPS/bitwarden/`
- Simplenote: local `~/.local/share/simplenote-backup/`, remote `gdrive:BACKUPS/SIMPLENOTE/` (versions like `SIMPLENOTE/2025-01-03_14-30/`)
- Repos manifest: `rclone/backup-repos.txt` (format: `/path:git` or `/path:full`)
- Setup: `rclone config` → create remote named `gdrive` (see `additional-installs.md`)
- First run: `bw login` for Bitwarden, create `~/.config/simplenote/credentials` (email + password lines)

## Tmux Sessionizer

Source: `~/.config/tmux-sessionizer/tmux-sessionizer` (symlinked to `~/.local/bin/`)

Config: `~/.config/tmux-sessionizer/tmux-sessionizer.conf`
- `TS_EXTRA_SEARCH_PATHS` - directories to search (format: `"path:depth"`)
- `TS_BLACKLIST` - regex patterns to exclude from results




