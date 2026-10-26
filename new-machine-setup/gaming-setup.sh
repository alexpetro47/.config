#!/bin/bash
#
# Gaming setup - opt-in, idempotent, safe to re-run
# Runs from install-packages.sh only with GAMING=1, or directly: ./gaming-setup.sh
#
# Installs: gamemode, Flatpak Steam + ProtonUp-Qt + MangoHud layer, perf-mode root helper
# (Alt+Shift+o), ntsync module, Cyberpunk 2077 settings. Steam launch options are manual:
# see additional-installs.md -> Gaming.
#
set -e

log() { echo "[$(date +%H:%M:%S)] $*"; }
DIR="$(cd "$(dirname "$0")" && pwd)"

log "Installing gamemode..."
sudo apt install -y gamemode

log "Installing Flatpak Steam, ProtonUp-Qt, MangoHud layer..."
flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
flatpak --user install -y flathub com.valvesoftware.Steam net.davidotek.pupgui2
# Layer branch must match Steam's runtime branch (org.freedesktop.Platform/26.08)
flatpak --user install -y flathub org.freedesktop.Platform.VulkanLayer.MangoHud//26.08
# MangoHud output_folder (Cyberpunk launch options log here); inside Steam's sandbox so it's writable
mkdir -p "$HOME/.var/app/com.valvesoftware.Steam/mangologs"

# Perf mode toggle (perf-mode-toggle, Alt+Shift+o): root-owned sysfs helper + NOPASSWD rule.
# Copied, not symlinked: a user-writable target in sudoers would be a root escalation.
log "Installing perf-mode-apply helper..."
sudo install -o root -g root -m 755 "$DIR/perf-mode-apply" /usr/local/sbin/perf-mode-apply
echo "$USER ALL=(root) NOPASSWD: /usr/local/sbin/perf-mode-apply" | sudo tee /etc/sudoers.d/perf-mode >/dev/null
sudo chmod 440 /etc/sudoers.d/perf-mode
sudo visudo -cf /etc/sudoers.d/perf-mode >/dev/null

# ntsync: faster Windows sync primitives for Proton (PROTON_USE_NTSYNC=1)
log "Loading ntsync module (and at boot)..."
echo ntsync | sudo tee /etc/modules-load.d/ntsync.conf >/dev/null
sudo modprobe ntsync || log "WARN: ntsync module unavailable on this kernel"

# Cyberpunk settings need the game's prefix, which only exists after its first launch
"$DIR/cp2077-settings" --if-installed

log "Gaming setup complete. Set Steam launch options: see additional-installs.md -> Gaming"
