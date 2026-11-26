/**
 * Pi extension adapter for the dev-team plugin.
 * Delegates session context and bash guards to plugins/dev-team/hooks/*.sh and
 * registers the run_agent tool over pi, claude, and agy backends.
 */
import { spawn } from "node:child_process";
import type { ChildProcess } from "node:child_process";
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import type { TSchema } from "typebox";

const EXTENSION_PATH = fileURLToPath(import.meta.url);
const DEFAULT_PLUGIN_ROOT = path.resolve(path.dirname(EXTENSION_PATH), "..");

const REVIEW_GATES_LIST = [
  "pr-reviewer",
  "code-health-reviewer",
  "oss-readiness-reviewer",
  "security-reviewer",
  "readme-reviewer",
] as const;

const CANONICAL_AGENTS = ["implementer", ...REVIEW_GATES_LIST, "cold-reader"] as const;
type CanonicalAgent = (typeof CANONICAL_AGENTS)[number];

const REVIEW_GATES: ReadonlySet<string> = new Set(REVIEW_GATES_LIST);
const READ_ONLY_AGENTS: ReadonlySet<string> = new Set([...REVIEW_GATES_LIST, "cold-reader"]);

const BACKENDS = ["pi", "claude", "agy"] as const;
type Backend = (typeof BACKENDS)[number];

const CLAUDE_MODEL_ALIASES: ReadonlySet<string> = new Set(["sonnet", "opus", "fable"]);
const WRITE_TOOLS_CLAUDE: ReadonlySet<string> = new Set(["Edit", "MultiEdit", "Write"]);

const PI_TOOL_MAP: Readonly<Record<string, readonly string[]>> = {
  Read: ["read"],
  Glob: ["find", "ls"],
  Grep: ["grep"],
  Bash: ["bash"],
  Edit: ["edit"],
  MultiEdit: ["edit"],
  Write: ["write"],
};

const HOOK_TIMEOUT_MS = 10_000;
const MERGE_GATE_TIMEOUT_MS = 60_000;
const DEFAULT_AGENT_TIMEOUT_SECONDS = 600;
const MAX_AGENT_TIMEOUT_SECONDS = 3_600;
const MAX_OUTPUT_BYTES = 4 * 1024 * 1024;

const SELF_CHECK_BANNER =
  '[SELF-CHECK ONLY — NON-AUTHORITATIVE: ran via local pi backend. Do NOT record in gate-ledger; re-run with backend="claude" or backend="agy" for authoritative merge-gate verdicts.]';

const RUN_AGENT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["agent", "prompt"],
  properties: {
    agent: {
      type: "string",
      enum: [...CANONICAL_AGENTS],
      description: "Canonical dev-team agent name from plugins/dev-team/agents/*.md.",
    },
    backend: {
      type: "string",
      enum: [...BACKENDS],
      description:
        'Execution backend ("pi", "claude", or "agy"). Required for review-gate agents; defaults to "pi" for implementer and cold-reader.',
    },
    prompt: {
      type: "string",
      description: "Task brief for the subagent.",
    },
    cwd: {
      type: "string",
      description: "Working directory for the subagent (defaults to the session cwd).",
    },
    model: {
      type: "string",
      description: 'Optional model override. For backend "claude", alias-only ("sonnet", "opus", "fable").',
    },
    timeoutSeconds: {
      type: "number",
      description: `Execution timeout in seconds (default ${DEFAULT_AGENT_TIMEOUT_SECONDS}, max ${MAX_AGENT_TIMEOUT_SECONDS}).`,
    },
  },
} as const;

interface ExtensionOptions {
  pluginRoot?: string;
}

interface CommandResult {
  exitCode: number | null;
  stdout: string;
  stderr: string;
  timedOut: boolean;
  aborted: boolean;
  errorCode?: string;
  errorMessage?: string;
}

interface AgentDefinition {
  tools: string[];
  model?: string;
  skills: string[];
  body: string;
}

