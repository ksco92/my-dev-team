/**
 * Session cloud-mode state, /cloud command handler, and quote-aware bash cloud-CLI detector.
 */

export const CLOUD_MODES = ["off", "ask", "once", "on"] as const;
export type CloudMode = (typeof CLOUD_MODES)[number];
export type CloudBaseMode = "off" | "ask";
export type CloudCli = "claude" | "agy";
export type CloudDetection = { kind: "cli"; cli: CloudCli } | { kind: "depth-exceeded" } | null;

export interface CloudGateState {
  mode: CloudMode;
  baseMode: CloudBaseMode;
}

export interface CloudUiContext {
  hasUI?: boolean;
  ui?: {
    confirm?: (title: string, message: string) => Promise<boolean>;
    notify?: (message: string, type?: "info" | "warning" | "error") => void;
  };
}

export const CLOUD_MODE_NOTICES: Readonly<Partial<Record<CloudMode, string>>> = {
  off: 'Cloud backends (claude, agy) are DISABLED in this session. Stay local on backend="pi" and never invoke claude or agy via run_agent or bash.',
  ask: 'Cloud backends (claude, agy) require explicit user approval. Stay local on backend="pi" and do NOT call backend="claude", backend="agy", or the claude/agy CLIs unless the user explicitly asks you to.',
};

const MAX_SHELL_PARSE_DEPTH = 8;
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
const SHELL_BINARIES: ReadonlySet<string> = new Set(["sh", "bash", "zsh", "dash", "ksh"]);
const SHELL_LONG_ARG_FLAGS: ReadonlySet<string> = new Set(["--rcfile", "--init-file"]);

interface ShellToken {
  kind: "word" | "sep" | "redir";
  raw: string;
}

interface PendingHeredoc {
  delimiter: string;
  quoted: boolean;
  stripTabs: boolean;
}

interface TokenizedShell {
  tokens: ShellToken[];
  substitutions: string[];
}

interface WrapperSpec {
  shortArgFlags: ReadonlySet<string>;
  longArgFlags: ReadonlySet<string>;
  shortScriptFlags?: ReadonlySet<string>;
  longScriptFlags?: ReadonlySet<string>;
  allowEnvAssign?: boolean;
  allowBareDash?: boolean;
  skipPositional?: number;
  checkClaudePkg?: boolean;
}

const NPX_SPEC: WrapperSpec = {
  shortArgFlags: new Set(["p"]),
  longArgFlags: new Set(["--package"]),
  shortScriptFlags: new Set(["c"]),
  longScriptFlags: new Set(["--call"]),
  checkClaudePkg: true,
};

const PKG_MANAGER_PRE_SPEC: WrapperSpec = {
  shortArgFlags: new Set(["C"]),
  longArgFlags: new Set(["--dir", "--cwd", "--filter", "--workspace-root", "--config"]),
};

const WRAPPERS: Readonly<Record<string, WrapperSpec>> = {
  env: {
    shortArgFlags: new Set(["u", "C", "P"]),
    longArgFlags: new Set(["--unset", "--chdir", "--default-signal", "--ignore-signal", "--block-signal"]),
    shortScriptFlags: new Set(["S"]),
    longScriptFlags: new Set(["--split-string"]),
    allowEnvAssign: true,
    allowBareDash: true,
  },
  builtin: { shortArgFlags: new Set(), longArgFlags: new Set() },
  exec: { shortArgFlags: new Set(["a"]), longArgFlags: new Set() },
  nohup: { shortArgFlags: new Set(), longArgFlags: new Set() },
  time: { shortArgFlags: new Set(), longArgFlags: new Set() },
  nice: { shortArgFlags: new Set(["n"]), longArgFlags: new Set(["--adjustment"]) },
  sudo: {
    shortArgFlags: new Set(["u", "g", "C", "h", "p", "r", "t", "U", "D", "R", "T"]),
    longArgFlags: new Set(["--user", "--group", "--chdir", "--host", "--prompt", "--role", "--type", "--other-user"]),
    allowEnvAssign: true,
  },
  timeout: {
    shortArgFlags: new Set(["k", "s"]),
    longArgFlags: new Set(["--kill-after", "--signal"]),
    skipPositional: 1,
  },
  xargs: {
    shortArgFlags: new Set(["I", "L", "n", "P", "s", "E", "d", "a", "J", "R"]),
    longArgFlags: new Set(["--max-args", "--max-procs", "--replace", "--eof", "--delimiter", "--arg-file"]),
  },
  npx: NPX_SPEC,
  pnpx: NPX_SPEC,
  bunx: NPX_SPEC,
};

