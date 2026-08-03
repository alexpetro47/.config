#!/bin/bash
#
# Package installation script - idempotent, safe to re-run
# Optional/extras: see installs.md for manual install commands
#
# Options (set before running or export):
#   SKIP_LATEX=1         Skip texlive packages (~500MB) (default: 0)
#
# Example: SKIP_LATEX=1 ./install-packages.sh  # skip large LaTeX packages
#
set -e

log() { echo "[$(date +%H:%M:%S)] $*"; }
installed() { command -v "$1" &>/dev/null; }

# =============================================================================
# OPTIONS
# =============================================================================
SKIP_LATEX="${SKIP_LATEX:-0}"

# =============================================================================
# APT PACKAGES
# =============================================================================
log "Installing APT packages..."
sudo apt update
# Core packages (always installed)
sudo apt install -y \
    git \
    cmake \
    zsh \
    tmux \
    polybar \
    rofi \
    feh \
    nsxiv \
    fzf \
    ripgrep \
    universal-ctags \
    btop \
    trash-cli \
    zathura zathura-pdf-poppler \
    flameshot \
    playerctl \
    brightnessctl \
    cbonsai \
    xclip \
    xdotool \
    gromit-mpx \
    slop \
    zenity \
    inotify-tools \
    curl \
    zip \
    unzip \
    wget \
    zoxide \
    eza \
    pandoc \
    rclone \
    caffeine \
    sqlite3 \
    libsqlite3-dev \
    pipewire-jack \
    pavucontrol \
    thunar \
    sox \
    libsox-fmt-all \
    pulseaudio-utils \
    cava \
    mpv \
    libgtk-3-dev \
    dunst \
    tlp \
    tlp-rdw \
    ffmpeg \
    flatpak \
    libsecret-tools \
    libheif-examples \

# =============================================================================
# BROWSERS
# =============================================================================
# GOOGLE CHROME
if ! installed google-chrome; then
    log "Installing Google Chrome..."
    curl -fsSLo /tmp/google-chrome.deb https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo dpkg -i /tmp/google-chrome.deb
    sudo apt-get install -f -y
    rm /tmp/google-chrome.deb
else
    log "Google Chrome already installed"
fi

# BRAVE
if ! installed brave-browser; then
    log "Installing Brave..."
    sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update
    sudo apt install -y brave-browser
else
    log "Brave already installed"
fi


# =============================================================================
# TELEGRAM DESKTOP (Flatpak - sandboxed, latest version)
# =============================================================================
if ! flatpak --user list --app | grep -q org.telegram.desktop; then
    log "Installing Telegram Desktop via Flatpak..."
    flatpak --user remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    flatpak --user install -y flathub org.telegram.desktop
else
    log "Telegram Desktop already installed"
fi

# CLI wrapper for telegram
if [ ! -f "$HOME/.local/bin/telegram" ]; then
    log "Creating telegram CLI wrapper..."
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/telegram" << 'EOF'
#!/bin/bash
exec flatpak run org.telegram.desktop "$@"
EOF
    chmod +x "$HOME/.local/bin/telegram"
fi

# Flatpak XDG_DATA_DIRS for app launchers (rofi, etc)
if ! grep -q "flatpak/exports/share" "$HOME/.zshrc" 2>/dev/null; then
    log "Adding flatpak exports to XDG_DATA_DIRS..."
    echo '
# Flatpak user apps (for rofi/app launchers)
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"' >> "$HOME/.zshrc"
fi

# LaTeX packages (skip with SKIP_LATEX=1)
if [ "$SKIP_LATEX" != "1" ]; then
    log "Installing LaTeX packages (~500MB)..."
    sudo apt install -y \
        texlive-latex-recommended texlive-fonts-recommended texlive-xetex \
        texlive-latex-extra texlive-science texlive-pictures \
        texlive-bibtex-extra latexmk texlive-font-utils texlive-plain-generic
else
    log "Skipping LaTeX packages (SKIP_LATEX=1)"
fi

# =============================================================================
# I3
# =============================================================================
if ! installed i3; then
    log "Installing i3..."
    sudo apt install -y i3
