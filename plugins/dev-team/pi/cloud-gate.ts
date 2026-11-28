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
const CMD_POS_KEYWORDS: ReadonlySet<string> = new Set([...SHELL_PREFIX_KEYWORDS, "time"]);
const SHELL_BINARIES: ReadonlySet<string> = new Set(["sh", "bash", "zsh", "dash", "ksh", "csh", "tcsh"]);
const SHELL_LONG_ARG_FLAGS: ReadonlySet<string> = new Set(["--rcfile", "--init-file"]);

interface ParseContext {
  substitutions?: string[];
  depthExceeded: boolean;
}

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
  depthExceeded: boolean;
}

interface WrapperSpec {
  shortArgFlags: ReadonlySet<string>;
  longArgFlags: ReadonlySet<string>;
  shortScriptFlags?: ReadonlySet<string>;
  longScriptFlags?: ReadonlySet<string>;
  scriptPrefix?: string;
  decodeEnvS?: boolean;
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
    decodeEnvS: true,
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

const ENV_S_ESCAPES: Readonly<Record<string, string>> = {
  _: " ",
  t: "\t",
  n: "\n",
  r: "\r",
  f: "\f",
  v: "\v",
  "#": "#",
  "\\": "\\",
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

function skipHorizontalSpace(input: string, start: number): number {
  let i = start;
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

function skipSingleQuoted(input: string, openQuoteIdx: number): number {
  const close = input.indexOf("'", openQuoteIdx + 1);
  return close === -1 ? input.length : close + 1;
}

function skipAnsiCSingleQuoted(input: string, openQuoteIdx: number): number {
  let i = openQuoteIdx + 1;
  while (i < input.length) {
    if (input[i] === "\\" && i + 1 < input.length) {
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
      const end = skipSingleQuoted(raw, i);
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
        const end = skipAnsiCSingleQuoted(raw, next);
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
      const end = skipSingleQuoted(raw, i);
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

function matchRedirOp(input: string, start: number, allowFdPrefix: boolean): { op: string; end: number } | null {
  let p = start;
  let hasDigits = false;
  if (allowFdPrefix) {
    while (p < input.length && input[p] >= "0" && input[p] <= "9") {
      hasDigits = true;
      p += 1;
    }
    if (hasDigits) p = nextNonContIdx(input, p);
  }
  const c0 = input[p];
  if (c0 !== "<" && c0 !== ">" && c0 !== "&") return null;
  const p1 = nextNonContIdx(input, p + 1);
  const c1 = input[p1];
  const p2 = nextNonContIdx(input, p1 + 1);
  const c2 = input[p2];
  if (c0 === "&") {
    if (hasDigits || c1 !== ">") return null;
    return c2 === ">" ? { op: "&>>", end: p2 + 1 } : { op: "&>", end: p1 + 1 };
  }
  if (c0 === "<") {
    if (c1 === "(") return null;
    if (c1 === "<") {
      if (c2 === "<") return { op: "<<<", end: p2 + 1 };
      if (c2 === "-") return { op: "<<-", end: p2 + 1 };
      return { op: "<<", end: p1 + 1 };
    }
    return c1 === ">" || c1 === "&" ? { op: `<${c1}`, end: p1 + 1 } : { op: "<", end: p + 1 };
  }
  if (c1 === "(") return null;
  return c1 === ">" || c1 === "|" || c1 === "&" ? { op: `>${c1}`, end: p1 + 1 } : { op: ">", end: p + 1 };
}

function skipArithExpr(
  input: string,
  secondOpenIdx: number,
  ctx: ParseContext,
  nestedDepth: number,
): { closed: boolean; end: number } {
  let parenDepth = 0;
  let inDouble = false;
  let i = secondOpenIdx + 1;
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
      const step = stepDollar(input, i, inDouble, ctx, nestedDepth);
      if (step.enteredDouble) inDouble = true;
      i = step.end;
    } else if (ch === "`") {
      const sub = readBacktick(input, i, inDouble);
      ctx.substitutions?.push(sub.content);
      i = sub.end;
    } else if (inDouble) {
      if (ch === '"') inDouble = false;
      i += 1;
    } else if (ch === "'") {
      i = skipSingleQuoted(input, i);
    } else if (ch === '"') {
      inDouble = true;
      i += 1;
    } else if (ch === "(") {
      parenDepth += 1;
      i += 1;
    } else if (ch === ")") {
      if (parenDepth > 0) {
        parenDepth -= 1;
        i += 1;
      } else {
        const next = nextNonContIdx(input, i + 1);
        if (input[next] === ")") return { closed: true, end: next + 1 };
        return { closed: false, end: i };
      }
    } else {
      i += 1;
    }
  }
  return { closed: false, end: i };
}

function stepDollar(
  input: string,
  dollarIdx: number,
  inDouble: boolean,
  ctx: ParseContext,
  nestedDepth: number,
): { end: number; enteredDouble: boolean } {
  const next = nextNonContIdx(input, dollarIdx + 1);
  if (input[next] === "(" || input[next] === "{") {
    if (nestedDepth >= MAX_SHELL_PARSE_DEPTH) {
      ctx.depthExceeded = true;
      return { end: input.length, enteredDouble: false };
    }
    if (input[next] === "(") {
      const next2 = nextNonContIdx(input, next + 1);
      if (input[next2] === "(") {
        const arith = skipArithExpr(input, next2, ctx, nestedDepth + 1);
        if (arith.closed) return { end: arith.end, enteredDouble: false };
      }
      const sub = readCommandSubst(input, next, ctx, nestedDepth + 1);
      ctx.substitutions?.push(sub.content);
      return { end: sub.end, enteredDouble: false };
    }
    return { end: skipParamExpansion(input, next, inDouble, ctx, nestedDepth + 1), enteredDouble: false };
  }
  if (!inDouble && input[next] === "'") {
    return { end: skipAnsiCSingleQuoted(input, next), enteredDouble: false };
  }
  if (!inDouble && input[next] === '"') {
    return { end: next + 1, enteredDouble: true };
  }
  return { end: dollarIdx + 1, enteredDouble: false };
}

function skipParamExpansion(
  input: string,
  openBraceIdx: number,
  outerDouble: boolean,
  ctx: ParseContext,
  nestedDepth: number,
): number {
  let inDouble = false;
  let i = openBraceIdx + 1;
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
      const step = stepDollar(input, i, outerDouble || inDouble, ctx, nestedDepth);
      if (step.enteredDouble) inDouble = true;
      i = step.end;
    } else if (ch === "`") {
      const sub = readBacktick(input, i, outerDouble || inDouble);
      ctx.substitutions?.push(sub.content);
      i = sub.end;
    } else if (inDouble) {
      if (ch === '"') inDouble = false;
      i += 1;
    } else if (!outerDouble && ch === "'") {
      i = skipSingleQuoted(input, i);
    } else if (ch === '"') {
      inDouble = true;
      i += 1;
    } else if (ch === "}") {
      return i + 1;
    } else {
      i += 1;
    }
  }
  return i;
}

interface CaseFrame {
  depth: number;
  stage: "word" | "in" | "pattern" | "body";
}

interface SubstState {
  depth: number;
  curWord: string;
  curWordQuoted: boolean;
  inCmdPos: boolean;
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
  const i = skipHorizontalSpace(input, afterOpIdx);
  const delimWord = readShellWord(input, i, { depthExceeded: false });
  if (delimWord.raw.length > 0) {
    const cleanRaw = stripLineContinuations(delimWord.raw);
    const delimiter = unquoteWord(cleanRaw);
    pendingHeredocs.push({ delimiter, quoted: /['"\\]/.test(cleanRaw), stripTabs, targetScripts });
  }
  return delimWord.end;
}

function finishSubstWord(state: SubstState): void {
  const hasWord = state.curWord.length > 0 || state.curWordQuoted;
  const word = state.curWordQuoted ? "" : state.curWord;
  state.curWord = "";
  state.curWordQuoted = false;
  if (!hasWord) return;
  const top = state.caseStack[state.caseStack.length - 1];
  if (top && top.depth === state.depth && top.stage === "word") {
    top.stage = "in";
    state.inCmdPos = false;
    return;
  }
  if (top && top.depth === state.depth && top.stage === "in") {
    if (word === "in") top.stage = "pattern";
    else state.caseStack.pop();
    state.inCmdPos = false;
    return;
  }
  if (state.inCmdPos && word === "case") {
    state.caseStack.push({ depth: state.depth, stage: "word" });
    state.inCmdPos = false;
    return;
  }
  if (top && top.depth === state.depth && word === "esac" && (state.inCmdPos || top.stage === "pattern")) {
    state.caseStack.pop();
    state.inCmdPos = false;
    return;
  }
  if (state.inCmdPos && (CMD_POS_KEYWORDS.has(word) || ENV_ASSIGN_RE.test(word))) return;
  state.inCmdPos = false;
}

function trySkipArithCompound(input: string, openParenIdx: number, ctx: ParseContext, nestedDepth: number): number {
  const next = nextNonContIdx(input, openParenIdx + 1);
  if (input[next] !== "(") return -1;
  const arith = skipArithExpr(input, next, ctx, nestedDepth);
  return arith.closed ? arith.end : -1;
}

function stepSubstOperator(input: string, i: number, state: SubstState, ctx: ParseContext, nestedDepth: number): number {
  finishSubstWord(state);
  const ch = input[i];
  if (ch === " " || ch === "\t" || ch === "\r") return i + 1;
  if (ch === "\n") {
    state.inCmdPos = true;
    if (state.pendingHeredocs.length === 0) return i + 1;
    const end = consumeHeredocs(input, i + 1, state.pendingHeredocs, { depthExceeded: false });
    state.pendingHeredocs.length = 0;
    return end;
  }
  if (ch === "<" || ch === ">") {
    const redir = matchRedirOp(input, i, false);
    if (redir) {
      return redir.op === "<<" || redir.op === "<<-"
        ? queueHeredoc(input, redir.end, redir.op.endsWith("-"), state.pendingHeredocs, [])
        : redir.end;
    }
  }
  const top = state.caseStack[state.caseStack.length - 1];
  if (ch === ";" && top && top.depth === state.depth) {
    const step = input.slice(i, i + 3) === ";;&" ? 3 : input[i + 1] === ";" || input[i + 1] === "&" ? 2 : 0;
    if (step > 0) {
      top.stage = "pattern";
      state.inCmdPos = true;
      return i + step;
    }
  }
  if (ch === ";" || ch === "|" || ch === "&") {
    state.inCmdPos = true;
    return i + 1;
  }
  if (ch === "(") {
    const arithEnd = trySkipArithCompound(input, i, ctx, nestedDepth);
    if (arithEnd >= 0) {
      state.inCmdPos = false;
      return arithEnd;
    }
    state.depth += 1;
    state.inCmdPos = true;
    return i + 1;
  }
  if (ch === ")") {
    if (!(top && top.stage === "pattern" && top.depth === state.depth)) state.depth -= 1;
    const closedPattern = Boolean(top && top.stage === "pattern" && top.depth === state.depth);
    if (closedPattern) top.stage = "body";
    state.inCmdPos = closedPattern;
  }
  return i + 1;
}

function readCommandSubst(
  input: string,
  openParenIdx: number,
  outerCtx: ParseContext,
  nestedDepth = 0,
): { content: string; end: number } {
  const innerCtx: ParseContext = { depthExceeded: false };
  const state: SubstState = { depth: 1, curWord: "", curWordQuoted: false, inCmdPos: true, caseStack: [], pendingHeredocs: [] };
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
      state.curWordQuoted = true;
      i += 2;
    } else if (ch === "$") {
      const step = stepDollar(input, i, inDouble, innerCtx, nestedDepth);
      if (step.enteredDouble) inDouble = true;
      atWordStart = false;
      state.curWordQuoted = true;
      i = step.end;
    } else if (ch === "`") {
      i = readBacktick(input, i, inDouble).end;
      atWordStart = false;
      state.curWordQuoted = true;
    } else if (inDouble) {
      if (ch === '"') inDouble = false;
      i += 1;
    } else if (atWordStart && ch === "#") {
      const nl = input.indexOf("\n", i);
      i = nl === -1 ? input.length : nl;
    } else if (ch === "'" || ch === '"') {
      i = ch === "'" ? skipSingleQuoted(input, i) : i + 1;
      if (ch === '"') inDouble = true;
      atWordStart = false;
      state.curWordQuoted = true;
    } else if (/[ \t\r\n;|&()<>]/.test(ch)) {
      atWordStart = true;
      i = stepSubstOperator(input, i, state, innerCtx, nestedDepth);
    } else {
      state.curWord += ch;
      atWordStart = false;
      i += 1;
    }
  }
  if (innerCtx.depthExceeded) outerCtx.depthExceeded = true;
  return { content: input.slice(openParenIdx + 1, state.depth === 0 ? i - 1 : i), end: i };
}

function readShellWord(input: string, start: number, ctx: ParseContext): { raw: string; end: number } {
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
      const step = stepDollar(input, i, inDouble, ctx, 0);
      if (step.enteredDouble) inDouble = true;
      i = step.end;
    } else if (ch === "`") {
      const sub = readBacktick(input, i, inDouble);
      ctx.substitutions?.push(sub.content);
      i = sub.end;
    } else if (inDouble) {
      if (ch === '"') inDouble = false;
      i += 1;
    } else if ((ch === "<" || ch === ">") && input[i + 1] === "(") {
      const sub = readCommandSubst(input, i + 1, ctx);
      ctx.substitutions?.push(sub.content);
      i = sub.end;
    } else if (ch === "'") {
      i = skipSingleQuoted(input, i);
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

function scanHeredocSubstitutions(body: string, ctx: ParseContext): void {
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
      i = stepDollar(body, i, true, ctx, 0).end;
      continue;
    }
    if (ch === "`") {
      const sub = readBacktick(body, i, false);
      ctx.substitutions?.push(sub.content);
      i = sub.end;
      continue;
    }
    i += 1;
  }
}

function expandUnquotedHeredoc(body: string): string {
  let out = "";
  let i = 0;
  while (i < body.length) {
    const cont = lineContinuationLen(body, i);
    if (cont > 0) {
      i += cont;
      continue;
    }
    if (body[i] === "\\" && i + 1 < body.length && "$`\\".includes(body[i + 1])) {
      out += body[i + 1];
      i += 2;
      continue;
    }
    out += body[i];
    i += 1;
  }
  return out;
}

function consumeHeredocs(input: string, start: number, queue: PendingHeredoc[], ctx: ParseContext): number {
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
      hd.targetScripts.push(hd.quoted ? body : expandUnquotedHeredoc(body));
      if (!hd.quoted) scanHeredocSubstitutions(body, ctx);
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
  ctx: ParseContext,
): number {
  if (op === "<<" || op === "<<-") {
    return queueHeredoc(input, afterOpIdx, op.endsWith("-"), pendingHeredocs, currentSeg.stdinScripts);
  }
  const i = skipHorizontalSpace(input, afterOpIdx);
  if (i >= input.length || /[ \t\r\n;|&()]/.test(input[i])) return i;
  const target = readShellWord(input, i, ctx);
  if (op === "<<<" && target.raw) {
    currentSeg.stdinScripts.push(unquoteWord(target.raw));
  }
  return target.end;
}

function tokenizeShell(input: string): TokenizedShell {
  const segments: CommandSegment[] = [];
  const ctx: ParseContext = { substitutions: [], depthExceeded: false };
  const pendingHeredocs: PendingHeredoc[] = [];
  let current: CommandSegment = { words: [], stdinScripts: [] };
  const flush = (): void => {
    if (current.words.length > 0) segments.push(current);
    current = { words: [], stdinScripts: [] };
  };
  let i = 0;
  while (i < input.length) {
    i = skipHorizontalSpace(input, i);
    if (i >= input.length) break;
    const ch = input[i];
    if (ch === "\r") {
      i += 1;
    } else if (ch === "#") {
      const nl = input.indexOf("\n", i);
      i = nl === -1 ? input.length : nl;
    } else if (ch === "\n") {
      flush();
      i += 1;
      if (pendingHeredocs.length > 0) {
        i = consumeHeredocs(input, i, pendingHeredocs, ctx);
        pendingHeredocs.length = 0;
      }
    } else if (input.slice(i, i + 2) === "&&" || input.slice(i, i + 2) === "||" || input.slice(i, i + 2) === "|&") {
      flush();
      i += 2;
    } else {
      const arithEnd = ch === "(" ? trySkipArithCompound(input, i, ctx, 0) : -1;
      const redir = arithEnd >= 0 ? null : matchRedirOp(input, i, true);
      if (arithEnd >= 0) {
        flush();
        i = arithEnd;
      } else if (redir) {
        i = consumeRedirection(input, redir.end, redir.op, current, pendingHeredocs, ctx);
      } else if (ch === ";" || ch === "(" || ch === ")" || ch === "|" || ch === "&") {
        flush();
        i += 1;
      } else {
        const word = readShellWord(input, i, ctx);
        if (word.raw) current.words.push(word.raw);
        i = word.end > i ? word.end : i + 1;
      }
    }
  }
  flush();
  return { segments, substitutions: ctx.substitutions!, depthExceeded: ctx.depthExceeded };
}

function decodeEnvSplitString(raw: string): string {
  let out = "";
  let i = 0;
  while (i < raw.length) {
    if (raw[i] === "\\" && i + 1 < raw.length) {
      const next = raw[i + 1];
      if (next === "c") break;
      if (next in ENV_S_ESCAPES) {
        out += ENV_S_ESCAPES[next];
        i += 2;
        continue;
      }
    }
    out += raw[i];
    i += 1;
  }
  return out;
}

function inspectScriptPayload(script: string, spec: WrapperSpec, depth: number): CloudDetection {
  const body = spec.decodeEnvS ? decodeEnvSplitString(script) : script;
  const payload = spec.scriptPrefix ? `${spec.scriptPrefix}${body}` : body;
  return payload ? detectCloudCliInvocation(payload, depth + 1) : null;
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
        const hit = inspectScriptPayload(rawScript, spec, depth);
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
        const hit = script ? inspectScriptPayload(script, spec, depth) : null;
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
      const isMinus = w[0] === "-";
      let extraArgs = 0;
      for (let k = 1; k < w.length; k += 1) {
        const ch = w[k];
        if (isMinus && ch === "c") hasDashC = true;
        else if (ch === "n") hasDashN = isMinus;
        else if (isMinus && ch === "s") hasDashS = true;
        else if (ch === "o" || ch === "O") {
          extraArgs += 1;
          const opt = ch === "o" && i + extraArgs < words.length ? unquoteWord(words[i + extraArgs]) : "";
          if (opt === "noexec") hasDashN = isMinus;
        }
      }
      i += 1 + extraArgs;
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
  const { segments, substitutions, depthExceeded } = tokenizeShell(command);
  if (depthExceeded) return { kind: "depth-exceeded" };
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