const ANSI_C_SIMPLE: Readonly<Record<string, string>> = {
  a: "\x07",
  b: "\b",
  e: "\x1b",
  E: "\x1b",
  f: "\f",
  n: "\n",
  r: "\r",
  t: "\t",
  v: "\v",
  "\\": "\\",
  "'": "'",
  '"': '"',
};

export function parseCloudMode(raw: string | undefined): CloudMode | undefined {
  const normalized = raw?.trim().toLowerCase();
  if (normalized && (CLOUD_MODES as readonly string[]).includes(normalized)) {
    return normalized as CloudMode;
  }
  return undefined;
}

export function resetCloudState(state: CloudGateState): void {
  const initial = parseCloudMode(process.env.DEV_TEAM_CLOUD_MODE) ?? "ask";
  state.mode = initial;
  state.baseMode = initial === "off" ? "off" : "ask";
}

export async function authorizeCloudCall(
  state: CloudGateState,
  uiCtx: CloudUiContext,
  subject: string,
  title: string,
  detail: string,
): Promise<string | undefined> {
  if (state.mode === "on") return undefined;
  if (state.mode === "once") {
    state.mode = state.baseMode;
    return undefined;
  }
  if (state.mode === "off") {
    return `${subject} disabled (cloud mode is "off"; run /cloud ask, /cloud once, or /cloud on to allow).`;
  }
  if (!uiCtx.hasUI || !uiCtx.ui?.confirm) {
    return `${subject} requires interactive approval (no UI available); run /cloud on or stay on backend="pi".`;
  }
  try {
    const approved = await uiCtx.ui.confirm(title, detail);
    if (approved === true) return undefined;
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    return `${subject} denied (confirmation failed: ${msg}).`;
  }
  return `${subject} denied by user.`;
}

export function handleCloudCommand(state: CloudGateState, rawArgs: string | undefined, ctx: CloudUiContext): void {
  const notify = (message: string, level: "info" | "warning"): void => {
    if (ctx.ui?.notify) ctx.ui.notify(message, level);
    else process.stderr.write(`${message}\n`);
  };
  const trimmed = (rawArgs ?? "").trim().toLowerCase();
  if (!trimmed || trimmed === "status") {
    notify(`Cloud backend mode: \`${state.mode}\``, "info");
    return;
  }
  const next = parseCloudMode(trimmed);
  if (next) {
    state.mode = next;
    if (next === "off" || next === "ask") state.baseMode = next;
    notify(`Cloud backend mode set to \`${state.mode}\`.`, "info");
    return;
  }
  notify("Usage: /cloud [off|ask|once|on|status]", "warning");
}

function lineContinuationLen(input: string, idx: number): number {
  if (input[idx] !== "\\") return 0;
  if (input[idx + 1] === "\n") return 2;
  if (input[idx + 1] === "\r" && input[idx + 2] === "\n") return 3;
  return 0;
}

function decodeAnsiCEscape(raw: string, slashIdx: number): { ch: string; end: number } {
  const next = raw[slashIdx + 1];
  if (next === undefined) return { ch: "\\", end: slashIdx + 1 };
  if (next in ANSI_C_SIMPLE) return { ch: ANSI_C_SIMPLE[next], end: slashIdx + 2 };
  if (next === "x" || next === "u" || next === "U") {
    const maxDigits = next === "x" ? 2 : next === "u" ? 4 : 8;
    const hex = /^[0-9A-Fa-f]+/.exec(raw.slice(slashIdx + 2, slashIdx + 2 + maxDigits))?.[0];
    if (hex) {
      const code = Number.parseInt(hex, 16);
      const ch = next === "x" ? String.fromCharCode(code) : code <= 0x10ffff ? String.fromCodePoint(code) : "";
      return { ch, end: slashIdx + 2 + hex.length };
    }
  }
  const oct = /^[0-7]{1,3}/.exec(raw.slice(slashIdx + 1, slashIdx + 4))?.[0];
  if (oct) return { ch: String.fromCharCode(Number.parseInt(oct, 8) & 0xff), end: slashIdx + 1 + oct.length };
  return { ch: `\\${next}`, end: slashIdx + 2 };
}