else
    log "i3 already installed"
fi

# Backlight permissions (for brightness keys without root)
if [ ! -f /etc/udev/rules.d/90-backlight.rules ]; then
    log "Setting up backlight permissions..."
    echo 'ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"' | sudo tee /etc/udev/rules.d/90-backlight.rules
    sudo usermod -aG video "$USER"
    sudo udevadm control --reload-rules && sudo udevadm trigger
else
    log "Backlight udev rule already exists"
fi

# Ensure i3 session file exists for login screen
if [ ! -f /usr/share/xsessions/i3.desktop ]; then
    log "Creating i3 session file..."
    sudo tee /usr/share/xsessions/i3.desktop > /dev/null << 'EOF'
[Desktop Entry]
Name=i3
Comment=improved dynamic tiling window manager
Exec=i3
TryExec=i3
Type=Application
X-LightDM-DesktopName=i3
DesktopNames=i3
Keywords=tiling;wm;windowmanager;window;manager;
EOF
else
    log "i3 session file already exists"
fi

# =============================================================================
# UV (Python package manager)
# =============================================================================
if ! installed uv; then
    log "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
else
    log "uv already installed"
fi

log "Installing uv tools..."
uv tool install jupyterlab || true
uv tool install ruff || true
uv tool install pytest || true
uv tool install pyright || true
uv tool install pre-commit || true
uv tool install whisper-ctranslate2 || true
uv tool install llm || true
uv tool install rofimoji || true   # emoji/symbol picker (rofi) for the clipboard popup
llm install llm-openrouter 2>/dev/null || true
uv tool install demucs --with torchcodec || true   # audio stem separation (vocals/drums/bass/other); torchcodec needed for torchaudio>=2.9 file writes

# pre-warm audio-analyze's deps (librosa etc., self-bootstrapped by uv) so the first chop isn't slow
if [ -x "$HOME/.config/new-machine-setup/audio-analyze" ]; then
    log "Pre-warming audio-analyze (librosa)..."
    _aa_tmp=$(mktemp --suffix=.wav)
    sox -n -r 48000 -c 2 "$_aa_tmp" synth 3 sine 220 2>/dev/null \
        && "$HOME/.config/new-machine-setup/audio-analyze" tempo-key "$_aa_tmp" >/dev/null 2>&1 || true
    rm -f "$_aa_tmp"
fi
# rclip: semantic image search - isolated project (torch dep issues with uv tool install)
if [ ! -f "$HOME/.local/share/rclip-env/.venv/bin/rclip" ]; then
    log "Installing rclip (isolated environment)..."
    mkdir -p "$HOME/.local/share/rclip-env"
    cat > "$HOME/.local/share/rclip-env/pyproject.toml" << 'EOF'
[project]
name = "rclip-env"
version = "0.1.0"
requires-python = ">=3.11,<3.13"
dependencies = ["rclip>=2.0.0"]

[tool.uv]
override-dependencies = ["torch>=2.0.0", "torchvision>=0.15.0"]
EOF
    (cd "$HOME/.local/share/rclip-env" && uv sync) || log "WARN: rclip install failed"
    # Wrapper script
    cat > "$HOME/.local/bin/rclip" << 'EOF'
#!/bin/bash
exec ~/.local/share/rclip-env/.venv/bin/rclip "$@"
EOF
    chmod +x "$HOME/.local/bin/rclip"
else
    log "rclip already installed"
fi

# =============================================================================
# CODE Q/A TOOLS
# =============================================================================
log "Installing code Q/A tools..."

# Python (via uv)
uv tool install mypy || true
uv tool install bandit || true

# Bash
sudo apt install -y shellcheck

# Go-based tools (shfmt)
go install mvdan.cc/sh/v3/cmd/shfmt@latest || true
# ctags-lsp: nvim symbol-search LSP (<leader>ss / <leader>sw). Needs universal-ctags (apt block above).
go install github.com/netmute/ctags-lsp@latest || true

# =============================================================================
# RUST/CARGO
# =============================================================================
if ! installed rustup; then
    log "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
else
    log "Rust already installed, updating..."
    rustup update
