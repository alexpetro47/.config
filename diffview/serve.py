#!/usr/bin/env python3
"""diffview review server — a tiny stdlib HTTP app backing the review dashboard.

Launched (backgrounded) by the `diffview` launcher with a resolved targets spec:
    serve.py <spec.json> [port]

It computes the feature groups + per-commit diffs once at startup (fast, local
git), then serves a single page. Interactive review state — per-file "viewed",
group status, verify-playbook steps, and notes — is read live from the on-disk
store on every request and written on every POST, so it stays in sync with
whatever Claude writes to the same files. Stdlib only (runs via `uv run`).

Routes:
    GET  /             the dashboard (diffs baked in, live state re-read per load)
    GET  /api/state    merged review state as JSON
    POST /api/review   {op, group, ...} -> mutate the store
"""
import html
import json
import os
import sys
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import dv_core          # noqa: E402
import render_diff      # noqa: E402  (reuse its diff parser + CSS)

LOCK = threading.Lock()
SPEC = {}
STATIC = {}   # gid -> precomputed {title, repos, commits, files, commit_blocks}
ORDER = []    # gids, display order

STATUSES = ["in-queue", "reviewing", "reviewed"]
BUCKETS = [("logs", "Logs to check"), ("ui", "UI · where + what changes"),
           ("e2e", "e2e setup flow"), ("backend", "Backend data checks")]


# ----------------------------- precompute -----------------------------
def file_block(key, f):
    badge = {"added": "NEW", "deleted": "DEL", "renamed": "REN",
             "modified": "MOD"}[f["status"]]
    if f["binary"]:
        inner = '<div class="binary">binary file — not shown</div>'
        counts = '<span class="bin">binary</span>'
    else:
        inner = f'<table class="diff">{render_diff.render_rows(f["rows"])}</table>'
        counts = (f'<span class="add-c">+{f["added"]}</span>'
                  f'<span class="del-c">−{f["removed"]}</span>')
    return (f'<details class="file" data-key="{html.escape(key)}" open>'
            f'<summary><span class="st st-{f["status"]}">{badge}</span>'
            f'<span class="path">{html.escape(f["path"])}</span>'
            f'<span class="counts">{counts}</span></summary>{inner}</details>')


def precompute(spec):
    commits = dv_core.gather(spec["targets"], spec.get("author"),
                             spec.get("since"))
    groups = dv_core.group_commits(commits, spec.get("group", "scope"))
    static = {}
    for gid, g in groups.items():
        blocks = []
        for c in g["commits"]:
            patch = dv_core.git(c["dir"], "show", "--format=", "--no-color",
                                c["sha"])
            fb = "".join(file_block(f'{c["repo"]}:{f["path"]}', f)
                         for f in render_diff.parse_diff(patch))
            blocks.append({"sha": c["sha"], "subject": c["subject"],
                           "repo": c["repo"], "html": fb})
        static[gid] = {
            "id": gid, "title": g["title"],
            "repos": sorted({c["repo"] for c in g["commits"]}),
            "commits": g["commits"], "files": dv_core.files_of(g),
            "commit_blocks": blocks}
    return static


# ----------------------------- rendering ------------------------------
def render_verify(gid, store):
    v = store.get("verify", {})
    out = ['<div class="verify"><div class="vhdr">✓ verify playbook</div>']
    for key, label in BUCKETS:
        steps = v.get(key, [])
        out.append(f'<div class="vbucket"><div class="vlabel">{label}</div>')
        for i, s in enumerate(steps):
            ck = "checked" if s.get("done") else ""
            out.append(
                f'<label class="vstep"><input type="checkbox" class="vtoggle" '
                f'data-gid="{html.escape(gid)}" data-bucket="{key}" '
                f'data-i="{i}" {ck}>'
                f'<span>{html.escape(s.get("text", ""))}</span></label>')
        out.append(
            f'<input class="vadd" data-gid="{html.escape(gid)}" '
            f'data-bucket="{key}" placeholder="+ add step…">')
        out.append("</div>")
    out.append("</div>")
    return "".join(out)


