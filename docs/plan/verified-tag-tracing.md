---
difficulty: low
priority: p2
status: done
---

## Context
A verified tag covers every clause beside the one it was written for, and a quoted exemption
without its carve-outs overstates the rule; the correctness gate checks both.

## Requirements
- [ ] The pr-reviewer agent's learned patterns gain one bullet covering both checks.

## Acceptance Criteria
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main plugins/dev-team/agents/pr-reviewer.md` passes
- [ ] `plugin.json` version bumped one patch step

## Implementation Plan
Append one bullet to `## Learned patterns` in `agents/pr-reviewer.md`; bump the patch version.

## Dependencies
- Blocked by: none · Blocks: none

## Out of Scope
Repo-specific citation rules, which belong in the source repository's `.claude/rules/`.
