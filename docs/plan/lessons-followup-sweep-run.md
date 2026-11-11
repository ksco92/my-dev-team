---
difficulty: low
priority: p2
status: done
---

## Context

A run that worked six follow-up tickets of one library through the gates in parallel, with serial
merges and a version bump per PR, returned seven lessons with evidence. One lands in the phase text
of the `tpm` skill, four as folds into existing text and two as new bullets.

## Requirements

- [x] Phase 5.2 of `skills/tpm/SKILL.md` lets a clean rebase carry verdicts for a file the trunk
      changed outside the PR's hunks by an equal `git patch-id` of the PR's diff of that file
      against the old base and against the new one (evidence: four PRs rebased in turn onto a trunk
      that had merged a sibling's README and test-file edits; the blob hash of those two files
      differed at every rebase while `git diff <old base> <old head> -- <file> | git patch-id` and
      `git diff <new base> <new head> -- <file> | git patch-id` printed the same id, and CI passed
      on each new head).
- [x] The sibling-merge bullet of `context/tpm/briefing.md` gains the one-commit final rebase
      (evidence: two gates failed a PR on a fix-round commit subject that named a function the head
      no longer had; the repository's squash message is built from the commit subjects, and one
      commit under the PR title closed both).
- [x] The pre-push check of `context/agent-baseline.md` gains the function recount (evidence: a
      code-economy gate failed a PR whose one added call took a function at the length limit over
      it).
- [x] The reword bullet of `context/tpm/doc-edits.md` covers a number the sentence already carries
      (evidence: a gate failed a PR body bullet that gave one figure three times after a fix clause
      was spliced in).
- [x] `context/tpm/doc-edits.md` carries the moved-check rule (evidence: a rules-file sentence named
      the old home of a check after a fix round moved it into a new helper, and the next round's fix
      deleted the helper).
- [x] `context/tpm/doc-edits.md` carries the randomised-wait rule (evidence: two review rounds on
      one README sentence, first for an expected wait given without its distribution and then for a
      claim that jitter keeps two executions from retrying at the same time).
- [x] The heavy-jobs bullet of `context/tpm/operations.md` gains the touched-files rule (evidence:
      with a load average between 13 and 28 from parallel implementers and gates, a full `npx jest`
      run hung for more than 20 minutes for one implementer; the touched test files run with
      `--runInBand` finished).
- [x] Version bumped one patch step.

## Acceptance Criteria

- [x] `lesson-lint --added` exits 0; prettier check passes.
- [x] `briefing.md` stays under 30 bullets.

## Implementation Plan

Bullet-level edits only.

## Dependencies

- Blocked by: lessons-issue-sweep-run (stacked on it) · Blocks: none

## Out of Scope

Splitting `gates.md`, over its budget before this change and not touched by it. Its bullet on two
PRs that wrote the same next version states the object-hash proof alone; it is reworded when the
file is split.
