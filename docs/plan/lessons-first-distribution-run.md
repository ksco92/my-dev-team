---
difficulty: medium
priority: p1
status: done
---

## Context

Three lesson lists are over the budget `lesson-lint` enforces: `context/tpm/review-probes.md` (35 of
30), `context/tpm/briefing.md` (31 of 30) and the `code-health` skill's Learned patterns (21 of 20).
Nine candidates wait in the lesson outbox. This is the `lessons` skill's decision table for those
three lists and those nine candidates; the orchestrating session made the decisions and gathered the
evidence, and this change applies them. Every bullet of the three lists that the table does not name
is a keep.

## Requirements

Each row is applied exactly: a moved or folded bullet keeps its words, and no neighbour is reworded.

- [x] `review-probes.md`, "A PR body that calls a state unreachable …": drop, ground 1. The rule is
      stated in `context/django-coding-guide.md` section 1 ("A `ModelAdmin` that overrides
      `has_add_permission` but not `has_delete_permission` … A claim that "nothing deletes X today"
      is checked against the admin as well as the application code."), which the correctness gate
      reads for a Django diff (`agents/pr-reviewer.md` step 3).
- [x] `review-probes.md`, "Verify an "the ORM cannot do X" justification …": move to
      `context/django-coding-guide.md`, Learned patterns. Loader: `agents/pr-reviewer.md` step 3,
      `skills/code-health/SKILL.md` Context Loading 1, `skills/oss-reviewer/SKILL.md` step 5.
- [x] `review-probes.md`, "Check a uniqueness guard on a name that becomes a physical resource name
      …": move to `context/cdk-services-coding-guide.md`, Learned patterns. Loader: the same three
      lines, with that guide's own lead-in ("Read with `cdk-coding-guide.md`").
- [x] `review-probes.md`, "When a guide names a setting as required for a security mode …": move to
      `context/tpm/doc-edits.md`, whose lead-in names prose that describes code and is read "with
      `review-probes.md` before the first gate on a PR that changes it" (`skills/tpm/SKILL.md` Phase
      5 reading list).
- [x] `review-probes.md`, "When a PR validates input against a character-class pattern …": merge
      into "Mutating a regex guard …", which becomes: "Mutating a regex guard, change only the
      `RegExp` line, never the message that quotes it, and mutate each piece (each alternative, `^`,
      `$`, `+` to `*`, each path group, each character class deleted in turn, each position of a
      counted class alone, each literal as a class of itself and a neighbouring class, each flag),
      requiring a test to fail for each; a mutant caught because the message changed failed on text,
      not behaviour, and a fixture with one sample of every allowed character usually leaves out a
      class."
- [x] `briefing.md`, "Headless `claude -p`: `--allowedTools` is variadic …": move to
      `context/tpm/operations.md`. Loader: `skills/tpm/SKILL.md` Phase 4 reads both files before the
      first brief of a run.
- [x] `briefing.md`, "Send a change you already know you will ask for …": move to
      `context/tpm/gates.md`, whose lead-in is running the gates and which Phase 5 reads before the
      first gate of a run.
- [x] `skills/code-health/SKILL.md` Learned patterns, "Before accepting a doc comment on a `const`
      or small `type` alias …" and "A crate under a package's `[dependencies]` …": fold each, as its
      own bullet with its words unchanged, into `context/rust-coding-guide.md` section 6 (Known
      Pitfalls), which the skill's Context Loading 1 makes binding ("its numbered sections and
      `## Learned patterns`").
- [x] Candidate, rule text that waits on the owner: keep, new bullet in `doc-edits.md`: "Rule text
      that makes an action wait on the owner says "and wait" or "until the owner agrees" at every
      such place; a file that says it in some bullets and only "put it to the owner" in others is
      read as notify-and-proceed in the second kind."
- [x] Candidate, a procedure against a do-not list: keep, new bullet in `doc-edits.md`: "When a PR's
      procedure assigns the orchestrator an act that a skill's do-not list names (push, merge,
      write), brief the correctness gate to grep that list for every verb the procedure assigns and
      to require a clause at one of the two sites saying which wins."
