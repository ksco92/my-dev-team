/**
 * Session cloud-mode state, /cloud command handler, and quote-aware bash cloud-CLI detector.
 */

const CLOUD_MODES = ["off", "ask", "once", "on"] as const;
type CloudMode = (typeof CLOUD_MODES)[number];
type CloudBaseMode = "off" | "ask";
type CloudCli = "claude" | "agy";
type CloudDetection = { kind: "cli"; cli: CloudCli } | { kind: "depth-exceeded" } | null;

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
const ENV_ASSIGN_RE = /^[A-Za-z_][A-Za-z0-9_]*\+?=/;
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
  "coproc",
]);
const SHELL_BINARIES: ReadonlySet<string> = new Set(["sh", "bash", "zsh", "dash", "ksh", "csh", "tcsh"]);
const SHELL_LONG_ARG_FLAGS: ReadonlySet<string> = new Set(["--rcfile", "--init-file"]);

interface PendingHeredoc {
  delimiter: string;
  quoted: boolean;
  stripTabs: boolean;
  targetScripts: string[];
}

interface CommandSegment {
  words: string[];
  stdinScripts: string[];
}

interface TokenizedShell {
  segments: CommandSegment[];
  substitutions: string[];
}

interface WrapperSpec {
  shortArgFlags: ReadonlySet<string>;
  longArgFlags: ReadonlySet<string>;
  shortScriptFlags?: ReadonlySet<string>;
  longScriptFlags?: ReadonlySet<string>;
  scriptPrefix?: string;
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
    longArgFlags: new Set(["--unset", "--chdir"]),
    shortScriptFlags: new Set(["S"]),
    longScriptFlags: new Set(["--split-string"]),
    scriptPrefix: "env ",
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
    shortArgFlags: new Set(["I", "L", "n", "P", "s", "S", "E", "d", "a", "J", "R"]),
    longArgFlags: new Set(["--max-args", "--max-procs", "--delimiter", "--arg-file"]),
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

function parseCloudMode(raw: string | undefined): CloudMode | undefined {
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

function nextNonContIdx(input: string, idx: number): number {
  let i = idx;
  while (i < input.length) {
    const cont = lineContinuationLen(input, i);
    if (cont === 0) break;
    i += cont;
  }
  return i;
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

function stripLineContinuations(raw: string): string {
  let out = "";
  let i = 0;
  while (i < raw.length) {
    const ch = raw[i];
    if (ch === "'") {
      const end = skipSingleQuoted(raw, i, false);
      out += raw.slice(i, end);
      i = end;
      continue;
    }
    const cont = lineContinuationLen(raw, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    if (ch === "\\" && i + 1 < raw.length) {
      out += raw.slice(i, i + 2);
      i += 2;
      continue;
    }
    if (ch === "$") {
      const next = nextNonContIdx(raw, i + 1);
      if (raw[next] === "'") {
        const end = skipSingleQuoted(raw, next, true);
        out += `$${raw.slice(next, end)}`;
        i = end;
        continue;
      }
    }
    out += ch;
    i += 1;
  }
  return out;
}

function decodeAnsiCSegment(raw: string, openQuoteIdx: number): { text: string; end: number } {
  let text = "";
  let i = openQuoteIdx + 1;
  while (i < raw.length && raw[i] !== "'") {
    if (raw[i] === "\\") {
      const dec = decodeAnsiCEscape(raw, i);
      text += dec.ch;
      i = dec.end;
    } else {
      text += raw[i];
      i += 1;
    }
  }
  return { text, end: raw[i] === "'" ? i + 1 : i };
}

function unquoteWord(raw: string): string {
  let out = "";
  let inDouble = false;
  let i = 0;
  while (i < raw.length) {
    const cont = lineContinuationLen(raw, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    const ch = raw[i];
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
    } else if (ch === "$" && (raw[nextNonContIdx(raw, i + 1)] === "'" || raw[nextNonContIdx(raw, i + 1)] === '"')) {
      const next = nextNonContIdx(raw, i + 1);
      if (raw[next] === "'") {
        const dec = decodeAnsiCSegment(raw, next);
        out += dec.text;
        i = dec.end;
      } else {
        inDouble = true;
        i = next + 1;
      }
    } else if (ch === '"') {
      inDouble = true;
      i += 1;
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

function stepDollar(
  input: string,
  dollarIdx: number,
  inDouble: boolean,
  substitutions: string[] | undefined,
  nestedDepth: number,
): { end: number; enteredDouble: boolean } {
  const next = nextNonContIdx(input, dollarIdx + 1);
  if (input[next] === "(" && nestedDepth < MAX_SHELL_PARSE_DEPTH + 2) {
    const sub = readCommandSubst(input, next, nestedDepth + 1);
    substitutions?.push(sub.content);
    return { end: sub.end, enteredDouble: false };
  }
  if (input[next] === "{" && nestedDepth < MAX_SHELL_PARSE_DEPTH + 2) {
    return { end: skipParamExpansion(input, next, substitutions, nestedDepth + 1), enteredDouble: false };
  }
  if (!inDouble && input[next] === "'") {
    return { end: skipSingleQuoted(input, next, true), enteredDouble: false };
  }
  if (!inDouble && input[next] === '"') {
    return { end: next + 1, enteredDouble: true };
  }
  return { end: dollarIdx + 1, enteredDouble: false };
}

function skipParamExpansion(
  input: string,
  openBraceIdx: number,
  substitutions: string[] | undefined,
  nestedDepth = 0,
): number {
  let depth = 1;
  let inDouble = false;
  let i = openBraceIdx + 1;
  while (i < input.length && depth > 0) {
    const cont = lineContinuationLen(input, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    const ch = input[i];
    if (ch === "\\" && i + 1 < input.length) {
      i += 2;
    } else if (ch === "$") {
      const step = stepDollar(input, i, inDouble, substitutions, nestedDepth);
      if (step.enteredDouble) inDouble = true;
      i = step.end;
    } else if (ch === "`") {
      const sub = readBacktick(input, i, inDouble);
      substitutions?.push(sub.content);
      i = sub.end;
    } else if (inDouble) {
      if (ch === '"') inDouble = false;
      i += 1;
    } else if (ch === "'") {
      i = skipSingleQuoted(input, i, false);
    } else if (ch === '"') {
      inDouble = true;
      i += 1;
    } else {
      if (ch === "{") depth += 1;
      else if (ch === "}") depth -= 1;
      i += 1;
    }
  }
  return i;
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
  pendingHeredocs: PendingHeredoc[];
}

function queueHeredoc(
  input: string,
  afterOpIdx: number,
  stripTabs: boolean,
  pendingHeredocs: PendingHeredoc[],
  targetScripts: string[],
): number {
  let i = afterOpIdx;
  while (i < input.length && (input[i] === " " || input[i] === "\t")) i += 1;
  const delimWord = readShellWord(input, i, []);
  const cleanRaw = stripLineContinuations(delimWord.raw);
  const delimiter = unquoteWord(cleanRaw);
  if (delimiter) {
    pendingHeredocs.push({ delimiter, quoted: /['"\\]/.test(cleanRaw), stripTabs, targetScripts });
  }
  return delimWord.end;
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
  if (ch === "\n" && state.pendingHeredocs.length > 0) {
    const end = consumeHeredocs(input, i + 1, state.pendingHeredocs, []);
    state.pendingHeredocs.length = 0;
    return end;
  }
  if (ch === "<" && input[i + 1] === "<" && input[i + 2] !== "<") {
    const stripTabs = input[i + 2] === "-";
    return queueHeredoc(input, i + (stripTabs ? 3 : 2), stripTabs, state.pendingHeredocs, []);
  }
  const top = caseStack[caseStack.length - 1];
  if (ch === ";" && top && top.depth === state.depth) {
    if (input.slice(i, i + 3) === ";;&") {
      top.inPattern = true;
      return i + 3;
    }
    if (input[i + 1] === ";" || input[i + 1] === "&") {
      top.inPattern = true;
      return i + 2;
    }
  }
  if (ch === "(") {
    state.depth += 1;
  } else if (ch === ")") {
    if (top && top.inPattern && top.depth === state.depth) top.inPattern = false;
    else {
      state.depth -= 1;
      if (top && top.inPattern && top.depth === state.depth) top.inPattern = false;
    }
  }
  return i + 1;
}

function readCommandSubst(input: string, openParenIdx: number, nestedDepth = 0): { content: string; end: number } {
  const state: SubstState = { depth: 1, curWord: "", caseStack: [], pendingHeredocs: [] };
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
    } else if (ch === "$") {
      const step = stepDollar(input, i, inDouble, undefined, nestedDepth);
      if (step.enteredDouble) inDouble = true;
      atWordStart = false;
      state.curWord = "";
      i = step.end;
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
    } else if (ch === "'" || ch === '"') {
      i = ch === "'" ? skipSingleQuoted(input, i, false) : i + 1;
      if (ch === '"') inDouble = true;
      atWordStart = false;
      state.curWord = "";
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
    } else if (ch === "$") {
      const step = stepDollar(input, i, inDouble, substitutions, 0);
      if (step.enteredDouble) inDouble = true;
      i = step.end;
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
    } else if (ch === "'") {
      i = skipSingleQuoted(input, i, false);
    } else if (ch === '"') {
      inDouble = true;
      i += 1;
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
    if (ch === "$") {
      const next = nextNonContIdx(body, i + 1);
      if (body[next] === "(") {
        const sub = readCommandSubst(body, next);
        substitutions.push(sub.content);
        i = sub.end;
        continue;
      }
      if (body[next] === "{") {
        i = skipParamExpansion(body, next, substitutions);
        continue;
      }
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
    if (bodyEnd > bodyStart) {
      const body = input.slice(bodyStart, bodyEnd);
      hd.targetScripts.push(body);
      if (!hd.quoted) scanHeredocSubstitutions(body, substitutions);
    }
  }
  return i;
}

function consumeRedirection(
  input: string,
  afterOpIdx: number,
  op: string,
  currentSeg: CommandSegment,
  pendingHeredocs: PendingHeredoc[],
  substitutions: string[],
): number {
  if (!op.endsWith("<<<") && (op.endsWith("<<") || op.endsWith("<<-"))) {
    return queueHeredoc(input, afterOpIdx, op.endsWith("-"), pendingHeredocs, currentSeg.stdinScripts);
  }
  let i = afterOpIdx;
  while (i < input.length) {
    const cont = lineContinuationLen(input, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    if (input[i] === " " || input[i] === "\t") {
      i += 1;
      continue;
    }
    break;
  }
  if (i >= input.length || /[ \t\r\n;|&()]/.test(input[i])) return i;
  const target = readShellWord(input, i, substitutions);
  if (op.endsWith("<<<") && target.raw) {
    currentSeg.stdinScripts.push(unquoteWord(target.raw));
  }
  return target.end;
}

function tokenizeShell(input: string): TokenizedShell {
  const segments: CommandSegment[] = [];
  const substitutions: string[] = [];
  const pendingHeredocs: PendingHeredoc[] = [];
  let current: CommandSegment = { words: [], stdinScripts: [] };
  const flush = (): void => {
    if (current.words.length > 0) segments.push(current);
    current = { words: [], stdinScripts: [] };
  };
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
      flush();
      i += 1;
      if (pendingHeredocs.length > 0) {
        i = consumeHeredocs(input, i, pendingHeredocs, substitutions);
        pendingHeredocs.length = 0;
      }
      continue;
    }
    const two = input.slice(i, i + 2);
    if (two === "&&" || two === "||" || two === "|&") {
      flush();
      i += 2;
      continue;
    }
    const redir = two !== "<(" && two !== ">(" ? REDIR_PREFIX_RE.exec(input.slice(i)) : null;
    if (redir) {
      i = consumeRedirection(input, i + redir[0].length, redir[0], current, pendingHeredocs, substitutions);
      continue;
    }
    if (ch === ";" || ch === "(" || ch === ")" || ch === "|" || ch === "&") {
      flush();
      i += 1;
      continue;
    }
    const word = readShellWord(input, i, substitutions);
    if (word.raw) current.words.push(word.raw);
    i = word.end > i ? word.end : i + 1;
  }
  flush();
  return { segments, substitutions };
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
      const rawScript = rest || (idx + 1 < words.length ? unquoteWord(words[idx + 1]) : "");
      if (rawScript) {
        const payload = spec.scriptPrefix ? `${spec.scriptPrefix}${rawScript}` : rawScript;
        const hit = detectCloudCliInvocation(payload, depth + 1);
        if (hit) return { detected: hit, advance: words.length };
      }
      return { advance: rest ? 1 : 2 };
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
        const payload = script && spec.scriptPrefix ? `${spec.scriptPrefix}${script}` : script;
        const hit = payload ? detectCloudCliInvocation(payload, depth + 1) : null;
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

function inspectShellInvocation(
  words: string[],
  start: number,
  stdinScripts: string[],
  depth: number,
): CloudDetection {
  let i = start;
  let hasDashC = false;
  let hasDashN = false;
  let hasDashS = false;
  while (i < words.length) {
    const w = unquoteWord(words[i]);
    if (w === "--" || w === "-") {
      i += 1;
      break;
    }
    if (w.startsWith("--") && w.length > 2) {
      i += SHELL_LONG_ARG_FLAGS.has(w) ? 2 : 1;
      continue;
    }
    if ((w.startsWith("-") || w.startsWith("+")) && w.length > 1) {
      let advance = 1;
      for (let k = 1; k < w.length; k += 1) {
        const ch = w[k];
        if (w[0] === "-" && ch === "c") hasDashC = true;
        else if (w[0] === "-" && ch === "n") hasDashN = true;
        else if (w[0] === "-" && ch === "s") hasDashS = true;
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
  if (hasDashN) return null;
  if (hasDashC) return i < words.length ? detectCloudCliInvocation(unquoteWord(words[i]), depth + 1) : null;
  if (i >= words.length || hasDashS) {
    for (const script of stdinScripts) {
      const hit = detectCloudCliInvocation(script, depth + 1);
      if (hit) return hit;
    }
  }
  return null;
}

function inspectCommandSegment(segment: CommandSegment, depth: number): CloudDetection {
  const { words, stdinScripts } = segment;
  let i = 0;
  while (i < words.length) {
    const raw = words[i];
    const unquoted = unquoteWord(raw);
    if (ENV_ASSIGN_RE.test(unquoted) || SHELL_PREFIX_KEYWORDS.has(stripLineContinuations(raw))) {
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
    if (SHELL_BINARIES.has(base)) return inspectShellInvocation(words, i + 1, stdinScripts, depth);
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
  const { segments, substitutions } = tokenizeShell(command);
  for (const segment of segments) {
    const hit = inspectCommandSegment(segment, depth);
    if (hit) return hit;
  }
  for (const sub of substitutions) {
    const hit = detectCloudCliInvocation(sub, depth + 1);
    if (hit) return hit;
  }
  return null;
}