fi

rustup component add rust-analyzer rust-src || true

if ! installed cargo-binstall; then
    log "Installing cargo-binstall..."
    cargo install cargo-binstall
fi

log "Installing cargo packages..."
cargo binstall -y xh fd-find tinty tree-sitter-cli bws || true

# Tinty setup (centralized theming)
if installed tinty; then
    log "Setting up tinty..."
    tinty install 2>/dev/null || true
    tinty sync 2>/dev/null || true
    tinty apply base16-gruvbox-dark-medium 2>/dev/null || true
fi

# =============================================================================
# GO
# =============================================================================
if ! installed go; then
    log "Installing Go..."
    GO_VERSION="1.23.4"
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz
    rm /tmp/go.tar.gz
    export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
else
    log "Go already installed"
fi

# =============================================================================
# NODE/NPM
# =============================================================================
if ! installed node || [[ "$(node -v | cut -d. -f1 | tr -d 'v')" -lt 22 ]]; then
    log "Installing Node.js 22..."
    curl -fsSL https://deb.nodesource.com/setup_22.x | sudo -E bash -
    sudo apt-get install -y nodejs
else
    log "Node.js 22+ already installed"
fi

# Configure npm to use user directory (avoids sudo for global installs)
npm config set prefix ~/.local

log "Installing npm global packages..."
npm install -g markserv @mermaid-js/mermaid-cli

# =============================================================================
# BUN
# =============================================================================
if ! installed bun; then
    log "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$HOME/.bun/bin:$PATH"
else
    log "Bun already installed"
fi

# SPOTIFY
if ! installed spotify; then
    log "Installing Spotify..."
    curl -sS https://download.spotify.com/debian/pubkey_C85668DF69375001.gpg | sudo gpg --dearmor --yes -o /etc/apt/trusted.gpg.d/spotify.gpg
    echo "deb https://repository.spotify.com stable non-free" | sudo tee /etc/apt/sources.list.d/spotify.list
    sudo apt update
    sudo apt install -y spotify-client
else
    log "Spotify already installed"
fi

# =============================================================================
# D2 (Diagram scripting language)
# =============================================================================
if ! installed d2; then
    log "Installing D2..."
    curl -fsSL https://d2lang.com/install.sh | sh -s --
else
    log "D2 already installed"
fi

# =============================================================================
# LAZYGIT
# =============================================================================
if ! installed lazygit; then
    log "Installing lazygit..."
    LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | grep -Po '"tag_name": *"v\K[^"]*')
    curl -Lo /tmp/lazygit.tar.gz "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_x86_64.tar.gz"
    tar xf /tmp/lazygit.tar.gz -C /tmp lazygit
    sudo install /tmp/lazygit -D -t /usr/local/bin/
    rm /tmp/lazygit.tar.gz /tmp/lazygit
else
    log "lazygit already installed"
fi

# =============================================================================
# TMUX SESSIONIZER
# =============================================================================
if [ ! -f "$HOME/.local/bin/tmux-sessionizer" ]; then
    log "Installing tmux-sessionizer..."
    mkdir -p "$HOME/.local/bin"
    curl -o "$HOME/.local/bin/tmux-sessionizer" https://raw.githubusercontent.com/ThePrimeagen/tmux-sessionizer/master/tmux-sessionizer
    chmod +x "$HOME/.local/bin/tmux-sessionizer"
else
    log "tmux-sessionizer already installed"
fi

# =============================================================================
# GIT CREDENTIAL MANAGER
# =============================================================================
if ! installed git-credential-manager; then
    log "Installing Git Credential Manager..."
    curl -L https://github.com/git-ecosystem/git-credential-manager/releases/download/v2.6.0/gcm-linux_amd64.2.6.0.deb -o /tmp/gcm.deb
    sudo dpkg -i /tmp/gcm.deb
    rm /tmp/gcm.deb
else
    log "Git Credential Manager already installed"
fi

# =============================================================================
# CLAUDE CODE
# =============================================================================
if ! installed claude; then
    log "Installing Claude Code..."
    curl -fsSL https://claude.ai/install.sh | bash
