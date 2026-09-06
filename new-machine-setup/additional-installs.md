
# ADDITIONAL INSTALLS

## Networking

tailscale - mesh VPN, access machines from anywhere
```
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

kdeconnect pairing - one-time per machine (pairing keys live untracked in ~/.config/kdeconnect).
Daemon is autostarted by i3 config. Same Wi-Fi, open KDE Connect app on the phone (iOS only
announces while foregrounded), then:
```
kdeconnect-cli --list-available   # get device id
kdeconnect-cli --pair -d <id>     # accept prompt on phone
```
If discovery fails (AP client isolation), use "Add device by IP" in the iOS app.

## Desktop

picom - compositor for transparency/shadows (disabled - causes idle crashes)
`sudo apt install picom`

## Windows on External SSD

For software that requires Windows (e.g., Respondus LockDown Browser for proctored exams).
Installs to external SSD - no changes to internal Linux partitions.

### Why external SSD instead of VM?

Respondus LockDown Browser detects and blocks virtual machines. A native Windows install
on external storage is the safest approach that doesn't touch your Linux partitions.

### Requirements

- External USB 3.0+ SSD (128GB minimum, ~$25-35)
- Spare USB flash drive (8GB+) for Windows installer
- Windows 11 ISO: https://www.microsoft.com/software-download/windows11
- Ventoy (to create bootable USB): https://www.ventoy.net/

### Step 1: Create bootable installer with Ventoy

```
# Download and extract Ventoy
curl -fLo /tmp/ventoy.tar.gz https://github.com/ventoy/Ventoy/releases/download/v1.0.99/ventoy-1.0.99-linux.tar.gz
tar -xzf /tmp/ventoy.tar.gz -C /tmp

# Install Ventoy to USB flash drive (WILL ERASE DRIVE)
# Find your USB with: lsblk
sudo /tmp/ventoy-1.0.99/Ventoy2Disk.sh -i /dev/sdX  # replace sdX with your USB

# Copy Windows ISO to the Ventoy USB
cp ~/Downloads/Win11_*.iso /media/$USER/Ventoy/
```

### Step 2: Install Windows to external SSD

1. Connect both: Ventoy USB (installer) + external SSD (target)
2. Reboot and enter boot menu (F12/F2/Esc depending on laptop)
3. Boot from Ventoy USB, select Windows ISO
4. At install screen: **Delete all partitions on the external SSD only**
5. Select the unallocated space on external SSD, click Next
6. Complete Windows installation

**CRITICAL**: Only touch partitions on the external SSD. Your internal drive
partitions should show your Linux install - do not modify these.

### Step 3: Boot into Windows

1. Connect external SSD
2. Enter boot menu (F12/F2/Esc)
3. Select the external SSD (usually shows as "UEFI: [SSD brand name]")
4. Windows boots from external drive

To return to Linux: reboot without external SSD, or select internal drive in boot menu.

### Step 4: Install Respondus LockDown Browser

In Windows, download from your school's LMS or: https://download.respondus.com/lockdown/download.php

### Notes

- First Windows boot is slow (driver setup). Subsequent boots are fast.
- Windows may activate automatically. If not, you can use it unactivated (watermark only).
- Keep external SSD plugged in during Windows updates.
- Webcam should work natively for Respondus Monitor (video proctoring).

## Fonts

FiraCode Nerd Font - alternative monospace font (ligatures)
```
mkdir -p ~/.local/share/fonts
curl -fLo /tmp/FiraCode.zip https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip
unzip -o /tmp/FiraCode.zip -d ~/.local/share/fonts/FiraCode
fc-cache -fv
rm /tmp/FiraCode.zip
```

## Development

c qa libs
```
sudo apt install clang-format clang-tidy cppcheck
```

demongrep
```
sudo apt-get update
sudo apt-get install -y build-essential protobuf-compiler libssl-dev pkg-config
cd /tmp/
git clone https://github.com/yxanul/demongrep.git
cd demongrep
cargo build --release
sudo cp target/release/demongrep ~/.local/bin 
```

bws (Bitwarden Secrets Manager) - centralized secrets for API keys, .env variables
```
# 1. Install (already in install-packages.sh via cargo binstall)
cargo binstall -y bws

# 2. Create machine account + access token in Bitwarden web vault:
#    - Secrets Manager → Machine Accounts → New
#    - Generate access token for machine account

# 3. Store token securely in GNOME keyring
secret-tool store --label="bws" service bws account default
# paste token, Ctrl+D

# 4. zshrc already configured - provides:
#    - BWS_ACCESS_TOKEN exported from keyring
#    - Warning on startup if token missing
#    - bws-list, bws-get, bws-projects aliases

# 5. First-time project setup
bws project create "dev-secrets"         # create project (note the UUID)

