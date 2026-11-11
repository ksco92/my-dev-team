---
difficulty: low
priority: p2
status: done
---

## Context

A run that worked six small tickets of one library through the gates (rules files, a lint preset, a
retry policy, test cleanup, a handler fix) returned five lessons with evidence. Three land as folds
into existing text and two as new bullets.

## Requirements

- [x] `context/tpm/verification.md` carries the mutant-count rule (evidence: an implementer's mutant
      runs used a `-k` filter that deselected eight slow tests and reported smaller failure counts
      than the correctness gate measured on the full suite; the full rerun matched the gate's
      numbers).
- [x] The rebase-brief bullet of `context/tpm/briefing.md` gains the PR-body re-derivation
      (evidence: after a merge-turn rebase a gate found the body's README line cites pointing at a
      code fence and a closing fence, and a pasted `git diff --stat` block listing one file where
      the head changed seven).
- [x] The sibling-merge bullet of `context/tpm/briefing.md` gains the title and commit messages
      (evidence: a gate failed a PR whose first commit message described checks a fix round had
      removed; the repository's squash message is built from the commit messages, so the merge would
      have published the false text).
- [x] The recipe paragraph of `skills/tpm/SKILL.md` says a prescribed message's remedy holds for
      each kind of object it can name (evidence: a prescribed error told the reader to remove the
      ref it named, and the ref could be the main branch, which the table format refuses to remove).
- [x] `context/cdk-coding-guide.md` section 2.3 carries the synthesized-template rule (evidence: a
      rules-file line said every grant to a service principal carried a source condition; the
      template of a stack with a `Trail` holds bucket `Allow` statements with none, which the source
      never writes).
- [x] Version bumped one patch step.

## Acceptance Criteria

- [x] `lesson-lint --added` exits 0; prettier check passes.
- [x] `briefing.md` stays under 30 bullets.

## Implementation Plan

Bullet-level edits only.

## Dependencies

- Blocked by: lessons-run-date-grain-run (stacked on it) · Blocks: none

## Out of Scope

Splitting `gates.md` and the learned patterns of `cdk-coding-guide.md`, both over their budget
before this change. The lint-preset lesson of the run is already a learned pattern of
`cdk-coding-guide.md` and is not restated.