interface RunAgentParams {
  agent?: unknown;
  backend?: unknown;
  prompt?: unknown;
  cwd?: unknown;
  model?: unknown;
  timeoutSeconds?: unknown;
}

interface ValidatedRunAgentParams {
  agent: CanonicalAgent;
  backend: Backend;
  prompt: string;
  workDir: string;
  model?: string;
  timeoutSeconds: number;
}

interface RunAgentDetails {
  agent: CanonicalAgent;
  backend: Backend;
  authoritative: boolean;
  exitCode: number;
  verdictValid?: boolean;
  verdictError?: string;
}

interface VerdictResult {
  verdictValid: boolean;
  verdictError?: string;
}

function isExecutableFile(filePath: string): boolean {
  try {
    if (!fs.statSync(filePath).isFile()) return false;
    fs.accessSync(filePath, fs.constants.X_OK);
    return true;
  } catch {
    return false;
  }
}

function hasJqOnPath(pathEnv: string | undefined): boolean {
  for (const dir of (pathEnv ?? "").split(path.delimiter)) {
    if (dir && isExecutableFile(path.join(dir, "jq"))) return true;
  }
  return false;
}

function collectStream(stream: NodeJS.ReadableStream | null): () => string {
  const chunks: Buffer[] = [];
  let bytes = 0;
  stream?.on("data", (chunk: Buffer) => {
    if (bytes >= MAX_OUTPUT_BYTES) return;
    const slice = bytes + chunk.length > MAX_OUTPUT_BYTES ? chunk.subarray(0, MAX_OUTPUT_BYTES - bytes) : chunk;
    chunks.push(slice);
    bytes += slice.length;
  });
  return () => Buffer.concat(chunks).toString("utf8");
}

interface RunCommandOptions {
  cwd?: string;
  env: NodeJS.ProcessEnv;
  stdin?: string;
  timeoutMs: number;
  signal?: AbortSignal;
}

function killProcessTree(child: ChildProcess, sig: NodeJS.Signals): void {
  try {
    if (process.platform !== "win32" && child.pid) process.kill(-child.pid, sig);
    else child.kill(sig);
  } catch {}
}

function runCommand(command: string, args: string[], options: RunCommandOptions): Promise<CommandResult> {
  if (options.signal?.aborted) {
    return Promise.resolve({ exitCode: null, stdout: "", stderr: "", timedOut: false, aborted: true });
  }

  return new Promise((resolve) => {
    const child = spawn(command, args, {
      cwd: options.cwd,
      env: options.env,
      detached: process.platform !== "win32",
      stdio: [options.stdin !== undefined ? "pipe" : "ignore", "pipe", "pipe"],
    });
    const readStdout = collectStream(child.stdout);
    const readStderr = collectStream(child.stderr);
    let timedOut = false;
    let aborted = false;
    let settled = false;
    let killTimer: ReturnType<typeof setTimeout> | undefined;

    const terminate = (): void => {
      if (killTimer) return;
      clearTimeout(timeoutHandle);
      options.signal?.removeEventListener("abort", onAbort);
      killProcessTree(child, "SIGTERM");
      killTimer = setTimeout(() => killProcessTree(child, "SIGKILL"), 2_000);
      killTimer.unref?.();
    };

    const finish = (exitCode: number | null, err?: NodeJS.ErrnoException): void => {
      if (settled) return;
      settled = true;
      clearTimeout(timeoutHandle);
      if (killTimer) clearTimeout(killTimer);
      options.signal?.removeEventListener("abort", onAbort);
      const base = { exitCode, stdout: readStdout(), stderr: readStderr(), timedOut, aborted };
      resolve(err ? { ...base, errorCode: err.code, errorMessage: err.message } : base);
    };

    const onAbort = (): void => {
      if (killTimer) return;
      aborted = true;
      terminate();
    };
    options.signal?.addEventListener("abort", onAbort, { once: true });

    const timeoutHandle = setTimeout(() => {
      if (killTimer) return;
      timedOut = true;
      terminate();
    }, options.timeoutMs);
    timeoutHandle.unref?.();

    child.on("error", (err: NodeJS.ErrnoException) => finish(null, err));
    child.on("close", (code) => finish(code));
    if (options.stdin !== undefined && child.stdin) {
      child.stdin.on("error", () => {});
      child.stdin.end(options.stdin);
    }
  });
}