def render_section(st, store):
    gid = st["id"]
    viewed = store.get("files", {})
    n_viewed = sum(1 for f in st["files"] if viewed.get(f["key"]))
    v = store.get("verify", {})
    v_total = sum(len(v.get(k, [])) for k, _ in BUCKETS)
    v_done = sum(1 for k, _ in BUCKETS for s in v.get(k, []) if s.get("done"))
    status = store.get("status", "in-queue")

    opts = "".join(
        f'<option value="{s}"{" selected" if s == status else ""}>{s}</option>'
        for s in STATUSES)

    navs = []
    for f in st["files"]:
        ck = "checked" if viewed.get(f["key"]) else ""
        navs.append(
            f'<label class="navfile"><input type="checkbox" class="viewed" '
            f'data-gid="{html.escape(gid)}" data-key="{html.escape(f["key"])}" '
            f'{ck}><span class="np">{html.escape(f["repo"])}: '
            f'{html.escape(f["path"])}</span></label>')

    commits = []
    for b in st["commit_blocks"]:
        commits.append(
            f'<div class="commit"><div class="chdr">'
            f'<span class="csha">{b["sha"][:8]}</span> '
            f'<span class="crepo">{html.escape(b["repo"])}</span> '
            f'<span class="csub">{html.escape(b["subject"])}</span></div>'
            f'{b["html"]}</div>')

    return f'''<section class="group collapsed" id="g-{html.escape(gid)}"
   data-gid="{html.escape(gid)}" data-status="{status}">
  <div class="grouphdr">
    <h2>{html.escape(st["title"])}</h2>
    <span class="repos">{html.escape(", ".join(st["repos"]))}</span>
    <select class="statussel" data-gid="{html.escape(gid)}">{opts}</select>
    <span class="progress">files <b class="fv">{n_viewed}</b>/{len(st["files"])}
      · verify <b>{v_done}</b>/{v_total}</span>
    <span class="grow"></span>
    <button class="toggle" data-gid="{html.escape(gid)}">expand</button>
  </div>
  <div class="gbody">
    <div class="cols">
      <div class="left">
        <div class="navfiles">{"".join(navs) or "<i>no files</i>"}</div>
        {"".join(commits)}
      </div>
      <aside class="right">
        {render_verify(gid, store)}
        <div class="notesbox"><div class="vhdr">notes</div>
          <textarea class="notes" data-gid="{html.escape(gid)}"
            placeholder="shared notes…">{html.escape(store.get("notes", ""))}</textarea>
        </div>
      </aside>
    </div>
  </div>
</section>'''


def render_page():
    secs = "\n".join(render_section(STATIC[g], dv_core.load_store(g))
                     for g in ORDER)
    nav = " ".join(f'<a href="#g-{html.escape(g)}">{html.escape(STATIC[g]["title"])}</a>'
                   for g in ORDER)
    title = html.escape(SPEC.get("title", "diffview review"))
    return f"""<!doctype html><html><head><meta charset="utf-8">
<title>{title}</title><style>{render_diff.CSS}{EXTRA_CSS}</style></head><body>
<div class="topbar">
  <h1>{title}</h1>
  <span class="reponav">{nav}</span>
  <span class="grow"></span>
  <button id="expandall">expand all</button>
  <button id="collapseall">collapse all</button>
</div>
<div class="wrap">{secs}</div>
<script>{JS}</script>
</body></html>"""


def state_json():
    return {"title": SPEC.get("title", ""), "groups": dv_core.build(SPEC)}


