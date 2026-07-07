#!/usr/bin/env python3
"""Render one or more `git diff` outputs into a single self-contained HTML page.

Input: a JSON manifest file (argv[1]) of the shape produced by the `diffview`
launcher; output HTML is written to argv[2]. Stdlib only -- no packages, no
network -- so it runs anywhere via `uv run --no-project python3`.

Manifest:
  {"title": str,
   "sections": [
     {"repo": str, "base": str, "head": str,
      "ahead": int, "behind": int, "diff_file": "/abs/path/to/raw.diff"} ...]}
"""
import html
import json
import re
import sys

HUNK_RE = re.compile(r"^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@(.*)$")


def parse_diff(text):
    """Parse unified `git diff` text into a list of file dicts."""
    files = []
    cur = None
    old_ln = new_ln = 0
    for line in text.split("\n"):
        if line.startswith("diff --git "):
            if cur:
                files.append(cur)
            # path is the b/ side; fall back to a/ side
            m = re.match(r"diff --git a/(.*?) b/(.*)$", line)
            path = m.group(2) if m else line[len("diff --git "):]
            cur = {"path": path, "meta": [], "rows": [], "added": 0,
                   "removed": 0, "binary": False, "status": "modified"}
            continue
        if cur is None:
            continue
        if line.startswith("new file"):
            cur["status"] = "added"
        elif line.startswith("deleted file"):
            cur["status"] = "deleted"
        elif line.startswith("rename from") or line.startswith("copy from"):
            cur["meta"].append(line)
            cur["status"] = "renamed"
        elif line.startswith("rename to") or line.startswith("copy to"):
            cur["meta"].append(line)
        elif line.startswith("Binary files") or line.startswith("GIT binary patch"):
            cur["binary"] = True
        elif line.startswith("index ") or line.startswith("similarity ") \
                or line.startswith("dissimilarity ") or line.startswith("old mode") \
                or line.startswith("new mode"):
            continue
        elif line.startswith("--- ") or line.startswith("+++ "):
            continue
        else:
            m = HUNK_RE.match(line)
            if m:
                old_ln = int(m.group(1))
                new_ln = int(m.group(2))
                cur["rows"].append(("hunk", "", "", line))
                continue
            if not line:
                continue
            tag = line[0]
            body = line[1:]
            if tag == "+":
                cur["added"] += 1
                cur["rows"].append(("add", "", new_ln, body))
                new_ln += 1
            elif tag == "-":
                cur["removed"] += 1
                cur["rows"].append(("del", old_ln, "", body))
                old_ln += 1
            elif tag == " ":
                cur["rows"].append(("ctx", old_ln, new_ln, body))
                old_ln += 1
                new_ln += 1
            elif tag == "\\":  # "\ No newline at end of file"
                cur["rows"].append(("meta", "", "", line))
    if cur:
        files.append(cur)
    return files


def render_rows(rows):
    out = []
    for kind, o, n, body in rows:
        if kind == "hunk":
            out.append(
                f'<tr class="hunk"><td class="ln" colspan="2"></td>'
                f'<td class="code">{html.escape(body)}</td></tr>')
        elif kind == "meta":
            out.append(
                f'<tr class="metarow"><td class="ln" colspan="2"></td>'
                f'<td class="code">{html.escape(body)}</td></tr>')
        else:
            out.append(
                f'<tr class="{kind}"><td class="ln">{o}</td>'
                f'<td class="ln">{n}</td>'
                f'<td class="code">{html.escape(body)}</td></tr>')
    return "\n".join(out)


def render_file(fid, f):
    status = f["status"]
    badge = {"added": "NEW", "deleted": "DEL", "renamed": "REN",
             "modified": "MOD"}[status]
    if f["binary"]:
        inner = '<div class="binary">binary file — not shown</div>'
        counts = '<span class="bin">binary</span>'
    else:
        inner = (f'<table class="diff">{render_rows(f["rows"])}</table>')
        counts = (f'<span class="add-c">+{f["added"]}</span>'
                  f'<span class="del-c">−{f["removed"]}</span>')
    meta = ""
    if f["meta"]:
        meta = ('<div class="filemeta">'
                + "<br>".join(html.escape(m) for m in f["meta"]) + "</div>")
    return f'''<details class="file" id="{fid}" open>
<summary><span class="st st-{status}">{badge}</span>
<span class="path">{html.escape(f["path"])}</span>
<span class="counts">{counts}</span></summary>
{meta}{inner}
</details>'''


def render_section(idx, sec):
    files = parse_diff(sec["_diff_text"])
    sid = f"s{idx}"
    total_add = sum(f["added"] for f in files)
    total_del = sum(f["removed"] for f in files)
    behind_note = ""
    if sec.get("behind"):
        behind_note = (f' · <span class="warn">prod is {sec["behind"]} '
                       f'commit(s) ahead of {html.escape(sec["head"])}</span>')
    file_blocks = []
    nav_items = []
    for j, f in enumerate(files):
        fid = f"{sid}f{j}"
        file_blocks.append(render_file(fid, f))
        c = (f'<span class="add-c">+{f["added"]}</span>'
             f'<span class="del-c">−{f["removed"]}</span>') if not f["binary"] \
            else '<span class="bin">bin</span>'
        nav_items.append(
            f'<a href="#{fid}" class="navfile">{html.escape(f["path"])} {c}</a>')
    if not files:
        file_blocks.append('<div class="empty">No differences.</div>')
    return f'''<section class="repo" id="{sid}">
<div class="repohdr">
  <h2>{html.escape(sec["repo"])}</h2>
  <code class="refs">{html.escape(sec["base"])} … {html.escape(sec["head"])}</code>
  <span class="summary">{len(files)} file(s) ·
    <span class="add-c">+{total_add}</span>
    <span class="del-c">−{total_del}</span> ·
    {sec.get("ahead", "?")} commit(s) ahead{behind_note}</span>
</div>
<div class="navfiles">{"".join(nav_items)}</div>
{"".join(file_blocks)}
</section>'''


