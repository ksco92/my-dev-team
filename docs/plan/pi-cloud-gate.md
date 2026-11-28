---
difficulty: high
priority: p0
status: done
---

# Gate Paid Cloud Backends (`claude`, `agy`) in Pi Extension

## Context

In `plugins/dev-team/pi/dev-team.ts`, a local Pi model can invoke paid cloud backends (`claude` or
`agy`) without user approval either through `run_agent(backend: "claude" | "agy")` or by shelling
out to `claude` / `agy` via `bash`. Adding a human-only `/cloud` session toggle plus per-call
`ctx.ui.confirm` approval ensures Pi stays local unless the user explicitly permits a cloud call.

## Requirements

- [ ] Add session cloud-mode state to `plugins/dev-team/pi/dev-team.ts` with modes
      `"off" | "ask" | "once" | "on"`: - Read the initial/reset mode from
      `process.env.DEV_TEAM_CLOUD_MODE` if it is one of `"off" | "ask" | "once" | "on"`, otherwise
      default to `"ask"`. - Track a `baseMode` (`"off"` when initialized or set to `"off"`,
      otherwise `"ask"`) so consuming `"once"` always reverts to `"off"` or `"ask"` and never leaves
      `"once"` armed. - Reset cloud mode and `baseMode` from `process.env.DEV_TEAM_CLOUD_MODE` on
      `session_start` so `"on"` and `"once"` never leak across `/new`, `/resume`, `/fork`, or
      `/reload`. - Behavior when a cloud backend (`claude` or `agy`) is requested: - `"off"`: deny
      immediately without prompting. - `"ask"`: if `!ctx.hasUI` or `!ctx.ui?.confirm`, deny
      immediately (fail-closed); otherwise call `await ctx.ui.confirm(title, details)` showing the
      operation (`run_agent` agent, backend, and resolved model, or the `bash` command snippet) and
      allow only when it resolves strictly to `true` (fail-closed on `false`, `undefined`, or
      thrown/rejected errors). - `"once"`: consume immediately (revert mode to `baseMode`) and allow
      this single call. - `"on"`: allow without prompting until toggled off or a new session starts.
- [ ] Register a human-only `/cloud` slash command via `pi.registerCommand("cloud", ...)`: -
      `/cloud` or `/cloud status`: notify `"Cloud backend mode: `<mode>`"` (`"info"`). -
      `/cloud off | ask | once | on`: update session mode (updating `baseMode` for `off`/`ask`) and
      notify `"Cloud backend mode set to `<mode>`."` (`"info"`). - Any other argument: notify
      `"Usage: /cloud [off|ask|once|on|status]"` (`"warning"`).
- [ ] Enforce the cloud-mode gate at every cloud-backend entry point: - `run_agent`: run the cloud
      gate for `backend === "claude" || backend === "agy"` after parameter and model-policy
      validation and before spawning the subprocess; throw a clear error naming the mode and
      `/cloud` remediation when denied. `backend === "pi"` is always local and never gated. - Child
      `pi` subagents spawned by `run_agent(backend="pi")` receive `DEV_TEAM_CLOUD_MODE: "off"` in
      `childEnv` so local subagents cannot invoke `claude` or `agy` via `bash`. - `bash`
      (`pi.on("tool_call")`): after `runBashHooks` passes, detect command-position invocations of
      `claude` or `agy` via a quote-aware shell detector covering: - Command separators (`;`, `&&`,
      `||`, `|`, `|&`, `&`, newlines, subshells `( ... )`), command substitutions (`$(...)` and
      backticks, including inside double quotes), and leading redirections (`<`, `>`, `>>`, `2>`,
      `&>`, `<<<`, `<<` with their target skipped). - Leading environment assignments (`VAR=val`)
      and wrapper prefixes (`env`, `command` excluding `-v`/`-V` existence checks, `exec`, `nohup`,
      `nice`, `time`, `sudo`, `timeout`, `npx`/`bunx` including `@anthropic-ai/claude-code`,
      `pnpm`/`yarn` `exec`/`dlx`, `xargs`, and `sh`/`bash`/`zsh`/`dash` `-c <script>`). - Path
      prefixes (`/opt/homebrew/bin/claude`, `./agy`), quotes/backslashes (`\claude`), and case
      variants (`CLAUDE`, `Agy`). - Must NOT false-match `.claude/` paths, `CLAUDE.md`,
      `grep claude ...`, `which claude`, `command -v claude`, redirection targets
      (`echo hi > claude`), or quoted arguments/commit messages (`echo "foo; claude -p hi"`,
      `git commit -m "Use claude"`). - Apply the exact same cloud-mode gate returning
      `{ block: true, reason }` when denied.
