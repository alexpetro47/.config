# diffview

View the **cumulative net diff** between two refs — everything on `<head>` that
isn't on `<base>` (`git diff base...head`) — across any of the ALIDA repos,
without `cd`-ing around. Repo paths and each repo's prod branch are baked into
`config`, so you type as little as possible.

## Use

```
diffview <repo> [head] [base]    # one repo   (defaults: head=personal branch, base=prod)
diffview all    [head]           # every repo vs its prod branch, in one view
diffview list                    # show the registry
```

Renderer is chosen automatically: **delta** if installed, otherwise a
self-contained **HTML** page opened in the browser. Override:

```
-s | --side-by-side   delta side-by-side
--html                force the HTML page
--structural          difftastic syntax-aware diff  (needs difft)
```

### Examples

```
diffview ad_platform                  # dev_amp vs origin/dev
diffview all                          # all four repos, one scroll
diffview all -s                       # ... side-by-side
diffview ad_modelpacks dev_amp main   # explicit base
diffview ad_libraries A1B2C3 D4E5F6   # any two commits
```

## Files

| file            | role                                                       |
|-----------------|------------------------------------------------------------|
| `config`        | **the only machine-specific file** — root path + registry  |
| `diffview`      | launcher (symlinked to `~/.local/bin/diffview`)            |
| `render_diff.py`| stdlib-only HTML renderer (run via `uv run`)               |
| `install.sh`    | idempotent setup: symlink + dependency check               |

## Reproduce on another machine

```
git clone/copy this dir to ~/.config/diffview
edit config: set ALIDA_ROOT and the REPOS registry
bash ~/.config/diffview/install.sh      # symlinks the command, checks deps
sudo apt install git-delta              # recommended renderer
```
