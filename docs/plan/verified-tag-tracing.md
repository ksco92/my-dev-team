---
difficulty: low
priority: p2
status: done
---

## Context
A skills-research run gated agent-instruction files whose legal claims carried a verified tag.
Two correctness findings recurred: an unverified clause sat under a tag written for its
neighbour, and a quoted statutory exemption omitted the statute's carve-out.

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
