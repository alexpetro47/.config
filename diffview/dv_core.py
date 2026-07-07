#!/usr/bin/env python3
"""diffview core — gather commits across repos, group them into features, manage
the persistent review store, and report status.

Invoked by the `diffview` launcher, which pipes a resolved *targets* spec on
stdin. Stdlib only, so it runs anywhere via `uv run --no-project python3`.

Commands:
  dv_core.py status [--json]      # print groups + review progress

Persistent human state lives at $XDG_DATA_HOME/diffview/groups/<id>.json and is
never overwritten by a re-run: commits/diffs are recomputed, but status, viewed
flags, verify playbooks and notes are keyed by stable group id and merged back.

targets spec (stdin):
  {"title": str, "group": "scope"|"time", "author": null|str, "since": null|str,
   "targets": [{"repo": str, "dir": str, "base": str, "head": str}, ...]}
"""
import json
import os
import re
import subprocess
import sys

DATA_DIR = os.path.join(
    os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share")),
    "diffview")
GROUPS_DIR = os.path.join(DATA_DIR, "groups")

# conventional-commit types that carry no feature meaning on their own
STD_TYPES = {"feat", "fix", "chore", "refactor", "docs", "test", "tests",
             "style", "perf", "build", "ci", "revert", "wip", "hotfix", "merge"}
# type(scope)!: ...   — scope is group 2; a bare non-standard type is a component
SUBJECT_RE = re.compile(r"^([A-Za-z0-9_.\-]+)(?:\(([^)]+)\))?!?:\s")
US = "\x1f"  # git-log field separator


def git(dir, *args):
    return subprocess.run(["git", "-C", dir, *args],
                          capture_output=True, text=True).stdout


def scope_of(subject):
    """Feature key from a commit subject, or None to fall back to time bucketing.

    `fix(chat): …` -> "chat";  `ady: …` -> "ady" (component);  `fix: …` -> None.
    """
    m = SUBJECT_RE.match(subject)
    if not m:
        return None
    typ, scope = m.group(1), m.group(2)
    if scope:
        return scope.strip()
    if typ.lower() not in STD_TYPES:
        return typ  # component-style prefix, e.g. "ady:", "mo_prereq:"
    return None


def slug(s):
    return re.sub(r"[^a-z0-9_.-]+", "-", s.lower()).strip("-") or "misc"


def gather(targets, author=None, since=None):
    commits = []
    fmt = US.join(["%H", "%an", "%ae", "%aI", "%s"])
    for t in targets:
        args = ["log", "--no-merges", f"--format={fmt}",
                f"{t['base']}..{t['head']}"]
        if since:
            args.append(f"--since={since}")
        if author:
            args.append(f"--author={author}")
        for line in git(t["dir"], *args).splitlines():
            if not line.strip():
                continue
            parts = (line.split(US) + ["", "", "", "", ""])[:5]
            h, an, ae, ai, subj = parts
            commits.append({"repo": t["repo"], "dir": t["dir"], "sha": h,
                            "author": an, "email": ae, "date": ai,
                            "subject": subj})
    return commits


def overrides_path():
    return os.path.join(DATA_DIR, "overrides.json")


def load_overrides():
    """Manual grouping: {"assign": {"repo:sha": gid}, "titles": {gid: title}}."""
    p = overrides_path()
    if os.path.exists(p):
        try:
            with open(p) as f:
                o = json.load(f)
            o.setdefault("assign", {})
            o.setdefault("titles", {})
            return o
        except (OSError, ValueError):
            pass
    return {"assign": {}, "titles": {}}


def save_overrides(o):
    os.makedirs(DATA_DIR, exist_ok=True)
    tmp = overrides_path() + ".tmp"
    with open(tmp, "w") as f:
        json.dump(o, f, indent=2)
    os.replace(tmp, overrides_path())


def override_group(assign, repo, sha):
    """A commit's manually assigned group, matching full or short-sha refs."""
    g = assign.get(f"{repo}:{sha}")
    if g:
        return g
    for k, v in assign.items():
        r, _, pfx = k.partition(":")
        if r == repo and pfx and sha.startswith(pfx):
            return v
    return None


