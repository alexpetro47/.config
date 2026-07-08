#!/bin/bash
#
# Symlink configuration files to expected locations
# Safe to re-run - uses ln -sf (force)
#
set -e

CONFIG_DIR="$HOME/.config"
log() { echo "[$(date +%H:%M:%S)] $*"; }

# Create symlink with backup
# Usage: link_config <source> <target>
_link_config() {
    local src="$1"
    local target="$2"

    if [ ! -e "$src" ]; then
        log "SKIP: Source does not exist: $src"
        return
    fi

    # If target exists and is not a symlink, back it up
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="${target}.backup-$(date +%Y%m%d-%H%M%S)"
        log "Backing up existing $target to $backup"
        mv "$target" "$backup"
    fi

    # Create parent directory if needed
    mkdir -p "$(dirname "$target")"

    ln -sf "$src" "$target"
    log "Linked: $target -> $src"
}

log "Creating symlinks..."

# =============================================================================
# HOME DIRECTORY SYMLINKS
# Files that expect to be in ~ rather than ~/.config
# =============================================================================

rm -f "$HOME/.zshrc"
_link_config "$CONFIG_DIR/zsh/.zshrc" "$HOME/.zshrc"
_link_config "$CONFIG_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
_link_config "$CONFIG_DIR/.xsessionrc" "$HOME/.xsessionrc"

# =============================================================================
# XDG_CONFIG_HOME SYMLINKS
# Most configs are already in ~/.config, no action needed
# These are for configs that might be cloned elsewhere
# =============================================================================

# If repo is cloned somewhere other than ~/.config, uncomment these:
# _link_config "$REPO_DIR/nvim" "$CONFIG_DIR/nvim"
# _link_config "$REPO_DIR/alacritty" "$CONFIG_DIR/alacritty"
# _link_config "$REPO_DIR/i3" "$CONFIG_DIR/i3"
# _link_config "$REPO_DIR/polybar" "$CONFIG_DIR/polybar"
# _link_config "$REPO_DIR/rofi" "$CONFIG_DIR/rofi"
# _link_config "$REPO_DIR/picom" "$CONFIG_DIR/picom"
# _link_config "$REPO_DIR/btop" "$CONFIG_DIR/btop"
# _link_config "$REPO_DIR/kitty" "$CONFIG_DIR/kitty"
# _link_config "$REPO_DIR/lf" "$CONFIG_DIR/lf"
# _link_config "$REPO_DIR/flameshot" "$CONFIG_DIR/flameshot"
# _link_config "$REPO_DIR/pandoc" "$CONFIG_DIR/pandoc"

# =============================================================================
# LOCAL BIN SCRIPTS
# =============================================================================

mkdir -p "$HOME/.local/bin"

# Nerd dictation toggle (if exists)
if [ -f "$CONFIG_DIR/nerd-dictation/nerd-dictation-toggle" ]; then
    _link_config "$CONFIG_DIR/nerd-dictation/nerd-dictation-toggle" "$HOME/.local/bin/nerd-dictation-toggle"
fi

