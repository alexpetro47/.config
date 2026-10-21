// Alt+Shift+A (or the toolbar button): read the page's empty fields, ask the native host
// (~/.config/new-machine-setup/clef-autofill) which AUTOFILL_* value goes where, then fill them.
// No remote debugging, so Brave never shows "Allow remote debugging?".
const HOST = "com.alexpetro.clef_autofill";

// Runs in the page. Without `fills`: describe the visible, editable fields. With `fills`: type each value
// into its field. Both passes walk the page the same way, so an index means the same field in each.
function page(fills) {
  const SKIP = new Set(["hidden", "password", "checkbox", "radio", "file", "submit", "button", "reset", "image", "range", "color"]);
  // A page can plant fields you can't see ("address", "phone") to harvest autofill, so a field must be
  // really on show: real size, on the page, not transparent or clipped, no hidden ancestor. Viewport-independent
  // on purpose, so the scan and fill passes agree on indices even if the page scrolled in between.
  const visible = (el) => {
    const r = el.getBoundingClientRect(), cs = getComputedStyle(el);
    if (r.width < 8 || r.height < 8 || cs.visibility !== "visible" || cs.display === "none") return false;
    const pageW = document.documentElement.scrollWidth, pageH = document.documentElement.scrollHeight;
    const x = r.left + scrollX, y = r.top + scrollY;
    if (x + r.width <= 0 || y + r.height <= 0 || x >= pageW || y >= pageH) return false;
    if ((cs.clipPath && cs.clipPath !== "none") || (cs.clip && cs.clip !== "auto")) return false;
    for (let n = el; n; n = n.parentElement) {
      const s = n === el ? cs : getComputedStyle(n);
      if (parseFloat(s.opacity) < 0.1) return false;
      if (n !== el && s.overflow !== "visible" && (n.clientWidth < 8 || n.clientHeight < 8)) return false;
    }
    return true;
  };
  const els = [];
  const walk = (root) => {
    for (const el of root.querySelectorAll("*")) {
      if (el.shadowRoot) walk(el.shadowRoot);
      if (!["INPUT", "TEXTAREA", "SELECT"].includes(el.tagName)) continue;
      if (el.tagName === "INPUT" && SKIP.has((el.type || "text").toLowerCase())) continue;
      if (el.disabled || el.readOnly) continue;
      if (!visible(el)) continue;
      els.push(el);
    }
  };
  walk(document);

  if (fills) {
    const done = [];
    for (const { index, value } of fills) {
      const el = els[index];
      if (!el) continue;
      if (el.tagName === "SELECT") {
        const want = value.toLowerCase().trim();
        const opts = [...el.options], t = (o) => o.text.trim().toLowerCase();
        const o = opts.find((o) => o.value.toLowerCase() === want || t(o) === want)
          || opts.find((o) => t(o) && (t(o).startsWith(want) || want.startsWith(t(o))));
        if (!o) continue;
        el.value = o.value;
      } else {
        el.focus();
        el.select?.();
        // execCommand types like a user (React, input masks); the setter covers date inputs and the rest.
        let typed = false;
        try { typed = document.execCommand("insertText", false, value); } catch {}
        if (!typed || el.value !== value) {
          const proto = el.tagName === "TEXTAREA" ? HTMLTextAreaElement.prototype : HTMLInputElement.prototype;
          Object.getOwnPropertyDescriptor(proto, "value").set.call(el, value);
          el.dispatchEvent(new Event("input", { bubbles: true }));
        }
      }
      el.dispatchEvent(new Event("change", { bubbles: true }));
      el.blur();
      if (el.value) done.push(index);
    }
    return done;
  }

  const clean = (s) => (s || "").replace(/\s+/g, " ").trim().slice(0, 120);
  const nearText = (el) => {
    let n = el;
    for (let i = 0; i < 3 && n.parentElement; i++) {
      n = n.parentElement;
      const t = clean(n.innerText);
      if (t && n.querySelectorAll("input,textarea,select").length <= 2) return t;
    }
    return "";
  };
  const fields = els.map((el, i) => {
    const f = { index: i, tag: el.tagName.toLowerCase() };
    if (el.tagName === "INPUT") f.type = (el.type || "text").toLowerCase();
    const lbl = [...(el.labels || [])].map((l) => clean(l.innerText)).filter(Boolean).join(" / ");
    const by = (el.getAttribute("aria-labelledby") || "").split(/\s+/).map((id) => document.getElementById(id))
      .filter(Boolean).map((n) => clean(n.innerText)).join(" ");
    const attrs = { label: lbl, aria_label: el.getAttribute("aria-label"), labelled_by: by,
      placeholder: el.getAttribute("placeholder"), name: el.getAttribute("name"), id: el.id,
      autocomplete: el.getAttribute("autocomplete"), inputmode: el.getAttribute("inputmode") };
    for (const [k, v] of Object.entries(attrs)) if (clean(v)) f[k] = clean(v);
    if (!f.label && !f.aria_label && !f.labelled_by) { const t = nearText(el); if (t) f.nearby_text = t; }
    if (el.tagName === "SELECT") {
      f.options = [...el.options].slice(0, 12).map((o) => clean(o.text));
      f.empty = el.selectedIndex <= 0;
    } else f.empty = !el.value;
    return f;
  });
  return { page: { title: document.title, url: location.origin + location.pathname }, fields };
}

function badge(tabId, text, color) {
  chrome.action.setBadgeBackgroundColor({ tabId, color });
  chrome.action.setBadgeText({ tabId, text });
  setTimeout(() => chrome.action.setBadgeText({ tabId, text: "" }), 4000);
}

// The host shows the desktop notification, so report the real outcome back to it.
const report = (message, error = false) =>
  chrome.runtime.sendNativeMessage(HOST, { report: message, error }).catch(() => {});

chrome.action.onClicked.addListener(async (tab) => {
  badge(tab.id, "…", "#666");
  try {
    const [{ result: scan }] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: page, args: [null] });
    const reply = await chrome.runtime.sendNativeMessage(HOST, scan);
    if (reply.error) throw new Error(reply.error);
    if (!reply.fills.length) {
      badge(tab.id, "0", "#999");
      return report(reply.message);
    }
    const [{ result: done }] = await chrome.scripting.executeScript({ target: { tabId: tab.id }, func: page, args: [reply.fills] });
    const names = reply.fills.filter((f) => done.includes(f.index)).map((f) => f.name);
    const missed = reply.fills.length - done.length;
    badge(tab.id, String(done.length), done.length ? "#2a7" : "#c33");
    report(`Filled ${done.length}: ${names.join(", ")}` + (missed ? ` (${missed} didn't take)` : ""), !done.length);
  } catch (e) {
    console.error(e);
    badge(tab.id, "!", "#c33");
    chrome.action.setTitle({ tabId: tab.id, title: `Clef autofill failed: ${e.message}` });
    report(`Failed: ${e.message}`, true);
  }
});