# 6. Usage
bws secret list -o table                 # list all secrets
bws secret get <secret-id> | jq .value   # get specific secret value
bws secret create "KEY" "value" <project-id>  # create secret (KEY VALUE PROJECT order)
bws-list                                 # alias: table-formatted secret list
bws-get <secret-id>                      # alias: just the value
bws-projects                             # alias: list projects
```

rclone gdrive remote - for backup-repos script
```
rclone config
# n (new remote) → gdrive → drive → leave client_id/secret blank
# → 1 (full access) → n (no advanced) → n (no auto config on headless)
# → paste auth URL in browser, copy code back → n (not team drive) → y (confirm)
```

lazysql - tui for databases
`go install github.com/jorgerojas26/lazysql@latest`

usql - universal sql cli
`go install github.com/xo/usql@latest`

marp - markdown presentation cli
`npm i -g @marp-team/marp-cli`

cloudflared - cloudflare tunnel client
```
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared jammy main' | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install -y cloudflared
```

ngrok - localhost tunneling
```
curl -sSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc | sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null
echo "deb https://ngrok-agent.s3.amazonaws.com bookworm main" | sudo tee /etc/apt/sources.list.d/ngrok.list
sudo apt update && sudo apt install -y ngrok
```

azure-cli - azure command line
`curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash`

d2 - declarative diagramming
`curl -fsSL https://d2lang.com/install.sh | sh`

drawio - diagram editor
`curl -fLo ~/.local/bin/drawio "https://github.com/jgraph/drawio-desktop/releases/download/v28.0.6/drawio-x86_64-28.0.6.AppImage" && chmod +x ~/.local/bin/drawio`

blender - 3d modeling
```
curl -L https://download.blender.org/release/Blender4.2/blender-4.2.1-linux-x64.tar.xz | tar -xJ -C ~/.local
ln -sf ~/.local/blender-4.2.1-linux-x64/blender ~/.local/bin/blender
```

~sqlite-vec - vector extension for sqlite~
```
mkdir -p ~/.local/lib
curl -L https://github.com/asg017/sqlite-vec/releases/download/v0.1.3/sqlite-vec-0.1.3-loadable-linux-x86_64.tar.gz | tar -xz -C ~/.local/lib
```

neo4j - graph database (docker)
`docker run -p 7474:7474 -p 7687:7687 -e NEO4J_AUTH=neo4j/password neo4j`

reaper - digital audio workstation (manual)
https://www.reaper.fm/download.php

dbgate - database gui (manual)
https://dbgate.org/download/

amdgpu PSR fix - ThinkPad P14s Gen 6 / Ryzen AI 9 HX 370 / Radeon 890M
```
# Fixes input freezes, screen not updating (PSR regression in kernel 6.11+)
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 amdgpu.dcdebugmask=0x10"/' /etc/default/grub
sudo update-grub && sudo reboot
```

alacritty - terminal emulator (alternative to kitty, no image support)
`sudo apt install alacritty`



## ML/Data Science

Miniforge3 - conda distribution using conda-forge (avoids Anaconda licensing)
```
wget -qO /tmp/miniforge.sh https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh
bash /tmp/miniforge.sh -b -p ~/.local/miniforge3
~/.local/miniforge3/bin/conda init zsh
# Restart shell, then:
conda config --set auto_activate_base false
conda config --set channel_priority strict
```

## ML/Media Processing (for ~/.claude/skills media toolkits)

PyTorch + CUDA (required for GPU acceleration)
```
# Check CUDA version first: nvidia-smi
# Then install matching PyTorch: https://pytorch.org/get-started/locally/
pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu121
```

HuggingFace Transformers - Florence-2, SigLIP
`pip install transformers accelerate`

faster-whisper - audio transcription
`pip install faster-whisper`

pyannote-audio - speaker diarization (requires HF token)
```
pip install pyannote-audio
# Get token from: https://huggingface.co/pyannote/speaker-diarization
# Then: export HF_TOKEN="your_token"
```

ultralytics - YOLO object detection
`pip install ultralytics`

ffmpeg - required for audio/video processing
`sudo apt install ffmpeg`

ImageMagick 7 (magick CLI) - image processing with modern CLI
```
# ImageMagick 6 (convert) comes from apt: sudo apt install imagemagick
# ImageMagick 7 (magick) needs AppImage for latest CLI:
curl -fLo ~/.local/bin/magick https://imagemagick.org/archive/binaries/magick
chmod +x ~/.local/bin/magick
```

tesseract OCR - text extraction with bounding boxes (for img-text-regions)
`sudo apt install tesseract-ocr tesseract-ocr-eng`

opencv - shape detection (for img-detect-shapes, installed via uv run inline)

openjdk - java compiler and runtime (headless)
`sudo apt install openjdk-21-jdk-headless`

libfuse2 - required for AppImages
`sudo apt install libfuse2`

## bazel
```
sudo apt install curl gnupg
curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor >bazel-archive-keyring.gpg
sudo mv bazel-archive-keyring.gpg /usr/share/keyrings
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/bazel-archive-keyring.gpg] https://storage.googleapis.com/bazel-apt stable jdk1.8" | sudo tee /etc/apt/sources.list.d/bazel.list
sudo apt update && sudo apt install bazel
```
