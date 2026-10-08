---
difficulty: low
priority: p2
status: done
---

## Context
A run of about thirty docs-trim and small-fix PRs on a Rust core with Python bindings, each through
the five review gates, produced lessons for the orchestrator, the gates and the Rust guide. Each one
lands where the tpm skill's home test puts it, with its evidence in the change body.

## Requirements
- [ ] `context/tpm/operations.md` gains rules for per-agent scratch files, re-reading a PR body
      before editing it, and heredoc scratch writes.
- [ ] `context/tpm/briefing.md` states one push form, re-measures numeric targets with the issue's
      method, prescribes rewords as exact old and new text, and adds a doc-trim brief rule.
- [ ] `context/tpm/gates.md` states that a record at another head resets the ledger, rebases before
      the first gate round, ranks ticket text against gate preference, and diffs the sentence set of a
      doc restructure.
- [ ] `skills/tpm/SKILL.md` 5.1 and 5.2 agree on how a verdict reaches a new head; the reviewer
      baseline forbids cloning into or checking out in a probe.
- [ ] The code-health skill, the pr-reviewer agent, the oss-reviewer catalog and the Rust guide take
      the gate and Rust lessons, refined in place where a bullet already covers the subject.

## Acceptance Criteria
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main` passes on every edited file
- [ ] Each topic file stays at or under 30 bullets; the tpm skill stays under 350 lines
- [ ] `plugin.json` version bumped one patch step

## Implementation Plan
Grep each target section for the lesson, refine before adding, and keep evidence in the change body.

## Dependencies
- Blocked by: none · Blocks: none

## Out of Scope
Repo-specific rules for the source repository; splitting a topic file by trigger.
