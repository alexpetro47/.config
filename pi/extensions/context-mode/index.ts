/**
 * context-mode — Cycle through context density modes for pi.
 *
 * Adds `/context-mode` to toggle between:
 *   minimal  — only tool calls, no output (cleanest view)
 *   compact  — one-line summaries for tool results (DEFAULT)
 *   full     — complete tool output (pi default)
 *
 * Modes persist per session and affect all built-in tool renderers.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import {
  createBashTool,
  createEditTool,
  createFindTool,
  createGrepTool,
  createLsTool,
  createReadTool,
  createWriteTool,
} from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { homedir } from "os";

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

type ContextMode = "minimal" | "compact" | "full";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function shortenPath(path: string): string {
  const home = homedir();
  if (path.startsWith(home)) return `~${path.slice(home.length)}`;
  return path;
}

function countLines(text: string | undefined): number {
  if (!text) return 0;
  return text.trim().split("\n").filter(Boolean).length;
}

// Cache built-in tool creators keyed by cwd
const toolCache = new Map<string, ReturnType<typeof createBuiltInTools>>();

function createBuiltInTools(cwd: string) {
  return {
    read: createReadTool(cwd),
    bash: createBashTool(cwd),
    edit: createEditTool(cwd),
    write: createWriteTool(cwd),
    find: createFindTool(cwd),
    grep: createGrepTool(cwd),
    ls: createLsTool(cwd),
  };
}

function getBuiltInTools(cwd: string) {
  let tools = toolCache.get(cwd);
  if (!tools) {
    tools = createBuiltInTools(cwd);
    toolCache.set(cwd, tools);
  }
  return tools;
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  // Per-session mode state — reset on session_start
  let mode: ContextMode = "compact";

  // ── lifecycle ──────────────────────────────────────────────────────────

  pi.on("session_start", () => {
    mode = "compact";
  });

  // ── command ────────────────────────────────────────────────────────────

  pi.registerCommand("context-mode", {
    description: "Cycle context display mode: minimal | compact | full",
    handler: async (_args, ctx) => {
      const cycle: ContextMode[] = ["full", "compact", "minimal"];
      const idx = cycle.indexOf(mode);
      mode = cycle[(idx + 1) % cycle.length];
      ctx.ui.notify(`Context mode: ${mode}`, "info");
    },
  });

  // ── tool overrides ─────────────────────────────────────────────────────

  // ---- read --------------------------------------------------------------
  pi.registerTool({
    name: "read",
    label: "read",
    description:
      "Read the contents of a file. Supports text files and images (jpg, png, gif, webp). Images are sent as attachments. For text files, output is truncated to 2000 lines or 50KB (whichever is hit first). Use offset/limit for large files.",
    parameters: getBuiltInTools(process.cwd()).read.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const tools = getBuiltInTools(ctx.cwd);
      return tools.read.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      const path = shortenPath(args.path || "");
      let display = theme.fg("accent", path || "...");
      if (args.offset !== undefined || args.limit !== undefined) {
        const start = args.offset ?? 1;
        const end = args.limit !== undefined ? start + args.limit - 1 : "";
        display += theme.fg("warning", `:${start}${end ? `-${end}` : ""}`);
      }
      return new Text(`${theme.fg("toolTitle", theme.bold("read"))} ${display}`, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      if (mode === "minimal") return new Text("", 0, 0);
      const textContent = result.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);

      if (mode === "compact") {
        const lines = countLines(textContent.text);
        return new Text(theme.fg("muted", ` → ${lines} lines`), 0, 0);
      }

      // full — respect expanded toggle
      if (!expanded) return new Text("", 0, 0);
      const output = textContent.text
        .split("\n")
        .map((l) => theme.fg("toolOutput", l))
        .join("\n");
      return new Text(`\n${output}`, 0, 0);
    },
  });

  // ---- bash --------------------------------------------------------------
  pi.registerTool({
    name: "bash",
    label: "bash",
    description:
      "Execute a bash command in the current working directory. Returns stdout and stderr. Output is truncated to last 2000 lines or 50KB (whichever is hit first).",
    parameters: getBuiltInTools(process.cwd()).bash.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const tools = getBuiltInTools(ctx.cwd);
      return tools.bash.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      const cmd = args.command || "...";
      const timeout = args.timeout
        ? theme.fg("muted", ` (timeout ${args.timeout}s)`)
        : "";
      return new Text(theme.fg("toolTitle", theme.bold(`$ ${cmd}`)) + timeout, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      if (mode === "minimal") return new Text("", 0, 0);
      const textContent = result.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);

      if (mode === "compact") {
        const lines = countLines(textContent.text);
        if (lines === 0) return new Text("", 0, 0);
        return new Text(theme.fg("muted", ` → ${lines} lines`), 0, 0);
      }

      if (!expanded) return new Text("", 0, 0);
      const output = textContent.text
        .trim()
        .split("\n")
        .map((l) => theme.fg("toolOutput", l))
        .join("\n");
      if (!output) return new Text("", 0, 0);
      return new Text(`\n${output}`, 0, 0);
    },
  });

  // ---- write -------------------------------------------------------------
  pi.registerTool({
    name: "write",
    label: "write",
    description:
      "Write content to a file. Creates the file if it doesn't exist, overwrites if it does. Automatically creates parent directories.",
    parameters: getBuiltInTools(process.cwd()).write.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const tools = getBuiltInTools(ctx.cwd);
      return tools.write.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      const path = shortenPath(args.path || "");
      const lc = args.content ? args.content.split("\n").length : 0;
      return new Text(
        `${theme.fg("toolTitle", theme.bold("write"))} ${theme.fg("accent", path || "...")}${lc ? theme.fg("muted", ` (${lc} lines)`) : ""}`,
        0,
        0,
      );
    },

    renderResult(result, { expanded }, theme, _context) {
      if (mode === "minimal") return new Text("", 0, 0);
      if (mode === "compact") return new Text("", 0, 0); // just the call line
      // full
      if (!expanded) return new Text("", 0, 0);
      const textContent = result.content.find((c) => c.type === "text");
      if (textContent?.type === "text" && textContent.text)
        return new Text(`\n${theme.fg("error", textContent.text)}`, 0, 0);
      return new Text("", 0, 0);
    },
  });

  // ---- edit --------------------------------------------------------------
  pi.registerTool({
    name: "edit",
    label: "edit",
    description:
      "Edit a file by replacing exact text. The oldText must match exactly (including whitespace). Use this for precise, surgical edits.",
    parameters: getBuiltInTools(process.cwd()).edit.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const tools = getBuiltInTools(ctx.cwd);
      return tools.edit.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      const path = shortenPath(args.path || "");
      return new Text(`${theme.fg("toolTitle", theme.bold("edit"))} ${theme.fg("accent", path || "...")}`, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      if (mode === "minimal") return new Text("", 0, 0);
      if (mode === "compact") return new Text("", 0, 0); // call line self-documents
      // full
      if (!expanded) return new Text("", 0, 0);
      const textContent = result.content.find((c) => c.type === "text");
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);
      const txt = textContent.text;
      if (txt.includes("rror"))
        return new Text(`\n${theme.fg("error", txt)}`, 0, 0);
      return new Text(`\n${theme.fg("toolOutput", txt)}`, 0, 0);
    },
  });

  // ---- find --------------------------------------------------------------
  pi.registerTool({
    name: "find",
    label: "find",
    description:
      "Find files by name pattern (glob). Searches recursively from the specified path. Output limited to 200 results.",
    parameters: getBuiltInTools(process.cwd()).find.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const tools = getBuiltInTools(ctx.cwd);
      return tools.find.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      const pattern = args.pattern || "";
      const path = shortenPath(args.path || ".");
      let text = `${theme.fg("toolTitle", theme.bold("find"))} ${theme.fg("accent", pattern)} in ${theme.fg("toolOutput", path)}`;
      if (args.limit !== undefined) text += theme.fg("toolOutput", ` (limit ${args.limit})`);
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      const textContent = result.content.find((c) => c.type === "text");
      const count = textContent?.type === "text" ? countLines(textContent.text) : 0;

      if (mode === "minimal") return new Text("", 0, 0);
      if (mode === "compact")
        return new Text(theme.fg("muted", count ? ` → ${count} files` : ""), 0, 0);
      if (!expanded) return new Text("", 0, 0);
      // full
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);
      const output = textContent.text
        .trim()
        .split("\n")
        .map((l) => theme.fg("toolOutput", l))
        .join("\n");
      return new Text(`\n${output}`, 0, 0);
    },
  });

  // ---- grep --------------------------------------------------------------
  pi.registerTool({
    name: "grep",
    label: "grep",
    description:
      "Search file contents by regex pattern. Uses ripgrep for fast searching. Output limited to 200 matches.",
    parameters: getBuiltInTools(process.cwd()).grep.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const tools = getBuiltInTools(ctx.cwd);
      return tools.grep.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      const pattern = args.pattern || "";
      const path = shortenPath(args.path || ".");
      let text = `${theme.fg("toolTitle", theme.bold("grep"))} ${theme.fg("accent", `/${pattern}/`)} in ${theme.fg("toolOutput", path)}`;
      if (args.glob) text += theme.fg("toolOutput", ` (${args.glob})`);
      if (args.limit !== undefined) text += theme.fg("toolOutput", ` limit ${args.limit}`);
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      const textContent = result.content.find((c) => c.type === "text");
      const count = textContent?.type === "text" ? countLines(textContent.text) : 0;

      if (mode === "minimal") return new Text("", 0, 0);
      if (mode === "compact")
        return new Text(theme.fg("muted", count ? ` → ${count} matches` : ""), 0, 0);
      if (!expanded) return new Text("", 0, 0);
      // full
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);
      const output = textContent.text
        .trim()
        .split("\n")
        .map((l) => theme.fg("toolOutput", l))
        .join("\n");
      return new Text(`\n${output}`, 0, 0);
    },
  });

  // ---- ls ----------------------------------------------------------------
  pi.registerTool({
    name: "ls",
    label: "ls",
    description:
      "List directory contents with file sizes. Shows files and directories with their sizes. Output limited to 500 entries.",
    parameters: getBuiltInTools(process.cwd()).ls.parameters,

    async execute(toolCallId, params, signal, onUpdate, ctx) {
      const tools = getBuiltInTools(ctx.cwd);
      return tools.ls.execute(toolCallId, params, signal, onUpdate);
    },

    renderCall(args, theme, _context) {
      const path = shortenPath(args.path || ".");
      let text = `${theme.fg("toolTitle", theme.bold("ls"))} ${theme.fg("accent", path)}`;
      if (args.limit !== undefined) text += theme.fg("toolOutput", ` (limit ${args.limit})`);
      return new Text(text, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      const textContent = result.content.find((c) => c.type === "text");
      const count = textContent?.type === "text" ? countLines(textContent.text) : 0;

      if (mode === "minimal") return new Text("", 0, 0);
      if (mode === "compact")
        return new Text(theme.fg("muted", count ? ` → ${count} entries` : ""), 0, 0);
      if (!expanded) return new Text("", 0, 0);
      // full
      if (!textContent || textContent.type !== "text") return new Text("", 0, 0);
      const output = textContent.text
        .trim()
        .split("\n")
        .map((l) => theme.fg("toolOutput", l))
        .join("\n");
      return new Text(`\n${output}`, 0, 0);
    },
  });
}