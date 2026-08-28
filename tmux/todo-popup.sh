#!/usr/bin/env bash
# C-w T popup target: every tmux instance attaches to this one "todo" session,
# so tasks.md is only ever open in a single nvim (which autosaves on change).
unset TMUX
mkdir -p ~/Documents/daily_notes
exec tmux new-session -A -s todo \
  "nvim -c 'autocmd TextChanged,TextChangedI,InsertLeave <buffer> silent! update' ~/Documents/daily_notes/tasks.md" \
  \; set status off \; set detach-on-destroy on
