---
difficulty: low
priority: p2
status: done
---

## Context

Both rules are orchestrator checks between a fix round and the next gate round, the phase
`context/tpm/gates.md` governs; each folds into the existing bullet whose subject it shares.

## Requirements

- [x] The `context/tpm/gates.md` bullet beginning "Read the head SHA..." carries the landed-fix
      check.
- [x] The `context/tpm/gates.md` bullet beginning "A gate result that lacks the verdict block..."
      carries the stalled-gate rule.
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