else
    log "Claude Code already installed"
fi
# MCP servers documented in ~/.claude/CLAUDE-SYS.md

# =============================================================================
# FONTS (Nerd Fonts)
# =============================================================================
if [ ! -d "$HOME/.local/share/fonts/JetBrainsMono" ]; then
    log "Installing JetBrains Mono Nerd Font..."
    mkdir -p "$HOME/.local/share/fonts"
    curl -fLo /tmp/JetBrainsMono.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.zip
    unzip -o /tmp/JetBrainsMono.zip -d "$HOME/.local/share/fonts/JetBrainsMono"
    fc-cache -fv
    rm /tmp/JetBrainsMono.zip
else
    log "JetBrains Mono Nerd Font already installed"
fi

# =============================================================================
# CURSOR THEME (ComixCursors-White)
# =============================================================================
if [ ! -d /usr/share/icons/ComixCursors-White ]; then
    log "Installing ComixCursors theme..."
    sudo apt install -y comixcursors-righthanded
else
    log "ComixCursors theme already installed"
fi

# =============================================================================
# KITTY TERMINAL (for image.nvim support)
# =============================================================================
if ! installed kitty; then
    log "Installing Kitty terminal..."
    curl -L https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n
    mkdir -p "$HOME/.local/bin"
    ln -sf "$HOME/.local/kitty.app/bin/kitty" "$HOME/.local/bin/kitty"
    ln -sf "$HOME/.local/kitty.app/bin/kitten" "$HOME/.local/bin/kitten"
else
    log "Kitty already installed"
fi

# ImageMagick (required for image.nvim)
if ! installed magick && ! installed convert; then
    log "Installing ImageMagick..."
    sudo apt install -y imagemagick
else
    log "ImageMagick already installed"
fi

# librsvg (rsvg-convert required for mdmath.nvim LaTeX rendering)
if ! installed rsvg-convert; then
    log "Installing librsvg2-bin..."
    sudo apt install -y librsvg2-bin
else
    log "librsvg2-bin already installed"
fi

# =============================================================================
# NEOVIM (from source)
# =============================================================================
if ! installed nvim; then
    log "Installing Neovim from source..."
    sudo apt install -y ninja-build gettext cmake unzip curl build-essential
    git clone --branch stable --depth 1 https://github.com/neovim/neovim.git /tmp/neovim-build
    cd /tmp/neovim-build
    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make install
    cd ~
    rm -rf /tmp/neovim-build
else
    log "Neovim already installed"
fi

# =============================================================================
# TPM (tmux plugin manager)
# =============================================================================
if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    log "Installing TPM..."
    git clone https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
else
    log "TPM already installed"
fi

