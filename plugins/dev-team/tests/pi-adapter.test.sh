#!/usr/bin/env bash
# Tests for root package.json and plugins/dev-team/pi/dev-team.ts (Pi adapter).
# Run: bash plugins/dev-team/tests/pi-adapter.test.sh
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
PLUGIN="$REPO/plugins/dev-team"
EXT="$PLUGIN/pi/dev-team.ts"
PKG="$REPO/package.json"
PLUGIN_JSON="$PLUGIN/.claude-plugin/plugin.json"
MKT_JSON="$REPO/.claude-plugin/marketplace.json"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME"
export GATE_LEDGER_ROOT="$TMP/ledger"
unset GATE_LEDGER_GATES

pass=0
fail=0
check() {
  if [[ "$2" == "$3" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$1" "$3" "$2"
  fi
}

# --- Root package.json manifest checks ---
check "package.json exists" "$(test -f "$PKG" && echo yes || echo no)" "yes"
check "package.json name is my-dev-team" "$(jq -r .name "$PKG")" "my-dev-team"
check "package.json is private" "$(jq -r .private "$PKG")" "true"
check "package.json license is Apache-2.0" "$(jq -r .license "$PKG")" "Apache-2.0"
check "package.json keywords contains pi-package" "$(jq -r '.keywords | index("pi-package") != null' "$PKG")" "true"
check "package.json version matches plugin.json" "$(jq -r .version "$PKG")" "$(jq -r .version "$PLUGIN_JSON")"
check "package.json description matches plugin.json" "$(jq -r .description "$PKG")" "$(jq -r .description "$PLUGIN_JSON")"
check "package.json description matches marketplace top-level" "$(jq -r .description "$PKG")" "$(jq -r .description "$MKT_JSON")"
check "package.json description matches marketplace plugin entry" "$(jq -r .description "$PKG")" "$(jq -r '.plugins[0].description' "$MKT_JSON")"
check "package.json peerDependencies pins pi-coding-agent *" "$(jq -r '.peerDependencies["@earendil-works/pi-coding-agent"]' "$PKG")" "*"
check "package.json peerDependencies pins typebox *" "$(jq -r '.peerDependencies["typebox"]' "$PKG")" "*"
check "package.json dependencies omits host-provided packages" \
  "$(jq -r '(.dependencies // {}) | (has("@earendil-works/pi-coding-agent") or has("typebox"))' "$PKG")" "false"
check "package.json pi.extensions points to dev-team.ts" \
  "$(jq -r '.pi.extensions | index("./plugins/dev-team/pi/dev-team.ts") != null' "$PKG")" "true"
check "package.json pi.skills points to skills dir" \
  "$(jq -r '.pi.skills | index("./plugins/dev-team/skills") != null' "$PKG")" "true"

# --- Prepare isolated git repo, stub binaries, and fake plugin fixtures ---
TEST_REPO="$TMP/repo"
mkdir -p "$TEST_REPO"
git -C "$TEST_REPO" init -q -b main
git -C "$TEST_REPO" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "init"

STUB_BIN="$TMP/stubs"
mkdir -p "$STUB_BIN"

cat >"$STUB_BIN/agent-stub.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
name="${0##*/}"
prefix="$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
out_var="${prefix}_STUB_OUT"
stdout_var="${prefix}_STUB_STDOUT"
stderr_var="${prefix}_STUB_STDERR"
exit_var="${prefix}_STUB_EXIT"
marker_var="${prefix}_STUB_SLEEP_MARKER"
trap_var="${prefix}_STUB_TRAP_TERM_LOG"

out_dir="${!out_var:?}"
printf '%s\0' "$@" >"$out_dir/args.bin"
if [[ "$name" != "agy" ]]; then
  cat >"$out_dir/stdin.txt"
fi
printf '%s' "${CLAUDE_PLUGIN_ROOT:-}" >"$out_dir/plugin_root.txt"

trap_log="${!trap_var:-}"
if [[ -n "$trap_log" ]]; then
  exec node -e 'const fs=require("node:fs");let t;process.on("SIGTERM",()=>{fs.appendFileSync(process.argv[1],"TERM\n");if(!t)t=setTimeout(()=>process.exit(0),350);});setTimeout(()=>process.exit(0),5000);' "$trap_log"
fi
sleep_marker="${!marker_var:-}"
if [[ -n "$sleep_marker" ]]; then
  (sleep 1.2; touch "$sleep_marker") &
  wait
fi
if [[ -n "${!stderr_var:-}" ]]; then
  printf '%s\n' "${!stderr_var}" >&2
fi
if [[ -n "${!stdout_var:-}" ]]; then
  printf '%s\n' "${!stdout_var}"
fi
exit "${!exit_var:-0}"
EOF
chmod +x "$STUB_BIN/agent-stub.sh"
for bin in pi claude agy; do
  ln -s "$STUB_BIN/agent-stub.sh" "$STUB_BIN/$bin"
done

# Counting session-context wrapper for cache verification.
CACHE_PLUGIN="$TMP/cache-plugin"
mkdir -p "$CACHE_PLUGIN/hooks"
COUNT_FILE="$TMP/session-context-count.txt"
: >"$COUNT_FILE"
cat >"$CACHE_PLUGIN/hooks/session-context.sh" <<EOF
#!/usr/bin/env bash
printf 'call:%s\n' "\${1:-}" >>"$COUNT_FILE"
printf 'block=%s cwd=%s\n' "\${1:-}" "\$(jq -r '.cwd // empty')"
EOF
chmod +x "$CACHE_PLUGIN/hooks/session-context.sh"

# Broken session-context wrapper for graceful degradation verification.
BROKEN_PLUGIN="$TMP/broken-plugin"
mkdir -p "$BROKEN_PLUGIN/hooks"
cat >"$BROKEN_PLUGIN/hooks/session-context.sh" <<'EOF'
#!/usr/bin/env bash
echo "simulated failure" >&2
exit 1
EOF
chmod +x "$BROKEN_PLUGIN/hooks/session-context.sh"

# Empty plugin dir (missing hook scripts) for fail-closed check.
MISSING_HOOK_PLUGIN="$TMP/missing-hook-plugin"
mkdir -p "$MISSING_HOOK_PLUGIN/hooks"

# PATH directory without jq for fail-closed check.
NO_JQ_BIN="$TMP/no-jq-bin"
mkdir -p "$NO_JQ_BIN"
for util in bash env dirname cat rm mktemp grep sed awk tr; do
  if util_path="$(command -v "$util" 2>/dev/null)"; then
    ln -s "$util_path" "$NO_JQ_BIN/$util"
  fi
done

# Detect whether Node needs --experimental-strip-types (Node 22.6-22.17 vs 22.18+/26).
NODE_FLAGS=()
if ! node -e "import(process.argv[1])" "$EXT" >/dev/null 2>&1; then
  NODE_FLAGS=(--experimental-strip-types --no-warnings)
fi

RUNNER="$TMP/run-tests.mjs"
cat >"$RUNNER" <<'EOF'
import assert from "node:assert/strict";
import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";

const {
  EXT,
  PLUGIN,
  TEST_REPO,
  TMP,
  STUB_BIN,
  CACHE_PLUGIN,
  COUNT_FILE,
  BROKEN_PLUGIN,
  MISSING_HOOK_PLUGIN,
  NO_JQ_BIN,
} = process.env;

const { default: devTeamExtension } = await import(pathToFileURL(EXT).href);

function createHarness(options) {
  const handlers = new Map();
  const tools = new Map();
  const api = {
    on(event, fn) {
      handlers.set(event, fn);
    },
    registerTool(def) {
      tools.set(def.name, def);
    },
  };
  devTeamExtension(api, options);
  return { handlers, tools };
}

let passed = 0;
let failed = 0;
async function test(name, fn) {
  try {
    await fn();
    passed += 1;
  } catch (err) {
    failed += 1;
    process.stderr.write(`FAIL: ${name}\n  ${err instanceof Error ? err.message : String(err)}\n`);
  }
}

const origPath = process.env.PATH ?? "";
const stubPath = `${STUB_BIN}${path.delimiter}${origPath}`;
const readArgs = (dir) => {
  const raw = fs.readFileSync(path.join(dir, "args.bin"), "utf8");
  return raw.endsWith("\0") ? raw.slice(0, -1).split("\0") : raw.split("\0");
};

async function withStubEnv(prefix, dirName, env, fn) {
  const outDir = path.join(TMP, dirName);
  fs.mkdirSync(outDir, { recursive: true });
  const keys = [`${prefix}_STUB_OUT`, ...Object.keys(env)];
  process.env.PATH = stubPath;
  process.env[`${prefix}_STUB_OUT`] = outDir;
  for (const [k, v] of Object.entries(env)) process.env[k] = v;
  try {
    return await fn(outDir);
  } finally {
    for (const k of keys) delete process.env[k];
    process.env.PATH = origPath;
  }
}

// --- before_agent_start ---
await test("before_agent_start injects policy and process into systemPromptOptions.sections['dev-team']", async () => {
  const { handlers } = createHarness();
  const fn = handlers.get("before_agent_start");
  assert.equal(typeof fn, "function");
  const event = { systemPromptOptions: { sections: {} } };
  await fn(event, { cwd: TEST_REPO, hasUI: false });
  const section = event.systemPromptOptions.sections["dev-team"];
  assert.equal(typeof section, "string");
  assert.ok(section.includes(`Plugin root (\`\${CLAUDE_PLUGIN_ROOT}\`): \`${PLUGIN}\``));
  assert.ok(section.includes("# Harness policy (dev-team plugin)"));
  assert.ok(section.includes(`${PLUGIN}/context/`));
  assert.ok(section.includes("# Development process"));
});

await test("before_agent_start caches per cwd and refreshes for a new cwd", async () => {
  const { handlers } = createHarness({ pluginRoot: CACHE_PLUGIN });
  const fn = handlers.get("before_agent_start");
  const dirA = path.join(TMP, "cwd-a");
  const dirB = path.join(TMP, "cwd-b");
  fs.mkdirSync(dirA, { recursive: true });
  fs.mkdirSync(dirB, { recursive: true });

  const ev1 = { systemPromptOptions: { sections: {} } };
  await fn(ev1, { cwd: dirA, hasUI: false });
  assert.equal(fs.readFileSync(COUNT_FILE, "utf8").trim().split("\n").filter(Boolean).length, 2);

  const ev2 = { systemPromptOptions: { sections: {} } };
  await fn(ev2, { cwd: dirA, hasUI: false });
  assert.equal(fs.readFileSync(COUNT_FILE, "utf8").trim().split("\n").filter(Boolean).length, 2);
  assert.equal(ev2.systemPromptOptions.sections["dev-team"], ev1.systemPromptOptions.sections["dev-team"]);

  const ev3 = { systemPromptOptions: { sections: {} } };
  await fn(ev3, { cwd: dirB, hasUI: false });
  assert.equal(fs.readFileSync(COUNT_FILE, "utf8").trim().split("\n").filter(Boolean).length, 4);
  assert.ok(ev3.systemPromptOptions.sections["dev-team"].includes(`cwd=${dirB}`));
});

await test("before_agent_start degrades gracefully when session-context hook fails", async () => {
  const { handlers } = createHarness({ pluginRoot: BROKEN_PLUGIN });
  const fn = handlers.get("before_agent_start");
  const warnings = [];
  const event = { systemPromptOptions: { sections: {} } };
  await fn(event, {
    cwd: TEST_REPO,
    hasUI: true,
    ui: { notify: (msg, level) => warnings.push({ msg, level }) },
  });
  assert.equal(event.systemPromptOptions.sections["dev-team"], undefined);
  assert.equal(warnings.length, 2);
  assert.equal(warnings[0].level, "warning");
});

await test("before_agent_start degrades gracefully when session-context hook is missing", async () => {
  const { handlers } = createHarness({ pluginRoot: MISSING_HOOK_PLUGIN });
  const fn = handlers.get("before_agent_start");
  const warnings = [];
  const event = { systemPromptOptions: { sections: {} } };
  await fn(event, {
    cwd: TEST_REPO,
    hasUI: true,
    ui: { notify: (msg, level) => warnings.push({ msg, level }) },
  });
  assert.equal(event.systemPromptOptions.sections["dev-team"], undefined);
  assert.equal(warnings.length, 1);
  assert.ok(warnings[0].msg.includes("not executable"));
});

// --- tool_call ---
const { handlers: realHandlers, tools: realTools } = createHarness();
const onToolCall = realHandlers.get("tool_call");
const runAgent = realTools.get("run_agent");

await test("tool_call allows safe git status", async () => {
  const res = await onToolCall({ toolName: "bash", input: { command: "git status" } }, { cwd: TEST_REPO });
  assert.equal(res, undefined);
});

await test("tool_call denies git push --force origin main via real merge-gate.sh", async () => {
  const res = await onToolCall(
    { toolName: "bash", input: { command: "git push --force origin main" } },
    { cwd: TEST_REPO },
  );
  assert.equal(res?.block, true);
  assert.ok(res.reason.includes("merge-gate"));
});

await test("tool_call denies Claude, Gemini, and Antigravity attribution trailers via real attribution-guard.sh", async () => {
  const trailers = [
    "Co-Authored-By: Cla" + "ude <noreply@example.com>",
    "Co-Authored-By: Agent <gem" + "ini@example.com>",
    "Generated with Anti" + "gravity",
  ];
  for (const trailer of trailers) {
    const res = await onToolCall(
      { toolName: "bash", input: { command: `git commit -m "Msg\n\n${trailer}"` } },
      { cwd: TEST_REPO },
    );
    assert.equal(res?.block, true, `expected block for ${trailer}`);
    assert.ok(res.reason.includes("attribution-guard"));
  }
});

await test("tool_call allows clean git commit", async () => {
  const res = await onToolCall(
    { toolName: "bash", input: { command: 'git commit -m "Plain commit message"' } },
    { cwd: TEST_REPO },
  );
  assert.equal(res, undefined);
});

await test("tool_call ignores non-bash tools", async () => {
  const res = await onToolCall(
    { toolName: "read", input: { command: "git push --force origin main" } },
    { cwd: TEST_REPO },
  );
  assert.equal(res, undefined);
});

await test("tool_call allows empty bash command", async () => {
  const res = await onToolCall({ toolName: "bash", input: { command: "" } }, { cwd: TEST_REPO });
  assert.equal(res, undefined);
});

await test("tool_call fails closed on non-string command", async () => {
  for (const bad of [["git", "status"], null, 42, undefined]) {
    const res = await onToolCall({ toolName: "bash", input: { command: bad } }, { cwd: TEST_REPO });
    assert.equal(res?.block, true);
    assert.ok(res.reason.includes("non-string"));
  }
});

await test("tool_call fails closed when jq is absent from PATH", async () => {
  process.env.PATH = NO_JQ_BIN;
  try {
    const res = await onToolCall(
      { toolName: "bash", input: { command: "git push --force origin main" } },
      { cwd: TEST_REPO },
    );
    assert.equal(res?.block, true);
    assert.ok(res.reason.includes("jq"));
  } finally {
    process.env.PATH = origPath;
  }
});

await test("tool_call fails closed when hook script is missing", async () => {
  const { handlers } = createHarness({ pluginRoot: MISSING_HOOK_PLUGIN });
  const res = await handlers.get("tool_call")(
    { toolName: "bash", input: { command: "git status" } },
    { cwd: TEST_REPO },
  );
  assert.equal(res?.block, true);
  assert.ok(res.reason.includes("not executable"));
});

// --- run_agent validation ---
const callAgent = (params, signal) => runAgent.execute("call-1", params, signal, undefined, { cwd: TEST_REPO });

await test("run_agent rejects unknown agent", async () => {
  await assert.rejects(() => callAgent({ agent: "unknown-agent", backend: "pi", prompt: "hi" }), /unknown agent/);
});

await test("run_agent rejects unknown backend", async () => {
  await assert.rejects(() => callAgent({ agent: "implementer", backend: "bogus", prompt: "hi" }), /unknown backend/);
});

await test("run_agent rejects omitted backend on review-gate agents", async () => {
  for (const gate of [
    "pr-reviewer",
    "code-health-reviewer",
    "oss-readiness-reviewer",
    "security-reviewer",
    "readme-reviewer",
  ]) {
    await assert.rejects(() => callAgent({ agent: gate, prompt: "review PR" }), /backend is required/);
  }
});

await test("run_agent rejects empty or whitespace prompt", async () => {
  await assert.rejects(() => callAgent({ agent: "implementer", prompt: "   " }), /non-empty/);
});

await test("run_agent rejects invalid timeoutSeconds", async () => {
  for (const bad of [0, -5, Number.NaN, Number.POSITIVE_INFINITY, 3601, "60"]) {
    await assert.rejects(
      () => callAgent({ agent: "implementer", prompt: "do work", timeoutSeconds: bad }),
      /timeoutSeconds/,
    );
  }
});

await test("run_agent rejects non-existent or non-directory cwd", async () => {
  await assert.rejects(
    () => callAgent({ agent: "implementer", prompt: "do work", cwd: path.join(TMP, "does-not-exist") }),
    /cwd does not exist/,
  );
  const filePath = path.join(TMP, "not-a-dir.txt");
  fs.writeFileSync(filePath, "x");
  await assert.rejects(
    () => callAgent({ agent: "implementer", prompt: "do work", cwd: filePath }),
    /cwd is not a directory/,
  );
});

await test("run_agent rejects flag-like model strings starting with -", async () => {
  await assert.rejects(
    () => callAgent({ agent: "implementer", backend: "pi", prompt: "do work", model: "--dangerously-skip" }),
    /invalid model/,
  );
  await assert.rejects(
    () => callAgent({ agent: "pr-reviewer", backend: "agy", prompt: "review", model: "-p" }),
    /invalid model/,
  );
});

await test("run_agent (claude) rejects versioned model IDs and enforces policy", async () => {
  await assert.rejects(
    () => callAgent({ agent: "pr-reviewer", backend: "claude", prompt: "review", model: "claude-sonnet-4-6" }),
    /alias/,
  );
  await assert.rejects(
    () => callAgent({ agent: "security-reviewer", backend: "claude", prompt: "review", model: "sonnet" }),
    /security-reviewer requires model "opus"/,
  );
  await assert.rejects(
    () => callAgent({ agent: "security-reviewer", backend: "claude", prompt: "review", model: "fable" }),
    /security-reviewer requires model "opus"/,
  );
  await assert.rejects(
    () => callAgent({ agent: "implementer", backend: "claude", prompt: "build", model: "fable" }),
    /only allowed for cold-reader/,
  );
  await assert.rejects(
    () => callAgent({ agent: "pr-reviewer", backend: "claude", prompt: "review", model: "fable" }),
    /only allowed for cold-reader/,
  );
});

await test("run_agent surfaces clear ENOENT remediation naming the missing binary", async () => {
  process.env.PATH = NO_JQ_BIN;
  try {
    await assert.rejects(
      () => callAgent({ agent: "pr-reviewer", backend: "claude", prompt: "review" }),
      /"claude" binary not found/,
    );
    await assert.rejects(
      () => callAgent({ agent: "pr-reviewer", backend: "agy", prompt: "review" }),
      /"agy" binary not found/,
    );
    await assert.rejects(
      () => callAgent({ agent: "implementer", backend: "pi", prompt: "build" }),
      /"pi" binary not found/,
    );
  } finally {
    process.env.PATH = origPath;
  }
});

await test("run_agent respects an already-aborted AbortSignal", async () => {
  const controller = new AbortController();
  controller.abort();
  process.env.PATH = stubPath;
  try {
    await assert.rejects(
      () => callAgent({ agent: "implementer", backend: "pi", prompt: "build" }, controller.signal),
      /aborted/,
    );
  } finally {
    process.env.PATH = origPath;
  }
});

// --- run_agent end-to-end with stubbed backends + real verdict-guard.sh ---
await test("run_agent defaults implementer to pi backend with write tools and stdin prompt", async () => {
  await withStubEnv("PI", "stub-pi-impl", { PI_STUB_STDOUT: "implemented slice", PI_STUB_EXIT: "0" }, async (outDir) => {
    const res = await callAgent({ agent: "implementer", prompt: "Build feature X" });
    const args = readArgs(outDir);
    const stdinText = fs.readFileSync(path.join(outDir, "stdin.txt"), "utf8");

    assert.equal(fs.readFileSync(path.join(outDir, "plugin_root.txt"), "utf8"), PLUGIN);
    assert.ok(args.includes("--print") && args.includes("--no-session") && args.includes("--no-extensions"));
    assert.equal(args[args.indexOf("-e") + 1], EXT);
    assert.equal(args[args.indexOf("--tools") + 1], "read,write,edit,find,ls,grep,bash");
    assert.equal(args[args.indexOf("--exclude-tools") + 1], "run_agent");
    assert.ok(stdinText.includes(`Plugin root (CLAUDE_PLUGIN_ROOT): ${PLUGIN}`));
    assert.ok(stdinText.includes(`${PLUGIN}/context/agent-baseline.md`));
    assert.ok(stdinText.includes("Build feature X"));
    assert.equal(res.details.backend, "pi");
    assert.equal(res.details.authoritative, false);
    assert.equal(res.details.exitCode, 0);
    assert.equal(res.details.verdictValid, undefined);
    assert.equal(res.content[0].text, "implemented slice");
  });
});

await test("run_agent (pi) restricts cold-reader to read-only without bash, edit, or write", async () => {
  await withStubEnv("PI", "stub-pi-cold", { PI_STUB_STDOUT: "cold read report", PI_STUB_EXIT: "0" }, async (outDir) => {
    const res = await callAgent({ agent: "cold-reader", prompt: "Read README.md" });
    const args = readArgs(outDir);
    assert.equal(args[args.indexOf("--tools") + 1], "read");
    assert.equal(res.details.backend, "pi");
    assert.equal(res.details.authoritative, false);
  });
});

await test("run_agent (pi) review gate prepends SELF-CHECK ONLY banner and runs real verdict-guard.sh", async () => {
  const validOut = "Looks good.\n\nGATE: code-health\nVERDICT: PASS\nHEAD: 8e6c495\nFINDINGS: 0";
  await withStubEnv("PI", "stub-pi-gate", { PI_STUB_STDOUT: validOut, PI_STUB_EXIT: "0" }, async (outDir) => {
    const res = await callAgent({ agent: "code-health-reviewer", backend: "pi", prompt: "Audit diff" });
    const args = readArgs(outDir);
    const stdinText = fs.readFileSync(path.join(outDir, "stdin.txt"), "utf8");
    const tools = args[args.indexOf("--tools") + 1].split(",");
    assert.ok(!tools.includes("edit") && !tools.includes("write"));
    assert.ok(stdinText.includes(path.join(PLUGIN, "skills", "code-health", "SKILL.md")));
    assert.equal(res.details.authoritative, false);
    assert.equal(res.details.verdictValid, true);
    assert.equal(res.details.verdictError, undefined);
    assert.ok(res.content[0].text.startsWith("[SELF-CHECK ONLY — NON-AUTHORITATIVE:"));

    process.env.PI_STUB_STDOUT = "Looks good with no verdict block";
    const badRes = await callAgent({ agent: "code-health-reviewer", backend: "pi", prompt: "Audit diff" });
    assert.equal(badRes.details.authoritative, false);
    assert.equal(badRes.details.verdictValid, false);
    assert.ok(badRes.details.verdictError.includes("verdict-guard"));
    assert.ok(badRes.content[0].text.includes("[SELF-CHECK ONLY — NON-AUTHORITATIVE:"));
    assert.ok(badRes.content[0].text.includes("[VERDICT GUARD FAILED:"));
  });
});

await test("run_agent (claude) delivers prompt via stdin, enforces read-only tools, and validates verdict", async () => {
  const validOut = "Clean.\n\nGATE: pr-reviewer\nVERDICT: PASS\nHEAD: 8e6c495\nFINDINGS: 0";
  await withStubEnv("CLAUDE", "stub-claude-pr", { CLAUDE_STUB_STDOUT: validOut, CLAUDE_STUB_EXIT: "0" }, async (outDir) => {
    const res = await callAgent({
      agent: "pr-reviewer",
      backend: "claude",
      model: "sonnet",
      prompt: "Review PR #1",
    });
    const args = readArgs(outDir);
    const stdinText = fs.readFileSync(path.join(outDir, "stdin.txt"), "utf8");
    assert.deepEqual(args, ["-p", "--model", "sonnet", "--tools", "Read,Glob,Grep,Bash,WebFetch"]);
    assert.ok(stdinText.includes("Review PR #1"));
    assert.equal(res.details.authoritative, true);
    assert.equal(res.details.verdictValid, true);
    assert.ok(!res.content[0].text.includes("SELF-CHECK ONLY"));
  });
});

await test("run_agent (claude) surfaces verdict-guard failure on inconsistent PASS/FINDINGS", async () => {
  const badOut = "GATE: security-review\nVERDICT: PASS\nHEAD: 8e6c495\nFINDINGS: 2";
  await withStubEnv("CLAUDE", "stub-claude-sec", { CLAUDE_STUB_STDOUT: badOut, CLAUDE_STUB_EXIT: "0" }, async (outDir) => {
    const res = await callAgent({ agent: "security-reviewer", backend: "claude", prompt: "Audit security" });
    const args = readArgs(outDir);
    assert.equal(args[args.indexOf("--model") + 1], "opus");
    assert.equal(res.details.authoritative, true);
    assert.equal(res.details.verdictValid, false);
    assert.ok(res.details.verdictError.includes("PASS requires zero findings"));
    assert.ok(res.content[0].text.includes("[VERDICT GUARD FAILED:"));
  });
});

await test("run_agent (claude) permits fable on cold-reader", async () => {
  await withStubEnv("CLAUDE", "stub-claude-cold", { CLAUDE_STUB_STDOUT: "Cold read notes", CLAUDE_STUB_EXIT: "0" }, async (outDir) => {
    const res = await callAgent({ agent: "cold-reader", backend: "claude", prompt: "Cold read" });
    assert.deepEqual(readArgs(outDir), ["-p", "--model", "fable", "--tools", "Read,WebFetch,WebSearch"]);
    assert.equal(res.details.authoritative, true);
  });
});

await test("run_agent (agy) uses --mode auto for implementer and --mode plan for gates with --print=<prompt>", async () => {
  await withStubEnv("AGY", "stub-agy-impl", { AGY_STUB_STDOUT: "agy implemented", AGY_STUB_EXIT: "0" }, async (outDir) => {
    const implRes = await callAgent({
      agent: "implementer",
      backend: "agy",
      model: "pro",
      timeoutSeconds: 120,
      prompt: "Implement widget",
    });
    const implArgs = readArgs(outDir);
    assert.equal(implArgs[implArgs.indexOf("--mode") + 1], "auto");
    assert.ok(implArgs.includes("--disable-slash-commands"));
    assert.equal(implArgs[implArgs.indexOf("--print-timeout") + 1], "120s");
    assert.equal(implArgs[implArgs.indexOf("--model") + 1], "pro");
    assert.ok(!implArgs.includes("--agent"));
    assert.ok(implArgs.some((a) => a.startsWith("--print=") && a.includes("Implement widget")));
    assert.equal(implRes.details.authoritative, true);
  });

  const gateOut = "GATE: readme-writer\nVERDICT: PASS\nHEAD: 8e6c495\nFINDINGS: 0";
  await withStubEnv("AGY", "stub-agy-gate", { AGY_STUB_STDOUT: gateOut, AGY_STUB_EXIT: "0" }, async (outDir) => {
    const gateRes = await callAgent({ agent: "readme-reviewer", backend: "agy", prompt: "Check README" });
    const gateArgs = readArgs(outDir);
    assert.equal(gateArgs[gateArgs.indexOf("--mode") + 1], "plan");
    assert.ok(!gateArgs.includes("--agent"));
    const printArg = gateArgs.find((a) => a.startsWith("--print="));
    assert.ok(printArg && printArg.includes(path.join(PLUGIN, "skills", "readme-writer", "SKILL.md")));
    assert.equal(gateRes.details.authoritative, true);
    assert.equal(gateRes.details.verdictValid, true);
  });
});

await test("run_agent (pi) forwards explicit --model and rejects empty review-gate output via verdict guard", async () => {
  await withStubEnv("PI", "stub-pi-model-empty", { PI_STUB_STDOUT: "", PI_STUB_EXIT: "0" }, async (outDir) => {
    const res = await callAgent({
      agent: "oss-readiness-reviewer",
      backend: "pi",
      model: "local-qwen",
      prompt: "Scan repo",
    });
    const args = readArgs(outDir);
    assert.equal(args[args.indexOf("--model") + 1], "local-qwen");
    assert.equal(res.details.authoritative, false);
    assert.equal(res.details.verdictValid, false);
    assert.ok(res.details.verdictError.includes("empty output"));
    assert.ok(res.content[0].text.includes("[SELF-CHECK ONLY — NON-AUTHORITATIVE:"));
    assert.ok(res.content[0].text.includes("[VERDICT GUARD FAILED:"));
  });
});

await test("run_agent returns exitCode and stderr on non-zero child exit", async () => {
  await withStubEnv("PI", "stub-pi-fail", { PI_STUB_STDOUT: "", PI_STUB_STDERR: "boom on stderr", PI_STUB_EXIT: "3" }, async () => {
    const res = await callAgent({ agent: "code-health-reviewer", backend: "pi", prompt: "Audit" });
    assert.equal(res.details.exitCode, 3);
    assert.equal(res.details.verdictValid, undefined);
    assert.ok(res.content[0].text.includes("exited with code 3"));
    assert.ok(res.content[0].text.includes("boom on stderr"));
  });
});

await test("run_agent timeout kills background grandchild process group promptly", async () => {
  const marker = path.join(TMP, "timeout-grandchild-marker");
  await withStubEnv("PI", "stub-pi-timeout", { PI_STUB_SLEEP_MARKER: marker }, async () => {
    const start = Date.now();
    await assert.rejects(
      () => callAgent({ agent: "implementer", backend: "pi", prompt: "Slow task", timeoutSeconds: 0.25 }),
      /timed out/,
    );
    const elapsed = Date.now() - start;
    assert.ok(elapsed < 1000, `expected timeout to settle promptly, took ${elapsed}ms`);
    await new Promise((r) => setTimeout(r, 1300));
    assert.equal(fs.existsSync(marker), false, "grandchild should be terminated with its process group");
  });
});

await test("run_agent mid-run abort kills background grandchild process group promptly", async () => {
  const marker = path.join(TMP, "abort-grandchild-marker");
  await withStubEnv("PI", "stub-pi-abort", { PI_STUB_SLEEP_MARKER: marker }, async () => {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 150);
    const start = Date.now();
    try {
      await assert.rejects(
        () => callAgent({ agent: "implementer", backend: "pi", prompt: "Abortable task" }, controller.signal),
        /aborted/,
      );
    } finally {
      clearTimeout(timer);
    }
    const elapsed = Date.now() - start;
    assert.ok(elapsed < 1000, `expected abort to settle promptly, took ${elapsed}ms`);
    await new Promise((r) => setTimeout(r, 1300));
    assert.equal(fs.existsSync(marker), false, "grandchild should be terminated with its process group");
  });
});

await test("run_agent timeout and abort racing against a SIGTERM-trapping child honors first trigger once", async () => {
  const timeoutFirstLog = path.join(TMP, "term-timeout-first.log");
  await withStubEnv("PI", "stub-pi-race-timeout", { PI_STUB_TRAP_TERM_LOG: timeoutFirstLog }, async () => {
    const controller = new AbortController();
    const abortTimer = setTimeout(() => controller.abort(), 280);
    try {
      await assert.rejects(
        () => callAgent({ agent: "implementer", backend: "pi", prompt: "Trap term", timeoutSeconds: 0.15 }, controller.signal),
        /timed out/,
      );
    } finally {
      clearTimeout(abortTimer);
    }
    const terms = fs.readFileSync(timeoutFirstLog, "utf8").trim().split("\n").filter(Boolean);
    assert.equal(terms.length, 1);
  });

  const abortFirstLog = path.join(TMP, "term-abort-first.log");
  await withStubEnv("PI", "stub-pi-race-abort", { PI_STUB_TRAP_TERM_LOG: abortFirstLog }, async () => {
    const controller = new AbortController();
    const abortTimer = setTimeout(() => controller.abort(), 150);
    try {
      await assert.rejects(
        () => callAgent({ agent: "implementer", backend: "pi", prompt: "Trap term", timeoutSeconds: 0.28 }, controller.signal),
        /aborted/,
      );
    } finally {
      clearTimeout(abortTimer);
    }
    const terms = fs.readFileSync(abortFirstLog, "utf8").trim().split("\n").filter(Boolean);
    assert.equal(terms.length, 1);
  });
});

process.stdout.write(`NODE_SUMMARY:${passed}:${failed}\n`);
process.exitCode = failed === 0 ? 0 : 1;
EOF

node_out="$(
  EXT="$EXT" \
  PLUGIN="$PLUGIN" \
  TEST_REPO="$TEST_REPO" \
  TMP="$TMP" \
  STUB_BIN="$STUB_BIN" \
  CACHE_PLUGIN="$CACHE_PLUGIN" \
  COUNT_FILE="$COUNT_FILE" \
  BROKEN_PLUGIN="$BROKEN_PLUGIN" \
  MISSING_HOOK_PLUGIN="$MISSING_HOOK_PLUGIN" \
  NO_JQ_BIN="$NO_JQ_BIN" \
  node ${NODE_FLAGS[@]+"${NODE_FLAGS[@]}"} "$RUNNER"
)"
node_rc=$?
summary_line="$(grep '^NODE_SUMMARY:' <<<"$node_out" | tail -1 || true)"
if [[ -n "$summary_line" ]]; then
  node_pass="${summary_line#NODE_SUMMARY:}"
  node_fail="${node_pass#*:}"
  node_pass="${node_pass%%:*}"
  pass=$((pass + node_pass))
  fail=$((fail + node_fail))
else
  fail=$((fail + 1))
  printf 'FAIL: node test runner did not emit summary (exit %d)\n%s\n' "$node_rc" "$node_out"
fi
if (( node_rc != 0 )) && [[ -n "$summary_line" ]] && (( node_fail == 0 )); then
  fail=$((fail + 1))
  printf 'FAIL: node test runner exited %d unexpectedly\n' "$node_rc"
fi

echo "$pass passed, $fail failed"
(( fail == 0 ))
