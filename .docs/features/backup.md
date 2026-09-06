# Backup System

Versioned backup system for repositories (git bundles) and both Bitwarden stores (password vault + Secrets Manager). Uses rclone for Google Drive synchronization.

## Quick Usage

```bash
backup              # Interactive menu
backup --all        # Everything
backup --repos      # Repositories only
backup --bitwarden  # Password vault + machine secrets
backup --dry-run    # Preview without changes
```

## Components

### Interactive Menu (`backup`)

Main entry point. Presents menu:
```
1. All (Bitwarden + Repos)
2. Bitwarden only
3. Repos only
```

Location: `scripts/backup`

### Repository Backup (`backup-repos`)

Mirrors the GitHub repos in `rclone/backup-repos.txt` to `gdrive:BACKUPS/repos/` as dated git bundles (`<name>-YYYYMMDD.bundle`), 3 retained per repo. Manifest is one repo per line, full URL or `owner/name`.

**Backs up the remote, not the working copy.** A bundle carries every ref and all history, so this survives losing the GitHub account as well as the laptop — but it captures only what is *pushed*. Uncommitted work is backed up by nothing; this replaced the working-tree sync that used to cover it.

- **Bundles, not bare mirrors.** One file per repo instead of thousands of loose objects — Drive handles that far better. Restore is `git clone <name>-YYYYMMDD.bundle <dir>`.
- **Auth:** the global credential helper (`git-credential-manager`) is interactive and cannot serve a headless run, so the script injects a one-shot helper that reads `gh auth token`. Private repos therefore need `gh auth login`, not a git credential.
- **`git -C <dir> bundle create <path>` resolves `<path>` relative to `<dir>`**, not the cwd. The script passes an absolute path; anything you add must too.
- Every bundle is `git bundle verify`-ed before upload. A bundle that fails to verify is worse than no bundle — it looks like a backup.
- Full re-clone each run (~115 MB for the current three), so this is bandwidth-bound, not incremental.

```bash
backup-repos            # mirror + bundle + upload
backup-repos --dry-run  # clone and bundle for real, skip the upload and the prune
```

Location: `scripts/backup-repos`

### Overdue Reminder (`backup-reminder`)

`backup-reminder.timer` runs daily; the script stays silent unless the newest file in `~/.local/share/bitwarden-backup/` is more than 30 days old, then raises a dunst notification. Left-clicking it runs the backup right there — `backup-bitwarden` asks for the master password and the passphrase through zenity boxes and syncs headless, then a second notification reports success or failure.

Daily-and-nagging rather than monthly-and-once because `backup --bitwarden` needs a typed passphrase: a monthly popup dismissed at a busy moment is gone for a month, this one returns tomorrow and silences itself as soon as a backup exists.

- **systemd user timer, not cron.** `Persistent=true` catches up a run missed while the laptop was asleep or off — cron simply skips it, and a monthly job has roughly a 1-in-30 chance of landing while you are powered on.
- **The click only works because `dunstrc` sets `mouse_left_click = do_action`.** With the stock `close_current` alone a click just dismisses and the backup silently never runs.
- **Exactly one action, named `default`.** dunst invokes a single action in-process, so it lands before the binding's `close_current`. Two actions open the external dmenu picker instead, and the close then races the selection — `notify-send` returns an empty string and nothing happens.
- **`notify-send -A` implies `--wait`.** It blocks until clicked, hence `-t 60000`; without a timeout the service would hang indefinitely.
- **`TimeoutStartSec=30min`.** The backup runs inside the unit now, and the 90s default would kill it mid-upload.
- The service needs `DISPLAY`/`DBUS_SESSION_BUS_ADDRESS` in the user manager environment (gdm already exports them here). Without them it fails silently.

`backup-bitwarden` chooses its prompt by context — `read -rsp` when it has a TTY, `zenity --password` when it does not — so running it by hand from a shell is unchanged.

Units: `systemd/user/backup-reminder.{service,timer}` — these live in this repo, so `systemctl --user daemon-reload` is what makes a fresh machine see them. `configure-system.sh` does the reload and enable.

Location: `scripts/backup-reminder`

### Bitwarden Backup (`backup-bitwarden`)

Covers **both** Bitwarden stores in one run. Local `~/.local/share/bitwarden-backup/`, 7 of each retained, synced to `gdrive:BACKUPS/bitwarden/`.

| File | Store | Encryption |
|------|-------|------------|
| `vault-YYYYMMDD.json` | `bw` password vault | Bitwarden-native `encrypted_json` |
| `secrets-YYYYMMDD.json.gpg` | `bws` Secrets Manager | gpg symmetric, AES256 |

**One passphrase, typed twice, used for both.** It is deliberately not read from `bws` or the keyring — those are what you are recovering, so the machine that dies must not hold the key to its own backup. Consequence: **this cannot run unattended**, so it is not cron-able and never will be.

Constraints worth knowing before you touch this script:

