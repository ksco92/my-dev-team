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
printf '%s' "${DEV_TEAM_CLOUD_MODE:-}" >"$out_dir/cloud_mode.txt"

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

function createHarness(options, cloudModeEnv) {
  const handlers = new Map();
  const tools = new Map();
  const commands = new Map();
  const api = {
    on(event, fn) {
      handlers.set(event, fn);
    },
    registerTool(def) {
      tools.set(def.name, def);
    },
    registerCommand(name, def) {
      commands.set(name, def);
    },
  };
  const prevCloudMode = process.env.DEV_TEAM_CLOUD_MODE;
  if (cloudModeEnv === undefined) delete process.env.DEV_TEAM_CLOUD_MODE;
  else process.env.DEV_TEAM_CLOUD_MODE = cloudModeEnv;
  try {
    devTeamExtension(api, options);
  } finally {
    if (prevCloudMode === undefined) delete process.env.DEV_TEAM_CLOUD_MODE;
    else process.env.DEV_TEAM_CLOUD_MODE = prevCloudMode;
  }
  return { handlers, tools, commands };
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

function makeConfirmCtx(confirmFn, hasUI = true) {
  let calls = 0;
  const ctx = {
    cwd: TEST_REPO,
    hasUI,
    ui: {
      confirm: async (title, detail) => {
        calls += 1;
        return confirmFn(title, detail);
      },
    },
  };
  return { ctx, getCalls: () => calls };
}

const readCount = () => fs.readFileSync(COUNT_FILE, "utf8").trim().split("\n").filter(Boolean).length;

async function runBeforeStart(handlers, ctx) {
  const event = { systemPromptOptions: { sections: {} } };
  await handlers.get("before_agent_start")(event, ctx);
  return event.systemPromptOptions.sections["dev-team"];
}

// --- before_agent_start ---
await test("before_agent_start injects policy and process into systemPromptOptions.sections['dev-team']", async () => {
  const { handlers } = createHarness();
  assert.equal(typeof handlers.get("before_agent_start"), "function");
  const section = await runBeforeStart(handlers, { cwd: TEST_REPO, hasUI: false });
  assert.equal(typeof section, "string");
  assert.ok(section.includes(`Plugin root (\`\${CLAUDE_PLUGIN_ROOT}\`): \`${PLUGIN}\``));
  assert.ok(section.includes("# Harness policy (dev-team plugin)"));
  assert.ok(section.includes(`${PLUGIN}/context/`));
  assert.ok(section.includes("# Development process"));
});

await test("before_agent_start caches per cwd and refreshes for a new cwd", async () => {
  const { handlers } = createHarness({ pluginRoot: CACHE_PLUGIN });
  const dirA = path.join(TMP, "cwd-a");
  const dirB = path.join(TMP, "cwd-b");
  fs.mkdirSync(dirA, { recursive: true });
  fs.mkdirSync(dirB, { recursive: true });

  const sec1 = await runBeforeStart(handlers, { cwd: dirA, hasUI: false });
  assert.equal(readCount(), 2);

  const sec2 = await runBeforeStart(handlers, { cwd: dirA, hasUI: false });
  assert.equal(readCount(), 2);
  assert.equal(sec2, sec1);

  const sec3 = await runBeforeStart(handlers, { cwd: dirB, hasUI: false });
  assert.equal(readCount(), 4);
  assert.ok(sec3.includes(`cwd=${dirB}`));
});

await test("before_agent_start degrades gracefully when session-context hook fails", async () => {
  const { handlers, commands } = createHarness({ pluginRoot: BROKEN_PLUGIN });
  const warnings = [];
  const uiCtx = {
    cwd: TEST_REPO,
    hasUI: true,
    ui: { notify: (msg, level) => warnings.push({ msg, level }) },
  };
  const askSection = await runBeforeStart(handlers, uiCtx);
  assert.ok(askSection.includes("require explicit user approval"));
  assert.equal(warnings.length, 2);
  assert.equal(warnings[0].level, "warning");

  await commands.get("cloud").handler("on", { ui: { notify: () => {} } });
  assert.equal(await runBeforeStart(handlers, uiCtx), undefined);
});

await test("before_agent_start degrades gracefully when session-context hook is missing", async () => {
  const { handlers, commands } = createHarness({ pluginRoot: MISSING_HOOK_PLUGIN });
  const warnings = [];
  const uiCtx = {
    cwd: TEST_REPO,
    hasUI: true,
    ui: { notify: (msg, level) => warnings.push({ msg, level }) },
  };
  const askSection = await runBeforeStart(handlers, uiCtx);
  assert.ok(askSection.includes("require explicit user approval"));
  assert.equal(warnings.length, 1);
  assert.ok(warnings[0].msg.includes("not executable"));

  await commands.get("cloud").handler("on", { ui: { notify: () => {} } });
  assert.equal(await runBeforeStart(handlers, uiCtx), undefined);
});

// --- tool_call ---
const { handlers: realHandlers, tools: realTools } = createHarness(undefined, "on");
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

// --- cloud backend gate (/cloud, ask/off/once/on, bash detector, session_start, child pi env) ---
await test("default ask mode fails closed without UI on run_agent(claude/agy) and bash cloud CLIs", async () => {
  const { handlers, tools } = createHarness();
  const gatedToolCall = handlers.get("tool_call");
  const gatedRunAgent = tools.get("run_agent");
  const noUiCtx = { cwd: TEST_REPO, hasUI: false };

  await assert.rejects(
    () => gatedRunAgent.execute("c1", { agent: "pr-reviewer", backend: "claude", prompt: "review" }, undefined, undefined, noUiCtx),
    /requires interactive approval/,
  );
  await assert.rejects(
    () => gatedRunAgent.execute("c2", { agent: "pr-reviewer", backend: "agy", prompt: "review" }, undefined, undefined, noUiCtx),
    /requires interactive approval/,
  );

  const cloudBashCommands = [
    ["claude", "claude -p hi"],
    ["agy", "agy --print=hi"],
    ["claude", "/opt/homebrew/bin/claude -p hi"],
    ["agy", "FOO=1 env -u X /usr/local/bin/AGY --print=hi"],
    ["claude", "echo ok && claude -p hi"],
    ["claude", "echo $(claude -p hi)"],
    ["claude", 'echo "$(claude -p hi)"'],
    ["agy", "echo `agy --print=hi`"],
    ["agy", 'echo "`agy --print=hi`"'],
    ["claude", "npx -y @anthropic-ai/claude-code -p hi"],
    ["claude", "pnpx -y @anthropic-ai/claude-code -p hi"],
    ["claude", "bunx @anthropic-ai/claude-code@latest -p hi"],
    ["claude", "pnpm dlx @anthropic-ai/claude-code -p hi"],
    ["claude", "pnpm --silent dlx @anthropic-ai/claude-code -p hi"],
    ["claude", "pnpm -s exec claude -p hi"],
    ["claude", "yarn --cwd . exec claude -p hi"],
    ["claude", "yarn exec claude -p hi"],
    ["claude", 'bash -lc "claude -p hi"'],
    ["agy", "sh -c 'echo ok; agy --print=hi'"],
    ["claude", "> /dev/null claude -p hi"],
    ["claude", "2>&1 claude -p hi"],
    ["claude", "command -p claude -p hi"],
    ["claude", "builtin exec claude -p hi"],
    ["claude", "builtin command claude -p hi"],
    ["claude", "exec -a fake claude -p hi"],
    ["claude", "exec -ca fake claude -p hi"],
    ["claude", "nohup claude -p hi &"],
    ["claude", "time -p claude -p hi"],
    ["claude", "nice -n 5 claude -p hi"],
    ["claude", "sudo -u root FOO=1 claude -p hi"],
    ["claude", 'sudo "FOO=1" claude -p hi'],
    ["claude", "sudo -Hu root claude -p hi"],
    ["claude", "timeout -k 5 30 claude -p hi"],
    ["claude", "echo hi | xargs -I {} claude -p {}"],
    ["claude", "echo hi | xargs -0I {} claude -p"],
    ["claude", "echo hi | xargs -0n 1 claude -p"],
    ["claude", 'env "FOO=1" claude -p hi'],
    ["claude", "env - PATH=/bin claude -p hi"],
    ["claude", 'env -S "claude -p hi"'],
    ["claude", 'env -S"claude -p hi"'],
    ["claude", 'env -iS "claude -p hi"'],
    ["claude", "env -iu FOO claude -p hi"],
    ["claude", 'sh -co errexit "claude -p hi"'],
    ["claude", 'bash -O extglob -c "claude -p hi"'],
    ["claude", 'bash +O extglob -c "claude -p hi"'],
    ["claude", 'bash --rcfile /dev/null -c "claude -p hi"'],
    ["claude", 'bash --init-file /dev/null -c "claude -p hi"'],
    ["claude", 'npx -yc "claude -p hi"'],
    ["claude", 'npx -c"claude -p hi"'],
    ["claude", "(claude -p hi)"],
    ["claude", "echo ok |& claude -p hi"],
    ["claude", "\\claude -p hi"],
    ["claude", "CLAUDE -p hi"],
    ["claude", "cat <(claude -p hi)"],
    ["claude", "echo ok && \\\n  claude -p hi"],
    ["claude", "env FOO=1 \\\n  claude -p hi"],
    ["claude", "cl\\\naude -p hi"],
    ["claude", 'sh -c "cl\\\naude -p hi"'],
    ["claude", "sh -c \"echo \\'; claude -p hi\""],
    ["claude", "bash -c \"echo \\'; claude -p hi\""],
    ["claude", "echo \"`echo \\\"'\\\" ; claude -p hi`\""],
    ["claude", "echo \"`sh -c \\\"env FOO=1 claude -p hi\\\"`\""],
    ["claude", "$'claude' -p hi"],
    ["claude", "$'\\x63laude' -p hi"],
    ["claude", '$"claude" -p hi'],
    ["claude", 'echo "$( # )\nclaude -p hi)"'],
    ["claude", 'echo "$(echo "x"; claude -p hi)"'],
    ["claude", "echo \"$(case x in a) echo ok;; esac; claude -p hi)\""],
    ["claude", "echo \"$(case a in a) echo 1;& b) claude -p hi;; esac)\""],
    ["claude", "echo \"$(echo ${x:-)} ; claude -p hi)\""],
    ["claude", "echo $(cat <<'EOF'\n) '\nEOF\nclaude -p hi\n)"],
    ["claude", "echo $(cat <<'EOF'\n)\ncat <<'HIDE'\nEOF\nclaude -p hi\n)"],
    ["claude", "cat <<EOF\n$(claude -p hi)\nEOF"],
    ["claude", "cat <<< $(claude -p hi)"],
    ["claude", 'cat <<< "$(claude -p hi)"'],
    ["claude", "cat <<< foo\nclaude -p hi"],
    ["claude", "cat <<< 'foo'\nclaude -p hi"],
    ["claude", 'bash <<< "claude -p hi"'],
    ["claude", "bash <<'EOF'\nclaude -p hi\nEOF"],
    ["claude", "cat <<E\\\nOF\n$(claude -p hi)\nEOF"],
    ["claude", 'echo "$\\\n(claude -p hi)"'],
    ["claude", "cat <<EOF\n$\\\n(claude -p hi)\nEOF"],
    ["claude", "$\\\n'\\x63laude' -p hi"],
    ["claude", "if true; th\\\nen claude -p hi; fi"],
    ["claude", "wh\\\nile claude -p hi; do break; done"],
    ["claude", 'env -S "-u FOO claude -p hi"'],
    ["claude", 'env -S "-- claude -p hi"'],
    ["claude", 'env -S"-u FOO claude -p hi"'],
    ["claude", 'env --split-string="-u FOO claude -p hi"'],
    ["claude", 'sh -c - "claude -p hi"'],
    ["claude", 'bash -c - "claude -p hi"'],
    ["claude", 'sh -e -c - "claude -p hi"'],
    ["claude", "FOO+=bar claude -p hi"],
    ["claude", "echo hi | xargs --replace claude -p"],
    ["claude", "echo hi | xargs --replace={} claude -p {}"],
    ["claude", "env --default-signal claude -p hi"],
    ["claude", "env --default-signal=PIPE claude -p hi"],
    ["claude", "echo hi | xargs -I {} -S 1024 claude -p {}"],
    ["claude", 'csh -c "claude -p hi"'],
    ["claude", 'tcsh -c "claude -p hi"'],
    ["claude", 'coproc claude -p hi; read -p x; echo "$x"'],
    ["claude", 'echo "${x:-{}" ; claude'],
    ["claude", "echo ${x:-{} ; claude"],
    ["claude", 'echo "${x:-\'}" ; claude'],
    ["claude", 'echo "${x:-\'$(claude)}"'],
    ["claude", "zsh -c 'echo \"${x:-'\\''}\" && claude -p hi'"],
    ["claude", "(( 1 << 2 ))\nclaude -p hi"],
    ["claude", "if (( 1 << 2 )); then\nclaude -p hi\nfi"],
    ["claude", 'echo "$(if (( 1 << 2 )); then\nclaude -p hi\nfi)"'],
    ["claude", 'echo "$(cat <<< EOF\n)" ; claude'],
    ["claude", 'echo "$(echo case; echo in)" ; claude'],
    ["claude", 'echo "$(echo case in)" && claude -p hi'],
    ["claude", 'echo "$(grep case in /dev/null)" ; claude -p hi'],
    ["claude", 'bash -n +n -c "claude -p hi"'],
    ["claude", 'sh -n +n -c "claude -p hi"'],
    ["claude", 'bash -n +o noexec -c "claude -p hi"'],
    ["claude", 'bash -oc errexit "claude"'],
    ["claude", 'sh -oc errexit "claude"'],
    ["claude", "sh <<EOF\n\\\\claude\nEOF"],
    ["claude", "cat <<''\n\"\n\nclaude"],
    ["claude", "cat <<\\\n 'EOF'\n\"\nEOF\nclaude"],
    ["claude", 'sh <<\\\n< "claude"'],
    ["claude", 'sh <\\\n<< "claude"'],
    ["claude", "env -S 'FOO=1\\_claude'"],
    ["claude", "env -S 'env\\_claude'"],
    ["claude", "echo $(( 0 + '$(claude -p hi)' ))"],
    ["claude", "echo $(( '`claude -p hi`' ))"],
    ["claude", "(( 0 + '$(claude -p hi)' ))"],
    ["claude", "dash -c '((claude -p hi))'"],
    ["claude", "sh -c '(( 1 << 2 ))\nclaude -p hi'"],
    ["claude", "sh -c '((claude -p hi))'"],
    ["claude", "$'claude\\x00foo' -p hi"],
    ["claude", "$'claude\\0foo' -p hi"],
    ["claude", "$'claude\\u0000foo' -p hi"],
    ["claude", "$'env\\x00x' claude -p hi"],
    ["claude", "bash -c $'claude\\x00foo'"],
    ["claude", "bash <<< $'claude\\x00foo'"],
    ["claude", "env -S 'sh -c' 'claude -p hi'"],
    ["claude", "env -S '-u' FOO claude -p hi"],
    ["claude", "env -S 'FOO=\\\\ claude -p hi'"],
    ["claude", "env -S '-u \\# claude -p hi'"],
    ["claude", 'env -S "FOO=\'\\c\' claude -p hi"'],
    ["claude", 'env -S "FOO=\'a\\\'b\' claude -p hi"'],
    ["claude", "cat <<'EOF'\nEOF\r\n'\nEOF\nclaude -p hi"],
    ["claude", "bash <<-'EOF'\n\tcat <<'INNER'\n\tINNER\n\tclaude -p hi\n\tEOF"],
    ["claude", 'cat <<$"EOF"\n$EOF\nclaude -p hi'],
    ["claude", "bash /dev/fd/0 <<'EOF'\nclaude -p hi\nEOF"],
    ["claude", 'bash /dev/fd/0 <<< "claude -p hi"'],
    ["claude", 'sh /dev/fd/0 <<< "claude -p hi"'],
    ["claude", 'zsh -n -o exec -c "claude -p hi"'],
    ["claude", 'zsh -n +o no_exec -c "claude -p hi"'],
    ["claude", 'zsh -n +o NOEXEC -c "claude -p hi"'],
    ["claude", 'zsh -o noexec -o exec -c "claude -p hi"'],
    ["claude", "/usr/bin/time -o /dev/null claude -p hi"],
    ["claude", "/usr/bin/time -lo /dev/null claude -p hi"],
    ["claude", "1\\\n0>/dev/null claude -p hi"],
    ["claude", 'echo "$(case a in a|esac) claude -p hi;; esac)"'],
  ];
  for (const [cli, cmd] of cloudBashCommands) {
    const res = await gatedToolCall({ toolName: "bash", input: { command: cmd } }, noUiCtx);
    assert.equal(res?.block, true, `expected block for: ${cmd}`);
    assert.ok(res.reason.includes(`"${cli}"`), `expected CLI "${cli}" in reason for ${cmd}, got: ${res.reason}`);
    assert.ok(res.reason.includes("requires interactive approval"), `unexpected reason for ${cmd}: ${res.reason}`);
  }
});

await test("run_agent runs validation and model policy before cloud gate authorization", async () => {
  const { tools: offTools } = createHarness(undefined, "off");
  await assert.rejects(
    () =>
      offTools.get("run_agent").execute(
        "v1",
        { agent: "security-reviewer", backend: "claude", model: "sonnet", prompt: "audit" },
        undefined,
        undefined,
        { cwd: TEST_REPO, hasUI: false },
      ),
    /security-reviewer requires model "opus"/,
  );

  const { tools: askTools } = createHarness(undefined, "ask");
  const askUi = makeConfirmCtx(async () => true);
  await assert.rejects(
    () =>
      askTools.get("run_agent").execute(
        "v2",
        { agent: "security-reviewer", backend: "claude", model: "sonnet", prompt: "audit" },
        undefined,
        undefined,
        askUi.ctx,
      ),
    /security-reviewer requires model "opus"/,
  );
  assert.equal(askUi.getCalls(), 0);
});

await test("default ask mode allows run_agent(pi) without prompting and sets DEV_TEAM_CLOUD_MODE=off for child pi", async () => {
  const { tools } = createHarness();
  const ui = makeConfirmCtx(async () => false);
  await withStubEnv("PI", "stub-pi-cloud-ask", { PI_STUB_STDOUT: "local ok", PI_STUB_EXIT: "0" }, async (outDir) => {
    const res = await tools.get("run_agent").execute("p1", { agent: "implementer", backend: "pi", prompt: "do work" }, undefined, undefined, ui.ctx);
    assert.equal(res.content[0].text, "local ok");
    assert.equal(ui.getCalls(), 0);
    assert.equal(fs.readFileSync(path.join(outDir, "cloud_mode.txt"), "utf8"), "off");
  });

  const { tools: onTools } = createHarness(undefined, "on");
  await withStubEnv(
    "PI",
    "stub-pi-cloud-parent-on",
    { PI_STUB_STDOUT: "local ok", PI_STUB_EXIT: "0", DEV_TEAM_CLOUD_MODE: "on" },
    async (outDir) => {
      await onTools.get("run_agent").execute("p2", { agent: "implementer", backend: "pi", prompt: "do work" }, undefined, undefined, { cwd: TEST_REPO });
      assert.equal(fs.readFileSync(path.join(outDir, "cloud_mode.txt"), "utf8"), "off");
    },
  );
});

await test("benign bash commands and heredocs pass without prompting in both ask and off modes", async () => {
  const benignCommands = [
    "cat .claude/settings.json",
    "cat CLAUDE.md",
    "grep claude README.md",
    "which claude",
    "command -v claude",
    "command -V agy",
    "builtin command -v claude",
    'echo "foo; claude -p hi"',
    "echo 'agy --print=hi'",
    "echo 'cl\\\naude'",
    "echo '$(claude -p hi)'",
    "echo '`agy --print=hi`'",
    'echo "\\$(claude -p hi)"',
    'git commit -m "Use claude and agy"',
    "echo hi > claude",
    "echo hi >claude",
    "CLAUDE_CODE=1 git status",
    "# claude -p hi",
    "bash script.sh",
    "cat <<'EOF'\nclaude -p hi\nEOF",
    "cat <<EOF\nclaude is cool\nEOF",
    "cat <<'EOF'\n$(claude -p hi)\nEOF",
    "cat <<< claude",
    'bash - -c "claude -p hi"',
    "bash -n <<'EOF'\nclaude -p hi\nEOF",
    'bash -o noexec -c "claude -p hi"',
    'zsh +o exec -c "claude -p hi"',
  ];
  for (const mode of ["ask", "off"]) {
    const { handlers } = createHarness(undefined, mode);
    const gatedToolCall = handlers.get("tool_call");
    const ui = makeConfirmCtx(async () => false);
    for (const cmd of benignCommands) {
      const res = await gatedToolCall({ toolName: "bash", input: { command: cmd } }, ui.ctx);
      assert.equal(res, undefined, `unexpected block in mode=${mode} for benign command: ${cmd} (${res?.reason})`);
    }
    assert.equal(ui.getCalls(), 0);
  }
});

await test("ask mode with UI prompts via ctx.ui.confirm and honors allow, deny, non-boolean, hasUI=false, and rejection", async () => {
  const { handlers, tools } = createHarness();
  const gatedToolCall = handlers.get("tool_call");
  const gatedRunAgent = tools.get("run_agent");
  const prompts = [];
  const allowUi = makeConfirmCtx(async (title, detail) => {
    prompts.push({ title, detail });
    return true;
  });

  await withStubEnv("CLAUDE", "stub-claude-ask-allow", { CLAUDE_STUB_STDOUT: "ok\n\nGATE: pr-reviewer\nVERDICT: PASS\nHEAD: 8e6c495\nFINDINGS: 0", CLAUDE_STUB_EXIT: "0" }, async () => {
    const res = await gatedRunAgent.execute(
      "a1",
      { agent: "pr-reviewer", backend: "claude", model: "sonnet", prompt: "review" },
      undefined,
      undefined,
      allowUi.ctx,
    );
    assert.equal(res.details.authoritative, true);
    assert.equal(prompts.length, 1);
    assert.ok(prompts[0].title.includes("claude"));
    assert.ok(prompts[0].detail.includes("pr-reviewer") && prompts[0].detail.includes("claude") && prompts[0].detail.includes("sonnet"));
  });

  const denyUi = makeConfirmCtx(async (title, detail) => {
    prompts.push({ title, detail });
    return false;
  });
  await assert.rejects(
    () => gatedRunAgent.execute("a2", { agent: "implementer", backend: "agy", prompt: "build" }, undefined, undefined, denyUi.ctx),
    /denied by user/,
  );
  assert.ok(prompts[1].detail.includes("implementer") && prompts[1].detail.includes("agy") && prompts[1].detail.includes("default"));

  await assert.rejects(
    () => gatedRunAgent.execute("a3", { agent: "security-reviewer", backend: "claude", prompt: "audit" }, undefined, undefined, denyUi.ctx),
    /denied by user/,
  );
  assert.ok(prompts[2].detail.includes("Model: opus"));

  const headlessWithConfirm = makeConfirmCtx(async () => true, false);
  const headlessRes = await gatedToolCall({ toolName: "bash", input: { command: "claude -p hi" } }, headlessWithConfirm.ctx);
  assert.equal(headlessRes?.block, true);
  assert.ok(headlessRes.reason.includes("requires interactive approval"));
  assert.equal(headlessWithConfirm.getCalls(), 0);

  const truthyNonBool = await gatedToolCall(
    { toolName: "bash", input: { command: "claude -p hi" } },
    makeConfirmCtx(async () => "yes").ctx,
  );
  assert.equal(truthyNonBool?.block, true);
  assert.ok(truthyNonBool.reason.includes("denied by user"));

  const denyUndef = await gatedToolCall(
    { toolName: "bash", input: { command: "claude -p hi" } },
    makeConfirmCtx(async () => undefined).ctx,
  );
  assert.equal(denyUndef?.block, true);
  assert.ok(denyUndef.reason.includes("denied by user"));

  const longCmd = `claude -p "${"x".repeat(260)}"`;
  let seenBashDetail = "";
  const allowBash = await gatedToolCall(
    { toolName: "bash", input: { command: longCmd } },
    makeConfirmCtx(async (title, detail) => {
      assert.ok(title.includes("claude"));
      seenBashDetail = detail;
      return true;
    }).ctx,
  );
  assert.equal(allowBash, undefined);
  assert.equal(seenBashDetail.length, 203);
  assert.ok(seenBashDetail.endsWith("..."));

  const denyThrow = await gatedToolCall(
    { toolName: "bash", input: { command: "agy --print=hi" } },
    makeConfirmCtx(async () => {
      throw new Error("dialog closed");
    }).ctx,
  );
  assert.equal(denyThrow?.block, true);
  assert.ok(denyThrow.reason.includes("dialog closed"));
});

await test("/cloud status, usage, stderr fallback, and merge-gate priority before cloud confirm", async () => {
  const { handlers, commands } = createHarness();
  const cloudCmd = commands.get("cloud");
  const gatedToolCall = handlers.get("tool_call");
  const notes = [];
  const cmdCtx = { ui: { notify: (msg, level) => notes.push({ msg, level }) } };

  await cloudCmd.handler("", cmdCtx);
  assert.equal(notes.at(-1).msg, "Cloud backend mode: `ask`");
  assert.equal(notes.at(-1).level, "info");

  await cloudCmd.handler("status", cmdCtx);
  assert.equal(notes.at(-1).msg, "Cloud backend mode: `ask`");

  await cloudCmd.handler("bogus", cmdCtx);
  assert.equal(notes.at(-1).msg, "Usage: /cloud [off|ask|once|on|status]");
  assert.equal(notes.at(-1).level, "warning");

  let stderrOut = "";
  const origWrite = process.stderr.write.bind(process.stderr);
  process.stderr.write = (chunk) => {
    stderrOut += String(chunk);
    return true;
  };
  try {
    await cloudCmd.handler("status", {});
  } finally {
    process.stderr.write = origWrite;
  }
  assert.ok(stderrOut.includes("Cloud backend mode: `ask`"));

  const mgUi = makeConfirmCtx(async () => true);
  const mgRes = await gatedToolCall({ toolName: "bash", input: { command: "git push --force origin main && claude -p hi" } }, mgUi.ctx);
  assert.equal(mgRes?.block, true);
  assert.ok(mgRes.reason.includes("merge-gate"));
  assert.equal(mgUi.getCalls(), 0);
});

await test("/cloud off, once (concurrent and baseMode preservation), on, and session_start reset", async () => {
  const { handlers, commands } = createHarness();
  const cloudCmd = commands.get("cloud");
  const gatedToolCall = handlers.get("tool_call");
  const onSessionStart = handlers.get("session_start");
  const notes = [];
  const cmdCtx = { ui: { notify: (msg, level) => notes.push({ msg, level }) } };
  const ui = makeConfirmCtx(async () => true);

  await cloudCmd.handler("off", cmdCtx);
  assert.equal(notes.at(-1).msg, "Cloud backend mode set to `off`.");
  const offRes = await gatedToolCall({ toolName: "bash", input: { command: "claude -p hi" } }, ui.ctx);
  assert.equal(offRes?.block, true);
  assert.ok(offRes.reason.includes('cloud mode is "off"'));
  assert.equal(ui.getCalls(), 0);

  await cloudCmd.handler("once", cmdCtx);
  assert.equal(await gatedToolCall({ toolName: "bash", input: { command: "claude -p hi" } }, ui.ctx), undefined);
  const secondFromOff = await gatedToolCall({ toolName: "bash", input: { command: "claude -p hi" } }, ui.ctx);
  assert.equal(secondFromOff?.block, true);
  assert.ok(secondFromOff.reason.includes('cloud mode is "off"'));
  assert.equal(ui.getCalls(), 0);

  await cloudCmd.handler("on", cmdCtx);
  assert.equal(await gatedToolCall({ toolName: "bash", input: { command: "claude -p 1" } }, { cwd: TEST_REPO, hasUI: false }), undefined);
  assert.equal(await gatedToolCall({ toolName: "bash", input: { command: "agy --print=2" } }, { cwd: TEST_REPO, hasUI: false }), undefined);
  await cloudCmd.handler("once", cmdCtx);
  assert.equal(await gatedToolCall({ toolName: "bash", input: { command: "claude -p hi" } }, ui.ctx), undefined);
  const afterOnOnce = await gatedToolCall({ toolName: "bash", input: { command: "claude -p hi" } }, ui.ctx);
  assert.equal(afterOnOnce?.block, true);
  assert.ok(afterOnOnce.reason.includes('cloud mode is "off"'));

  delete process.env.DEV_TEAM_CLOUD_MODE;
  await onSessionStart({}, { cwd: TEST_REPO });
  await cloudCmd.handler("status", cmdCtx);
  assert.equal(notes.at(-1).msg, "Cloud backend mode: `ask`");
  await cloudCmd.handler("once", cmdCtx);
  const concurrentResults = await Promise.all([
    gatedToolCall({ toolName: "bash", input: { command: "agy --print=hi" } }, { cwd: TEST_REPO, hasUI: false }),
    gatedToolCall({ toolName: "bash", input: { command: "agy --print=hi" } }, { cwd: TEST_REPO, hasUI: false }),
  ]);
  assert.equal(concurrentResults.filter((r) => r === undefined).length, 1);
  const blockedConcurrent = concurrentResults.filter((r) => r?.block === true);
  assert.equal(blockedConcurrent.length, 1);
  assert.ok(blockedConcurrent[0].reason.includes("requires interactive approval"));

  process.env.DEV_TEAM_CLOUD_MODE = " OFF ";
  try {
    await onSessionStart({}, { cwd: TEST_REPO });
    await cloudCmd.handler("status", cmdCtx);
    assert.equal(notes.at(-1).msg, "Cloud backend mode: `off`");
  } finally {
    delete process.env.DEV_TEAM_CLOUD_MODE;
  }
});

await test("before_agent_start dynamically reflects /cloud mode without stale contextCache", async () => {
  fs.writeFileSync(COUNT_FILE, "");
  const { handlers, commands } = createHarness({ pluginRoot: CACHE_PLUGIN });
  const cloudCmd = commands.get("cloud");
  const dir = path.join(TMP, "cwd-cloud-notice");
  fs.mkdirSync(dir, { recursive: true });
  const cmdCtx = { ui: { notify: () => {} } };

  const secAsk = await runBeforeStart(handlers, { cwd: dir, hasUI: false });
  assert.ok(secAsk.includes("require explicit user approval"));
  assert.equal(readCount(), 2);

  await cloudCmd.handler("off", cmdCtx);
  const secOff = await runBeforeStart(handlers, { cwd: dir, hasUI: false });
  assert.ok(secOff.includes("DISABLED"));
  assert.equal(readCount(), 2);

  await cloudCmd.handler("on", cmdCtx);
  const secOn = await runBeforeStart(handlers, { cwd: dir, hasUI: false });
  assert.ok(!secOn.includes("DISABLED") && !secOn.includes("require explicit user approval"));
  assert.equal(readCount(), 2);

  await cloudCmd.handler("once", cmdCtx);
  const secOnce = await runBeforeStart(handlers, { cwd: dir, hasUI: false });
  assert.ok(!secOnce.includes("DISABLED") && !secOnce.includes("require explicit user approval"));
});

await test("run_agent enforces /cloud off and /cloud once and bash detector fails closed past parse depth limit", async () => {
  const { handlers, tools, commands } = createHarness(undefined, "off");
  const cloudCmd = commands.get("cloud");
  const gatedRunAgent = tools.get("run_agent");
  const gatedToolCall = handlers.get("tool_call");
  const cmdCtx = { ui: { notify: () => {} } };
  const ui = makeConfirmCtx(async () => true);

  await assert.rejects(
    () => gatedRunAgent.execute("r1", { agent: "pr-reviewer", backend: "claude", prompt: "review" }, undefined, undefined, ui.ctx),
    /cloud mode is "off"/,
  );
  assert.equal(ui.getCalls(), 0);

  await cloudCmd.handler("once", cmdCtx);
  await withStubEnv("CLAUDE", "stub-claude-once", { CLAUDE_STUB_STDOUT: "ok\n\nGATE: pr-reviewer\nVERDICT: PASS\nHEAD: 8e6c495\nFINDINGS: 0", CLAUDE_STUB_EXIT: "0" }, async () => {
    const okRes = await gatedRunAgent.execute("r2", { agent: "pr-reviewer", backend: "claude", prompt: "review" }, undefined, undefined, ui.ctx);
    assert.equal(okRes.details.verdictValid, true);
    await assert.rejects(
      () => gatedRunAgent.execute("r3", { agent: "pr-reviewer", backend: "claude", prompt: "review" }, undefined, undefined, ui.ctx),
      /cloud mode is "off"/,
    );
  });
  assert.equal(ui.getCalls(), 0);

  let deep = "echo ok";
  for (let i = 0; i < 12; i += 1) deep = `$(${deep})`;
  const deepOff = await gatedToolCall({ toolName: "bash", input: { command: `echo ${deep}` } }, ui.ctx);
  assert.equal(deepOff?.block, true);
  assert.ok(deepOff.reason.includes("parse depth limit"));
  assert.ok(deepOff.reason.includes('cloud mode is "off"'));
  assert.equal(ui.getCalls(), 0);

  await cloudCmd.handler("ask", cmdCtx);
  const deepAskHeadless = await gatedToolCall({ toolName: "bash", input: { command: `echo ${deep}` } }, { cwd: TEST_REPO, hasUI: false });
  assert.equal(deepAskHeadless?.block, true);
  assert.ok(deepAskHeadless.reason.includes("parse depth limit"));
  assert.ok(deepAskHeadless.reason.includes("requires interactive approval"));

  const deepAskApproved = await gatedToolCall({ toolName: "bash", input: { command: `echo ${deep}` } }, ui.ctx);
  assert.equal(deepAskApproved, undefined);
  assert.equal(ui.getCalls(), 1);

  const deepParam = 'echo "${a:-${a:-${a:-${a:-${a:-${a:-${a:-${a:-${a:-${a:-$(claude)}}}}}}}}}}"';
  const deepParamAsk = await gatedToolCall({ toolName: "bash", input: { command: deepParam } }, { cwd: TEST_REPO, hasUI: false });
  assert.equal(deepParamAsk?.block, true);
  assert.ok(deepParamAsk.reason.includes("parse depth limit"));
  assert.ok(deepParamAsk.reason.includes("requires interactive approval"));

  await cloudCmd.handler("off", cmdCtx);
  const deepParamOff = await gatedToolCall({ toolName: "bash", input: { command: deepParam } }, ui.ctx);
  assert.equal(deepParamOff?.block, true);
  assert.ok(deepParamOff.reason.includes("parse depth limit"));
  assert.ok(deepParamOff.reason.includes('cloud mode is "off"'));
});

await test("invalid DEV_TEAM_CLOUD_MODE falls back safely to ask", async () => {
  for (const badMode of ["always", "yes", "", "   "]) {
    const { commands } = createHarness(undefined, badMode);
    const notes = [];
    await commands.get("cloud").handler("status", { ui: { notify: (msg) => notes.push(msg) } });
    assert.equal(notes[0], "Cloud backend mode: `ask`", `expected fallback to ask for ${JSON.stringify(badMode)}`);
  }
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
