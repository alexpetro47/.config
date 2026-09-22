#!/bin/bash
#
# System configuration - git, systemctl, shell, defaults
# Safe to re-run - idempotent operations
#
set -e

log() { echo "[$(date +%H:%M:%S)] $*"; }

# =============================================================================
# GIT GLOBAL CONFIG
# =============================================================================
log "Configuring git..."

git config --global user.name "Alex Petro"
git config --global user.email "alexmpetro@gmail.com"
git config --global push.autoSetupRemote true
git config --global init.defaultBranch main
git config --global --replace-all credential.helper /usr/local/bin/git-credential-manager
git config --global credential.credentialStore secretservice

log "Git config set:"
git config --global --list | grep -E "^(user\.|push\.|init\.|credential\.)" | sed 's/^/  /'

# =============================================================================
# CLONE REPOS
# =============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/clone-repos.sh" ]; then
    bash "$SCRIPT_DIR/clone-repos.sh"
fi

# =============================================================================
# DEFAULT SHELL
# =============================================================================
if [ "$SHELL" != "$(which zsh)" ]; then
    log "Changing default shell to zsh..."
    chsh -s "$(which zsh)"
    log "Shell changed - will take effect on next login"
else
    log "Shell already set to zsh"
fi

# =============================================================================
# SYSTEMCTL ENABLES
# =============================================================================
log "Enabling system services..."

sudo systemctl enable NetworkManager 2>/dev/null || log "WARN: NetworkManager enable failed"
sudo systemctl enable docker 2>/dev/null || log "WARN: docker enable failed"

# Disable GNOME Remote Desktop - ships enabled by default on Ubuntu, not needed
systemctl --user disable --now gnome-remote-desktop.service 2>/dev/null || true
log "GNOME Remote Desktop disabled"

# Overdue-backup reminder. Unit files live in ~/.config/systemd/user (this repo), so the
# daemon-reload is what makes a fresh machine notice them.
systemctl --user daemon-reload
systemctl --user enable --now backup-reminder.timer 2>/dev/null || log "WARN: backup-reminder.timer enable failed"
log "Backup reminder timer enabled"

# TLP power management - optimized for unplugged laptop use
if command -v tlp &>/dev/null; then
    log "Enabling TLP power management..."
    sudo systemctl enable tlp
    sudo systemctl start tlp
    # Disable conflicting power-profiles-daemon if present
    sudo systemctl disable --now power-profiles-daemon 2>/dev/null || true
    sudo systemctl mask power-profiles-daemon 2>/dev/null || true

    # Configure CPU power management
    if [ -f /etc/tlp.conf ]; then
        scaling_driver=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_driver 2>/dev/null)
        if [[ "$scaling_driver" == "amd-pstate"* ]]; then
            # AMD pstate uses EPP for power control, governor is always powersave
            log "Configuring TLP for AMD pstate-epp (EPP: power on battery, balance_performance on AC)..."
            sudo sed -i 's/^#\?CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=powersave/' /etc/tlp.conf
            sudo sed -i 's/^#\?CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=powersave/' /etc/tlp.conf
            sudo sed -i 's/^#\?CPU_ENERGY_PERF_POLICY_ON_AC=.*/CPU_ENERGY_PERF_POLICY_ON_AC=balance_performance/' /etc/tlp.conf
            sudo sed -i 's/^#\?CPU_ENERGY_PERF_POLICY_ON_BAT=.*/CPU_ENERGY_PERF_POLICY_ON_BAT=power/' /etc/tlp.conf
        else
            # Intel/legacy: use traditional governors
            log "Configuring TLP governors (conservative on battery, ondemand on AC)..."
            sudo sed -i 's/^#\?CPU_SCALING_GOVERNOR_ON_AC=.*/CPU_SCALING_GOVERNOR_ON_AC=ondemand/' /etc/tlp.conf
            sudo sed -i 's/^#\?CPU_SCALING_GOVERNOR_ON_BAT=.*/CPU_SCALING_GOVERNOR_ON_BAT=conservative/' /etc/tlp.conf
        fi
        # Disable battery charge thresholds - always charge to 100% when plugged in
        log "Disabling battery charge thresholds (charge immediately to 100%)..."
        sudo sed -i 's/^#\?START_CHARGE_THRESH_BAT0=.*/START_CHARGE_THRESH_BAT0=0/' /etc/tlp.conf
        sudo sed -i 's/^#\?STOP_CHARGE_THRESH_BAT0=.*/STOP_CHARGE_THRESH_BAT0=100/' /etc/tlp.conf

        # Apply immediately
        sudo tlp start
    fi