- [x] Candidate, enumeration beside its defining rule: keep, new bullet in the `code-health` skill's
      Learned patterns: "When a sentence both enumerates a set and ends with the rule that defines
      it, keep the defining rule and delete the enumeration; the list is a second statement that
      drifts."
- [x] Candidate, wording of a fix: keep, new bullet in `agents/security-reviewer.md` Learned
      patterns: "When a rule gates a finding by the form of its fix, word the fix as the smallest
      replacement (parameterize, change the default, remove) before an added control; the wording
      decides whether the item blocks, so it is chosen against the defect."
- [x] Candidate, merge order: keep, new bullet in `gates.md`: "Two open changes that touch the same
      file merge in the order that costs one review: the one that is clean first merges first, and
      the other takes the next version in the fix round it already needs; a planned order is not a
      reason to hold a clean change."
- [x] Candidate, rule files in a cross-repo brief: keep, new bullet in `briefing.md`: "Every
      cross-repo brief names the target repository's `CLAUDE.md` and `.claude/rules/` files as
      required reading, read in the workspace or probe; a subagent loads the session repository's
      rules, not the target's."
- [x] Candidate, a ticket's size limit re-read at dispatch: drop, ground 1. `briefing.md` states it:
      "A numeric per-file target in an issue (a comment ratio, a line count) is recomputed at
      current main with the issue's own counting method at dispatch".
- [x] Candidates, an eval grader scoped to one item and an eval case run on the tree without the
      rule: both are true only in this repository, so they land in its own rules and not as plugin
      bullets. `.claude/rules/skills.md` gains: "An eval grader judges one item (a line, a fix, a
      row) and never a count of findings. An eval case meant to show that a rule suppresses a
      finding is run on the tree without the rule, with only the case and its fixture copied in, and
      is kept only if it fails there."
- [x] After the edits the counts are: `review-probes.md` 30, `briefing.md` 30, `code-health` 20,
      `doc-edits.md` 20, `gates.md` 25, `operations.md` 27, `django-coding-guide.md` 23,
      `cdk-services-coding-guide.md` 20, `security-reviewer.md` 4, `rust-coding-guide.md` Learned
      patterns 23, by the counting command in `skills/lessons/SKILL.md` section 1.
- [x] The change body carries what section 6 of the `lessons` skill lists: the two inventory tables,
      the decision table with one row for each of the 87 bullets and 9 candidates (first words,
      decision, destination, evidence, and for every kept, moved, folded or merged rule the
      `git grep` hit of its trigger words in a file its applier loads), and the count per decision,
      which sums to 96.
- [x] The three tickets `split-briefing-by-trigger`, `split-gates-by-trigger` and
      `split-cdk-guide-by-trigger` are committed with `status: done`: each list is at or under its
      budget at the head (`briefing.md` 30 of 30, `gates.md` 25 of 30, the CDK guide 25 of 25)
      without a split.

## Acceptance Criteria

- [x] All requirements verifiable from the diff and the counting command
- [x] Every local check in `CLAUDE.md` passes; `lesson-lint --added origin/main` prints no budget
      warning and no fault on a moved, merged or new bullet
- [x] The set of sentences of the moved and folded bullets is the same at the base and the head
      (diff the sorted sentences; the merged bullet and the dropped one are the only differences
      among existing bullets)
- [x] No eval run is needed; the change is lesson text

## Implementation Plan

Lint each bullet where it sits before moving it (`plugins/dev-team/bin/lesson-lint <file>`) and
carry no fault into its new place. Apply the rows in the order given. A new bullet goes at the end
of its list; a moved bullet goes at the end of its destination list or section. Build the decision
table's keep rows from the files: first words, the trigger words, and one `git grep` hit. The
version takes a patch bump in the final rebase.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Every other lesson list; the nineteen later candidates in the outbox; any split by trigger, which is
the owner's choice; the `pm` and `readme-writer` self-mutation paragraphs
(`process-text-consistency`).
