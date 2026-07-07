#!/usr/bin/env bash
# Reproducible setup for diffview. Idempotent — safe to re-run.
#   bash ~/.config/diffview/install.sh
set -euo pipefail
CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/diffview"
BIN="$HOME/.local/bin"

mkdir -p "$BIN"
ln -sf "$CFG_DIR/diffview" "$BIN/diffview"
chmod +x "$CFG_DIR/diffview"
echo "linked $BIN/diffview -> $CFG_DIR/diffview"

case ":$PATH:" in *":$BIN:"*) ;; *) echo "WARN: $BIN is not on PATH — add it to your shell rc";; esac

[ -f "$CFG_DIR/config" ] || { echo "ERROR: $CFG_DIR/config missing — create it (see README)"; exit 1; }

have() { command -v "$1" >/dev/null 2>&1; }
echo
echo "dependency check:"
have uv    && echo "  uv     ok ($(command -v uv))"           || echo "  uv     MISSING — needed for --html   (https://astral.sh/uv)"
have delta && echo "  delta  ok ($(command -v delta))"        || echo "  delta  optional (default renderer)   — sudo apt install git-delta   |  cargo install git-delta"
have difft && echo "  difft  ok ($(command -v difft))"        || echo "  difft  optional (--structural)        — sudo apt install difftastic   |  cargo install difftastic"
echo
echo "done. try:  diffview list"
