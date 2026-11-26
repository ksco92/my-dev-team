---
status: done
---

# Antigravity Dual-Harness Adapter

## Context

`dev-team` ships as a Claude Code plugin under `plugins/dev-team/`. Running the same workflow in
Antigravity without duplicating skills, coding guides, scripts, or hook logic requires a thin
adapter for Antigravity's hook JSON contract and a symlink-based installer for its plugin layout.

## Requirements

- Add `plugins/dev-team/hooks/agy-hook.sh` to translate Antigravity `PreToolUse` (`run_command`) and
  `SessionStart` JSON payloads to and from the existing `merge-gate.sh`, `attribution-guard.sh`, and
  `session-context.sh` scripts, failing closed when `jq` is unavailable on `PreToolUse`.
- Extend `plugins/dev-team/hooks/attribution-guard.sh` to block Antigravity/Gemini AI-attribution
  trailers alongside Claude ones.
- Add `plugins/dev-team/bin/install-agy` (Python 3 stdlib) to install into
  `~/.gemini/config/plugins/dev-team` by symlinking `skills/`, `context/`, `bin/`, `templates/`,
  `hooks/`, and `README.md` to the local clone and generating only `plugin.json`, `hooks.json`, and
  thin `agents/*.md` pointer stubs (plus safe `--uninstall`).
- Add a concise `Under Antigravity` note to `plugins/dev-team/skills/tpm/SKILL.md` (mapping tiers to
  Antigravity's `flash`/`pro`/`inherit` aliases), a `cold-reader` inheritance note to
  `plugins/dev-team/skills/audit/SKILL.md`, and dual installation instructions in `README.md`.
- Add `plugins/dev-team/tests/agy-adapter.test.sh`, wire it and `install-agy` into
  `.github/workflows/ci.yml`, `CLAUDE.md`, and `DEV_PROCESS.md`, and bump `plugin.json` to `0.19.0`.

## Acceptance Criteria

- Both Claude plugin manifests validate under `claude plugin validate --strict`.
- `shellcheck`, `python3 -m py_compile`, `prettier --check`, full-tree `lesson-lint`,
  `preflight-scan --scope=full`, and all 8 test scripts pass with zero errors and zero warnings.
- `DEV_PROCESS.md` remains under 9,500 UTF-8 characters and `README.md` retains the byte-identical
  one-line description.
