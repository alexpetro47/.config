/**
 * pi-web-access — Web search and fetch tools for pi.
 *
 * Tools:
 *   web_search  — Search DuckDuckGo (Lite) and return results
 *   web_fetch   — Fetch a URL and return text content (with HTML→text)
 *
 * No API keys, no dependencies. Uses DDG Lite HTML scraping + native fetch.
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Text } from "@earendil-works/pi-tui";
import { Type } from "typebox";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/** Strip HTML tags into plain text */
function stripHtml(html: string): string {
  return html
    .replace(/<br\s*\/?>/gi, "\n")
    .replace(/<\/p>/gi, "\n")
    .replace(/<li>/gi, "\n• ")
    .replace(/<\/li>/gi, "")
    .replace(/<[^>]+>/g, "")
    .replace(/&amp;/g, "&")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&quot;/g, '"')
    .replace(/&#x27;/g, "'")
    .replace(/&#39;/g, "'")
    .replace(/&nbsp;/g, " ")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
}

// ---------------------------------------------------------------------------
// DDG Lite search
// ---------------------------------------------------------------------------

interface SearchResult {
  title: string;
  snippet: string;
  url: string;
}

/** Extract real URL from DDG redirect like //duckduckgo.com/l/?uddg=ENCODED_URL&rut=... */
function decodeDDGUrl(href: string): string {
  // Normalize protocol-relative
  const full = href.startsWith("//") ? `https:${href}` : href;
  try {
    const u = new URL(full);
    const uddg = u.searchParams.get("uddg");
    if (uddg) return decodeURIComponent(uddg);
  } catch {}
  return href;
}

async function searchDDG(query: string, maxResults = 10): Promise<SearchResult[]> {
  const url =
    "https://lite.duckduckgo.com/lite/?" +
    new URLSearchParams({ q: query });

  const resp = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    },
    signal: AbortSignal.timeout(10_000),
  });

  if (!resp.ok) throw new Error(`DDG returned ${resp.status}`);
  const html = await resp.text();

  // DDG Lite structure per result:
  //   <a class='result-link' href="//duckduckgo.com/l/?uddg=...">TITLE</a>
  //   ...
  //   <td class='result-snippet'>SNIPPET</td>
  //   ...
  //   <span class='link-text'>display-url</span>

  const results: SearchResult[] = [];

  // Extract all result-link anchors
  const linkRe = /<a[^>]*class=['"]result-link['"][^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/gi;
  const links: { href: string; title: string }[] = [];
  let m: RegExpExecArray | null;
  while ((m = linkRe.exec(html)) !== null) {
    links.push({
      href: decodeDDGUrl(m[1]),
      title: stripHtml(m[2]),
    });
  }

  // Extract all result-snippet cells
  const snippetRe = /<td[^>]*class=['"]result-snippet['"][^>]*>([\s\S]*?)<\/td>/gi;
  const snippets: string[] = [];
  while ((m = snippetRe.exec(html)) !== null) {
    snippets.push(stripHtml(m[1]).replace(/\s+/g, " ").trim());
  }

  // Zip them together
  for (let i = 0; i < Math.min(links.length, snippets.length, maxResults); i++) {
    if (links[i].title && links[i].href) {
      results.push({
        title: links[i].title,
        url: links[i].href,
        snippet: snippets[i] || "",
      });
    }
  }

  return results;
}

// ---------------------------------------------------------------------------
// Web fetch
// ---------------------------------------------------------------------------

async function fetchPage(url: string, maxChars = 8000): Promise<string> {
  const resp = await fetch(url, {
    headers: {
      "User-Agent":
        "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "Accept": "text/html,*/*",
    },
    signal: AbortSignal.timeout(15_000),
    redirect: "follow",
  });

  if (!resp.ok) throw new Error(`HTTP ${resp.status}`);
  const contentType = resp.headers.get("content-type") || "";
  if (!contentType.includes("text/html") && !contentType.includes("text/plain")) {
    throw new Error(`Cannot fetch non-text content: ${contentType}`);
  }

  const html = await resp.text();
  const text = stripHtml(html);

  // Remove excessive whitespace lines
  const lines = text.split("\n").filter((l) => l.trim().length > 0);
  let result = lines.join("\n");

  // Truncate
  if (result.length > maxChars) {
    result = result.slice(0, maxChars) + `\n\n[... truncated at ${maxChars} chars]`;
  }

  return result;
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  // ── web_search ────────────────────────────────────────────────────────

  pi.registerTool({
    name: "web_search",
    label: "Web Search",
    description:
      "Search the web using DuckDuckGo (Lite). Returns titles, URLs, and snippets for each result. Use this to find current information, documentation, or answers to questions. Max 10 results.",
    parameters: Type.Object({
      query: Type.String({ description: "Search query" }),
      maxResults: Type.Optional(
        Type.Number({ description: "Max results to return (default 5, max 10)" }),
      ),
    }),

    renderCall(args, theme, _context) {
      const q = (args.query as string) || "...";
      const display = q.length > 40 ? q.slice(0, 40) + "…" : q;
      return new Text(`${theme.fg("toolTitle", theme.bold("web_search"))} ${theme.fg("accent", display)}`, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      // Always return a Text node — never undefined/null
      const textContent = result.content?.find?.((c: any) => c.type === "text");
      const text = textContent?.text ?? "";
      if (!text) return new Text("", 0, 0);

      if (!expanded) {
        const n = (text.match(/\n\n/g) || []).length + 1;
        return new Text(theme.fg("muted", ` → ${n} results`), 0, 0);
      }

      const output = text
        .split("\n")
        .map((l: string) => {
          if (l.startsWith("##")) return theme.fg("toolTitle", l);
          if (l.match(/^\d+\./)) return theme.fg("accent", l);
          if (l.startsWith("   http")) return theme.fg("muted", l);
          return theme.fg("toolOutput", l);
        })
        .join("\n");
      return new Text(`\n${output}`, 0, 0);
    },

    async execute(_toolCallId, params, _signal, onUpdate, _ctx) {
      const query = params.query;
      const max = Math.min(params.maxResults ?? 5, 10);

      if (onUpdate) onUpdate({ type: "status", text: `Searching: "${query}"…` });

      const results = await searchDDG(query, max);

      if (results.length === 0) {
        return {
          content: [{ type: "text", text: `No results found for "${query}".` }],
          details: { query, resultCount: 0 },
        };
      }

      const formatted = results
        .map(
          (r, i) =>
            `${i + 1}. ${r.title}\n   ${r.url}\n   ${r.snippet}`,
        )
        .join("\n\n");

      return {
        content: [
          {
            type: "text",
            text: `## Web Search: "${query}"\n\n${formatted}`,
          },
        ],
        details: { query, resultCount: results.length },
      };
    },
  });

  // ── web_fetch ──────────────────────────────────────────────────────────

  pi.registerTool({
    name: "web_fetch",
    label: "Web fetch",
    description:
      "Fetch the full text content of a web page. Strips HTML and returns plain text (max ~8000 chars). Use after web_search to read a specific page in detail. Works with most web pages.",
    parameters: Type.Object({
      url: Type.String({ description: "URL to fetch" }),
      maxChars: Type.Optional(
        Type.Number({ description: "Max characters to return (default 8000)" }),
      ),
    }),

    renderCall(args, theme, _context) {
      const u = (args.url as string) || "...";
      // Shorten common prefix noise
      const short = u.replace(/^https?:\/\/(www\.)?/, "");
      const display = short.length > 50 ? short.slice(0, 50) + "…" : short;
      return new Text(`${theme.fg("toolTitle", theme.bold("web_fetch"))} ${theme.fg("accent", display)}`, 0, 0);
    },

    renderResult(result, { expanded }, theme, _context) {
      const textContent = result.content?.find?.((c: any) => c.type === "text");
      const text = textContent?.text ?? "";
      if (!text) return new Text("", 0, 0);

      if (!expanded) {
        // Preview: show just the title line + first 80 chars
        const preview = text.replace(/^## .*\n*/, "").slice(0, 80).replace(/\n/g, " ");
        return new Text(theme.fg("muted", ` → ${preview}…`), 0, 0);
      }

      const output = text
        .split("\n")
        .map((l: string) => {
          if (l.startsWith("##")) return theme.fg("toolTitle", l);
          if (l.startsWith("[...")) return theme.fg("warning", l);
          return theme.fg("toolOutput", l);
        })
        .join("\n");
      return new Text(`\n${output}`, 0, 0);
    },

    async execute(_toolCallId, params, _signal, onUpdate, _ctx) {
      const url = params.url.trim();
      if (!url.startsWith("http://") && !url.startsWith("https://")) {
        return {
          content: [{ type: "text", text: `Invalid URL: "${url}". Must start with http:// or https://` }],
          details: {},
          isError: true,
        };
      }

      if (onUpdate) onUpdate({ type: "status", text: `Fetching: ${url}` });

      try {
        const text = await fetchPage(url, params.maxChars ?? 8000);
        return {
          content: [
            { type: "text", text: `## ${url}\n\n${text}` },
          ],
          details: { url, charCount: text.length },
        };
      } catch (err: any) {
        return {
          content: [
            { type: "text", text: `Failed to fetch "${url}": ${err.message}` },
          ],
          details: {},
          isError: true,
        };
      }
    },
  });

  // ── notify on load ────────────────────────────────────────────────────

  pi.on("session_start", (_event, ctx) => {
    ctx.ui.notify("pi-web-access: web_search + web_fetch ready", "info");
  });
}