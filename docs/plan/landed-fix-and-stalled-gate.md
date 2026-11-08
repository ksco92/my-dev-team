---
difficulty: low
priority: p2
status: done
---

## Context

An implementer's report can describe a change that is not in the pushed head, and every gate then
re-finds it. A gate subagent can hang on its last command after writing its findings, leaving no
verdict and no notification.

## Requirements

- [x] The `context/tpm/gates.md` bullet on grep-verifying a gate's factual claims also covers an
      implementer's report that a prescribed change landed, checked by `grep -n` on the head before
      the re-gate round.
- [x] The `context/tpm/gates.md` bullet on a gate result without the verdict block says a gate whose
      transcript stops advancing on its final cleanup command is stopped, its probe removed by the
      orchestrator, and relaunched at the same head.
- [x] Version bumped one patch step.

## Acceptance Criteria

- [x] No bullet is added to `gates.md`; both edits extend existing bullets.
- [x] `lesson-lint --added origin/main` exits 0; prettier check, every test script and both plugin
      validations pass.

## Implementation Plan

Bullet-level edits only, keeping each bullet's trigger phrase.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Splitting `gates.md` to meet its bullet budget.