# Install tmux plugins non-interactively (requires tmux.conf to be linked)
if [ -f "$HOME/.tmux.conf" ] && [ -x "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]; then
    log "Installing tmux plugins..."
    "$HOME/.tmux/plugins/tpm/bin/install_plugins" || log "WARN: tmux plugin install failed (may need tmux running)"
fi

# =============================================================================
# ASCIIQUARIUM (terminal aquarium for zen-mode)
# =============================================================================
if ! installed asciiquarium; then
    log "Installing asciiquarium..."
    sudo apt install -y libcurses-perl
    # Install Term::Animation from CPAN (required dependency)
    sudo cpan -T Term::Animation 2>/dev/null || log "WARN: Term::Animation install may need manual CPAN config"
    # Download and install asciiquarium
    curl -fLo /tmp/asciiquarium.tar.gz https://robobunny.com/projects/asciiquarium/asciiquarium.tar.gz
    tar -xzf /tmp/asciiquarium.tar.gz -C /tmp
    sudo install /tmp/asciiquarium_1.1/asciiquarium /usr/local/bin/
    rm -rf /tmp/asciiquarium.tar.gz /tmp/asciiquarium_1.1
else
    log "asciiquarium already installed"
fi

# =============================================================================
# DOCKER
# =============================================================================
if ! installed docker; then
    log "Installing Docker..."
    sudo apt install -y docker.io docker-compose-v2
    sudo usermod -aG docker "$USER"
else
    log "Docker already installed"
fi

# =============================================================================
# TTYD (snap - for viewing/debugging TUI apps via Playwright)
# =============================================================================
if ! installed ttyd; then
    log "Installing ttyd via snap..."
    sudo snap install ttyd --classic
else
    log "ttyd already installed"
fi

# =============================================================================
# OBSIDIAN (snap)
# =============================================================================
if ! installed obsidian; then
    log "Installing Obsidian via snap..."
    sudo snap install obsidian --classic
else
    log "Obsidian already installed"
fi

# =============================================================================
# GHOSTTY (snap - terminal for the black hole break-reminder shader, needs 1.3+)
# =============================================================================
if ! installed ghostty; then
    log "Installing Ghostty via snap..."
    sudo snap install ghostty --classic
else
    log "Ghostty already installed"
fi

# =============================================================================
# BITWARDEN CLI (native binary)
# =============================================================================
if ! installed bw; then
    log "Installing Bitwarden CLI..."
    BW_VERSION=$(curl -s "https://api.github.com/repos/bitwarden/clients/releases?per_page=50" | grep -Po '"tag_name": *"cli-v\K[^"]*' | head -1)
    curl -fLo /tmp/bw.zip "https://github.com/bitwarden/clients/releases/download/cli-v${BW_VERSION}/bw-linux-${BW_VERSION}.zip"
    unzip -o /tmp/bw.zip -d /tmp
    sudo install /tmp/bw /usr/local/bin/
    rm /tmp/bw.zip /tmp/bw
else
    log "Bitwarden CLI already installed"
fi

# =============================================================================
# GREENCLIP (clipboard-history daemon for the Alt+Ctrl+v clipboard popup)
# =============================================================================
if ! installed greenclip; then
    log "Installing greenclip..."
    mkdir -p "$HOME/.local/bin"
    GREENCLIP_URL=$(curl -s "https://api.github.com/repos/erebe/greenclip/releases/latest" | grep -Po '"browser_download_url": *"\K[^"]*/greenclip(?=")' | head -1)
    curl -fLo "$HOME/.local/bin/greenclip" "$GREENCLIP_URL"
    chmod +x "$HOME/.local/bin/greenclip"
else
    log "greenclip already installed"
fi

# =============================================================================
# REAPER DAW (manual download required)
# =============================================================================
if [ ! -f "$HOME/.local/opt/reaper/reaper" ]; then
    log "Reaper not found. Download from https://www.reaper.fm/download.php"
    log "Then extract to ~/.local/opt/reaper/"
else
    log "Reaper already installed"
fi

# Create reaper wrapper with PipeWire low-latency settings
if [ ! -f "$HOME/.local/bin/reaper" ]; then
    log "Creating Reaper launcher wrapper..."
    mkdir -p "$HOME/.local/bin"
    cat > "$HOME/.local/bin/reaper" << 'EOF'
#!/bin/bash
# Launch Reaper with PipeWire low-latency settings
# 256 samples at 48kHz = ~5.3ms latency
# Audio setup: Preferences → Audio → Device → ALSA, pick hw:Stomp from dropdown
export PIPEWIRE_LATENCY="256/48000"
exec ~/.local/opt/reaper/reaper "$@"
EOF
    chmod +x "$HOME/.local/bin/reaper"
else
    log "Reaper wrapper already exists"
fi

# =============================================================================
# CLEANUP
# =============================================================================
log "Cleaning up orphaned packages..."
sudo apt autoremove -y

log "Package installation complete!"

# =============================================================================
# AUTO-LOGOUT (to select i3 at login)
# =============================================================================
if [ -f /usr/share/xsessions/i3.desktop ] && [ -n "$DISPLAY" ]; then
    log "i3 session available. Logging out in 5 seconds to switch session..."
    log "Press Ctrl+C to cancel"
    sleep 5
    # Try various logout methods
    if installed gnome-session-quit; then
        gnome-session-quit --no-prompt --logout
    elif installed loginctl; then
        loginctl terminate-user "$USER"
    else
        pkill -KILL -u "$USER"
    fi
fi
