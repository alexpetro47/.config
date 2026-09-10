#!/usr/bin/env bash
# Keep this laptop's checkouts level with their remotes.
#
# The agent works in a sealed container whose clones are its own; anything it lands reaches this
# machine only when something pulls it. That something is this script, driven either by the server
# (the sync-laptop device skill, fired when a run lands work) or by hand.
#
# The one rule it is built around: it never stops halfway and never loses a side. A conflicting
# hunk is not a question to come back to later - it is resolved on the spot, with the losing
# version written beside the file as <name>.conflictN, which is the convention this vault already
# uses. A repo that cannot be reconciled at all is put back exactly as it was found and reported;
# the next repo is still attempted.
#
# Usage: sync-repos.sh [repo ...]   (default: all of them)
#   SYNC_PUSH=0   pull only, never push local commits up

set -uo pipefail          # deliberately not -e: one bad repo must not take the rest with it

# Where each repo actually lives here. This is NOT config.repos' layout: the container keeps every
# clone under one root, while on this machine two of them are dotfile checkouts in $HOME. The name
# on the left is the key the server queues by (config.repos' `path`).
declare -A REPOS=(
  [agentic_os]="$HOME/Documents/agentic_os"
  [daily_notes]="$HOME/Documents/daily_notes"
  [.claude]="$HOME/.claude"
  [config]="$HOME/.config"
  [personal-site]="$HOME/Documents/personal-site"
  [agency/docs]="$HOME/Documents/agency/docs"
  [agency/pai-site]="$HOME/Documents/agency/pai-site"
  [agency/vapi-voice-agent]="$HOME/Documents/agency/vapi-voice-agent"
)

PUSH=${SYNC_PUSH:-1}
failed=()

# Credentials without a desktop. This machine's git is configured for git-credential-manager, whose
# secretservice store needs a graphical session and so cannot answer over ssh - which is the only
# way this script is ever called unattended: "Cannot use the 'secretservice' credential backing
# store without a graphical interface present", and then every fetch fails as if the box were
# offline. gh keeps its token where a headless session can still read it, so it stands in. The
# empty value first clears the inherited helper; without that both are consulted and GCM answers.
if command -v gh >/dev/null 2>&1; then
  export GIT_CONFIG_COUNT=2
  export GIT_CONFIG_KEY_0=credential.helper GIT_CONFIG_VALUE_0=
  export GIT_CONFIG_KEY_1=credential.helper GIT_CONFIG_VALUE_1='!gh auth git-credential'
fi
# Counted as they are written, not from `git status` at the end: by then they are committed, and a
# run that resolved three collisions would report none.
conflicts=0

# A free <file>.conflictN, so a second conflict in the same file never overwrites the first.
conflict_path() {
  local f=$1 n=1
  while [ -e "$f.conflict$n" ]; do n=$((n + 1)); done
  printf '%s.conflict%s' "$f" "$n"
}

# Resolve every conflicted path in the index, keeping both sides.
#
# $1 says which stage belongs at the real path. During a rebase our stage 2 is the upstream (what
# was just pulled) and stage 3 is the local commit being replayed, so "2" means the shared version
# wins the path and the local one lands beside it. A stash pop is the other way round: stage 3 is
# the uncommitted work that was on screen a moment ago, and that keeps the path.
#
# A missing stage is a delete/modify conflict rather than an error - whichever side still has
# content takes the path, because a file that exists on one side is not something to throw away.
resolve_conflicts() {
  local keep=$1 other f c
  other=$([ "$keep" = "2" ] && echo 3 || echo 2)
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    if git show ":$keep:$f" > "$f.sync.tmp" 2>/dev/null; then
      if git show ":$other:$f" > "$(conflict_path "$f").tmp" 2>/dev/null; then
        c=$(conflict_path "$f"); mv "$c.tmp" "$c"; git add -- "$c"; conflicts=$((conflicts + 1))
      else
        rm -f "$(conflict_path "$f").tmp"
      fi
      mv "$f.sync.tmp" "$f"; git add -- "$f"
    elif git show ":$other:$f" > "$f.sync.tmp" 2>/dev/null; then
      mv "$f.sync.tmp" "$f"; git add -- "$f"
    else
      rm -f "$f.sync.tmp"; git rm -q --cached -- "$f" 2>/dev/null
    fi
  done < <(git diff --name-only --diff-filter=U)
}

