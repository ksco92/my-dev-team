---
difficulty: high
priority: p0
status: done
---

# Pi Adapter Package and `run_agent` Tool

## Context

`dev-team` supports Claude Code natively and Antigravity via `hooks/agy-hook.sh` and
`bin/install-agy`. Adding a native Pi (`@earendil-works/pi-coding-agent`) package at the repository
root makes `ksco92/my-dev-team` the single source of truth across Claude Code, Antigravity, and Pi
with zero duplicated guard logic, while enabling local Pi subagents for pre-submission self-checks
and SOTA models via `claude` or `agy` CLIs for authoritative merge-blocking review gates.

## Requirements

- [ ] Add root `package.json` declaring a native Pi package (`"keywords": ["pi-package"]`,
      `"private": true`, `"license": "Apache-2.0"`, `"version": "0.20.0"`, exact synced one-line
      `"description"`, `"peerDependencies"` for host-provided Pi packages with `"*"` ranges and none
      of them in `"dependencies"`, and
      `"pi": { "extensions": ["./plugins/dev-team/pi/dev-team.ts"], "skills": ["./plugins/dev-team/skills"] }`).
- [ ] Add `plugins/dev-team/pi/dev-team.ts` using only Node built-in modules at runtime and
      type-only imports (`@earendil-works/pi-coding-agent`, `typebox`) with erasable TypeScript
      syntax so both Pi (`jiti`) and Node 22+ load it directly without `npm install`.
- [ ] In `before_agent_start`, invoke `hooks/session-context.sh policy` and
      `hooks/session-context.sh process` with `CLAUDE_PLUGIN_ROOT` set and `{ cwd }` on stdin,
      prepend `Plugin root (\`${CLAUDE_PLUGIN_ROOT}\`):
      \`<root>\``to the policy block (matching    `agy-hook.sh`), cache per `cwd`, inject via `event.systemPromptOptions.sections["dev-team"]`,
      and degrade gracefully on error without crashing the session.
- [ ] In `tool_call` for `bash`, pipe `{ tool_input: { command }, cwd }` with `CLAUDE_PLUGIN_ROOT`
      into `hooks/merge-gate.sh` (60s timeout) and `hooks/attribution-guard.sh` (10s timeout),
      blocking (`{ block: true, reason }`) on non-zero exit, missing script, spawn error, timeout,
      or non-string `command` (fail-closed).
- [ ] Register the `run_agent` custom tool supporting the 7 canonical agents in
      `plugins/dev-team/agents/*.md` (`implementer`, `pr-reviewer`, `code-health-reviewer`,
      `oss-readiness-reviewer`, `security-reviewer`, `readme-reviewer`, `cold-reader`) across three
      backends (`pi`, `claude`, `agy`): - Read canonical agent frontmatter (`tools`, `model`,
      `skills`) and body from `plugins/dev-team/agents/<agent>.md` (expanding
      `${CLAUDE_PLUGIN_ROOT}` and naming preloaded skill paths) with no duplicated agent
      definitions. - Default `backend` to `"pi"` for `implementer` and `cold-reader`; require an
      explicit `backend` for the five review-gate agents. - `backend: "pi"`: spawn
      `pi --print --no-session --no-extensions -e <dev-team.ts> --tools <mapped> --exclude-tools run_agent`
      with prompt on stdin (read-only agents never receive `edit`/`write`; `cold-reader` never
      receives `bash`). Mark gate outputs `authoritative: false` with an explicit
      `SELF-CHECK ONLY (non-authoritative)` warning banner forbidding recording in `gate-ledger`. -
      `backend: "claude"`: spawn `claude -p --model <alias> --tools <csv>` with prompt on stdin.
      Enforce alias-only models (`sonnet`, `opus`, `fable`; never versioned IDs), reject `sonnet`
      and `fable` on `security-reviewer`, and reject `fable` on every agent except `cold-reader`. -
      `backend: "agy"`: spawn
      `agy --mode <plan|auto> --disable-slash-commands --print-timeout <N>s [--model <m>] --print=<prompt>`
      with `stdin` ignored (`--mode plan` for read-only agents and `cold-reader`, `--mode auto` for
      `implementer`; do not pass `--agent` since installed plugin stubs have `mainAgent: false`). -
      Reject flag-like `model` strings starting with `-`, unknown agent/backend, empty prompt,
      invalid `timeoutSeconds`, and invalid `cwd`; surface a clear remediation message on
      `ENOENT`. - Run `hooks/verdict-guard.sh` on review-gate outputs when exit code is 0 and
      populate `details.verdictValid` and `details.verdictError`, prefixing a visible warning when
      invalid.