def group_commits(commits, strategy):
    ov = load_overrides()
    assign, titles = ov["assign"], ov["titles"]
    groups = {}
    for c in commits:
        gid = override_group(assign, c["repo"], c["sha"])
        if gid:
            title = gid
        elif strategy == "time":
            gid, title = "day-" + c["date"][:10], c["date"][:10]
        else:
            sc = scope_of(c["subject"])
            if sc:
                gid, title = slug(sc), sc
            else:
                gid = "day-" + c["date"][:10]
                title = c["date"][:10] + " (unscoped)"
        title = titles.get(gid, title)  # manual rename wins, even for auto groups
        g = groups.setdefault(gid, {"id": gid, "title": title, "commits": []})
        g["commits"].append(c)
    return groups


def files_of(group):
    """Union of files touched by a group's commits, keyed 'repo:path'."""
    files, seen = [], set()
    for c in group["commits"]:
        out = git(c["dir"], "show", "--name-only", "--format=", c["sha"])
        for p in out.splitlines():
            p = p.strip()
            if not p:
                continue
            key = f'{c["repo"]}:{p}'
            if key in seen:
                continue
            seen.add(key)
            files.append({"repo": c["repo"], "path": p, "key": key})
    return files


def default_store():
    return {"status": "in-queue", "files": {},
            "verify": {"logs": [], "ui": [], "e2e": [], "backend": []},
            "notes": ""}


def load_store(gid):
    p = os.path.join(GROUPS_DIR, gid + ".json")
    if os.path.exists(p):
        try:
            with open(p) as f:
                return {**default_store(), **json.load(f)}
        except (OSError, ValueError):
            pass
    return default_store()


def save_store(gid, store):
    os.makedirs(GROUPS_DIR, exist_ok=True)
    p = os.path.join(GROUPS_DIR, gid + ".json")
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(store, f, indent=2)
    os.replace(tmp, p)  # atomic


def update_store(gid, fn):
    """Load, mutate via fn, and persist a group's store. fn edits in place."""
    store = load_store(gid)
    fn(store)
    save_store(gid, store)
    return store


def build(spec):
    commits = gather(spec["targets"], spec.get("author"), spec.get("since"))
    groups = group_commits(commits, spec.get("group", "scope"))
    out = []
    for gid, g in groups.items():
        files = files_of(g)
        store = load_store(gid)
        viewed = store.get("files", {})
        n_viewed = sum(1 for f in files if viewed.get(f["key"]))
        v = store.get("verify", {})
        v_total = sum(len(v.get(k, [])) for k in ("logs", "ui", "e2e", "backend"))
        v_done = sum(1 for k in ("logs", "ui", "e2e", "backend")
                     for s in v.get(k, []) if s.get("done"))
        out.append({
            "id": gid, "title": g["title"],
            "status": store.get("status", "in-queue"),
            "repos": sorted({c["repo"] for c in g["commits"]}),
            "commits": g["commits"], "files": files,
            "n_commits": len(g["commits"]), "n_files": len(files),
            "n_viewed": n_viewed, "verify_total": v_total, "verify_done": v_done,
            "verify": v, "notes": store.get("notes", ""),
        })
    order = {"reviewing": 0, "in-queue": 1, "reviewed": 2}
    out.sort(key=lambda r: (order.get(r["status"], 1), r["title"].lower()))
    return out


ICON = {"reviewed": "\033[32m✓\033[0m", "reviewing": "\033[33m●\033[0m",
        "in-queue": "\033[90m○\033[0m"}