- [ ] Append the live cloud-mode notice dynamically on `before_agent_start` (outside `contextCache`
      so `/cloud` toggles take effect on the next turn without stale cache, and injected even if
      `session-context.sh` returns empty): - When mode is `"off"`:
      `Cloud backends (claude, agy) are DISABLED in this session. Stay local on backend="pi" and never invoke claude or agy via run_agent or bash.` -
      When mode is `"ask"`:
      `Cloud backends (claude, agy) require explicit user approval. Stay local on backend="pi" and do NOT call backend="claude", backend="agy", or the claude/agy CLIs unless the user explicitly asks you to.` -
      Omit the restriction notice in `"on"` and `"once"` modes.
- [ ] Extend `plugins/dev-team/tests/pi-adapter.test.sh` to cover all cloud modes, fail-closed
      headless (`!ctx.hasUI`) behavior, `ctx.ui.confirm` allow/deny/throw, `/cloud` subcommands and
      invalid arg usage, `session_start` reset, child `DEV_TEAM_CLOUD_MODE=off`,
      `before_agent_start` dynamic notice across mode toggles, and every covered `bash` detection
      positive and negative case.
- [ ] Update `README.md` (`## Usage` Pi paragraph documenting `/cloud` and `DEV_TEAM_CLOUD_MODE`,
      and `Status` line to `v0.22.0`) and bump `version` from `0.21.0` to `0.22.0` in both
      `plugins/dev-team/.claude-plugin/plugin.json` and root `package.json` (keeping the one-line
      description byte-identical across all 6 synced files).

## Acceptance Criteria

- [ ] Every function in `plugins/dev-team/pi/dev-team.ts` stays at or under 60 code lines and 4
      levels of nesting, with only `node:*` runtime imports, erasable TypeScript syntax, and comment
      lines well under code lines (no single-use one-statement helpers).
- [ ] All covered `bash` cloud-CLI forms (direct, path-prefixed, case variant, wrappers, pipelines,
      command substitutions, `sh -c`) are gated and all benign non-invocation forms (`.claude/`,
      `CLAUDE.md`, quoted strings, `which`/`command -v`, redirection targets, commit messages) pass
      without prompting. Accepted boundary: dynamic dispatch (`eval`, variable command names `$CMD`,
      shell aliases/functions, encoded scripts) is not parsed statically, matching `merge-gate.sh`.
- [ ] `claude plugin validate` (both manifests `--strict`), `shellcheck`, `python3 -m py_compile`,
      `prettier@3.6.2 --check`, full-tree `lesson-lint`, `preflight-scan --scope=diff` and
      `--scope=full`, and all 9 test scripts (including `pi-adapter.test.sh` direct and via a
      symlinked path) pass with zero errors and zero warnings.
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` and root `package.json` both read `0.22.0`,
      `README.md` status reads `v0.22.0`, zero em-dashes added to touched Markdown, and the one-line
      description matches byte-for-byte across all 6 synced files.

## Implementation Plan

1. Add cloud-mode state management (`parseCloudMode`, `createCloudGate` or module helpers), the
   `/cloud` command handler, and `session_start` reset in `plugins/dev-team/pi/dev-team.ts`.
2. Add quote-aware shell tokenization and `detectCloudCliInvocation` (with bounded recursion depth
   for nested substitutions / `sh -c`) and wire cloud authorization into both `tool_call` (`bash`)
   and `executeRunAgent`, plus `DEV_TEAM_CLOUD_MODE: "off"` for `backend: "pi"` child processes and
   dynamic cloud-mode notice in `before_agent_start`.
3. Update `plugins/dev-team/tests/pi-adapter.test.sh` (record `DEV_TEAM_CLOUD_MODE` in
   `agent-stub.sh`, keep existing backend tests passing with `DEV_TEAM_CLOUD_MODE=on`, and add
   comprehensive cloud-gate tests).
4. Update `README.md` (`## Usage` and `v0.22.0` status) and bump `plugin.json` + `package.json` to
   `0.22.0`.

## Dependencies

- Blocked by: pi-adapter-core (merged in PR #78) · Blocks: none

## Out of Scope

- Changes to external chat-bridge repositories or workstation setup scripts.
- Static evaluation of arbitrary shell `eval`, variable indirection (`$CMD`), or encoded scripts.