# ------------------------------- store --------------------------------
def handle_review(p):
    gid, op = p["group"], p["op"]

    def upd(s):
        if op == "status":
            s["status"] = p["value"]
        elif op == "viewed":
            s.setdefault("files", {})[p["key"]] = bool(p["value"])
        elif op == "notes":
            s["notes"] = p["value"]
        elif op == "verify_toggle":
            s["verify"][p["bucket"]][p["index"]]["done"] = bool(p["value"])
        elif op == "verify_add":
            s["verify"].setdefault(p["bucket"], []).append(
                {"text": p["text"], "done": False})
        else:
            raise ValueError(f"unknown op {op}")
    dv_core.update_store(gid, upd)


# ------------------------------- server -------------------------------
class Handler(BaseHTTPRequestHandler):
    def _send(self, code, body, ctype):
        b = body.encode() if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(b)))
        self.end_headers()
        self.wfile.write(b)

    def do_GET(self):
        if self.path == "/":
            self._send(200, render_page(), "text/html; charset=utf-8")
        elif self.path == "/api/state":
            with LOCK:
                self._send(200, json.dumps(state_json()), "application/json")
        else:
            self._send(404, "not found", "text/plain")

    def do_POST(self):
        if self.path != "/api/review":
            return self._send(404, "not found", "text/plain")
        n = int(self.headers.get("Content-Length", 0))
        try:
            data = json.loads(self.rfile.read(n) or b"{}")
            with LOCK:
                handle_review(data)
            self._send(200, '{"ok":true}', "application/json")
        except Exception as e:  # noqa: BLE001 — report any store error to client
            self._send(400, json.dumps({"error": str(e)}), "application/json")

    def log_message(self, format, *args):  # noqa: A002 — silence access log
        pass


EXTRA_CSS = """
.group { margin-top:26px; border:1px solid #30363d; border-radius:8px; overflow:hidden; }
.grouphdr { position:sticky; top:47px; z-index:10; display:flex; gap:12px;
  align-items:center; background:#161b22; border-bottom:1px solid #30363d;
  padding:10px 14px; }
.grouphdr h2 { font-size:15px; margin:0; }
.grouphdr .repos { color:#8b949e; font-size:12px; }
.statussel { font:inherit; background:#21262d; color:#c9d1d9;
  border:1px solid #30363d; border-radius:6px; padding:3px 8px; }
.group[data-status=reviewed] .grouphdr { border-left:3px solid #3fb950; }
.group[data-status=reviewing] .grouphdr { border-left:3px solid #e3b341; }
.progress { color:#8b949e; font-size:12px; }
.grouphdr .grow { flex:1; }
.toggle { font:inherit; background:#21262d; color:#c9d1d9; border:1px solid #30363d;
  border-radius:6px; padding:3px 10px; cursor:pointer; }
.gbody { padding:0 14px 14px; }
.group.collapsed .gbody { display:none; }
.cols { display:flex; gap:16px; align-items:flex-start; }
.left { flex:1; min-width:0; }
.right { width:320px; flex:none; position:sticky; top:100px; }
.navfile { display:flex; align-items:center; gap:8px; }
.navfile input { flex:none; }
.navfile.done .np { color:#6e7681; text-decoration:line-through; }
.file.dim { opacity:.45; }
.commit { margin:14px 0; }
.chdr { display:flex; gap:8px; align-items:baseline; padding:6px 4px;
  border-bottom:1px solid #21262d; margin-bottom:6px; }
.csha { font-family:ui-monospace,monospace; color:#8b949e; font-size:11px; }
.crepo { color:#58a6ff; font-size:11px; }
.csub { font-weight:600; }
.verify, .notesbox { background:#161b22; border:1px solid #30363d;
  border-radius:8px; padding:10px 12px; margin-bottom:12px; }
.vhdr { font-weight:600; font-size:12px; color:#c9d1d9; margin-bottom:8px; }
.vbucket { margin-bottom:10px; }
.vlabel { font-size:11px; text-transform:uppercase; letter-spacing:.04em;
  color:#8b949e; margin-bottom:4px; }
.vstep { display:flex; gap:8px; align-items:flex-start; font-size:12px;
  padding:2px 0; }
.vstep input { margin-top:2px; flex:none; }
.vstep input:checked + span { color:#6e7681; text-decoration:line-through; }
.vadd { width:100%; margin-top:4px; font:inherit; font-size:12px;
  background:#0d1117; color:#c9d1d9; border:1px solid #30363d; border-radius:6px;
  padding:4px 8px; }
.notes { width:100%; min-height:80px; resize:vertical; font:inherit; font-size:12px;
  background:#0d1117; color:#c9d1d9; border:1px solid #30363d; border-radius:6px;
  padding:6px 8px; }
"""

