# New Machine Setup

Automated dotfiles bootstrap for fresh Ubuntu. Idempotent - safe to re-run.

## Quick Start

```bash
# Full install
sudo apt install curl
curl -fsSL https://raw.githubusercontent.com/justatoaster47/linux_dotfiles/main/new-machine-setup/bootstrap.sh | bash
```

### Post-install steps
- brave
  - sync account (sync everything opt)
  - login to bitwarden, add browser extension, add pin,
  signout of browser ext: never
  - login to google, github
  - right click on popups on start page to hide
  - right click on menubar 
    - show bookmarks: never
    - use vertical tabs
    - hide brave rewards icon
  - settings
    - new page page: homepage
    - theme: gtk
    - autocomplete suggestions: bookmarks (only)
- first git push will have you authenticate in browser
- spotify login
- `cp ~/.config/.env.example ~/.config/.env` then fill in keys (sourced by `.zshrc`)
- `pi` → `/login` - pi coding agent auth (subscription or API key; creds in `~/.pi/agent/`)
- `bw login` - authenticate bitwarden CLI (for password backups)
- (in alacritty) `<C-w>I` to install tmux plugins
- `rclone config` - create `gdrive` remote for `backup` script

## Re-run Individual Phases

All scripts are idempotent - safe to re-run anytime.

```bash
cd ~/.config/new-machine-setup
./link-configs.sh      # symlinks (.zshrc, .tmux.conf, scripts to ~/.local/bin)
./install-packages.sh  # apt, cargo, uv, custom binaries
./configure-system.sh  # git config, default shell, services, clone repos
./verify.sh            # check everything is installed correctly
```
Logs: `~/bootstrap-<timestamp>.log`