sync_one() {
  local name=$1 dir=${REPOS[$1]}
  conflicts=0
  [ -d "$dir/.git" ] || { echo "$name: not a checkout at $dir - skipped"; return 0; }
  cd "$dir" || return 1

  local start; start=$(git rev-parse HEAD 2>/dev/null)
  git fetch -q origin 2>/dev/null || { echo "$name: fetch failed (offline?)"; return 1; }

  local branch; branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null)
  [ -n "$branch" ] || { echo "$name: detached HEAD - left alone"; return 1; }
  git rev-parse --verify -q "origin/$branch" >/dev/null || { echo "$name: origin/$branch does not exist - left alone"; return 0; }

  # Nothing to do is the common case and says nothing, so a quiet run means everything is level.
  local ahead behind
  behind=$(git rev-list --count "HEAD..origin/$branch")
  ahead=$(git rev-list --count "origin/$branch..HEAD")
  local dirty; dirty=$(git status --porcelain | wc -l)
  [ "$behind" = 0 ] && [ "$ahead" = 0 ] && [ "$dirty" = 0 ] && return 0

  # Autostash rather than a bare refusal on a dirty tree: this runs unattended and the tree here is
  # usually mid-edit. GIT_EDITOR=true keeps a rebase that wants to open one from hanging forever.
  if [ "$behind" != 0 ]; then
    GIT_EDITOR=true git -c core.mergeoptions=--no-edit pull --rebase --autostash -q origin "$branch" 2>/dev/null
    while [ -d "$(git rev-parse --git-path rebase-merge)" ] || [ -d "$(git rev-parse --git-path rebase-apply)" ]; do
      resolve_conflicts 2
      if ! GIT_EDITOR=true git -c core.editor=true rebase --continue >/dev/null 2>&1; then
        # Nothing left to apply is a commit that became empty against the new base, not a failure.
        GIT_EDITOR=true git rebase --skip >/dev/null 2>&1 || {
          git rebase --abort >/dev/null 2>&1
          echo "$name: rebase could not be resolved; put back at $(git rev-parse --short HEAD)"
          return 1
        }
      fi
    done
    # An autostash that would not reapply cleanly is resolved the same way, the other way round, and
    # then unstaged: this is work that was uncommitted when the sync started and it stays that way.
    # The tree is left as it was found - the edit modified, the .conflict file beside it untracked -
    # rather than half-staged for a commit nobody asked for.
    if git diff --name-only --diff-filter=U | grep -q .; then resolve_conflicts 3; git reset -q; fi
  fi

  # Pushing is counted separately from pulling, because a push does not move HEAD: a repo that was
  # only ahead would otherwise finish having sent commits up and reported doing nothing at all.
  local pushed=0
  if [ "$PUSH" = 1 ]; then
    local out; out=$(git rev-list --count "origin/$branch..HEAD")
    if [ "$out" != 0 ]; then
      if git push -q origin "$branch" 2>/dev/null; then pushed=$out
      else echo "$name: $out local commit(s) could not be pushed"; fi
    fi
  fi

  local now; now=$(git rev-parse HEAD)
  local said=()
  [ "$start" = "$now" ] || said+=("$(git rev-parse --short "$start")..$(git rev-parse --short "$now")")
  [ "$pushed" = 0 ] || said+=("pushed $pushed")
  [ "$conflicts" = 0 ] || said+=("$conflicts .conflict file(s) written, reconcile by hand")
  # printf, not "${said[*]}" with IFS: that joins on IFS's first character only, so a two-character
  # separator silently becomes one and the line reads "a..b,pushed 1".
  [ ${#said[@]} -eq 0 ] || echo "$name: $(printf '%s, ' "${said[@]}" | sed 's/, $//')"
  return 0
}

# One at a time: two of these racing in the same checkout is how a half-finished rebase happens.
exec 9>"${TMPDIR:-/tmp}/sync-repos.lock"
flock -w 300 9 || { echo "another sync is already running"; exit 1; }

names=("$@"); [ ${#names[@]} -gt 0 ] || names=("${!REPOS[@]}")
for n in "${names[@]}"; do
  [ -v "REPOS[$n]" ] || { echo "$n: not a repo this machine knows"; failed+=("$n"); continue; }
  sync_one "$n" || failed+=("$n")
done

[ ${#failed[@]} -eq 0 ] || { echo "could not sync: ${failed[*]}"; exit 1; }
