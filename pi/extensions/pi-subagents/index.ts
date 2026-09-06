/**
 * pi-subagents — Delegate tasks to specialized subagents.
 *
 * Spawns isolated `pi` processes per task so each agent gets its own
 * context window.  Three built-in agents come pre-configured:
 *
 *   reviewer   — Code review with severity ratings and suggestions
 *   architect  — System design, tradeoffs, and architecture decisions
 *   tester     — Generate test cases, edge cases, and test plans
 *
 * Add custom agents as markdown files in ~/.pi/agent/agents/:
 *
 *   ---
 *   name: my-agent
 *   description: what it does
 *   tools: read, bash, edit
 *   model: openrouter/anthropic/claude-sonnet  (optional)
 *   ---
 *   Agent system prompt here…
 *
 * Modes: single {agent, task}, parallel {tasks: [...]}, chain {chain: [...]}
 */

import { spawn } from "node:child_process";
import * as fs from "node:fs";
import * as os from "node:os";
import * as path from "node:path";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { Type } from "typebox";

// ---------------------------------------------------------------------------
// Built-in agents
// ---------------------------------------------------------------------------

const BUILTIN_AGENTS: Record<string, { description: string; systemPrompt: string; tools?: string[] }> = {
  reviewer: {
    description: "Code review with severity ratings and actionable suggestions",
    tools: ["read", "ls", "grep", "find"],
    systemPrompt: `You are a senior code reviewer. When given code or a task:

1. Identify issues by severity: 🔴 critical  🟡 warning  🔵 suggestion
2. For each issue explain: what is wrong, why it matters, and how to fix it
3. After listing issues, give a 1-3 sentence summary verdict
4. Praise good patterns you notice
5. Be concise — prefer bullet points over paragraphs

Focus on: correctness, security, performance, readability, and maintainability.`,
  },
  architect: {
    description: "System design, tradeoffs, and architecture decisions",
    tools: ["read", "ls", "grep", "find"],
    systemPrompt: `You are a systems architect. When given a design question:

1. Start with a 1-sentence recommendation
2. List 2-4 viable approaches with pros/cons for each
3. Explain your recommended approach in more detail
4. Note key tradeoffs: complexity, scalability, maintainability, cost
5. If applicable, sketch a component/data-flow outline
6. End with concrete next steps

Be pragmatic. Prefer simpler solutions unless complexity is justified.`,
  },
  tester: {
    description: "Generate test cases, edge cases, and test plans",
    tools: ["read", "ls", "grep", "find"],
    systemPrompt: `You are a QA engineer. When given code or a feature description:

1. Identify what needs testing (functions, modules, behaviors)
2. List happy-path test cases
3. List edge cases: nulls, empties, boundaries, concurrency, errors
4. List integration concerns if applicable
5. For each test case give: input, expected output/behavior, and why it matters
6. Suggest test framework/approach if relevant

Be thorough but organized. Group related tests together.`,
  },
};

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

const MAX_PARALLEL = 4;
const MAX_TASKS = 8;

// ---------------------------------------------------------------------------
// Agent discovery & frontmatter
// ---------------------------------------------------------------------------

interface AgentConfig {
  name: string;
  description: string;
  tools?: string[];
  model?: string;
  systemPrompt: string;
  source: "builtin" | "user";
}

function parseSimpleFrontmatter(content: string): Record<string, any> & { body: string } {
  const match = content.match(/^---\n([\s\S]*?)\n---\n?([\s\S]*)$/);
  if (!match) return { body: content };
  const yaml = match[1];
  const body = match[2].trim();
  const result: Record<string, any> = { body };
  for (const line of yaml.split("\n")) {
    const kv = line.match(/^(\w+):\s*(.+)$/);
    if (!kv) continue;
    const key = kv[1].trim();
    let val: any = kv[2].trim();
    if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'")))
      val = val.slice(1, -1);
    if (key === "tools")
      val = val.replace(/^\[|\]$/g, "").split(",").map((s: string) => s.trim()).filter(Boolean);
    result[key] = val;
  }
  return result;
}

