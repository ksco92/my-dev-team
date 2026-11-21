---
difficulty: high
priority: p1
status: done
---

## Context

Lessons land as bullets, files reach their bullet budgets, and the only rule for a full file is
"split by trigger, the axis is the owner's call", which leaves candidates waiting in an outbox and
three split tickets open. Many bullets are also not list material: a Python rule belongs in the
prose of the Python guide's own section, and some rules are by now stated elsewhere or enforced by a
hook or a test. The owner wants a skill that owns this: it takes the lessons, distributes each to
where it belongs, and decides with evidence whether each is still worth keeping.

## Requirements

- [x] `plugins/dev-team/skills/lessons/SKILL.md`, name `lessons`, with a description that triggers
      on a request to redistribute, prune or re-home learned patterns, on a lesson file over its
      budget, on a non-empty lesson outbox, and at the end of a run that returned lesson proposals.
- [x] Operating boundaries: the skill runs in the main session; it reads every list `lesson-lint`
      checks, the lesson outbox, and the proposals of the session; it edits the plugin's files only
      through one change in the plugin's repository, landed by the `tpm` pipeline; it removes an
      outbox entry only after the change that lands it has merged.
- [x] Inventory step: a table of every list with its file, bullet count and budget, and every
      candidate with its source.
- [x] Each bullet and each candidate gets exactly one decision, with the evidence the decision
      needs:
  - fold: the rule belongs to a subject that a section of a guide, a phase of a skill or a check of
    an agent file already treats; that passage gains the rule and the bullet is deleted. A
    stack-specific rule goes to that stack's guide. A fold into another file needs the evidence a
    move needs, and a fold removes nothing the passage stated: the row quotes the passage before and
    after.
  - move: another file's trigger fits; the destination is read by every agent that applied the rule,
    shown from the text that loads each file.
  - merge: with a bullet that shares its trigger.
  - keep: where it is.
  - drop, on one of these grounds only: the rule is already stated (the sentence is quoted, from a
    file the rule's applier reads); a hook or a check that runs on every change, in each repository
    where the applier works, enforces it (it is named and shown failing on the rule's case; a check
    only a session runs does not count); the rule is no longer true (the command that shows it); the
    rule would not hold in another repository (the row cites the merged change that carries it in
    that repository's own rules, and without one the decision is keep); a candidate has no evidence
    on record. An existing bullet whose evidence cannot be found, after following every source its
    landing change cites, is kept with a question to the owner.
  - a bullet that carries rules with different homes is split, and each fragment gets its own
    decision and row.
- [x] The home test decides every candidate's place; a home the candidate names is a suggestion the
      test confirms or overrides. A candidate's claim about a tool is checked by a one-line
      reproduction or against the tool's source before it lands.
- [x] After the change that lands an outbox entry has merged, the skill removes that entry.
- [x] Rules for every edit: the rule keeps the trigger words that say when it applies; the text
      states the rule and not the incident; each fragment of a split bullet is re-read alone; a
      bullet that records an owner decision is neither dropped nor weakened without the owner's
      answer; after the change every rule that was kept is found by a search for its trigger words
      in a file its readers load. The counts sum to the bullets and candidates of the inventory plus
      the fragments splits added.
- [x] Budget outcome: after a run no list is over its budget, or the change body names the list, its
      count, and the split by trigger the skill proposes for it.
- [x] Output: the change body carries the decision table (rule, decision, destination, evidence) and
      the counts per decision, which sum to the inventory's total.
- [x] The triage and landing rules now in the "Learned patterns and where they go" section of
      `skills/tpm/SKILL.md` (the home test, the evidence rule, bullet-level edits, the outbox) move
      into the new skill, and that section keeps a pointer of at most five lines saying when the
      orchestrator runs the skill. No rule is stated in both files.
- [x] `context/policy.md`'s "Where lessons go" section agrees with the new skill and names it as the
      landing procedure; `policy.md` does not grow.
- [x] Every file that lists the plugin's skills lists the new one.
- [x] An eval case `plugins/dev-team/evals/lessons-fold-move-drop`, in the form of the existing
      cases, whose scaffold builds a small plugin-shaped tree with: a stack-specific bullet sitting
      in an orchestrator reference, whose subject a section of that stack's guide already treats; a
      bullet whose rule a sentence in a guide already states; and a bullet that a check run by the
      tree's own CI workflow enforces. Its graders require the report to fold the first into the
      guide, drop the second quoting the sentence, and drop the third naming the test.

## Acceptance Criteria

- [x] All requirements verifiable from the files and the test scripts
- [x] Every local check in `CLAUDE.md` passes; `bash plugins/dev-team/tests/evals.test.sh` covers
      the new case
- [x] The new eval case is run once with the command form `CLAUDE.md` gives and its result is in the
      change body
- [x] `skills/lessons/SKILL.md` is under 200 lines; `skills/tpm/SKILL.md` is shorter than on the
      base
- [x] The change body pairs each sentence removed from `skills/tpm/SKILL.md` with the line of the
      new skill that carries its rule

## Implementation Plan

The decisions to weigh: how much of the tpm section is procedure the new skill owns and how much is
a pointer the orchestrator still needs at the end of a run; whether the outbox path and the "machine
that cannot push" rule stay with the pointer; and the report's layout. `bin/lesson-lint` already
prints budget warnings and register faults; the skill uses it and needs no new mode. Model the file
on `skills/code-health/SKILL.md` for register. The version takes a minor bump in the final rebase.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Running the skill on this repository's lists, which is the next change; changes to `lesson-lint`;
the three open split tickets, which that first run closes.