JS = """
const post = (body) => fetch('/api/review', {method:'POST',
  headers:{'Content-Type':'application/json'}, body:JSON.stringify(body)});

function setGroupOpen(g, open){ g.classList.toggle('collapsed', !open);
  g.querySelector('.toggle').textContent = open ? 'collapse' : 'expand'; }

document.querySelectorAll('.toggle').forEach(b => b.onclick = () => {
  const g = b.closest('.group'); setGroupOpen(g, g.classList.contains('collapsed')); });
document.getElementById('expandall').onclick = () =>
  document.querySelectorAll('.group').forEach(g => setGroupOpen(g, true));
document.getElementById('collapseall').onclick = () =>
  document.querySelectorAll('.group').forEach(g => setGroupOpen(g, false));

document.querySelectorAll('.statussel').forEach(sel => sel.onchange = () => {
  post({op:'status', group:sel.dataset.gid, value:sel.value});
  sel.closest('.group').dataset.status = sel.value; });

function applyViewed(cb){
  const g = cb.closest('.group'); const key = cb.dataset.key;
  cb.closest('.navfile').classList.toggle('done', cb.checked);
  g.querySelectorAll('details.file[data-key]').forEach(d => {
    if (d.dataset.key === key){ d.classList.toggle('dim', cb.checked); d.open = !cb.checked; }});
  const cnt = [...g.querySelectorAll('.viewed')].filter(x=>x.checked).length;
  g.querySelector('.fv').textContent = cnt;
}
document.querySelectorAll('.viewed').forEach(cb => {
  applyViewed(cb);
  cb.onchange = () => { applyViewed(cb);
    post({op:'viewed', group:cb.dataset.gid, key:cb.dataset.key, value:cb.checked}); };
});

document.querySelectorAll('.vtoggle').forEach(cb => cb.onchange = () =>
  post({op:'verify_toggle', group:cb.dataset.gid, bucket:cb.dataset.bucket,
        index:+cb.dataset.i, value:cb.checked}));

document.querySelectorAll('.vadd').forEach(inp => inp.onkeydown = (e) => {
  if (e.key !== 'Enter' || !inp.value.trim()) return;
  post({op:'verify_add', group:inp.dataset.gid, bucket:inp.dataset.bucket,
        text:inp.value.trim()}).then(() => location.reload()); });

document.querySelectorAll('.notes').forEach(t => {
  let timer; t.oninput = () => { clearTimeout(timer);
    timer = setTimeout(() => post({op:'notes', group:t.dataset.gid, value:t.value}), 500); };
});
"""


def main():
    global SPEC, STATIC, ORDER
    spec_path = sys.argv[1]
    port = int(sys.argv[2]) if len(sys.argv) > 2 else \
        int(os.environ.get("DIFFVIEW_PORT", "8765"))
    with open(spec_path) as f:
        SPEC = json.load(f)
    STATIC = precompute(SPEC)
    ORDER = sorted(STATIC, key=lambda g: STATIC[g]["title"].lower())
    os.makedirs(dv_core.DATA_DIR, exist_ok=True)
    with open(os.path.join(dv_core.DATA_DIR, "server.url"), "w") as f:
        f.write(f"http://127.0.0.1:{port}")
    httpd = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