function discoverAgents(): AgentConfig[] {
  const agents: AgentConfig[] = [];
  for (const [name, cfg] of Object.entries(BUILTIN_AGENTS)) {
    agents.push({ name, ...cfg, source: "builtin" });
  }
  const agentsDir = path.join(os.homedir(), ".pi", "agent", "agents");
  if (fs.existsSync(agentsDir)) {
    for (const entry of fs.readdirSync(agentsDir, { withFileTypes: true })) {
      if (!entry.name.endsWith(".md")) continue;
      if (!entry.isFile() && !entry.isSymbolicLink()) continue;
      try {
        const content = fs.readFileSync(path.join(agentsDir, entry.name), "utf-8");
        const fm = parseSimpleFrontmatter(content);
        if (fm.name && fm.description) {
          agents.push({
            name: fm.name,
            description: fm.description,
            tools: fm.tools,
            model: fm.model,
            systemPrompt: fm.body,
            source: "user",
          });
        }
      } catch { /* skip */ }
    }
  }
  return agents;
}

// ---------------------------------------------------------------------------
// Subagent runner
// ---------------------------------------------------------------------------

interface SubagentResult {
  agent: string;
  task: string;
  ok: boolean;
  output: string;
  usage: { input: number; output: number; cost: number; turns: number };
  model?: string;
  error?: string;
}

function spawnPi(
  cwd: string,
  task: string,
  systemPrompt: string,
  model: string | undefined,
  thinkingLevel: string | undefined,
  signal: AbortSignal | undefined,
): Promise<SubagentResult> {
  return new Promise((resolve) => {
    const tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "pi-sub-"));
    const promptPath = path.join(tmpDir, "prompt.md");
    fs.writeFileSync(promptPath, systemPrompt, "utf-8");

    const finalArgs = ["--mode", "json", "-p", "--no-session"];
    if (model) finalArgs.push("--model", model);
    if (thinkingLevel) finalArgs.push("--thinking", thinkingLevel);
    finalArgs.push("--append-system-prompt", promptPath);

    // Write the task via stdin so long tasks aren't limited by argv
    const proc = spawn("pi", finalArgs, {
      cwd,
      shell: false,
      stdio: ["pipe", "pipe", "pipe"],
    });

    proc.stdin.write(task);
    proc.stdin.end();

    const result: SubagentResult = {
      agent: "",
      task,
      ok: true,
      output: "",
      usage: { input: 0, output: 0, cost: 0, turns: 0 },
    };

    let buffer = "";
    let aborted = false;

    const processLine = (line: string) => {
      if (!line.trim()) return;
      try {
        const event = JSON.parse(line);
        if (event.type === "message_end" && event.message) {
          const msg = event.message;
          if (msg.role === "assistant") {
            result.usage.turns++;
            if (msg.usage) {
              result.usage.input += msg.usage.input || 0;
              result.usage.output += msg.usage.output || 0;
              result.usage.cost += msg.usage.cost?.total || 0;
            }
            if (!result.model && msg.model) result.model = msg.model;
            for (const part of msg.content) {
              if (part.type === "text") result.output = (result.output + "\n" + part.text).trim();
            }
          }
        }
      } catch { /* skip */ }
    };

    proc.stdout.on("data", (data: Buffer) => {
      buffer += data.toString();
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";
      for (const l of lines) processLine(l);
    });

    proc.on("close", (code: number | null) => {
      if (buffer.trim()) processLine(buffer);
      cleanup(tmpDir, promptPath);
      result.ok = code === 0 && !aborted;
      if (code !== 0 && !result.output) result.error = `exit code ${code}`;
      resolve(result);
    });

    proc.on("error", (err: Error) => {
      cleanup(tmpDir, promptPath);
      result.ok = false;
      result.error = err.message || "spawn failed";
      resolve(result);
    });

    if (signal) {
      const kill = () => { aborted = true; proc.kill("SIGTERM"); };
      signal.aborted ? kill() : signal.addEventListener("abort", kill, { once: true });
    }
  });
}

function cleanup(tmpDir: string, promptPath: string) {
  try { fs.unlinkSync(promptPath); } catch {}
  try { fs.rmdirSync(tmpDir); } catch {}
}

// ---------------------------------------------------------------------------
// Extension
// ---------------------------------------------------------------------------