CSS = """
* { box-sizing: border-box; }
body { margin:0; font:13px/1.5 -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif;
  background:#0d1117; color:#c9d1d9; }
a { color:#58a6ff; text-decoration:none; }
a:hover { text-decoration:underline; }
.topbar { position:sticky; top:0; z-index:20; background:#161b22;
  border-bottom:1px solid #30363d; padding:10px 16px; display:flex;
  gap:14px; align-items:center; flex-wrap:wrap; }
.topbar h1 { font-size:14px; margin:0; font-weight:600; }
.topbar .grow { flex:1; }
.topbar button, .topbar input { font:inherit; background:#21262d; color:#c9d1d9;
  border:1px solid #30363d; border-radius:6px; padding:4px 10px; }
.topbar input { min-width:220px; }
.reponav a { margin-right:12px; font-weight:600; }
.wrap { padding:0 16px 80px; max-width:1400px; margin:0 auto; }
.repo { margin-top:28px; }
.repohdr { position:sticky; top:47px; z-index:10; background:#0d1117;
  padding:10px 0 8px; border-bottom:1px solid #30363d; }
.repohdr h2 { display:inline; font-size:16px; margin:0 10px 0 0; }
.refs { background:#21262d; padding:2px 8px; border-radius:6px; font-size:12px; }
.summary { color:#8b949e; margin-left:8px; font-size:12px; }
.warn { color:#e3b341; }
.navfiles { display:flex; flex-direction:column; gap:2px; margin:8px 0 14px;
  padding:8px 12px; background:#161b22; border:1px solid #30363d; border-radius:6px; }
.navfile { font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px; }
.file { border:1px solid #30363d; border-radius:6px; margin:10px 0; overflow:hidden; }
.file > summary { cursor:pointer; padding:8px 12px; background:#161b22;
  list-style:none; display:flex; align-items:center; gap:10px;
  font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px;
  position:sticky; top:92px; z-index:5; }
.file > summary::-webkit-details-marker { display:none; }
.file > summary:hover { background:#1c2230; }
.path { flex:1; word-break:break-all; }
.st { font-size:10px; font-weight:700; padding:1px 6px; border-radius:4px; }
.st-added { background:#1a4d2e; color:#7ee2a8; }
.st-deleted { background:#5a1e1e; color:#ffb3b3; }
.st-modified { background:#3a3410; color:#e3d07a; }
.st-renamed { background:#1e3a5a; color:#9ecbff; }
.add-c { color:#3fb950; margin-right:6px; }
.del-c { color:#f85149; }
.bin { color:#8b949e; }
.filemeta { padding:6px 12px; color:#8b949e; background:#0d1117;
  font-family:ui-monospace,monospace; font-size:11px; }
table.diff { width:100%; border-collapse:collapse;
  font-family:ui-monospace,SFMono-Regular,Menlo,monospace; font-size:12px; }
table.diff td { padding:0 8px; white-space:pre-wrap; word-break:break-word;
  vertical-align:top; }
td.ln { width:1%; min-width:44px; text-align:right; color:#6e7681;
  user-select:none; border-right:1px solid #21262d; white-space:nowrap; }
td.code { width:100%; }
tr.add { background:#132d1c; } tr.add td.code { color:#aff5cb; }
tr.del { background:#3a1417; } tr.del td.code { color:#ffc9cd; }
tr.hunk td { background:#1c2230; color:#8b949e; padding:2px 8px; }
tr.metarow td { color:#6e7681; }
.binary,.empty { padding:14px; color:#8b949e; }
"""

JS = """
function setAll(open){document.querySelectorAll('details.file')
  .forEach(d=>d.open=open);}
document.getElementById('expand').onclick=()=>setAll(true);
document.getElementById('collapse').onclick=()=>setAll(false);
document.getElementById('filter').addEventListener('input',e=>{
  const q=e.target.value.toLowerCase();
  document.querySelectorAll('details.file').forEach(d=>{
    const p=d.querySelector('.path').textContent.toLowerCase();
    d.style.display = p.includes(q)?'':'none';
  });
});
"""


def main():
    manifest_path, out_path = sys.argv[1], sys.argv[2]
    with open(manifest_path) as fh:
        man = json.load(fh)
    for sec in man["sections"]:
        with open(sec["diff_file"], encoding="utf-8", errors="replace") as fh:
            sec["_diff_text"] = fh.read()
    sections_html = "\n".join(
        render_section(i, s) for i, s in enumerate(man["sections"]))
    repo_nav = " ".join(
        f'<a href="#s{i}">{html.escape(s["repo"])}</a>'
        for i, s in enumerate(man["sections"]))
    title = html.escape(man.get("title", "diff"))
    doc = f"""<!doctype html><html><head><meta charset="utf-8">
<title>{title}</title><style>{CSS}</style></head><body>
<div class="topbar">
  <h1>{title}</h1>
  <span class="reponav">{repo_nav}</span>
  <span class="grow"></span>
  <input id="filter" placeholder="filter files…">
  <button id="expand">expand all</button>
  <button id="collapse">collapse all</button>
</div>
<div class="wrap">{sections_html}</div>
<script>{JS}</script>
</body></html>"""
    with open(out_path, "w", encoding="utf-8") as fh:
        fh.write(doc)
    print(out_path)


if __name__ == "__main__":
    main()
