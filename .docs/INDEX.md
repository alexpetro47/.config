# ~/.config Documentation

Production-grade dotfiles + system setup repository for Ubuntu-based Linux workstations with i3. Provides automated, idempotent bootstrapping and extensive tooling for development, media, and system administration.

## Contents

| Path | Description |
|------|-------------|
| [setup/](setup/INDEX.md) | New machine bootstrapping pipeline: package installation, config linking, system configuration, and verification. |
| [features/](features/INDEX.md) | Core system capabilities: theming, backup, voice dictation, productivity toggles, and workspace management. |
| [applications/](applications/INDEX.md) | Per-application configuration reference: i3, polybar, zsh, tmux, neovim, terminals, and utilities. |
| [scripts/](scripts/INDEX.md) | Utility scripts index: toggles, backup tools, voice dictation workers, and integrations. |
| [integrations/](integrations/INDEX.md) | External service connections: Bitwarden secrets, rclone backup, Google Drive sync, and remote access. |

## Quick Reference

### New Machine Setup
```bash
# Full bootstrap (run on fresh Ubuntu)
curl -fsSL https://raw.githubusercontent.com/justatoaster47/linux_dotfiles/main/new-machine-setup/bootstrap.sh | bash

# Re-run individual phases
./new-machine-setup/install-packages.sh   # Update packages
./new-machine-setup/link-configs.sh       # Fix symlinks
./new-machine-setup/configure-system.sh   # System config
./new-machine-setup/verify.sh             # Verify installation
```

### Keybindings (Mod = Alt)
| Key | Action |
|-----|--------|
| `Mod+Shift+t` | Toggle theme (dark/light) |
| `Mod+Shift+n` | Toggle focus mode |
| `Mod+Shift+b` | Toggle polybar |
| `Mod+Shift+c` | Toggle screen recording |
| `Mod+Shift+a` | Toggle lid suspend |
| `Mod+v` | Voice dictation (toggle) |
| `Mod+Shift+v` | Cancel voice dictation |
| `Ctrl+j/k/l/;` | Switch workspaces 1-4 |

### Backup
```bash
backup              # Interactive menu
backup --all        # Bitwarden + Repos
backup --repos      # Repos only
backup --dry-run    # Preview sync
```

### Theme
```bash
toggle-theme              # Switch dark/light
tinty apply <scheme>      # Apply specific base16 scheme
tinty list | grep gruvbox # Find schemes
```

## Design Principles

1. **Idempotency**: All scripts check state before acting; safe to re-run
2. **Reproducibility**: Every change tracked in git or documented in `additional-installs.md`
3. **Layered Setup**: Bootstrap → Install → Link → Configure → Verify
4. **Centralized Theming**: Single `toggle-theme` updates 6+ applications via tinty
5. **Secrets Management**: API keys in `~/.claude/.env`, passwords in Bitwarden Secrets Manager