# Theme toggle (gruvbox dark/light)
if [ -f "$CONFIG_DIR/new-machine-setup/toggle-theme" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/toggle-theme" "$HOME/.local/bin/toggle-theme"
fi

# Focus mode toggle
if [ -f "$CONFIG_DIR/new-machine-setup/focus-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/focus-toggle" "$HOME/.local/bin/focus-toggle"
fi

# Screen recording toggle
if [ -f "$CONFIG_DIR/new-machine-setup/screen-record-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/screen-record-toggle" "$HOME/.local/bin/screen-record-toggle"
fi

# Lid suspend toggle and sync
if [ -f "$CONFIG_DIR/new-machine-setup/lid-suspend-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/lid-suspend-toggle" "$HOME/.local/bin/lid-suspend-toggle"
fi
if [ -f "$CONFIG_DIR/new-machine-setup/lid-suspend-sync" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/lid-suspend-sync" "$HOME/.local/bin/lid-suspend-sync"
fi

# VPN toggle and sync (Tailscale exit node)
if [ -f "$CONFIG_DIR/new-machine-setup/vpn-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/vpn-toggle" "$HOME/.local/bin/vpn-toggle"
fi
if [ -f "$CONFIG_DIR/new-machine-setup/vpn-sync" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/vpn-sync" "$HOME/.local/bin/vpn-sync"
fi

# Backup scripts
if [ -f "$CONFIG_DIR/scripts/backup" ]; then
    _link_config "$CONFIG_DIR/scripts/backup" "$HOME/.local/bin/backup"
fi
if [ -f "$CONFIG_DIR/scripts/backup-repos" ]; then
    _link_config "$CONFIG_DIR/scripts/backup-repos" "$HOME/.local/bin/backup-repos"
fi
if [ -f "$CONFIG_DIR/scripts/backup-bitwarden" ]; then
    _link_config "$CONFIG_DIR/scripts/backup-bitwarden" "$HOME/.local/bin/backup-bitwarden"
fi

# Lock script (kills picom during lock)
if [ -f "$CONFIG_DIR/scripts/lock" ]; then
    _link_config "$CONFIG_DIR/scripts/lock" "$HOME/.local/bin/lock"
fi

# Real-time chord/note detector (popup toggle + engine)
if [ -f "$CONFIG_DIR/scripts/chord-detector" ]; then
    _link_config "$CONFIG_DIR/scripts/chord-detector" "$HOME/.local/bin/chord-detector"
fi
if [ -f "$CONFIG_DIR/scripts/chord-detector-popup" ]; then
    _link_config "$CONFIG_DIR/scripts/chord-detector-popup" "$HOME/.local/bin/chord-detector-popup"
fi

# cava audio visualizer popup toggle
if [ -f "$CONFIG_DIR/scripts/cava-popup" ]; then
    _link_config "$CONFIG_DIR/scripts/cava-popup" "$HOME/.local/bin/cava-popup"
fi

# Tmux sessionizer
if [ -f "$CONFIG_DIR/tmux-sessionizer/tmux-sessionizer" ]; then
    _link_config "$CONFIG_DIR/tmux-sessionizer/tmux-sessionizer" "$HOME/.local/bin/tmux-sessionizer"
fi

# Voice dictation (v2 with background transcription)
if [ -f "$CONFIG_DIR/new-machine-setup/voice-dictation" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/voice-dictation" "$HOME/.local/bin/voice-dictation"
fi
if [ -f "$CONFIG_DIR/new-machine-setup/voice-dictation-transcribe" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/voice-dictation-transcribe" "$HOME/.local/bin/voice-dictation-transcribe"
fi

# Standup recorder (crash-safe long-form capture -> chunked local transcription)
if [ -f "$CONFIG_DIR/new-machine-setup/standup-record" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/standup-record" "$HOME/.local/bin/standup-record"
fi
if [ -f "$CONFIG_DIR/new-machine-setup/standup-transcribe-worker" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/standup-transcribe-worker" "$HOME/.local/bin/standup-transcribe-worker"
fi

# Screenshot (picom off → flameshot → picom on)
if [ -f "$CONFIG_DIR/new-machine-setup/screenshot" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/screenshot" "$HOME/.local/bin/screenshot"
fi

# AirPods Bluetooth toggle
if [ -f "$CONFIG_DIR/new-machine-setup/airpods-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/airpods-toggle" "$HOME/.local/bin/airpods-toggle"
fi

# Picom compositor toggle
if [ -f "$CONFIG_DIR/new-machine-setup/picom-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/picom-toggle" "$HOME/.local/bin/picom-toggle"
fi

# Audio stem separation toggle (record system audio -> Demucs 4 stems)
if [ -f "$CONFIG_DIR/new-machine-setup/audio-stems-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/audio-stems-toggle" "$HOME/.local/bin/audio-stems-toggle"
fi

# SD card mount/eject toggle
if [ -f "$CONFIG_DIR/new-machine-setup/sdcard-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/sdcard-toggle" "$HOME/.local/bin/sdcard-toggle"
fi

# Chord/BPM/key analysis popup (captures stream -> full report)
if [ -f "$CONFIG_DIR/new-machine-setup/chord-analyze-popup" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/chord-analyze-popup" "$HOME/.local/bin/chord-analyze-popup"
fi

# Audio analysis helper (BPM/key/onset-slicing) used by audio-stems-toggle
if [ -f "$CONFIG_DIR/new-machine-setup/audio-analyze" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/audio-analyze" "$HOME/.local/bin/audio-analyze"
fi

# Guitar tab popup (record a riff -> engrave notation + tablature)
if [ -f "$CONFIG_DIR/new-machine-setup/guitar-tab-popup" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/guitar-tab-popup" "$HOME/.local/bin/guitar-tab-popup"
fi

# Ralf (ClawdBot CLI wrapper)
if [ -f "$CONFIG_DIR/new-machine-setup/ralf" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/ralf" "$HOME/.local/bin/ralf"
fi

# Desktop sprite toggle (animated on-screen character)
if [ -f "$CONFIG_DIR/new-machine-setup/sprite-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/sprite-toggle" "$HOME/.local/bin/sprite-toggle"
fi

# Black hole break reminder toggle (Ghostty shader terminal)
if [ -f "$CONFIG_DIR/new-machine-setup/blackhole-toggle" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/blackhole-toggle" "$HOME/.local/bin/blackhole-toggle"
fi

# Clipboard history + emoji popup
if [ -f "$CONFIG_DIR/new-machine-setup/clipboard-popup" ]; then
    _link_config "$CONFIG_DIR/new-machine-setup/clipboard-popup" "$HOME/.local/bin/clipboard-popup"
fi


# =============================================================================
# DESKTOP ENTRIES
# =============================================================================

mkdir -p "$HOME/.local/share/applications"

# Jupyter Lab
if [ -f "$CONFIG_DIR/applications/jupyter-lab.desktop" ]; then
    _link_config "$CONFIG_DIR/applications/jupyter-lab.desktop" "$HOME/.local/share/applications/jupyter-lab.desktop"
fi

log "Symlink creation complete!"
