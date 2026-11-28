/**
 * Pi extension adapter for the dev-team plugin.
 * Delegates session context and bash guards to plugins/dev-team/hooks/*.sh,
 * gates paid cloud backends via /cloud, and registers run_agent over pi, claude, and agy.
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

const CLOUD_MODES = ["off", "ask", "once", "on"] as const;
type CloudMode = (typeof CLOUD_MODES)[number];
type CloudBaseMode = "off" | "ask";
type CloudCli = "claude" | "agy";

const CLOUD_MODE_NOTICES: Readonly<Partial<Record<CloudMode, string>>> = {
  off: 'Cloud backends (claude, agy) are DISABLED in this session. Stay local on backend="pi" and never invoke claude or agy via run_agent or bash.',
  ask: 'Cloud backends (claude, agy) require explicit user approval. Stay local on backend="pi" and do NOT call backend="claude", backend="agy", or the claude/agy CLIs unless the user explicitly asks you to.',
};

const MAX_SHELL_PARSE_DEPTH = 8;
const MAX_BASH_SNIPPET_CHARS = 200;
const REDIR_PREFIX_RE = /^(?:&>>|&>|(?:[0-9]+)?(?:<<<|<<-|<<|>>|<>|>\||>&|<&|[<>]))/;
const ENV_ASSIGN_RE = /^[A-Za-z_][A-Za-z0-9_]*=/;
const SHELL_PREFIX_KEYWORDS: ReadonlySet<string> = new Set([
  "!",
  "{",
  "if",
  "then",
  "else",
  "elif",
  "do",
  "while",
  "until",
]);
const SHELL_BINARIES: ReadonlySet<string> = new Set(["sh", "bash", "zsh", "dash"]);
const ENV_ARG_FLAGS: ReadonlySet<string> = new Set([
  "-u",
  "--unset",
  "-C",
  "--chdir",
  "-P",
  "--default-signal",
  "--ignore-signal",
  "--block-signal",
]);

interface WrapperSpec {
  argFlags: ReadonlySet<string>;
  allowEnvAssign?: boolean;
  skipPositional?: number;
}

const SIMPLE_WRAPPERS: Readonly<Record<string, WrapperSpec>> = {
  exec: { argFlags: new Set(["-a"]) },
  nohup: { argFlags: new Set() },
  time: { argFlags: new Set() },
  nice: { argFlags: new Set(["-n", "--adjustment"]) },
  sudo: {
    argFlags: new Set([
      "-u", "-g", "-C", "-h", "-p", "-r", "-t", "-U", "-D", "-R", "-T",
      "--user", "--group", "--chdir", "--host", "--prompt", "--role", "--type", "--other-user",
    ]),
    allowEnvAssign: true,
  },
  timeout: {
    argFlags: new Set(["-k", "-s", "--kill-after", "--signal"]),
    skipPositional: 1,
  },
  xargs: {
    argFlags: new Set([
      "-I", "-L", "-n", "-P", "-s", "-E", "-d", "-a", "-J", "-R",
      "--max-args", "--max-procs", "--replace", "--eof", "--delimiter", "--arg-file",
    ]),
  },
};

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

const ENOENT_REMEDIATION: Readonly<Record<Backend, string>> = {
  claude: 'Install Claude Code ("claude") on PATH, or run with backend="agy".',
  agy: 'Install Antigravity CLI ("agy") on PATH, or run with backend="claude".',
  pi: 'Install Pi ("pi") and ensure it is on PATH.',
};

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

interface CloudGateState {
  mode: CloudMode;
  baseMode: CloudBaseMode;
}

interface CloudUiContext {
  hasUI?: boolean;
  ui?: {
    confirm?: (title: string, message: string) => Promise<boolean>;
    notify?: (message: string, type?: "info" | "warning" | "error") => void;
  };
}

interface ShellToken {
  kind: "word" | "sep" | "redir";
  raw: string;
}

interface TokenizedShell {
  tokens: ShellToken[];
  substitutions: string[];
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

    const terminate = (reason: "abort" | "timeout"): void => {
      if (killTimer) return;
      if (reason === "abort") aborted = true;
      else timedOut = true;
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

    const onAbort = (): void => terminate("abort");
    options.signal?.addEventListener("abort", onAbort, { once: true });

    const timeoutHandle = setTimeout(() => terminate("timeout"), options.timeoutMs);
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

function parseCloudMode(raw: string | undefined): CloudMode {
  const normalized = raw?.trim().toLowerCase();
  if (normalized && (CLOUD_MODES as readonly string[]).includes(normalized)) {
    return normalized as CloudMode;
  }
  return "ask";
}

function resetCloudState(state: CloudGateState): void {
  const initial = parseCloudMode(process.env.DEV_TEAM_CLOUD_MODE);
  state.mode = initial;
  state.baseMode = initial === "off" ? "off" : "ask";
}

async function authorizeCloudCall(
  state: CloudGateState,
  uiCtx: CloudUiContext,
  subject: string,
  title: string,
  detail: string,
): Promise<{ allowed: true } | { allowed: false; reason: string }> {
  if (state.mode === "on") return { allowed: true };
  if (state.mode === "once") {
    state.mode = state.baseMode;
    return { allowed: true };
  }
  if (state.mode === "off") {
    return {
      allowed: false,
      reason: `${subject} disabled (cloud mode is "off"; run /cloud ask, /cloud once, or /cloud on to allow).`,
    };
  }
  if (!uiCtx.hasUI || !uiCtx.ui?.confirm) {
    return {
      allowed: false,
      reason: `${subject} requires interactive approval (no UI available); run /cloud on or stay on backend="pi".`,
    };
  }
  try {
    const approved = await uiCtx.ui.confirm(title, detail);
    if (approved === true) return { allowed: true };
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return { allowed: false, reason: `${subject} denied (confirmation failed: ${msg}).` };
  }
  return { allowed: false, reason: `${subject} denied by user.` };
}

function handleCloudCommand(state: CloudGateState, rawArgs: string | undefined, ctx: CloudUiContext): void {
  const notify = (message: string, level: "info" | "warning"): void => {
    if (ctx.ui?.notify) ctx.ui.notify(message, level);
    else process.stderr.write(`${message}\n`);
  };
  const arg = (rawArgs ?? "").trim().toLowerCase();
  if (!arg || arg === "status") {
    notify(`Cloud backend mode: \`${state.mode}\``, "info");
    return;
  }
  if ((CLOUD_MODES as readonly string[]).includes(arg)) {
    const next = arg as CloudMode;
    state.mode = next;
    if (next === "off" || next === "ask") state.baseMode = next;
    notify(`Cloud backend mode set to \`${state.mode}\`.`, "info");
    return;
  }
  notify("Usage: /cloud [off|ask|once|on|status]", "warning");
}

function unquoteWord(raw: string): string {
  let out = "";
  let quote: "'" | '"' | null = null;
  for (let i = 0; i < raw.length; i += 1) {
    const ch = raw[i];
    if (quote === "'") {
      if (ch === "'") quote = null;
      else out += ch;
      continue;
    }
    if (ch === "\\" && i + 1 < raw.length) {
      i += 1;
      out += raw[i];
      continue;
    }
    if (quote === '"') {
      if (ch === '"') quote = null;
      else out += ch;
      continue;
    }
    if (ch === "'" || ch === '"') quote = ch;
    else out += ch;
  }
  return out;
}

function readCommandSubst(input: string, openParenIdx: number): { content: string; end: number } {
  let depth = 1;
  let quote: "'" | '"' | null = null;
  let i = openParenIdx + 1;
  while (i < input.length && depth > 0) {
    const ch = input[i];
    if (quote === "'") {
      if (ch === "'") quote = null;
      i += 1;
      continue;
    }
    if (ch === "\\" && i + 1 < input.length) {
      i += 2;
      continue;
    }
    if (quote === '"') {
      if (ch === '"') quote = null;
      i += 1;
      continue;
    }
    if (ch === "'" || ch === '"') quote = ch;
    else if (ch === "(") depth += 1;
    else if (ch === ")") depth -= 1;
    i += 1;
  }
  const contentEnd = depth === 0 ? i - 1 : i;
  return { content: input.slice(openParenIdx + 1, contentEnd), end: i };
}

function readBacktick(input: string, openTickIdx: number): { content: string; end: number } {
  let content = "";
  let i = openTickIdx + 1;
  while (i < input.length) {
    const ch = input[i];
    if (ch === "\\" && i + 1 < input.length) {
      const next = input[i + 1];
      content += next === "`" || next === "\\" || next === "$" ? next : `\\${next}`;
      i += 2;
      continue;
    }
    if (ch === "`") return { content, end: i + 1 };
    content += ch;
    i += 1;
  }
  return { content, end: i };
}

function readShellWord(input: string, start: number, substitutions: string[]): { raw: string; end: number } {
  let quote: "'" | '"' | null = null;
  let i = start;
  while (i < input.length) {
    const ch = input[i];
    if (quote === "'") {
      if (ch === "'") quote = null;
      i += 1;
      continue;
    }
    if (ch === "\\" && i + 1 < input.length) {
      i += 2;
      continue;
    }
    if (ch === "$" && input[i + 1] === "(") {
      const sub = readCommandSubst(input, i + 1);
      substitutions.push(sub.content);
      i = sub.end;
      continue;
    }
    if (ch === "`") {
      const sub = readBacktick(input, i);
      substitutions.push(sub.content);
      i = sub.end;
      continue;
    }
    if (quote === '"') {
      if (ch === '"') quote = null;
      i += 1;
      continue;
    }
    if ((ch === "<" || ch === ">") && input[i + 1] === "(") {
      const sub = readCommandSubst(input, i + 1);
      substitutions.push(sub.content);
      i = sub.end;
      continue;
    }
    if (ch === "'" || ch === '"') {
      quote = ch;
      i += 1;
      continue;
    }
    if (/[ \t\r\n;|&()<>]/.test(ch)) break;
    i += 1;
  }
  return { raw: input.slice(start, i), end: i };
}

function tokenizeShell(input: string): TokenizedShell {
  const tokens: ShellToken[] = [];
  const substitutions: string[] = [];
  let i = 0;
  while (i < input.length) {
    const ch = input[i];
    if (ch === " " || ch === "\t" || ch === "\r") {
      i += 1;
      continue;
    }
    if (ch === "#") {
      const nl = input.indexOf("\n", i);
      i = nl === -1 ? input.length : nl;
      continue;
    }
    if (ch === "\n" || ch === ";" || ch === "(" || ch === ")") {
      tokens.push({ kind: "sep", raw: ch });
      i += 1;
      continue;
    }
    const two = input.slice(i, i + 2);
    if (two === "&&" || two === "||" || two === "|&") {
      tokens.push({ kind: "sep", raw: two });
      i += 2;
      continue;
    }
    const redir = two !== "<(" && two !== ">(" ? REDIR_PREFIX_RE.exec(input.slice(i)) : null;
    if (redir) {
      i += redir[0].length;
      if (i < input.length && !/[ \t\r\n;|&()]/.test(input[i])) {
        i = readShellWord(input, i, substitutions).end;
      } else {
        tokens.push({ kind: "redir", raw: redir[0] });
      }
      continue;
    }
    if (ch === "|" || ch === "&") {
      tokens.push({ kind: "sep", raw: ch });
      i += 1;
      continue;
    }
    const word = readShellWord(input, i, substitutions);
    if (word.raw) tokens.push({ kind: "word", raw: word.raw });
    i = word.end > i ? word.end : i + 1;
  }
  return { tokens, substitutions };
}

function extractCommandSegments(tokens: ShellToken[]): string[][] {
  const segments: string[][] = [];
  let current: string[] = [];
  let skipNextWord = false;
  for (const tok of tokens) {
    if (tok.kind === "sep") {
      if (current.length > 0) segments.push(current);
      current = [];
      skipNextWord = false;
      continue;
    }
    if (tok.kind === "redir") {
      skipNextWord = true;
      continue;
    }
    if (skipNextWord) {
      skipNextWord = false;
      continue;
    }
    current.push(tok.raw);
  }
  if (current.length > 0) segments.push(current);
  return segments;
}

function skipSimpleWrapperArgs(words: string[], start: number, spec: WrapperSpec): number {
  let i = start;
  let stopFlags = false;
  while (i < words.length) {
    const raw = words[i];
    const unquoted = unquoteWord(raw);
    if (!stopFlags && unquoted === "--") {
      i += 1;
      stopFlags = true;
      continue;
    }
    if (!stopFlags && unquoted.startsWith("-") && unquoted.length > 1) {
      i += spec.argFlags.has(unquoted) ? 2 : 1;
      continue;
    }
    if (spec.allowEnvAssign && ENV_ASSIGN_RE.test(raw)) {
      i += 1;
      continue;
    }
    break;
  }
  return i + (spec.skipPositional ?? 0);
}

function unwrapEnv(words: string[], start: number, depth: number): { matched?: CloudCli; nextIdx: number } {
  let i = start;
  let stopFlags = false;
  while (i < words.length) {
    const raw = words[i];
    const w = unquoteWord(raw);
    if (!stopFlags && w === "--") {
      i += 1;
      stopFlags = true;
      continue;
    }
    if (!stopFlags && (w === "-S" || w === "--split-string") && i + 1 < words.length) {
      const hit = detectCloudCliInvocation(unquoteWord(words[i + 1]), depth + 1);
      if (hit) return { matched: hit, nextIdx: words.length };
      i += 2;
      continue;
    }
    if (!stopFlags && w.startsWith("--split-string=")) {
      const hit = detectCloudCliInvocation(w.slice("--split-string=".length), depth + 1);
      if (hit) return { matched: hit, nextIdx: words.length };
      i += 1;
      continue;
    }
    if (!stopFlags && w.startsWith("-") && w.length > 1) {
      i += ENV_ARG_FLAGS.has(w) ? 2 : 1;
      continue;
    }
    if (ENV_ASSIGN_RE.test(raw)) {
      i += 1;
      continue;
    }
    break;
  }
  return { nextIdx: i };
}

function unwrapCommandBuiltin(words: string[], start: number): number | null {
  let i = start;
  while (i < words.length) {
    const w = unquoteWord(words[i]);
    if (w === "--") return i + 1;
    if (/^-[A-Za-z]*[vV][A-Za-z]*$/.test(w)) return null;
    if (w.startsWith("-") && w.length > 1) {
      i += 1;
      continue;
    }
    break;
  }
  return i;
}

function unwrapNpx(words: string[], start: number, depth: number): { matched?: CloudCli; nextIdx: number } {
  let i = start;
  let stopFlags = false;
  while (i < words.length) {
    const w = unquoteWord(words[i]);
    if (!stopFlags && w === "--") {
      i += 1;
      stopFlags = true;
      continue;
    }
    if (!stopFlags && (w === "-c" || w === "--call") && i + 1 < words.length) {
      const hit = detectCloudCliInvocation(unquoteWord(words[i + 1]), depth + 1);
      if (hit) return { matched: hit, nextIdx: words.length };
      i += 2;
      continue;
    }
    if (!stopFlags && w.startsWith("--call=")) {
      const hit = detectCloudCliInvocation(w.slice("--call=".length), depth + 1);
      if (hit) return { matched: hit, nextIdx: words.length };
      i += 1;
      continue;
    }
    if (!stopFlags && w.startsWith("-") && w.length > 1) {
      i += w === "-p" || w === "--package" ? 2 : 1;
      continue;
    }
    break;
  }
  const pkg = i < words.length ? unquoteWord(words[i]) : "";
  if (pkg === "@anthropic-ai/claude-code" || pkg.startsWith("@anthropic-ai/claude-code@")) {
    return { matched: "claude", nextIdx: words.length };
  }
  return { nextIdx: i };
}

function unwrapShellDashC(words: string[], start: number, depth: number): CloudCli | null {
  let i = start;
  let hasDashC = false;
  while (i < words.length) {
    const w = unquoteWord(words[i]);
    if (w === "--") {
      i += 1;
      break;
    }
    if (w === "-o" || w === "+o") {
      i += 2;
      continue;
    }
    if (/^-[A-Za-z]*c[A-Za-z]*$/.test(w)) {
      hasDashC = true;
      i += 1;
      continue;
    }
    if ((w.startsWith("-") || w.startsWith("+")) && w.length > 1) {
      i += 1;
      continue;
    }
    break;
  }
  if (!hasDashC || i >= words.length) return null;
  return detectCloudCliInvocation(unquoteWord(words[i]), depth + 1);
}

function inspectCommandSegment(words: string[], depth: number): CloudCli | null {
  let i = 0;
  while (i < words.length) {
    const raw = words[i];
    if (ENV_ASSIGN_RE.test(raw) || SHELL_PREFIX_KEYWORDS.has(raw)) {
      i += 1;
      continue;
    }
    const unquoted = unquoteWord(raw);
    const slash = unquoted.lastIndexOf("/");
    const base = (slash >= 0 ? unquoted.slice(slash + 1) : unquoted).toLowerCase();
    if (base === "claude" || base === "agy") return base;
    if (base === "env") {
      const res = unwrapEnv(words, i + 1, depth);
      if (res.matched) return res.matched;
      i = res.nextIdx;
      continue;
    }
    if (base === "command") {
      const next = unwrapCommandBuiltin(words, i + 1);
      if (next === null) return null;
      i = next;
      continue;
    }
    if (SHELL_BINARIES.has(base)) return unwrapShellDashC(words, i + 1, depth);
    if (base === "npx" || base === "bunx" || base === "pnpm" || base === "yarn") {
      let startIdx = i + 1;
      if (base === "pnpm" || base === "yarn") {
        const sub = startIdx < words.length ? unquoteWord(words[startIdx]) : "";
        if (sub !== "exec" && sub !== "dlx") return null;
        startIdx += 1;
      }
      const res = unwrapNpx(words, startIdx, depth);
      if (res.matched) return res.matched;
      i = res.nextIdx;
      continue;
    }
    const spec = SIMPLE_WRAPPERS[base];
    if (!spec) return null;
    i = skipSimpleWrapperArgs(words, i + 1, spec);
  }
  return null;
}

function detectCloudCliInvocation(command: string, depth = 0): CloudCli | null {
  if (depth > MAX_SHELL_PARSE_DEPTH || !command.trim()) return null;
  const { tokens, substitutions } = tokenizeShell(command);
  for (const segment of extractCommandSegments(tokens)) {
    const hit = inspectCommandSegment(segment, depth);
    if (hit) return hit;
  }
  for (const sub of substitutions) {
    const hit = detectCloudCliInvocation(sub, depth + 1);
    if (hit) return hit;
  }
  return null;
}

async function executeRunAgent(
  pluginRoot: string,
  cloudState: CloudGateState,
  rawParams: unknown,
  signal: AbortSignal | undefined,
  ctx: CloudUiContext & { cwd: string },
): Promise<{ content: [{ type: "text"; text: string }]; details: RunAgentDetails }> {
  const params = validateRunAgentParams(rawParams, ctx.cwd);
  const agentPath = path.join(pluginRoot, "agents", `${params.agent}.md`);
  if (!fs.existsSync(agentPath)) {
    throw new Error(`run_agent: agent definition not found: ${agentPath}`);
  }
  const agentDef = parseAgentFile(fs.readFileSync(agentPath, "utf8"), pluginRoot);
  const assembledPrompt = assembleAgentPrompt(pluginRoot, agentDef, params.prompt);
  const { binary, args, stdin } = buildBackendInvocation(params, agentDef, assembledPrompt);
  if (params.backend === "claude" || params.backend === "agy") {
    const resolvedModel =
      params.backend === "claude" ? (params.model ?? agentDef.model ?? "default") : (params.model ?? "default");
    const auth = await authorizeCloudCall(
      cloudState,
      ctx,
      `cloud backend "${params.backend}" for agent "${params.agent}"`,
      `Allow cloud run_agent (${params.backend})?`,
      `Agent: ${params.agent}\nBackend: ${params.backend}\nModel: ${resolvedModel}`,
    );
    if (!auth.allowed) throw new Error(`run_agent: ${auth.reason}`);
  }

  const childEnv: NodeJS.ProcessEnv = {
    ...process.env,
    CLAUDE_PLUGIN_ROOT: pluginRoot,
    ...(params.backend === "pi" ? { DEV_TEAM_CLOUD_MODE: "off" } : {}),
  };
  const res = await runCommand(binary, args, {
    cwd: params.workDir,
    env: childEnv,
    stdin,
    timeoutMs: Math.round(params.timeoutSeconds * 1000),
    signal,
  });

  if (res.errorCode === "ENOENT") {
    throw new Error(`run_agent: "${binary}" binary not found on PATH (ENOENT). ${ENOENT_REMEDIATION[params.backend]}`);
  }
  if (res.errorCode) throw new Error(`run_agent: failed to spawn "${binary}": ${res.errorMessage ?? res.errorCode}`);
  if (res.aborted) throw new Error(`run_agent: aborted "${params.agent}" on backend "${params.backend}".`);
  if (res.timedOut) {
    throw new Error(`run_agent: "${params.agent}" on backend "${params.backend}" timed out after ${params.timeoutSeconds}s.`);
  }

  const verdict =
    REVIEW_GATES.has(params.agent) && (res.exitCode ?? 1) === 0
      ? await validateGateVerdict(params.agent, res.stdout, pluginRoot, params.workDir, childEnv)
      : undefined;
  return formatRunAgentResult(params, binary, res, verdict);
}

async function guardBashToolCall(
  pluginRoot: string,
  cloudState: CloudGateState,
  command: unknown,
  ctx: CloudUiContext & { cwd: string },
): Promise<{ block: true; reason: string } | undefined> {
  const hookRes = await runBashHooks(pluginRoot, command, ctx.cwd);
  if (hookRes) return hookRes;
  if (typeof command !== "string" || command === "") return undefined;
  const detectedCli = detectCloudCliInvocation(command);
  if (!detectedCli) return undefined;
  const snippet = command.length > MAX_BASH_SNIPPET_CHARS ? `${command.slice(0, MAX_BASH_SNIPPET_CHARS)}...` : command;
  const auth = await authorizeCloudCall(
    cloudState,
    ctx,
    `dev-team: bash invocation of cloud CLI "${detectedCli}"`,
    `Allow cloud CLI (${detectedCli}) in bash?`,
    snippet,
  );
  return auth.allowed ? undefined : { block: true, reason: auth.reason };
}

export default function devTeamExtension(pi: ExtensionAPI, options?: ExtensionOptions): void {
  const pluginRoot = options?.pluginRoot ?? DEFAULT_PLUGIN_ROOT;
  const contextCache = new Map<string, string>();
  const cloudState: CloudGateState = { mode: "ask", baseMode: "ask" };
  resetCloudState(cloudState);

  pi.on("session_start", () => resetCloudState(cloudState));

  pi.registerCommand("cloud", {
    description: "Control paid cloud backends (claude, agy): /cloud [off|ask|once|on|status]",
    handler: async (args, ctx) => handleCloudCommand(cloudState, args, ctx),
  });

  pi.on("before_agent_start", async (event, ctx) => {
    const notifyWarn = (message: string): void => {
      if (ctx.hasUI && ctx.ui?.notify) ctx.ui.notify(message, "warning");
      else process.stderr.write(`${message}\n`);
    };
    const combined = await loadSessionContext(pluginRoot, ctx.cwd || process.cwd(), contextCache, notifyWarn);
    const section = [combined, CLOUD_MODE_NOTICES[cloudState.mode]].filter(Boolean).join("\n\n");
    if (!section) return;
    const target = event as { systemPromptOptions?: { sections?: Record<string, string> } };
    target.systemPromptOptions ??= {};
    target.systemPromptOptions.sections ??= {};
    target.systemPromptOptions.sections["dev-team"] = section;
  });

  pi.on("tool_call", async (event, ctx) => {
    if (event.toolName !== "bash") return;
    const input = event.input as Record<string, unknown> | undefined;
    return guardBashToolCall(pluginRoot, cloudState, input?.command, ctx);
  });

  pi.registerTool({
    name: "run_agent",
    label: "Run dev-team agent",
    description:
      "Run a canonical dev-team subagent (implementer, five review gates, or cold-reader) on pi, claude, or agy backends.",
    parameters: RUN_AGENT_SCHEMA as unknown as TSchema,
    execute: (_toolCallId, rawParams, signal, _onUpdate, ctx) =>
      executeRunAgent(pluginRoot, cloudState, rawParams, signal, ctx),
  });
}