function parseAgentFile(raw: string, pluginRoot: string): AgentDefinition {
  const normalized = raw.replace(/\r\n/g, "\n");
  const match = /^---\n([\s\S]*?)\n---\n?([\s\S]*)$/.exec(normalized);
  const frontmatter = match ? match[1] : "";
  const body = (match ? match[2] : normalized).replaceAll("${CLAUDE_PLUGIN_ROOT}", pluginRoot);

  const scalars = new Map<string, string>();
  const lists = new Map<string, string[]>();
  let currentListKey: string | undefined;

  for (const line of frontmatter.split("\n")) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;

    if (currentListKey && trimmed.startsWith("- ")) {
      lists.get(currentListKey)?.push(trimmed.slice(2).trim().replace(/^['"]|['"]$/g, ""));
      continue;
    }

    currentListKey = undefined;
    const colon = line.indexOf(":");
    if (colon === -1) continue;

    const key = line.slice(0, colon).trim();
    const val = line.slice(colon + 1).trim();
    if (!val) {
      lists.set(key, []);
      currentListKey = key;
    } else {
      scalars.set(key, val.replace(/^['"]|['"]$/g, ""));
    }
  }

  const toolsRaw = lists.get("tools") ?? (scalars.get("tools") ? scalars.get("tools")!.split(",") : []);
  const skillsRaw = lists.get("skills") ?? (scalars.get("skills") ? scalars.get("skills")!.split(",") : []);
  return {
    tools: toolsRaw.map((t) => t.trim()).filter(Boolean),
    model: scalars.get("model")?.trim() || undefined,
    skills: skillsRaw.map((s) => s.trim()).filter(Boolean),
    body,
  };
}

function mapPiTools(agent: CanonicalAgent, canonicalTools: string[]): string[] {
  const mapped: string[] = [];
  const seen = new Set<string>();
  const isReadOnly = READ_ONLY_AGENTS.has(agent);

  for (const tool of canonicalTools) {
    for (const piTool of PI_TOOL_MAP[tool] ?? []) {
      if (isReadOnly && (piTool === "edit" || piTool === "write")) continue;
      if (agent === "cold-reader" && piTool === "bash") continue;
      if (!seen.has(piTool)) {
        seen.add(piTool);
        mapped.push(piTool);
      }
    }
  }
  return mapped;
}

function extractHookReason(hookName: string, result: CommandResult): string {
  try {
    const parsed = JSON.parse(result.stdout) as {
      hookSpecificOutput?: { permissionDecisionReason?: unknown };
    };
    const reason = parsed?.hookSpecificOutput?.permissionDecisionReason;
    if (typeof reason === "string" && reason.trim()) return reason.trim();
  } catch {}
  return result.stderr.trim() || result.stdout.trim() || `blocked by ${hookName}`;
}

function validateRunAgentParams(rawParams: unknown, defaultCwd: string): ValidatedRunAgentParams {
  const params = (rawParams ?? {}) as RunAgentParams;
  if (typeof params.agent !== "string" || !(CANONICAL_AGENTS as readonly string[]).includes(params.agent)) {
    throw new Error(
      `run_agent: unknown agent "${String(params.agent ?? "")}". Expected one of: ${CANONICAL_AGENTS.join(", ")}.`,
    );
  }
  const agent = params.agent as CanonicalAgent;

  let backend: Backend;
  if (params.backend === undefined) {
    if (REVIEW_GATES.has(agent)) {
      throw new Error(
        `run_agent: backend is required for review-gate agent "${agent}" (use "claude" or "agy" for authoritative verdicts, or "pi" for a non-authoritative self-check).`,
      );
    }
    backend = "pi";
  } else if (typeof params.backend === "string" && (BACKENDS as readonly string[]).includes(params.backend)) {
    backend = params.backend as Backend;
  } else {
    throw new Error(`run_agent: unknown backend "${String(params.backend)}". Expected one of: ${BACKENDS.join(", ")}.`);
  }

  if (typeof params.prompt !== "string" || params.prompt.trim().length === 0) {
    throw new Error("run_agent: prompt must be a non-empty string.");
  }

  const workDir = params.cwd === undefined ? defaultCwd : params.cwd;
  if (typeof workDir !== "string" || !workDir.trim()) {
    throw new Error("run_agent: cwd must be an existing directory path.");
  }
  let stat: fs.Stats;
  try {
    stat = fs.statSync(workDir);
  } catch {
    throw new Error(`run_agent: cwd does not exist: ${workDir}`);
  }
  if (!stat.isDirectory()) throw new Error(`run_agent: cwd is not a directory: ${workDir}`);

  let model: string | undefined;
  if (params.model !== undefined) {
    if (typeof params.model !== "string" || !params.model.trim()) {
      throw new Error("run_agent: model must be a non-empty string when provided.");
    }
    const trimmedModel = params.model.trim();
    if (trimmedModel.startsWith("-") || /[\s\0]/.test(trimmedModel)) {
      throw new Error(`run_agent: invalid model "${trimmedModel}" (must not start with "-" or contain whitespace).`);
    }
    model = trimmedModel;
  }

  const timeoutSeconds = params.timeoutSeconds ?? DEFAULT_AGENT_TIMEOUT_SECONDS;
  if (typeof timeoutSeconds !== "number" || !Number.isFinite(timeoutSeconds) || timeoutSeconds <= 0 || timeoutSeconds > MAX_AGENT_TIMEOUT_SECONDS) {
    throw new Error(`run_agent: timeoutSeconds must be a finite number > 0 and <= ${MAX_AGENT_TIMEOUT_SECONDS}.`);
  }

  return { agent, backend, prompt: params.prompt.trim(), workDir, model, timeoutSeconds };
}

function assembleAgentPrompt(pluginRoot: string, agentDef: AgentDefinition, prompt: string): string {
  const sections = [`Plugin root (CLAUDE_PLUGIN_ROOT): ${pluginRoot}`];
  if (agentDef.skills.length > 0) {
    const skillPaths = agentDef.skills.map((skill) => path.join(pluginRoot, "skills", skill, "SKILL.md"));
    sections.push(`Preloaded skill(s): read ${skillPaths.join(", ")} before starting.`);
  }
  sections.push(agentDef.body.trim(), `## Task\n\n${prompt}`);
  return sections.join("\n\n");
}

function buildClaudeInvocation(
  params: ValidatedRunAgentParams,
  agentDef: AgentDefinition,
  assembledPrompt: string,
): { binary: string; args: string[]; stdin: string } {
  const resolvedModel = params.model ?? agentDef.model;
  if (!resolvedModel || !CLAUDE_MODEL_ALIASES.has(resolvedModel)) {
    throw new Error(
      `run_agent (claude): model must be an alias ("sonnet", "opus", or "fable"), got "${resolvedModel ?? ""}".`,
    );
  }
  if (params.agent === "security-reviewer" && resolvedModel !== "opus") {
    throw new Error(`run_agent (claude): security-reviewer requires model "opus" (got "${resolvedModel}").`);
  }
  if (params.agent !== "cold-reader" && resolvedModel === "fable") {
    throw new Error(`run_agent (claude): model "fable" is only allowed for cold-reader (got "${params.agent}").`);
  }
  const claudeTools = READ_ONLY_AGENTS.has(params.agent)
    ? agentDef.tools.filter((t) => !WRITE_TOOLS_CLAUDE.has(t))
    : agentDef.tools;
  return {
    binary: "claude",
    args: ["-p", "--model", resolvedModel, ...(claudeTools.length > 0 ? ["--tools", claudeTools.join(",")] : [])],
    stdin: assembledPrompt,
  };
}

function buildBackendInvocation(
  params: ValidatedRunAgentParams,
  agentDef: AgentDefinition,
  assembledPrompt: string,
): { binary: string; args: string[]; stdin?: string } {
  if (params.backend === "claude") {
    return buildClaudeInvocation(params, agentDef, assembledPrompt);
  }
  if (params.backend === "agy") {
    return {
      binary: "agy",
      args: [
        "--mode",
        READ_ONLY_AGENTS.has(params.agent) ? "plan" : "auto",
        "--disable-slash-commands",
        "--print-timeout",
        `${Math.ceil(params.timeoutSeconds)}s`,
        ...(params.model ? ["--model", params.model] : []),
        `--print=${assembledPrompt}`,
      ],
    };
  }
  const piTools = mapPiTools(params.agent, agentDef.tools);
  return {
    binary: "pi",
    args: [
      "--print",
      "--no-session",
      "--no-extensions",
      "-e",
      EXTENSION_PATH,
      "--tools",
      piTools.join(","),
      "--exclude-tools",
      "run_agent",
      ...(params.model ? ["--model", params.model] : []),
      "--",
      "Follow the agent instructions and task provided on stdin.",
    ],
    stdin: assembledPrompt,
  };
}

async function validateGateVerdict(
  agent: CanonicalAgent,
  stdout: string,
  pluginRoot: string,
  workDir: string,
  env: NodeJS.ProcessEnv,
): Promise<VerdictResult> {
  if (!stdout.trim()) {
    return { verdictValid: false, verdictError: "verdict-guard: review gate produced empty output with no verdict block." };
  }
  if (!hasJqOnPath(env.PATH)) {
    return { verdictValid: false, verdictError: "verdict-guard: jq is required on PATH to validate review-gate verdicts." };
  }
  const guardPath = path.join(pluginRoot, "hooks", "verdict-guard.sh");
  const guardRes = await runCommand(guardPath, [], {
    cwd: workDir,
    env,
    stdin: JSON.stringify({ agent_type: agent, stop_hook_active: false, last_assistant_message: stdout }),
    timeoutMs: HOOK_TIMEOUT_MS,
  });
  if (guardRes.errorCode || guardRes.timedOut) {
    return {
      verdictValid: false,
      verdictError: guardRes.timedOut
        ? "verdict-guard timed out."
        : `verdict-guard failed to run: ${guardRes.errorMessage ?? guardRes.errorCode}`,
    };
  }
  if (guardRes.exitCode === 0) return { verdictValid: true };
  return {
    verdictValid: false,
    verdictError:
      guardRes.stderr.trim() || guardRes.stdout.trim() || `verdict-guard exited with code ${guardRes.exitCode}`,
  };
}

function formatRunAgentResult(
  params: ValidatedRunAgentParams,
  binary: string,
  res: CommandResult,
  verdict: VerdictResult | undefined,
): { content: [{ type: "text"; text: string }]; details: RunAgentDetails } {
  const exitCode = res.exitCode ?? 1;
  const isGate = REVIEW_GATES.has(params.agent);
  const banners: string[] = [];
  if (isGate && params.backend === "pi") banners.push(SELF_CHECK_BANNER);
  if (verdict && !verdict.verdictValid) {
    banners.push(`[VERDICT GUARD FAILED: ${verdict.verdictError ?? "missing or invalid verdict block"}]`);
  }

  let body = res.stdout.trimEnd();
  if (exitCode !== 0) {
    const parts = [`[${binary} exited with code ${exitCode}]`];
    if (body) parts.push(body);
    if (res.stderr.trim()) parts.push(res.stderr.trim());
    body = parts.join("\n\n");
  } else if (!body && res.stderr.trim()) {
    body = res.stderr.trim();
  }

  const details: RunAgentDetails = {
    agent: params.agent,
    backend: params.backend,
    authoritative: params.backend !== "pi",
    exitCode,
    ...(verdict
      ? { verdictValid: verdict.verdictValid, ...(verdict.verdictError ? { verdictError: verdict.verdictError } : {}) }
      : {}),
  };
  return {
    content: [{ type: "text", text: [...banners, body].filter(Boolean).join("\n\n") }],
    details,
  };
}

async function loadSessionContext(
  pluginRoot: string,
  cwd: string,
  contextCache: Map<string, string>,
  notifyWarn: (message: string) => void,
): Promise<string | undefined> {
  const cached = contextCache.get(cwd);
  if (cached) return cached;

  const scriptPath = path.join(pluginRoot, "hooks", "session-context.sh");
  if (!isExecutableFile(scriptPath)) {
    notifyWarn(`dev-team: session-context hook not executable: ${scriptPath}`);
    return undefined;
  }

  const hookEnv: NodeJS.ProcessEnv = { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot };
  delete hookEnv.CLAUDE_PROJECT_DIR;
  const payload = JSON.stringify({ cwd });
  const spawnCwd = fs.existsSync(cwd) ? cwd : undefined;

  const parts: string[] = [];
  let hadError = false;
  for (const block of ["policy", "process"] as const) {
    const res = await runCommand(scriptPath, [block], {
      cwd: spawnCwd,
      env: hookEnv,
      stdin: payload,
      timeoutMs: HOOK_TIMEOUT_MS,
    });
    if (res.errorCode || res.timedOut || res.exitCode !== 0) {
      hadError = true;
      const detail = res.timedOut ? "timed out" : res.errorMessage || res.stderr.trim() || `exit ${res.exitCode}`;
      notifyWarn(`dev-team: session-context (${block}) failed: ${detail}`);
      continue;
    }
    const text = res.stdout.trim();
    if (!text) continue;
    parts.push(block === "policy" ? `Plugin root (\`\${CLAUDE_PLUGIN_ROOT}\`): \`${pluginRoot}\`\n\n${text}` : text);
  }

  const combined = parts.join("\n\n");
  if (!combined) return undefined;
  if (!hadError) contextCache.set(cwd, combined);
  return combined;
}

async function runBashHooks(
  pluginRoot: string,
  command: unknown,
  cwd: string,
): Promise<{ block: true; reason: string } | undefined> {
  if (typeof command !== "string") {
    return { block: true, reason: "dev-team: unexpected non-string bash command." };
  }
  if (command === "") return undefined;
  if (!hasJqOnPath(process.env.PATH)) {
    return { block: true, reason: "dev-team: jq is required on PATH to run bash security hooks." };
  }

  const payload = JSON.stringify({ tool_input: { command }, cwd });
  const hookEnv: NodeJS.ProcessEnv = { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot };
  const spawnCwd = cwd && fs.existsSync(cwd) ? cwd : undefined;
  const hooks: ReadonlyArray<readonly [string, number]> = [
    ["merge-gate.sh", MERGE_GATE_TIMEOUT_MS],
    ["attribution-guard.sh", HOOK_TIMEOUT_MS],
  ];

  for (const [hookFile, timeoutMs] of hooks) {
    const scriptPath = path.join(pluginRoot, "hooks", hookFile);
    if (!isExecutableFile(scriptPath)) {
      return { block: true, reason: `dev-team: hook script not executable: ${scriptPath}` };
    }
    const res = await runCommand(scriptPath, [], { cwd: spawnCwd, env: hookEnv, stdin: payload, timeoutMs });
    if (res.timedOut) return { block: true, reason: `dev-team: ${hookFile} timed out after ${timeoutMs / 1000}s.` };
    if (res.errorCode) {
      return { block: true, reason: `dev-team: failed to execute ${hookFile}: ${res.errorMessage ?? res.errorCode}` };
    }
    if (res.exitCode !== 0) return { block: true, reason: extractHookReason(hookFile, res) };
  }
  return undefined;
}

async function executeRunAgent(
  pluginRoot: string,
  rawParams: unknown,
  signal: AbortSignal | undefined,
  defaultCwd: string,
): Promise<{ content: [{ type: "text"; text: string }]; details: RunAgentDetails }> {
  const params = validateRunAgentParams(rawParams, defaultCwd);
  const agentPath = path.join(pluginRoot, "agents", `${params.agent}.md`);
  if (!fs.existsSync(agentPath)) {
    throw new Error(`run_agent: agent definition not found: ${agentPath}`);
  }
  const agentDef = parseAgentFile(fs.readFileSync(agentPath, "utf8"), pluginRoot);
  const assembledPrompt = assembleAgentPrompt(pluginRoot, agentDef, params.prompt);
  const { binary, args, stdin } = buildBackendInvocation(params, agentDef, assembledPrompt);
  const childEnv: NodeJS.ProcessEnv = { ...process.env, CLAUDE_PLUGIN_ROOT: pluginRoot };

  const res = await runCommand(binary, args, {
    cwd: params.workDir,
    env: childEnv,
    stdin,
    timeoutMs: Math.round(params.timeoutSeconds * 1000),
    signal,
  });

  if (res.errorCode === "ENOENT") {
    const remediation: Record<Backend, string> = {
      claude: 'Install Claude Code ("claude") on PATH, or run with backend="agy".',
      agy: 'Install Antigravity CLI ("agy") on PATH, or run with backend="claude".',
      pi: 'Install Pi ("pi") and ensure it is on PATH.',
    };
    throw new Error(`run_agent: "${binary}" binary not found on PATH (ENOENT). ${remediation[params.backend]}`);
  }
  if (res.errorCode) {
    throw new Error(`run_agent: failed to spawn "${binary}": ${res.errorMessage ?? res.errorCode}`);
  }
  if (res.aborted) {
    throw new Error(`run_agent: aborted "${params.agent}" on backend "${params.backend}".`);
  }
  if (res.timedOut) {
    throw new Error(`run_agent: "${params.agent}" on backend "${params.backend}" timed out after ${params.timeoutSeconds}s.`);
  }

  const verdict =
    REVIEW_GATES.has(params.agent) && (res.exitCode ?? 1) === 0
      ? await validateGateVerdict(params.agent, res.stdout, pluginRoot, params.workDir, childEnv)
      : undefined;
  return formatRunAgentResult(params, binary, res, verdict);
}

export default function devTeamExtension(pi: ExtensionAPI, options?: ExtensionOptions): void {
  const pluginRoot = options?.pluginRoot ?? DEFAULT_PLUGIN_ROOT;
  const contextCache = new Map<string, string>();

  pi.on("before_agent_start", async (event, ctx) => {
    const notifyWarn = (message: string): void => {
      if (ctx.hasUI && ctx.ui?.notify) ctx.ui.notify(message, "warning");
      else process.stderr.write(`${message}\n`);
    };
    const combined = await loadSessionContext(pluginRoot, ctx.cwd || process.cwd(), contextCache, notifyWarn);
    if (!combined) return;
    const target = event as { systemPromptOptions?: { sections?: Record<string, string> } };
    target.systemPromptOptions ??= {};
    target.systemPromptOptions.sections ??= {};
    target.systemPromptOptions.sections["dev-team"] = combined;
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const input = event.input as Record<string, unknown> | undefined;
    return runBashHooks(pluginRoot, input?.command, ctx.cwd);
  });

  pi.registerTool({
    name: "run_agent",
    label: "Run dev-team agent",
    description:
      "Run a canonical dev-team subagent (implementer, five review gates, or cold-reader) on pi, claude, or agy backends.",
    parameters: RUN_AGENT_SCHEMA as unknown as TSchema,
    execute: (_toolCallId, rawParams, signal, _onUpdate, ctx) => executeRunAgent(pluginRoot, rawParams, signal, ctx.cwd),
  });
}
