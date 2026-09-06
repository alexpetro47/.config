#!/bin/bash
# verify.sh - Post-install verification
# Usage: ./verify.sh

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'
PASS=0; FAIL=0; WARN=0

pass() { ((PASS++)); echo -e "${GREEN}✓${NC} $1"; }
fail() { ((FAIL++)); echo -e "${RED}✗${NC} $1"; }
warn() { ((WARN++)); echo -e "${YELLOW}!${NC} $1 (needs reboot)"; }
section() { echo -e "\n=== $1 ==="; }

section "Core"
for cmd in i3 zsh alacritty tmux nvim rofi polybar; do
    command -v "$cmd" &>/dev/null && pass "$cmd" || fail "$cmd"
done

section "Dev"
for cmd in git uv cargo node claude pi lazygit docker; do
    command -v "$cmd" &>/dev/null && pass "$cmd" || fail "$cmd"
done

section "Backup"
for cmd in rclone bw bws gpg jq secret-tool gh; do
    command -v "$cmd" &>/dev/null && pass "$cmd" || fail "$cmd"
done
rclone listremotes 2>/dev/null | grep -q '^gdrive:' && pass "gdrive remote" || fail "gdrive remote (rclone config)"
systemctl --user is-enabled backup-reminder.timer &>/dev/null && pass "backup-reminder.timer" || fail "backup-reminder.timer"

section "Symlinks"
for link in ~/.zshrc ~/.tmux.conf; do
    [ -L "$link" ] && pass "$link" || fail "$link"
done

section "Services"
systemctl is-enabled docker &>/dev/null && pass "docker" || fail "docker"

section "Post-reboot"
[[ "$SHELL" == */zsh ]] && pass "shell=zsh" || warn "shell=zsh"
groups | grep -q docker && pass "docker group" || warn "docker group"

section "Fonts"
fc-list | grep -qi jetbrainsmono && pass "JetBrainsMono" || fail "JetBrainsMono"

echo -e "\n─────────────────────────"
echo -e "Pass: ${GREEN}$PASS${NC}  Fail: ${RED}$FAIL${NC}  Warn: ${YELLOW}$WARN${NC}"
[ $FAIL -eq 0 ] && echo -e "${GREEN}All critical checks passed!${NC}" || echo -e "${RED}Some checks failed.${NC}"
exit $FAIL
