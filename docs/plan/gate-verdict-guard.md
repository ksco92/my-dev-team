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
  `HEAD: <7 to 40 hex>` and `FINDINGS: <digits>` each on its own line in the final assistant text
  (BLOCKED needs only the first two), and on a miss prints one sentence naming the missing lines to
  stderr and exits 2. An unreadable transcript exits 0 with nothing printed.
- [x] `hooks/hooks.json` registers it under `SubagentStop` with timeout 10.
- [x] `tests/verdict-guard.test.sh` covers a complete block, a cleanup sentence after an earlier
  block, BLOCKED, a non-gate subagent, `stop_hook_active`, and an unreadable transcript.
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
The final text comes from the hook input's `last_assistant_message`, falling back to the last
assistant text in `agent_transcript_path`.

## Dependencies
- Blocked by: none · Blocks: none

## Out of Scope
Checking that the HEAD matches the PR head, or that FINDINGS agrees with the listed findings.
