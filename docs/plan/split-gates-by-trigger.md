---
difficulty: medium
priority: p2
status: done
---

## Context

https://github.com/ksco92/my-dev-team/pull/44 leaves `plugins/dev-team/context/tpm/gates.md` past
the lesson-lint budget of 30 bullets (28 on main before it). The tpm skill says a topic file past
~30 entries is split by trigger, not trimmed; the split axis is the owner's call, which is why it is
a ticket.

## Requirements

- [ ] `gates.md` is split into two or more topic files, each under 30 bullets, each with a lead-in
      that names its trigger (for example: ledger and merge mechanics; rebase and verdict carry;
      findings triage and rulings), and the `tpm` skill's Phase 5 text names each new file where it
      names `gates.md` today.
- [ ] No bullet is trimmed or reworded in the split; every sentence of `gates.md` has a home in one
      of the new files (diff the set of sentences between base and head).
- [ ] `lesson-lint` runs clean, with no budget warning on the new files.

## Acceptance Criteria

- [ ] All requirements verifiable from the diff
- [ ] `claude plugin validate` and the four test scripts pass
- [ ] The plugin version bumps a minor (a skill file's required reading changed)

## Implementation Plan

Owner picks the split axis; then one docs PR.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Any new lesson; `briefing.md` and the CDK guide, which have their own split tickets.