fi

# =============================================================================
# BLUETOOTH (AirPods Pro compatibility)
# =============================================================================
if [ -f /etc/bluetooth/main.conf ]; then
    log "Configuring Bluetooth for AirPods Pro..."

    # ControllerMode=bredr forces Classic Bluetooth for initial pairing.
    # AirPods advertise over BLE ("Find My") which can't carry A2DP audio.
    # After pairing, can optionally switch back to dual.
    if ! grep -q "^ControllerMode = bredr" /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#\?ControllerMode.*/ControllerMode = bredr/' /etc/bluetooth/main.conf
        log "Set ControllerMode=bredr (required for AirPods audio)"
    fi

    # FastConnectable reduces reconnection time (trades power for speed)
    if ! grep -q "^FastConnectable = true" /etc/bluetooth/main.conf; then
        sudo sed -i 's/^#\?FastConnectable.*/FastConnectable = true/' /etc/bluetooth/main.conf
        log "Enabled FastConnectable"
    fi

    sudo systemctl daemon-reload
    sudo systemctl restart bluetooth 2>/dev/null || true
    log "Bluetooth configured and restarted"
fi

# =============================================================================
# BRAVE SITE BLOCKLIST
# =============================================================================
# Managed policy: blocked domains (and their subdomains) show an error page, and the
# block can't be switched off from brave://settings. Check it at brave://policy.
if command -v brave-browser &>/dev/null; then
    BRAVE_POLICY=/etc/brave/policies/managed/block-sites.json
    BRAVE_POLICY_JSON='{
  "URLBlocklist": [
    "instagram.com",
    "pinterest.com",
    "pin.it",
    "youtube.com",
    "youtu.be",
    "x.com",
    "twitter.com"
  ]
}'
    if [ "$(cat "$BRAVE_POLICY" 2>/dev/null)" != "$BRAVE_POLICY_JSON" ]; then
        sudo mkdir -p "$(dirname "$BRAVE_POLICY")"
        echo "$BRAVE_POLICY_JSON" | sudo tee "$BRAVE_POLICY" >/dev/null
        log "Brave site blocklist written - restart Brave to apply"
    else
        log "Brave site blocklist already set"
    fi
fi

# =============================================================================
# DEFAULT APPLICATIONS
# =============================================================================
log "Setting default applications..."

xdg-mime default org.pwmt.zathura.desktop application/pdf 2>/dev/null || true
log "PDF viewer set to zathura"

# Set nsxiv as default image viewer
for mime in image/png image/jpeg image/gif image/webp image/bmp image/tiff; do
    xdg-mime default nsxiv.desktop "$mime" 2>/dev/null || true
done
log "Image viewer set to nsxiv"

# =============================================================================
# ENSURE ~/.local/bin IN PATH
# =============================================================================
LOCAL_BIN="$HOME/.local/bin"
mkdir -p "$LOCAL_BIN"

if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
    log "NOTE: ~/.local/bin not in PATH - will be added by .zshrc on next shell"
fi

# =============================================================================
# DOCKER GROUP
# =============================================================================
if groups "$USER" | grep -q docker; then
    log "User already in docker group"
else
    log "Adding user to docker group..."
    sudo usermod -aG docker "$USER"
    log "Added to docker group - will take effect on next login"
fi

# =============================================================================
# VERIFICATION
# =============================================================================
log ""
log "Verification:"
log "  OpenGL: $(glxinfo 2>/dev/null | grep 'OpenGL renderer' | cut -d: -f2 | xargs || echo 'N/A')"
log "  Audio:  $(pactl info 2>/dev/null | grep 'Server Name' | cut -d: -f2 | xargs || echo 'N/A')"
log "  Network: $(nmcli device status 2>/dev/null | head -2 | tail -1 || echo 'N/A')"

log ""
log "System configuration complete!"
