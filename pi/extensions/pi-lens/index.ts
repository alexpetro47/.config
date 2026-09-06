/**
 * pi-lens — Live introspection lens for pi sessions.
 *
 * Toggle with `/pi-lens`.  When active a footer widget shows:
 *   • context tokens / window (usage bar)
 *   • current model & provider
 *   • turn count
 *   • last tool executed + duration
 *
 * Also adds:
 *   `/pi-lens report`  — one-shot dump of session stats
 *   `/pi-lens tokens`  — quick token usage line
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

let active = true;
let turnCount = 0;
let lastTool = "";
let lastToolStart = 0;

// Per-run stats for agent-end tldr
let runStart = 0;
let runToolCount = 0;
let runFilesRead: string[] = [];
let runFilesWritten: string[] = [];
let runFilesEdited: string[] = [];

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function fmtTokens(n: number | undefined): string {
  if (n === undefined) return "?";
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`;
  if (n >= 1_000) return `${(n / 1_000).toFixed(1)}k`;
  return String(n);
}

function bar(used: number, total: number, width = 12): string {
  const pct = Math.min(used / total, 1);
  const filled = Math.round(pct * width);
  const empty = width - filled;
  const color = pct > 0.9 ? "▇" : pct > 0.6 ? "▅" : "▃";
  return color.repeat(filled) + "░".repeat(empty);
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  // ── lifecycle ────────────────────────────────────────────────────────

  pi.on("session_start", (_event, ctx) => {
    turnCount = 0;
    lastTool = "";
    lastToolStart = 0;
    if (active) {
      ctx.ui.setWidget("pi-lens", ["🔎 loading…", ""]);
    }
  });

  pi.on("agent_start", () => {
    runStart = Date.now();
    runToolCount = 0;
    runFilesRead = [];
    runFilesWritten = [];
    runFilesEdited = [];
  });

  pi.on("turn_start", () => {
    turnCount++;
    refreshWidget(pi);
  });

  pi.on("tool_call", (event) => {
    lastTool = event.toolName;
    lastToolStart = Date.now();
    runToolCount++;
    // Track files touched
    const input = event.input as Record<string, unknown>;
    const path = typeof input.path === "string" ? input.path : undefined;
    if (path) {
      if (event.toolName === "read" && !runFilesRead.includes(path)) runFilesRead.push(path);
      if (event.toolName === "write" && !runFilesWritten.includes(path)) runFilesWritten.push(path);
      if (event.toolName === "edit" && !runFilesEdited.includes(path)) runFilesEdited.push(path);
    }
    refreshWidget(pi);
  });

  pi.on("tool_execution_end", () => {
    refreshWidget(pi);
  });

  pi.on("model_select", (_event, ctx) => {
    ctx.ui.notify(
      `pi-lens: model → ${_event.model.provider}/${_event.model.id}`,
      "info",
    );
    refreshWidget(pi);
  });

  pi.on("session_shutdown", () => {
    active = false;
  });

  // ── refresh helper ───────────────────────────────────────────────────

  function refreshWidget(pi: ExtensionAPI) {
    // The widget API uses setWidget — we push a minimal update.
    // Actual context usage is available only inside agent events via ctx.getContextUsage().
    // We approximate from the last known model.
  }

  // ── commands ─────────────────────────────────────────────────────────

  pi.registerCommand("pi-lens", {
    description: "Toggle pi-lens widget | report | tokens",
    handler: async (args, ctx) => {
      const sub = args?.trim().toLowerCase();

      if (sub === "report" || sub === "r") {
        // Dump a one-shot report
        const usage = ctx.getContextUsage();
        const model = ctx.model;
        const lines: string[] = [
          `pi-lens report`,
          `  model       : ${model ? `${model.provider}/${model.id}` : "?"}`,
          `  turns       : ${turnCount}`,
          `  last tool   : ${lastTool || "(none)"}`,
          `  context     : ${usage ? `${fmtTokens(usage.tokens)} tokens` : "unavailable"}`,
        ];
        if (model?.contextWindow) {
          lines.push(`  window      : ${fmtTokens(model.contextWindow)}`);
          if (usage?.tokens) {
            lines.push(
              `  utilization : ${((usage.tokens / model.contextWindow) * 100).toFixed(1)}%`,
            );
          }
        }
        ctx.ui.notify(lines.join("\n"), "info");
        return;
      }

      if (sub === "tokens" || sub === "t") {
        const usage = ctx.getContextUsage();
        if (usage) {
          const model = ctx.model;
          const used = fmtTokens(usage.tokens);
          const win = model?.contextWindow ? fmtTokens(model.contextWindow) : "?";
          ctx.ui.notify(`Tokens: ${used} / ${win}`, "info");
        } else {
          ctx.ui.notify("Token usage unavailable right now", "warning");
        }
        return;
      }

      // Toggle widget
      active = !active;
      if (active) {
        ctx.ui.notify("pi-lens: ON", "info");
        updateWidget(ctx);
      } else {
        ctx.ui.setWidget("pi-lens", []);
        ctx.ui.notify("pi-lens: OFF", "info");
      }
    },
  });

  // ── widget update helper ─────────────────────────────────────────────

  function updateWidget(ctx: import("@earendil-works/pi-coding-agent").ExtensionContext) {
    if (!active) return;
    const usage = ctx.getContextUsage();
    const model = ctx.model;
    const used = usage?.tokens ?? 0;
    const win = model?.contextWindow ?? 200_000;
    const pct = win ? ((used / win) * 100).toFixed(0) : "?";

    const modelTag = model ? `${model.provider}/${model.id}` : "?";
    const b = bar(used, win);

    // Use a fresh context to keep the widget updated each turn
    ctx.ui.setWidget("pi-lens", [
      `🔎 ${modelTag}  T${turnCount}  ctx ${fmtTokens(used)}/${fmtTokens(win)} (${pct}%) ${b}`,
      lastTool
        ? `   last: ${lastTool}${lastToolStart ? ` (${Date.now() - lastToolStart}ms)` : ""}`
        : "",
    ]);
  }

  // ── event hooks for widget refresh ───────────────────────────────────

  pi.on("turn_end", (_event, ctx) => {
    if (active) updateWidget(ctx);
  });

  pi.on("agent_end", async (_event, ctx) => {
    // TLDR stop-hook: flash summary in widget + notify
    const elapsed = runStart > 0 ? ((Date.now() - runStart) / 1000).toFixed(1) : "?";
    const usage = ctx.getContextUsage();
    const parts: string[] = [`⚡ ${elapsed}s  ·  ${runToolCount} tools  ·  T${turnCount}`];
    if (usage?.tokens) parts.push(`ctx ${fmtTokens(usage.tokens)}`);
    if (runFilesRead.length) parts.push(`read ${runFilesRead.length}`);
    if (runFilesWritten.length) parts.push(`wrote ${runFilesWritten.length}`);
    if (runFilesEdited.length) parts.push(`edited ${runFilesEdited.length}`);
    const tldr = parts.join("  ");

    // Push into widget (always visible since pi-lens widget is active)
    const model = ctx.model;
    const modelTag = model ? `${model.provider}/${model.id}` : "?";
    ctx.ui.setWidget("pi-lens", [
      `🔎 ${modelTag}  T${turnCount}  ${tldr}`,
      "",
    ]);

    // Also notify
    await ctx.ui.notify(tldr, "info");

    // Reset to normal widget display after 3s
    setTimeout(() => {
      try { if (active) updateWidget(ctx); } catch { /* ctx stale */ }
    }, 3000);
  });

  pi.on("agent_settled", (_event, ctx) => {
    if (active) updateWidget(ctx);
  });
}