export default function (pi: ExtensionAPI) {
  pi.registerTool({
    name: "subagent",
    label: "Subagent",
    description: [
      "Delegate tasks to specialized subagents with isolated context windows.",
      "Built-in agents: reviewer, architect, tester.",
      "Modes: single (agent + task), parallel (tasks array), chain (sequential, {previous} placeholder).",
      "Add custom agents in ~/.pi/agent/agents/*.md with YAML frontmatter.",
    ].join(" "),
    parameters: Type.Object({
      agent: Type.Optional(Type.String({ description: "Agent name for single mode" })),
      task: Type.Optional(Type.String({ description: "Task for single mode" })),
      tasks: Type.Optional(
        Type.Array(
          Type.Object({
            agent: Type.String(),
            task: Type.String(),
          }),
          { description: "Array for parallel execution" },
        ),
      ),
      chain: Type.Optional(
        Type.Array(
          Type.Object({
            agent: Type.String(),
            task: Type.String({ description: "Use {previous} for prior output" }),
          }),
          { description: "Array for sequential chained execution" },
        ),
      ),
    }),
    async execute(_toolCallId, params, signal, _onUpdate, ctx) {
      const agents = discoverAgents();
      const agentMap = new Map(agents.map((a) => [a.name, a]));
      const dispatchModel = ctx.model ? `${ctx.model.provider}/${ctx.model.id}` : undefined;

      const resolveAgent = (name: string) => {
        const a = agentMap.get(name);
        if (!a) {
          const list = agents.map((x) => x.name).join(", ") || "none";
          throw new Error(`Unknown agent "${name}". Available: ${list}`);
        }
        return a;
      };

      // ---- Single ----
      if (params.agent && params.task) {
        const agent = resolveAgent(params.agent);
        const r = await spawnPi(
          ctx.cwd, params.task, agent.systemPrompt,
          agent.model ?? dispatchModel, ctx.thinkingLevel, signal,
        );
        r.agent = agent.name;
        return {
          content: [{ type: "text", text: r.ok ? r.output : `Error: ${r.error || r.output}` }],
          details: { mode: "single", results: [r] },
          isError: !r.ok,
        };
      }

      // ---- Parallel ----
      if (params.tasks?.length) {
        if (params.tasks.length > MAX_TASKS) {
          return {
            content: [{ type: "text", text: `Too many tasks (${params.tasks.length}). Max: ${MAX_TASKS}` }],
            details: {},
          };
        }

        const results: SubagentResult[] = [];
        const queue = [...params.tasks];

        // Concurrency-limited worker pool
        const workers = Math.min(MAX_PARALLEL, queue.length);
        const workerFn = async (): Promise<void> => {
          while (queue.length) {
            const t = queue.shift()!;
            let agent: AgentConfig;
            try {
              agent = resolveAgent(t.agent);
            } catch (err: any) {
              results.push({ agent: t.agent, task: t.task, ok: false, output: "", usage: { input: 0, output: 0, cost: 0, turns: 0 }, error: err.message });
              continue;
            }
            const r = await spawnPi(
              ctx.cwd, t.task, agent.systemPrompt,
              agent.model ?? dispatchModel, ctx.thinkingLevel, signal,
            );
            r.agent = agent.name;
            results.push(r);
          }
        };

        await Promise.all(Array.from({ length: workers }, () => workerFn()));

        const okCount = results.filter((r) => r.ok).length;
        const text = results
          .map((r) => `### ${r.agent} ${r.ok ? "✓" : "✗"}\n${r.error ? `Error: ${r.error}\n` : ""}${r.output}`)
          .join("\n\n---\n\n");
        return {
          content: [{ type: "text", text: `Parallel: ${okCount}/${results.length} OK\n\n${text}` }],
          details: { mode: "parallel", results },
        };
      }

      // ---- Chain ----
      if (params.chain?.length) {
        const results: SubagentResult[] = [];
        let previous = "";
        for (const step of params.chain) {
          let agent: AgentConfig;
          try {
            agent = resolveAgent(step.agent);
          } catch (err: any) {
            return {
              content: [{ type: "text", text: err.message }],
              details: { mode: "chain", results },
              isError: true,
            };
          }
          const task = step.task.replace(/\{previous\}/g, previous || "(start)");
          const r = await spawnPi(
            ctx.cwd, task, agent.systemPrompt,
            agent.model ?? dispatchModel, ctx.thinkingLevel, signal,
          );
          r.agent = agent.name;
          results.push(r);
          if (!r.ok) {
            return {
              content: [{ type: "text", text: `Chain stopped at ${agent.name}: ${r.error || r.output}` }],
              details: { mode: "chain", results },
              isError: true,
            };
          }
          previous = r.output;
        }
        const last = results[results.length - 1];
        return {
          content: [{ type: "text", text: last.output }],
          details: { mode: "chain", results },
        };
      }

      return {
        content: [{ type: "text", text: `Provide agent+task, tasks array, or chain. Agents: ${agents.map((a) => a.name).join(", ")}` }],
        details: {},
      };
    },
  });

  pi.on("session_start", (_event, ctx) => {
    const agents = discoverAgents();
    ctx.ui.notify(`pi-subagents: ${agents.length} agents ready`, "info");
  });
}