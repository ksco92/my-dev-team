---
difficulty: medium
priority: p2
status: done
---

## Context

https://github.com/ksco92/my-dev-team/pull/30 left `plugins/dev-team/context/tpm/briefing.md` at 31
bullets against the lesson-lint budget of 30. The tpm skill says a topic file past ~30 entries is
split by trigger, not trimmed; the split axis is the owner's call, which is why it is a ticket.

## Requirements

- [ ] `briefing.md` is split into two `context/tpm/*.md` files along one trigger axis the owner
      picks (for example implementer briefs versus reviewer and fix-round briefs), each under 30
      bullets
- [ ] Every bullet keeps its text; a bullet whose purpose clause depended on a neighbour is re-read
      alone
- [ ] `skills/tpm/SKILL.md` Phase 4, Phase 5.2 and the "Learned patterns and where they go" topic
      list name the new file where the orchestrator must read it
- [ ] `lesson-lint` runs clean on both files, with no budget warning

## Acceptance Criteria

- [ ] All requirements verifiable from the diff
- [ ] `bash plugins/dev-team/tests/lesson-lint.test.sh` passes
- [ ] The set of bullet sentences before and after the split is identical

## Implementation Plan

Group the 31 bullets by their trigger phrase, propose the axis to the owner, move the bullets,
update SKILL.md's read instructions, bump the patch version.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Rewording any bullet; splitting `gates.md` (27 bullets) before it passes its budget.
