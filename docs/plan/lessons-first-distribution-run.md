---
difficulty: medium
priority: p1
status: done
---

## Context

Three lesson lists are over the budget `lesson-lint` enforces: `context/tpm/review-probes.md` (35 of
30), `context/tpm/briefing.md` (31 of 30) and the `code-health` skill's Learned patterns (21 of 20).
Candidates wait in the lesson outbox. This is the `lessons` skill's decision table for those three
lists and eight of the candidates; the orchestrating session made the decisions and gathered the
evidence, and this change applies them. Every bullet of the three lists that the table does not name
is a keep. A move is made only where the agent that applies the rule reads the destination at every
moment it read the source; two lists stay over their budget for that reason and get a proposed
split.

## Requirements

Each row is applied exactly: a moved or folded bullet keeps its words, and no neighbour is reworded.

- [x] `review-probes.md`, "Verify an "the ORM cannot do X" justification …": move to
      `context/django-coding-guide.md`, Learned patterns. Loader: `agents/pr-reviewer.md` step 3,
      `skills/code-health/SKILL.md` Context Loading 1, `skills/oss-reviewer/SKILL.md` step 5.
- [x] `review-probes.md`, "When a PR validates input against a character-class pattern …": merge
      into "Mutating a regex guard …", which becomes: "Mutating a regex guard, change only the
      `RegExp` line, never the message that quotes it, and mutate each piece (each alternative, `^`,
      `$`, `+` to `*`, each path group, each character class deleted in turn, each position of a
      counted class alone, each literal as a class of itself and a neighbouring class, each flag),
      requiring a test to fail for each; a mutant caught because the message changed failed on text,
      not behaviour, and a fixture with one sample of every allowed character usually leaves out a
      class."
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
- [x] Candidate, enumeration beside its defining rule: drop, ground 1. The `code-health` skill's
      Learned patterns state it: "A rule or rationale stated in two homes … is A2 duplication: one
      home plus a one-line pointer."
- [x] Candidate, wording of a fix: keep, new bullet in `agents/security-reviewer.md` Learned
      patterns: "When a defect's fix is a replacement (parameterize, change the default, remove),
      word it as that replacement, not as an added control, and never word an added control as a
      replacement."
- [x] Candidate, merge order: keep, new bullet in `gates.md`: "Two open changes that touch the same
      file merge the clean one first, so the other change is rebased once."
- [x] Candidate, a ticket's size limit re-read at dispatch: drop, ground 1. `briefing.md` states it:
      "A numeric per-file target in an issue (a comment ratio, a line count) is recomputed at
      current main with the issue's own counting method at dispatch".
- [x] Candidates, an eval grader scoped to one item and an eval case run on the tree without the
      rule: both are true only in this repository, so they land in its own rules and not as plugin
      bullets. A new `.claude/rules/evals.md` holds: "An eval grader judges one item (a line, a fix,
      a row) and never a count of findings. An eval case meant to show that a rule suppresses a
      finding is run on the tree without the rule, with only the case and its fixture copied in, and
      is kept only if it fails there."
- [x] After the edits the counts are: `review-probes.md` 33, `briefing.md` 31, `code-health` 19,
      `doc-edits.md` 19, `gates.md` 24, `operations.md` 26, `django-coding-guide.md` 23,
      `cdk-services-coding-guide.md` 19, `security-reviewer.md` 4, `rust-coding-guide.md` Learned
      patterns 23, by the counting command in `skills/lessons/SKILL.md` section 1.
- [x] The change body carries what section 6 of the `lessons` skill lists: the two inventory tables,
      the decision table with one row for each of the 87 bullets and 8 candidates (first words,
      decision, destination, evidence, and for every kept, moved, folded or merged rule the
      `git grep` hit of its trigger words in a file its applier loads; a fold row quotes the passage
      before and after), the count per decision (keep 87, move 1, fold 2, merge 1, drop 4), which
      sums to 95, and for each of the two lists still over its budget its count and this proposed
      split, which the owner chooses:
  - `review-probes.md` (33): the bullets whose trigger is a mutant or the fixture that kills it move
    to a new `context/tpm/mutation-probes.md`, read with `review-probes.md` before the first gate of
    a run (the `tpm` skill's Phase 5 reading list names it); the rest stay.
  - `briefing.md` (31): the bullets whose trigger is a fix brief or a fix round move to a new
    `context/tpm/fix-briefs.md`, read before each fix brief (the `tpm` skill's 5.2 reading line
    names it in place of the re-read of `briefing.md`); the rest stay.
- [x] The tickets `split-gates-by-trigger` and `split-cdk-guide-by-trigger` are committed with
      `status: done`: each list is at or under its budget at the head (`gates.md` 24 of 30, the CDK
      guide 25 of 25) without a split. `split-briefing-by-trigger` stays open and is not committed.

## Acceptance Criteria

- [x] All requirements verifiable from the diff and the counting command
- [x] Every local check in `CLAUDE.md` passes; `lesson-lint --added origin/main` prints no fault on
      a moved, merged or new bullet, and no budget warning other than the two lists above
- [x] The set of sentences of the moved and folded bullets is the same at the base and the head
      (diff the sorted sentences; the merged bullet is the only difference among existing bullets)
- [x] No eval run is needed; the change is lesson text

## Implementation Plan

Lint each bullet where it sits before moving it (`plugins/dev-team/bin/lesson-lint <file>`) and
carry no fault into its new place. Apply the rows in the order given. A new bullet goes at the end
of its list; a moved bullet goes at the end of its destination list or section. Build the decision
table's keep rows from the files: first words, the trigger words, and one `git grep` hit. For each
proposed split, list in the change body the first words of the bullets that would move. The version
takes a patch bump in the final rebase.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Every other lesson list; the other candidates in the outbox, the cross-repo briefing rule among
them; carrying out either split, which waits on the owner's choice; the `pm` and `readme-writer`
self-mutation paragraphs.