- **`bws` has no export or import.** Backup is `bws secret list -o json`; restore is a `bws secret create` loop (below). The dump runs with no project filter so a newly-granted project is picked up automatically — but a project the service-account token was *never* granted is invisible. The `projects` array in the dump exists to make that miss visible at restore.
- **Plaintext must never reach disk.** The bws dump is a single `jq | gpg` pipe; secrets travel on stdin, not argv. `set -o pipefail` is load-bearing — without it a failed `bws` mid-pipe yields a valid gpg file wrapping an error blob, which then syncs over a good backup.
- **Known leak:** `bw export` takes its password as an argv flag with no stdin alternative, so the passphrase is briefly visible in `/proc/<pid>/cmdline` to local users. Single-user machine; accepted.
- Empty-result guard: a 0-secret dump aborts rather than overwriting a good backup.

Location: `scripts/backup-bitwarden`

## rclone Remote Setup

1. Run configuration:
   ```bash
   rclone config
   ```

2. Create new remote:
   - Name: `gdrive`
   - Type: `Google Drive`
   - Follow OAuth prompts

**Deadline:** rclone's shared Google Drive `client_id` is being retired and stops working during 2026. Every backup path here dies with it. Make your own client_id (https://rclone.org/drive/#making-your-own-client-id) and set it on the remote before then.

3. Verify:
   ```bash
   rclone listremotes | grep gdrive
   rclone lsd gdrive:BACKUPS
   ```

## Cloud Structure

```
gdrive:BACKUPS/
├── repos/
│   ├── linux_dotfiles-YYYYMMDD.bundle   # full history, all refs
│   ├── .claude-YYYYMMDD.bundle
│   └── daily_notes-YYYYMMDD.bundle
├── bitwarden/
│   ├── vault-YYYYMMDD.json              # bw password vault (Bitwarden-encrypted)
│   └── secrets-YYYYMMDD.json.gpg        # bws Secrets Manager (gpg AES256)
```

The `.claude/` and `.config/` working-tree trees from the old `backup-repos` are still up there. They are stale now — delete them once you trust the bundles.

## Adding Repos to Backup

Edit `~/.config/rclone/backup-repos.txt`:

```bash
echo "https://github.com/user/myrepo" >> ~/.config/rclone/backup-repos.txt
```

## Dry Run

Preview what would be synced:

```bash
backup --dry-run
backup-repos --dry-run
```

Shows:
- Files to upload
- Files to delete remotely
- Size changes

## Restore

### Repos

```bash
rclone lsl gdrive:BACKUPS/repos                                  # list bundles
rclone copy gdrive:BACKUPS/repos/linux_dotfiles-YYYYMMDD.bundle .
git clone linux_dotfiles-YYYYMMDD.bundle .config
```

The clone is a normal repo with full history; its `origin` points at the bundle file, so reset it to GitHub before pushing:

```bash
git -C .config remote set-url origin https://github.com/alexpetro47/linux_dotfiles.git
```

### Password vault (`bw`)

```bash
rclone copy gdrive:BACKUPS/bitwarden/vault-YYYYMMDD.json .
bw login && bw import bitwardenpasswordprotected vault-YYYYMMDD.json   # prompts for the backup passphrase
```

The format is `bitwardenpasswordprotected`, not `bitwardenjson` — the export is password-encrypted, not account-key-encrypted. `bw import --formats` lists all of them, but needs an unlocked vault.

`bw import` **merges** — it does not replace. Re-importing into a vault that already has the items duplicates every one of them.

### Secrets Manager (`bws`)

Read it first, restore second — this writes to live secrets and there is no undo.

```bash
rclone copy gdrive:BACKUPS/bitwarden/secrets-YYYYMMDD.json.gpg .
gpg -d secrets-YYYYMMDD.json.gpg | jq '{projects, count: (.secrets|length)}'   # audit before writing
```

Every project in `projects` must exist and be granted to the current token, or its secrets land nowhere. Create missing ones with `bws project create <name>` and map old→new ids by hand — project ids do not survive an account rebuild.

```bash
export BWS_ACCESS_TOKEN=$(secret-tool lookup service bws account default)
gpg -d secrets-YYYYMMDD.json.gpg \
  | jq -r '.secrets[] | [.key, .value, .projectId, .note] | @tsv' \
  | while IFS=$'\t' read -r key value project note; do
        bws secret create "$key" "$value" "$project" --note "$note" -o none
    done
```

`bws secret create` does not upsert — a key that already exists comes back as a second secret with the same name, and `bws-env.sh` will then export whichever one it reads last. Restore into an empty project, or delete first.

The pipe keeps plaintext off disk. If you decrypt to a file instead, overwrite it before `trash` — trashed files stay readable.

## Automation

`--all` and `--bitwarden` cannot be automated: both prompt for the backup passphrase, by design (see the Bitwarden section). Only the credential-free half is cron-able.

```bash
0 2 * * 0 ~/.local/bin/backup --repos
```