def cmd_status(spec, as_json):
    groups = build(spec)
    if as_json:
        print(json.dumps({"title": spec.get("title", ""), "groups": groups},
                         indent=2))
        return
    title = spec.get("title", "review")
    print(f"\n\033[1m{title}\033[0m\n")
    if not groups:
        print("  (no commits in range)\n")
        return
    for g in groups:
        icon = ICON.get(g["status"], "○")
        repos = ", ".join(g["repos"])
        vt = f'{g["verify_done"]}/{g["verify_total"]}' if g["verify_total"] \
            else "\033[90m—\033[0m"
        print(f'  {icon} \033[1m{g["title"]:<18}\033[0m '
              f'\033[36m{repos}\033[0m\n'
              f'      {g["n_commits"]} commit(s) · '
              f'files {g["n_viewed"]}/{g["n_files"]} · verify {vt}')
    counts = {}
    for g in groups:
        counts[g["status"]] = counts.get(g["status"], 0) + 1
    tail = " · ".join(f'{v} {k}' for k, v in sorted(counts.items()))
    print(f'\n  {len(groups)} group(s) · {tail}\n')


def cmd_verify(argv):
    """Author a group's verify playbook safely (load-modify-save)."""
    import argparse
    ap = argparse.ArgumentParser(prog="diffview verify")
    ap.add_argument("group")
    ap.add_argument("--logs", action="append", default=[], metavar="STEP")
    ap.add_argument("--ui", action="append", default=[], metavar="STEP")
    ap.add_argument("--e2e", action="append", default=[], metavar="STEP")
    ap.add_argument("--backend", action="append", default=[], metavar="STEP")
    ap.add_argument("--note")
    ap.add_argument("--status", choices=["in-queue", "reviewing", "reviewed"])
    ap.add_argument("--clear", action="store_true",
                    help="drop existing steps before adding")
    a = ap.parse_args(argv)

    def upd(s):
        if a.clear:
            s["verify"] = {"logs": [], "ui": [], "e2e": [], "backend": []}
        for b in ("logs", "ui", "e2e", "backend"):
            for t in getattr(a, b):
                s["verify"].setdefault(b, []).append({"text": t, "done": False})
        if a.note is not None:
            s["notes"] = a.note
        if a.status:
            s["status"] = a.status
    store = update_store(a.group, upd)
    print(f"{a.group}: " + ", ".join(
        f'{len(store["verify"][b])} {b}' for b in ("logs", "ui", "e2e", "backend"))
        + f' · status={store["status"]}')


def cmd_group(argv):
    """Curate group membership: override the automatic scope/time grouping."""
    ov = load_overrides()
    sub = argv[0] if argv else "show"
    if sub == "move":                       # move <gid> <repo:sha> [<repo:sha>…]
        gid, refs = argv[1], argv[2:]
        for ref in refs:
            ov["assign"][ref] = gid
        save_overrides(ov)
        print(f"moved {len(refs)} commit(s) -> {gid}")
    elif sub == "title":                    # title <gid> "<display title>"
        ov["titles"][argv[1]] = argv[2]
        save_overrides(ov)
        print(f'{argv[1]} titled "{argv[2]}"')
    elif sub == "unassign":                 # unassign <repo:sha> [<repo:sha>…]
        for ref in argv[1:]:
            ov["assign"].pop(ref, None)
        save_overrides(ov)
        print(f"unassigned {len(argv[1:])} commit(s)")
    elif sub == "reset":
        save_overrides({"assign": {}, "titles": {}})
        print("cleared all overrides")
    elif sub == "show":
        if not ov["assign"] and not ov["titles"]:
            print("no overrides — grouping is automatic")
            return
        for k, v in ov["assign"].items():
            print(f"  {k} -> {v}")
        for k, v in ov["titles"].items():
            print(f'  title {k} = "{v}"')
    else:
        sys.exit(f"diffview group: unknown subcommand {sub!r} "
                 "(move|title|unassign|reset|show)")


def main():
    argv = sys.argv[1:]
    cmd = argv[0] if argv else "status"
    if cmd == "verify":
        cmd_verify(argv[1:])
        return
    if cmd == "group":
        cmd_group(argv[1:])
        return
    as_json = "--json" in argv
    spec = json.load(sys.stdin)
    if cmd == "status":
        cmd_status(spec, as_json)
    else:
        sys.exit(f"dv_core: unknown command {cmd!r}")


if __name__ == "__main__":
    main()