- [ ] Add `plugins/dev-team/tests/pi-adapter.test.sh` testing the root `package.json`, live hook
      delegation (`session-context.sh`, `merge-gate.sh`, `attribution-guard.sh`, fail-closed without
      `jq` or hook script), and all three `run_agent` backends (via stubbed binaries and real
      `verdict-guard.sh`) directly in Node without requiring Pi or API keys.
- [ ] Wire `plugins/dev-team/tests/pi-adapter.test.sh` into `.github/workflows/ci.yml`, `CLAUDE.md`,
      and `DEV_PROCESS.md` (keeping `DEV_PROCESS.md` under 9,500 UTF-8 characters).
- [ ] Update `plugins/dev-team/skills/tpm/SKILL.md` (`Under Pi` notes), `README.md` (`### Pi` under
      `## Installation`, `## Verdict guard`, and a Table of Contents if `README.md` reaches 100
      lines), `CLAUDE.md` layout, and bump `plugins/dev-team/.claude-plugin/plugin.json` to `0.20.0`
      while keeping the one-line plugin description byte-identical across all synced files
      (including root `package.json`).

## Acceptance Criteria

- [ ] Both Claude manifests validate cleanly under
      `claude plugin validate .claude-plugin/marketplace.json --strict` and
      `claude plugin validate plugins/dev-team --strict`.
- [ ] `shellcheck`, `python3 -m py_compile`, `prettier --check` on all tracked `*.md`, full-tree
      `lesson-lint`, `preflight-scan --scope=diff`, and all 9 test scripts (including
      `pi-adapter.test.sh`) pass with zero errors and zero warnings.
- [ ] `pi-adapter.test.sh` covers `before_agent_start` caching and graceful degradation, `tool_call`
      allow/deny and fail-closed paths (missing `jq`, non-string command, missing hook), and every
      `run_agent` validation rule and backend (`pi`, `claude`, `agy`) plus `verdict-guard.sh`.
- [ ] `DEV_PROCESS.md` stays under 9,500 UTF-8 characters; root `package.json`, `README.md`,
      `plugins/dev-team/README.md`, `.claude-plugin/marketplace.json`, and
      `plugins/dev-team/.claude-plugin/plugin.json` carry the byte-identical one-line description.
- [ ] Comment and doc lines remain well under code lines in every touched source file, with no
      single-use one-statement helpers.

## Implementation Plan

Verified live constraints on this machine (`@earendil-works/pi-coding-agent` 1.5.2, `agy` 1.5.18,
`claude` 2.1.326, Node 22+ in CI):

1. Pi 1.5.2 provides `typebox` and `@earendil-works/pi-coding-agent` as host peer dependencies
   (never in `dependencies`), validates plain JSON Schema objects directly in `registerTool`, and
   supports cache-friendly prompt injection via `event.systemPromptOptions.sections["dev-team"]`.
2. `pi.exec` does not accept `stdin`, so `dev-team.ts` uses `node:child_process` `spawn` to pipe
   JSON payloads to Bash hooks and prompts to `claude` / `pi`.
3. `agy --agent <name>` rejects plugin stubs because `install-agy` sets `mainAgent: false`, and
   `agy --print` requires a value (`--print=<prompt>`). Therefore the `agy` backend passes the
   assembled agent prompt via `--print=<prompt>` with `--mode plan` (read-only) or `--mode auto`
   (`implementer`) and `--disable-slash-commands`.
4. `dev-team.ts` exports its default Pi extension factory (and pure helpers if useful for testing,
   or tested directly through a minimal mock `ExtensionAPI` in `pi-adapter.test.sh`) using erasable
   TypeScript syntax and only `node:*` runtime imports so CI runs `pi-adapter.test.sh` on stock Node
   22 with zero `npm install`.

## Dependencies

- Blocked by: none · Blocks: PersonalStuff mac_setup.sh Pi install and legacy pi_extensions cleanup
  (separate repo)

## Out of Scope

- Changes to `PersonalStuff` (`mac_setup.sh`, `claude_to_symlink/setup.sh`, or retiring legacy
  `claude_to_symlink/pi_extensions/*.ts`).
- Discord bot bridge or remote `oMLX` setup.
- Publishing `my-dev-team` to the public npm registry (`"private": true` in `package.json`).
