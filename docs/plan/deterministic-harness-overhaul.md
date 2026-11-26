---
status: done
---

# Deterministic Harness Overhaul

## Context

Mechanical checks that can be decided deterministically were split across large prompt references
and coding guides, while several pre-existing `lesson-lint` violations, legacy specialist agent
files, and non-atomic ledger writes remained in the plugin.

## Requirements

- Add deterministic `plugins/dev-team/bin/preflight-scan` (`AI001`–`AI009`, `CH001`–`CH006`,
  `DOC001`–`DOC004`) with a Bash test suite and wire it into `agent-baseline.md`, `code-health`,
  `oss-reviewer`, and `readme-writer`.
- Shrink `plugins/dev-team/skills/oss-reviewer/references/ai-tells.md` to structural patterns not
  expressible as deterministic regex checks and add diff-based fast-skip to `readme-writer`.
- Harden `gate-ledger` with atomic locked writes and configurable required gates (`gates:` in
  `DEV_PROCESS.md` frontmatter, read via `check --repo-dir`), and tighten `verdict-guard.sh` to
  enforce canonical `GATE:` names and `VERDICT:`/`FINDINGS:` consistency.
- Fix all pre-existing `lesson-lint` violations across `plugins/dev-team/**/*.md` and run full-tree
  `lesson-lint` in CI.
- Upgrade `lessons/SKILL.md` with Drop Ground 6 (automated or retired rules) and a total-phase
  context budget; align `pm/SKILL.md` to delegate learned patterns to `lessons`.
- Add a design/contract micro-checkpoint for `high` slices and `/pm` intake pointer in
  `tpm/SKILL.md`, relocate stack-specific bullets out of generic TPM/reviewer files into stack
  guides, and remove unused `backend.md` and `frontend.md` specialist agents (folding UI PR and
  accessibility guidance into `react-coding-guide.md`).
- Slim `python-coding-guide.md`, `react-coding-guide.md`, and `cdk-coding-guide.md` to reference
  deterministic linters (`max-lint` including `MXL001`–`MXL012` and private-function docstrings,
  hardened check-only ESLint with `eslint-plugin-jsdoc`).
- Add a `tpm` eval case (`plugins/dev-team/evals/tpm-decomposition-and-escalation/`), clean root
  workspace clutter, and bump `plugin.json` to `0.18.0`.

## Acceptance Criteria

- All plugin manifests validate under `claude plugin validate --strict`.
- `shellcheck`, `python3 -m py_compile`, `prettier --check`, full-tree `lesson-lint`, and all seven
  test scripts under `plugins/dev-team/tests/` pass with zero errors and zero warnings.
- `policy.md` and every `DEV_PROCESS.md` remain under 9,500 UTF-8 characters.