function skipSingleQuoted(input: string, openQuoteIdx: number, ansiC: boolean): number {
  let i = openQuoteIdx + 1;
  while (i < input.length) {
    if (ansiC && input[i] === "\\" && i + 1 < input.length) {
      i += 2;
      continue;
    }
    if (input[i] === "'") return i + 1;
    i += 1;
  }
  return i;
}

function unquoteWord(raw: string): string {
  let out = "";
  let inDouble = false;
  let i = 0;
  while (i < raw.length) {
    const ch = raw[i];
    const cont = lineContinuationLen(raw, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    if (inDouble) {
      if (ch === '"') {
        inDouble = false;
        i += 1;
      } else if (ch === "\\" && i + 1 < raw.length && '"\\$`'.includes(raw[i + 1])) {
        out += raw[i + 1];
        i += 2;
      } else {
        out += ch;
        i += 1;
      }
      continue;
    }
    if (ch === "'") {
      const end = skipSingleQuoted(raw, i, false);
      out += raw.slice(i + 1, end > i + 1 && raw[end - 1] === "'" ? end - 1 : end);
      i = end;
    } else if (ch === "$" && raw[i + 1] === "'") {
      i += 2;
      while (i < raw.length && raw[i] !== "'") {
        if (raw[i] === "\\") {
          const dec = decodeAnsiCEscape(raw, i);
          out += dec.ch;
          i = dec.end;
        } else {
          out += raw[i];
          i += 1;
        }
      }
      if (raw[i] === "'") i += 1;
    } else if (ch === '"' || (ch === "$" && raw[i + 1] === '"')) {
      inDouble = true;
      i += ch === "$" ? 2 : 1;
    } else if (ch === "\\" && i + 1 < raw.length) {
      out += raw[i + 1];
      i += 2;
    } else {
      out += ch;
      i += 1;
    }
  }
  return out;
}

function readBacktick(input: string, openTickIdx: number, inDoubleQuote: boolean): { content: string; end: number } {
  let content = "";
  let i = openTickIdx + 1;
  while (i < input.length) {
    const cont = lineContinuationLen(input, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    const ch = input[i];
    if (ch === "\\" && i + 1 < input.length) {
      const next = input[i + 1];
      const strip = next === "`" || next === "\\" || next === "$" || (inDoubleQuote && next === '"');
      content += strip ? next : `\\${next}`;
      i += 2;
      continue;
    }
    if (ch === "`") return { content, end: i + 1 };
    content += ch;
    i += 1;
  }
  return { content, end: i };
}

interface CaseFrame {
  depth: number;
  seenIn: boolean;
  inPattern: boolean;
}

interface SubstState {
  depth: number;
  curWord: string;
  caseStack: CaseFrame[];
}

function stepSubstOperator(input: string, i: number, state: SubstState): number {
  const { curWord, caseStack } = state;
  if (curWord === "case") {
    caseStack.push({ depth: state.depth, seenIn: false, inPattern: false });
  } else if (curWord === "in" && caseStack.length > 0 && !caseStack[caseStack.length - 1].seenIn) {
    caseStack[caseStack.length - 1].seenIn = true;
    caseStack[caseStack.length - 1].inPattern = true;
  } else if (curWord === "esac" && caseStack.length > 0 && caseStack[caseStack.length - 1].depth === state.depth) {
    caseStack.pop();
  }
  state.curWord = "";
  const ch = input[i];
  const top = caseStack[caseStack.length - 1];
  if (ch === ";" && input[i + 1] === ";" && top && top.depth === state.depth) {
    top.inPattern = true;
    return i + 2;
  }
  if (ch === "(") {
    state.depth += 1;
  } else if (ch === ")") {
    if (top && top.inPattern && top.depth === state.depth) {
      top.inPattern = false;
    } else {
      state.depth -= 1;
      if (top && top.inPattern && top.depth === state.depth) top.inPattern = false;
    }
  }
  return i + 1;
}

function readCommandSubst(input: string, openParenIdx: number, nestedDepth = 0): { content: string; end: number } {
  const state: SubstState = { depth: 1, curWord: "", caseStack: [] };
  let inDouble = false;
  let atWordStart = true;
  let i = openParenIdx + 1;
  while (i < input.length && state.depth > 0) {
    const cont = lineContinuationLen(input, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    const ch = input[i];
    if (ch === "\\" && i + 1 < input.length) {
      atWordStart = false;
      state.curWord = "";
      i += 2;
    } else if (ch === "$" && input[i + 1] === "(" && nestedDepth < MAX_SHELL_PARSE_DEPTH + 2) {
      i = readCommandSubst(input, i + 1, nestedDepth + 1).end;
      atWordStart = false;
      state.curWord = "";
    } else if (ch === "`") {
      i = readBacktick(input, i, inDouble).end;
      atWordStart = false;
      state.curWord = "";
    } else if (inDouble) {
      if (ch === '"') inDouble = false;
      i += 1;
    } else if (atWordStart && ch === "#") {
      const nl = input.indexOf("\n", i);
      i = nl === -1 ? input.length : nl;
    } else if (ch === "'" || (ch === "$" && input[i + 1] === "'")) {
      i = skipSingleQuoted(input, ch === "$" ? i + 1 : i, ch === "$");
      atWordStart = false;
      state.curWord = "";
    } else if (ch === '"' || (ch === "$" && input[i + 1] === '"')) {
      inDouble = true;
      atWordStart = false;
      state.curWord = "";
      i += ch === "$" ? 2 : 1;
    } else if (/[ \t\r\n;|&()<>]/.test(ch)) {
      atWordStart = true;
      i = stepSubstOperator(input, i, state);
    } else {
      state.curWord += ch;
      atWordStart = false;
      i += 1;
    }
  }
  return { content: input.slice(openParenIdx + 1, state.depth === 0 ? i - 1 : i), end: i };
}

function readShellWord(input: string, start: number, substitutions: string[]): { raw: string; end: number } {
  let inDouble = false;
  let i = start;
  while (i < input.length) {
    const cont = lineContinuationLen(input, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    const ch = input[i];
    if (ch === "\\" && i + 1 < input.length) {
      i += 2;
    } else if (ch === "$" && input[i + 1] === "(") {
      const sub = readCommandSubst(input, i + 1);
      substitutions.push(sub.content);
      i = sub.end;
    } else if (ch === "`") {
      const sub = readBacktick(input, i, inDouble);
      substitutions.push(sub.content);
      i = sub.end;
    } else if (inDouble) {
      if (ch === '"') inDouble = false;
      i += 1;
    } else if ((ch === "<" || ch === ">") && input[i + 1] === "(") {
      const sub = readCommandSubst(input, i + 1);
      substitutions.push(sub.content);
      i = sub.end;
    } else if (ch === "'" || (ch === "$" && input[i + 1] === "'")) {
      i = skipSingleQuoted(input, ch === "$" ? i + 1 : i, ch === "$");
    } else if (ch === '"' || (ch === "$" && input[i + 1] === '"')) {
      inDouble = true;
      i += ch === "$" ? 2 : 1;
    } else if (/[ \t\r\n;|&()<>]/.test(ch)) {
      break;
    } else {
      i += 1;
    }
  }
  return { raw: input.slice(start, i), end: i };
}

function scanHeredocSubstitutions(body: string, substitutions: string[]): void {
  let i = 0;
  while (i < body.length) {
    const cont = lineContinuationLen(body, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    const ch = body[i];
    if (ch === "\\" && i + 1 < body.length && "$`\\".includes(body[i + 1])) {
      i += 2;
      continue;
    }
    if (ch === "$" && body[i + 1] === "(") {
      const sub = readCommandSubst(body, i + 1);
      substitutions.push(sub.content);
      i = sub.end;
      continue;
    }
    if (ch === "`") {
      const sub = readBacktick(body, i, false);
      substitutions.push(sub.content);
      i = sub.end;
      continue;
    }
    i += 1;
  }
}

function consumeHeredocs(
  input: string,
  start: number,
  queue: PendingHeredoc[],
  substitutions: string[],
): number {
  let i = start;
  for (const hd of queue) {
    const bodyStart = i;
    let bodyEnd = i;
    while (i < input.length) {
      const nl = input.indexOf("\n", i);
      const lineEnd = nl === -1 ? input.length : nl;
      const rawLine = input.slice(i, lineEnd).replace(/\r$/, "");
      const candidate = hd.stripTabs ? rawLine.replace(/^\t+/, "") : rawLine;
      i = nl === -1 ? input.length : nl + 1;
      if (candidate === hd.delimiter) break;
      bodyEnd = i;
    }
    if (!hd.quoted && bodyEnd > bodyStart) {
      scanHeredocSubstitutions(input.slice(bodyStart, bodyEnd), substitutions);
    }
  }
  return i;
}

function consumeRedirection(
  input: string,
  afterOpIdx: number,
  op: string,
  tokens: ShellToken[],
  pendingHeredocs: PendingHeredoc[],
  substitutions: string[],
): number {
  let i = afterOpIdx;
  if (op.endsWith("<<") || op.endsWith("<<-")) {
    while (i < input.length && (input[i] === " " || input[i] === "\t")) i += 1;
    const delimWord = readShellWord(input, i, []);
    const delimiter = unquoteWord(delimWord.raw);
    if (delimiter) {
      pendingHeredocs.push({ delimiter, quoted: /['"\\]/.test(delimWord.raw), stripTabs: op.endsWith("-") });
    }
    return delimWord.end;
  }
  if (i < input.length && !/[ \t\r\n;|&()]/.test(input[i])) {
    return readShellWord(input, i, substitutions).end;
  }
  tokens.push({ kind: "redir", raw: op });
  return i;
}

function tokenizeShell(input: string): TokenizedShell {
  const tokens: ShellToken[] = [];
  const substitutions: string[] = [];
  const pendingHeredocs: PendingHeredoc[] = [];
  let i = 0;
  while (i < input.length) {
    const cont = lineContinuationLen(input, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
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
    if (ch === "\n") {
      tokens.push({ kind: "sep", raw: ch });
      i += 1;
      if (pendingHeredocs.length > 0) {
        i = consumeHeredocs(input, i, pendingHeredocs, substitutions);
        pendingHeredocs.length = 0;
      }
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
      i = consumeRedirection(input, i + redir[0].length, redir[0], tokens, pendingHeredocs, substitutions);
      continue;
    }
    if (ch === ";" || ch === "(" || ch === ")" || ch === "|" || ch === "&") {
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

function scanShortCluster(
  words: string[],
  idx: number,
  w: string,
  spec: WrapperSpec,
  depth: number,
): { detected?: CloudDetection; advance: number } {
  for (let k = 1; k < w.length; k += 1) {
    const ch = w[k];
    if (spec.shortScriptFlags?.has(ch)) {
      const rest = w.slice(k + 1);
      if (rest) {
        const hit = detectCloudCliInvocation(rest, depth + 1);
        return hit ? { detected: hit, advance: words.length } : { advance: 1 };
      }
      if (idx + 1 < words.length) {
        const hit = detectCloudCliInvocation(unquoteWord(words[idx + 1]), depth + 1);
        if (hit) return { detected: hit, advance: words.length };
      }
      return { advance: 2 };
    }
    if (spec.shortArgFlags.has(ch)) {
      return { advance: k + 1 < w.length ? 1 : 2 };
    }
  }
  return { advance: 1 };
}

function unwrapWrapper(
  words: string[],
  start: number,
  spec: WrapperSpec,
  depth: number,
): { detected?: CloudDetection; nextIdx: number } {
  let i = start;
  let stopFlags = false;
  while (i < words.length) {
    const w = unquoteWord(words[i]);
    if (!stopFlags && w === "--") {
      i += 1;
      stopFlags = true;
      continue;
    }
    if (!stopFlags && spec.allowBareDash && w === "-") {
      i += 1;
      continue;
    }
    if (!stopFlags && w.startsWith("--") && w.length > 2) {
      const eq = w.indexOf("=");
      const flag = eq >= 0 ? w.slice(0, eq) : w;
      if (spec.longScriptFlags?.has(flag)) {
        const script = eq >= 0 ? w.slice(eq + 1) : i + 1 < words.length ? unquoteWord(words[i + 1]) : "";
        const hit = script ? detectCloudCliInvocation(script, depth + 1) : null;
        if (hit) return { detected: hit, nextIdx: words.length };
        i += eq >= 0 ? 1 : 2;
        continue;
      }
      i += eq === -1 && spec.longArgFlags.has(flag) ? 2 : 1;
      continue;
    }
    if (!stopFlags && w.startsWith("-") && w.length > 1) {
      const res = scanShortCluster(words, i, w, spec, depth);
      if (res.detected) return { detected: res.detected, nextIdx: words.length };
      i += res.advance;
      continue;
    }
    if (spec.allowEnvAssign && ENV_ASSIGN_RE.test(w)) {
      i += 1;
      continue;
    }
    break;
  }
  i += spec.skipPositional ?? 0;
  if (spec.checkClaudePkg && i < words.length) {
    const pkg = unquoteWord(words[i]);
    if (pkg === "@anthropic-ai/claude-code" || pkg.startsWith("@anthropic-ai/claude-code@")) {
      return { detected: { kind: "cli", cli: "claude" }, nextIdx: words.length };
    }
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

function unwrapShellDashC(words: string[], start: number, depth: number): CloudDetection {
  let i = start;
  let hasDashC = false;
  while (i < words.length) {
    const w = unquoteWord(words[i]);
    if (w === "--") {
      i += 1;
      break;
    }
    if (w.startsWith("--") && w.length > 2) {
      const eq = w.indexOf("=");
      i += eq === -1 && SHELL_LONG_ARG_FLAGS.has(w) ? 2 : 1;
      continue;
    }
    if ((w.startsWith("-") || w.startsWith("+")) && w.length > 1) {
      let advance = 1;
      for (let k = 1; k < w.length; k += 1) {
        const ch = w[k];
        if (w[0] === "-" && ch === "c") hasDashC = true;
        else if (ch === "o" || ch === "O") {
          advance = k + 1 < w.length ? 1 : 2;
          break;
        }
      }
      i += advance;
      continue;
    }
    break;
  }
  if (!hasDashC || i >= words.length) return null;
  return detectCloudCliInvocation(unquoteWord(words[i]), depth + 1);
}

function inspectCommandSegment(words: string[], depth: number): CloudDetection {
  let i = 0;
  while (i < words.length) {
    const raw = words[i];
    const unquoted = unquoteWord(raw);
    if (ENV_ASSIGN_RE.test(unquoted) || SHELL_PREFIX_KEYWORDS.has(raw)) {
      i += 1;
      continue;
    }
    const slash = unquoted.lastIndexOf("/");
    const base = (slash >= 0 ? unquoted.slice(slash + 1) : unquoted).toLowerCase();
    if (base === "claude" || base === "agy") return { kind: "cli", cli: base };
    if (base === "command") {
      const next = unwrapCommandBuiltin(words, i + 1);
      if (next === null) return null;
      i = next;
      continue;
    }
    if (SHELL_BINARIES.has(base)) return unwrapShellDashC(words, i + 1, depth);
    if (base === "pnpm" || base === "yarn") {
      const pre = unwrapWrapper(words, i + 1, PKG_MANAGER_PRE_SPEC, depth);
      const sub = pre.nextIdx < words.length ? unquoteWord(words[pre.nextIdx]) : "";
      if (sub !== "exec" && sub !== "dlx") return null;
      const res = unwrapWrapper(words, pre.nextIdx + 1, NPX_SPEC, depth);
      if (res.detected) return res.detected;
      i = res.nextIdx;
      continue;
    }
    const spec = WRAPPERS[base];
    if (!spec) return null;
    const res = unwrapWrapper(words, i + 1, spec, depth);
    if (res.detected) return res.detected;
    i = res.nextIdx;
  }
  return null;
}

export function detectCloudCliInvocation(command: string, depth = 0): CloudDetection {
  if (depth > MAX_SHELL_PARSE_DEPTH) return { kind: "depth-exceeded" };
  if (!command.trim()) return null;
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
