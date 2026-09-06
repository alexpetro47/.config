# Post-Install Manual Steps

Steps that must be completed manually after automated setup.

## Required Steps

### 1. Brave Browser Setup

1. Open Brave and sign into sync account
2. Log into Bitwarden extension
3. Log into GitHub
4. Settings:
   - Theme: GTK (follows system)
   - Enable vertical tabs
   - Set as default browser

### 2. Git Authentication

First push to GitHub will:
1. Open browser for OAuth authentication
2. Store credentials via Git Credential Manager

```bash
cd ~/.config
git push origin main  # Triggers auth flow
```

### 3. Spotify Login

Open Spotify and log into account.

### 4. Bitwarden CLI

```bash
bw login
```

Stores session in GNOME keyring for `bws` commands.

### 5. Tmux Plugins

Open tmux in Alacritty and install plugins:

```
<C-w>I
```

(Ctrl+w, then Shift+I)

### 6. rclone Configuration

Create Google Drive remote for backups:

```bash
rclone config
# Create remote named "gdrive"
# Type: Google Drive
# Follow OAuth flow
```

See [additional-installs.md](../../new-machine-setup/additional-installs.md) for detailed instructions.

## Optional Steps

### Tailscale (Mesh VPN)

```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

### Neovim Plugins

Open Neovim - Lazy.nvim will auto-install plugins on first launch.

### Claude API Key

Add to `~/.claude/.env`:

```bash
ANTHROPIC_API_KEY=sk-ant-...
```

### Bitwarden Secrets Manager

For programmatic secrets access:

```bash
bws login
# Store access token in keyring
```

See [integrations/bitwarden.md](../integrations/bitwarden.md) for setup.

## Verification

After completing manual steps, verify with:

```bash
# Check Brave is default
xdg-settings get default-web-browser

# Check git auth
gh auth status

# Check rclone remote
rclone listremotes | grep gdrive

# Check bw logged in
bw status
```

## Reboot/Logout Items

These require session restart to take effect:

| Change | Action Required |
|--------|-----------------|
| Default shell (zsh) | Logout and login |
| Docker group | Logout and login |
| TLP power settings | Reboot |
| DPI changes | Restart X session |
