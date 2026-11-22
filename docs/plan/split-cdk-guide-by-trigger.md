---
difficulty: medium
priority: p2
status: done
---

## Context

https://github.com/ksco92/my-dev-team/pull/42 leaves the `## Learned patterns` section of
`plugins/dev-team/context/cdk-coding-guide.md` at 28 bullets against the lesson-lint budget of 25.
The tpm skill says a file past its budget is split by trigger, not trimmed; the split axis is the
owner's call, which is why it is a ticket.

## Requirements

- [ ] The CDK guide's learned patterns are split along one trigger axis the owner picks (for example
      Lake Formation and Glue Data Catalog rules versus jsii, tooling and template-test rules),
      either into a second `context/*-coding-guide.md` or into a second section `lesson-lint` counts
      on its own, each under 25 bullets
- [ ] Every bullet keeps its text; a bullet whose purpose clause depended on a neighbour is re-read
      alone
- [ ] `context/policy.md`'s guide table and the tpm skill's "Learned patterns and where they go"
      name the new home where the orchestrator must read it
- [ ] `lesson-lint` runs clean on both homes, with no budget warning

## Acceptance Criteria

- [ ] All requirements verifiable from the diff
- [ ] `bash plugins/dev-team/tests/lesson-lint.test.sh` passes
- [ ] The set of bullet sentences before and after the split is identical

## Implementation Plan

Group the 28 bullets by their trigger phrase, propose the axis to the owner, move the bullets,
update the policy table and SKILL.md, bump the patch version.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Rewording or dropping any bullet.
