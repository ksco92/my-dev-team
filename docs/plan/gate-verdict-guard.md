---
difficulty: medium
priority: p1
status: done
---

## Context
A review gate that runs a cleanup tool call after writing its report can end on a one-line note,
leaving its final message without the verdict block the orchestrator records.

## Requirements
- [x] `hooks/verdict-guard.sh` exits 0 unless the subagent type is one of the five gate agents or
  `stop_hook_active` is true; otherwise it requires `GATE: <name>`, `VERDICT: PASS|FAIL|BLOCKED`,
  `HEAD: <7 to 40 hex>` and `FINDINGS: <digits>` each on its own line in `last_assistant_message`
  (BLOCKED needs only the first two), and on a miss prints one sentence naming the missing lines to
  stderr and exits 2. A missing or empty message, and input that does not parse, exit 0.
- [x] The type is matched by exact name, bare or `dev-team:`-prefixed, with no generic prefix strip:
  the hooks reference shows plugin agents as `<plugin>:<agent>`, so another plugin's agent of the
  same name is not held.
- [x] `hooks/hooks.json` registers it under `SubagentStop` with timeout 10.
- [x] `tests/verdict-guard.test.sh` covers a complete block, HEAD length bounds (6, 7, 40, 41 and
  non-hex), a cleanup sentence, a missing HEAD and a non-numeric FINDINGS naming the line, bad
  VERDICT and GATE values, markdown or prose wrapping, trailing space and CR, text after a complete
  block, BLOCKED, bare and prefixed agent types, a non-gate subagent, `stop_hook_active`, and an
  empty, absent or unparseable input.
- [x] Each gate agent file carries the sentence: remove your probe and finish every tool call before
  writing the verdict; the verdict block is the last text you emit.
- [x] `context/tpm/gates.md` states that a result without the block is void until the gate resends it.
- [x] The root README, `CLAUDE.md` and the CI `validate` job name the hook and its test.
- [x] Version bumped one minor step.

## Acceptance Criteria
- [x] shellcheck clean on the hook and the test; every test script passes; both plugin validations pass.
- [x] `lesson-lint --added origin/main` exits 0.
- [x] Positive and negative hook-input cases run by hand.

## Implementation Plan
The final text is the hook input's `last_assistant_message`, the field the hooks reference names as
the supported source; the transcript is not read.

## Dependencies
- Blocked by: none · Blocks: none

## Out of Scope
Checking that the HEAD matches the PR head, or that FINDINGS agrees with the listed findings.
