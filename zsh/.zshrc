
# alida dev debugging, agent context windows
payloads() {
  local dest=~/Documents/ALIDA/agent_payloads
  rm -rf "$dest" && mkdir -p "$dest"
  # keep only the 3 newest payloads per agent type: select + tar inside the
  # container (filenames are ts-prefixed, so sort == chronological), stream out
  docker exec ad_platform-dev sh -c '
    cd /tmp/agent_payloads 2>/dev/null || exit 0
    set --
    for d in */; do
      for f in $(ls -1 "$d"*.json 2>/dev/null | sort | tail -3); do
        set -- "$@" "$f"
      done
    done
    [ "$#" -gt 0 ] && tar -cf - "$@"
  ' | tar -xf - -C "$dest"
  # the captured request.system is a list of {type,text} cache blocks (not a
  # plain string), so the prompt is unreadable in the raw JSON. Extract the
  # concatenated text into a sibling .system.txt per capture.
  local f
  for f in "$dest"/**/*.json(N); do
    jq -r '(.request.system // []) | if type=="string" then . else (map(.text // "") | join("\n")) end' \
      "$f" > "${f%.json}.system.txt" 2>/dev/null
  done
  echo "synced $(find "$dest" -name '*.json' | wc -l | tr -d ' ') payloads (3 newest/type) -> $dest"
  local latest_ady=$(ls -1 "$dest"/ady/*.system.txt(N) 2>/dev/null | sort | tail -1)
  [ -n "$latest_ady" ] && echo "latest ady system prompt -> $latest_ady"
}












# API keys live in the `laptop` bws project, not on disk. Nothing is exported at login: `envload`
# pulls them into the current shell when something needs them, so opening a terminal stays instant.
envload() { . "$HOME/.config/bws-env.sh"; }

export EDITOR=nvim
export BUN_INSTALL="$HOME/.bun"
export PATH="$HOME/.cargo/bin:$BUN_INSTALL/bin:$PATH"
export PATH="$HOME/.local/share/gem/ruby/3.2.0/bin:$PATH"
export PATH="/usr/local/go/bin:$HOME/go/bin:$PATH"
export PATH="$HOME/.bun/bin:$PATH"
export SQLITE_VEC_PATH="$HOME/.local/lib/vec0.so"
# Bitwarden Secrets Manager
BWS_ACCESS_TOKEN=$(secret-tool lookup service bws account default 2>/dev/null)
if [[ -n "$BWS_ACCESS_TOKEN" ]]; then
  export BWS_ACCESS_TOKEN
  # Convenience aliases
  bws-get() { bws secret get "$1" | jq -r .value; }
  bws-list() { bws secret list -o table; }
  bws-projects() { bws project list -o table; }
else
  [[ -o interactive ]] && echo "⚠ BWS_ACCESS_TOKEN not found in keyring (run: secret-tool store --label='bws' service bws account default)"
fi

# Database connections (used by lazysql + usql)
# export DB_LOCAL_PG="postgres://user:pass@localhost:5432/mydb"
# export DB_LOCAL_MYSQL="mysql://user:pass@localhost:3306/mydb"
# export DB_LOCAL_SQLITE="file:$HOME/data.db"
export PATH="$HOME/.local/share/nvim/mason/bin:$PATH"

HISTORY=5000
HISTSIZE=5000
SAVEHIST=5000
HISTFILE=~/.zsh_history

# Essential options:
setopt SHARE_HISTORY
setopt APPEND_HISTORY
setopt INC_APPEND_HISTORY
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS


if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi
source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

zinit load zsh-users/zsh-autosuggestions
zinit load zsh-users/zsh-syntax-highlighting
zinit snippet OMZ::plugins/git/git.plugin.zsh
zinit load zsh-users/zsh-completions
zinit load agkozak/zsh-z
zinit load junegunn/fzf
zinit load rupa/z
zinit load zsh-users/zsh-history-substring-search
zinit load hlissner/zsh-autopair

fzf-history-widget() {
    BUFFER=$(fc -rl 1 | fzf --no-sort | sed 's/^[ 0-9]*//')
    CURSOR=$#BUFFER
}
zle -N fzf-history-widget

bindkey '^R' fzf-history-widget
bindkey '^[OA' history-beginning-search-backward
bindkey '^[OB' history-beginning-search-forward
bindkey '^F' forward-word
bindkey '^B' backward-word
bindkey '^D' kill-word

# Minimal prompt: ❯ (yellow success, red error) - matches Claude Code style
PROMPT='%F{%(?.#b8bb26.#fb4934)}❯%f '
eval "$(zoxide init zsh)"
tinty init >/dev/null 2>&1  # centralized theming - tinty apply <scheme>

alias s="source ~/.zshrc ~/.config/lf/lfrc ~/.config/tmux/tmux.conf ~/.config/nvim/init.lua && setxkbmap -option ctrl:nocaps -layout us && i3-msg restart >/dev/null 2>&1 && echo 'Sourced zsh, tmux, nvim, i3, xkbmap, lfrc'"
alias v="nvim"
alias lg="lazygit"
alias c="clear"
alias x="exit"
alias ls='eza -a --long --sort type --no-user --icons --group-directories-first'
alias lsr='eza --icons --group-directories-first --tree'
alias gd='echo -e "\033[1mStaged changes:\033[0m" && git diff --cached --numstat | awk '\''{printf "\033[32m+%s\033[0m \033[31m-%s\033[0m %s\n", $1, $2, $3}'\'' && echo -e "\n\033[1mUnstaged changes:\033[0m" && git diff --numstat | awk '\''{printf "\033[32m+%s\033[0m \033[31m-%s\033[0m %s\n", $1, $2, $3}'\'' && echo -e "\n\033[1mUntracked files:\033[0m" && git ls-files --others --exclude-standard | while read file; do lines=$(wc -l < "$file"); printf "\033[32m+%s\033[0m %s\n" "$lines" "$file"; done'
alias gdp='git --no-pager diff HEAD'
# alias gi='git init && touch .gitignore && git add .gitignore && git commit -m "init" && git remote add origin https://github.com/alexpetro47/$(basename $(pwd)).git && gh repo create $(basename $(pwd)) --private && git push && git status'
# alias cl="claude --permission-mode plan"
alias cl="claude"
alias clc="claude -c"
alias clr="claude --resume"
alias clu="curl -fsSL https://claude.ai/install.sh | bash"
alias trashList="trash-list | sort -r | head -25"
alias marpp="marp --watch --preview "
alias c7="markserv"  # markdown live preview in browser
# alias fullcharge="sudo tlp fullcharge"  # DEPRECATED: TLP disabled

alias musicExport="rclone copy -v ~/Documents/prod/drive_workspace/ google_drive:music/workspace/"
alias musicImport="rclone copy -v google_drive:music/workspace ~/Documents/prod/drive_workspace"
# alias noteSync="cd ~/Documents/code/simplenote_sync && uv run python simplenote_sync.py"  # DEPRECATED: script doesn't exist

# mini pc (UM890PRO) - via Tailscale
# alias pc="ssh alexpetro@alexpetro-um890pro"
# alias pcc="ssh carlbot@alexpetro-um890pro"
# alias pcsync="rsync -avhP --compress --partial"  # usage: pcsync file.txt alexpetro@alexpetro-um890pro:~/

# alias sd="cd ~ && cd \$(find * -type d | fzf)"
# alias lc="git ls-files -z | xargs -0 wc -l 2>/dev/null"
# alias grep='rg'
# alias search='rg'
# alias tp='trash-put'
# alias del='trash-put'
# alias restore='trash-restore'
# alias clickKill="xdotool selectwindow | xargs -I WID i3-msg \"[id=WID] kill\""
# alias wifiConnect='nmcli dev wifi list | fzf | awk "{printf \"%s\", \$2}" | xargs -I {} nmcli dev wifi connect "{}"'
# alias k3000='sudo fuser -k 3000/tcp'
# alias rcloneBackupDocuments="rclone sync -v --exclude-from ~/.config/rclone/documents-backup-exclude.txt ~/Documents/ google_drive:DOCUMENTS"
# alias rcloneBackupConfig="rclone sync -v --filter-from ~/.config/rclone/config-backup-filter.txt ~/.config/ google_drive:CONFIG"
# alias rcloneBackupClaude="rclone sync -v --exclude-from ~/.config/rclone/claude-backup-exclude.txt ~/.claude/ google_drive:CLAUDE"
# alias rcBACKUP="rcloneBackupDocuments && rcloneBackupConfig && rcloneBackupClaude"
# alias rcloneSetup="rclone config reconnect google-drive: || rclone config "
# alias rcloneFavoritesAdd="rclone move ~/Documents/prod/favorites/ google_drive:favorites_prod"


# alias clm="claude mcp list"
# alias clr="claude --resume"
# alias vid="openshot-qt"
# alias sql="sqlitebrowser &"
# alias db="dbgate &"

# alias puml="/usr/bin/java -jar /home/alexpetro/Documents/code/plantuml/plantuml.jar" 
# alias j1="clear; cbonsai -l -i -t .045 -M 15 -L 75" 




# alias br='bun dev '
# alias bc='rm -rf .next && echo "nextjs cache and error log cleared"'
# alias bC='rm -rf .next node_modules bun.lockb && bun install && echo "nextjs cache and error log cleared"'
# alias bi='bun install'
# alias bb='bun --bun run build'
# alias bl='bun --bun run lint'
# alias bt='npx @agentdeskai/browser-tools-server@latest'

# alias "uv run"="PYTHONPATH=. uv run"

alias uvs='uv sync'
alias uvr='uv run'
alias uva='uv add'
# alias uvd='uv remove'
# alias uvi='uv init'
# alias uvl='uv lock'
# alias uvt='uv tree'
# alias jl='jupyter-lab'


# Memory search tool from memorcy_mcp project
# memory() {
#   ORIGINAL_CWD=$(pwd) uv run --directory /home/alexpetro/Documents/code/memory_mcp python -c "
# import os
# import sys
# if 'ORIGINAL_CWD' in os.environ:
#   os.chdir(os.environ['ORIGINAL_CWD'])
# sys.path.insert(0, '/home/alexpetro/Documents/code/memory_mcp')
# exec(open('/home/alexpetro/Documents/code/memory_mcp/cli.py').read())
# " "$@"
# }

# Shorthand aliases
# alias sem-index='memory index $(pwd) --verbose'
# alias sem-search='memory search'




### Added by Zinit's installer
if [[ ! -f $HOME/.local/share/zinit/zinit.git/zinit.zsh ]]; then
    print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$HOME/.local/share/zinit"
    command git clone https://github.com/zdharma-continuum/zinit "$HOME/.local/share/zinit/zinit.git" && \
        print -P "%F{33} %F{34}Installation successful.%f%b" || \
        print -P "%F{160} The clone has failed.%f%b"
fi

source "$HOME/.local/share/zinit/zinit.git/zinit.zsh"
autoload -Uz _zinit
(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes, without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust


[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh 
[ -s "/home/alexpetro/.bun/_bun" ] && source "/home/alexpetro/.bun/_bun"
[ -s ~/.luaver/luaver ] && . ~/.luaver/luaver >/dev/null 2>&1




# opencode
export PATH=/home/alexpetro/.opencode/bin:$PATH

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/alexpetro/.local/miniforge3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/alexpetro/.local/miniforge3/etc/profile.d/conda.sh" ]; then
        . "/home/alexpetro/.local/miniforge3/etc/profile.d/conda.sh"
    else
        export PATH="/home/alexpetro/.local/miniforge3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

export PATH="$HOME/.local/bin:$PATH"

# ralph - Claude orchestration
alias rd='ralph dashboard'
alias rs='ralph status'
alias rsp='ralph spawn'
alias rk='ralph kill'

# Flatpak user apps (for rofi/app launchers)
export XDG_DATA_DIRS="$HOME/.local/share/flatpak/exports/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"

# Composio CLI
export PATH="$HOME/.local/bin:$PATH"
