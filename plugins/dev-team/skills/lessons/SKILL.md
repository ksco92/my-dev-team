---
name: lessons
description: Lesson distributor for the dev-team plugin's learned patterns. Use on a request to redistribute, prune, or re-home learned patterns; when `lesson-lint` warns that a lesson list is over its budget; when the lesson outbox has entries; and at the end of a run that returned `Proposed learned pattern:` bullets. Gives every bullet and every waiting candidate one decision (fold, move, merge, keep, or drop) with the evidence it needs, and lands the result as one change in the plugin's repository through the `tpm` pipeline.
user-invocable: true
argument-hint: "[candidate lessons, or the lesson files to redistribute]"
---

# Lesson Distributor

A learned pattern exists to change what one agent does at one moment. You put each rule where the
agent that applies it reads it, as prose in the passage that already treats its subject when there
is one, and you remove a rule only on evidence. A fold or a move changes where a rule lives, never
who reads it or when.

## Operating boundaries

You do:

- Run in the main session.
- Read every list `${CLAUDE_PLUGIN_ROOT}/bin/lesson-lint` checks, the lesson outbox
  (`~/.claude/lesson-outbox.md`), and the `Proposed learned pattern:` bullets of the session.
- Work in a workspace of the plugin's repository (`ksco92/my-dev-team`) created by that repository's
  process file, never in the installed copy under `${CLAUDE_PLUGIN_ROOT}`.

You do not:

- Change the plugin's files other than through one change in its repository, landed by the `tpm`
  skill's pipeline.
- Remove an outbox entry before the change that lands it has merged.
- Drop or weaken a bullet that records an owner decision without the owner's answer. A bullet
  records one when its text says so or the change that landed it does; until the owner answers, its
  decision is keep.

## 1. Inventory

In the workspace, count each list's bullets the way `lesson-lint` does (every bullet, nested ones
included, under a `## Learned patterns` heading and in a `context/tpm/*.md` file, outside fenced
blocks):

````
for f in $(git ls-files 'plugins/dev-team/*.md'); do
  awk '/^(```|~~~)/ { q = !q; next } q { next } /^# / { s = 0 }
    /^## / { s = /^## Learned patterns[[:space:]]*$/ }
    (s || FILENAME ~ /context\/tpm\//) && /^[[:space:]]*[-*] / { n++ }
    END { if (n) print n, FILENAME }' "$f"
done
````

A list's budget is set by the `case` on its path in `bin/lesson-lint`, which prints a
`warning: budget` line for each list over it. Then take every candidate: each outbox entry (its home
in parentheses, its evidence after `Evidence:`), each proposal of the session with the agent that
returned it, and each lesson you learned yourself with the command or transcript line it rests on.

The report opens with two tables, the lists (file, bullets, budget) and the candidates (text,
source), and their total; the decision counts sum to it.

## 2. Readers

For every file a decision may touch, establish who reads it and at what moment from the text that
loads it: run `git grep -n '<file name>' plugins/dev-team` and read each hit. The loaders are:

- the `tpm` skill's Phase 4 and Phase 5 reading lists, each for the orchestrator under the trigger
  its sentence names; a `context/tpm/*.md` file reaches a subagent only through a brief;
- each agent file's opening lines and its `skills:` frontmatter, which preloads a skill into that
  agent;
- the first steps of `context/agent-baseline.md` and `context/reviewer-baseline.md`, and each gate
  skill's context-loading step, which load the stack guides;
- `context/policy.md`'s guide table, for the main session;
- `hooks/session-context.sh`, which inlines `context/policy.md` into every session.

A rule's applier is the agent that acts on it, not the list's current reader: a Python rule in an
orchestrator reference is applied by the implementer that writes the Python.

## 3. Decide

Before a candidate gets any decision but drop, verify its substance: run a command it prescribes
against the case it cites, and check each claim about a tool by a one-line reproduction or against
the tool's source. Before deciding any rule, search its destination and the files its applier also
reads for the same rule.

`context/policy.md`'s "Where lessons go" test picks the destination. True in another repository and
stack-agnostic: the `context/tpm/<topic>.md` whose lead-in names the rule's trigger, the agent or
skill file of the agent that applies it, or `context/policy.md` for policy that binds every session.
Stack-specific: that stack's `context/<stack>-coding-guide.md`. True in one repository only: drop
ground 4. A candidate's place is the list its source names, or the one this test picks when it names
none.

Give every bullet and every candidate exactly one decision, the first in this order that holds:

<!-- prettier-ignore -->
| Decision | Holds when | Evidence in the row |
| --- | --- | --- |
| drop | one of the five grounds below holds | the ground and its evidence |
| fold | a section of a guide or of `context/policy.md`, a phase of a skill, or a check of an agent file already treats the rule's subject; a stack-specific rule folds into that stack's guide, a change to the procedure into the `tpm` skill's phase text | the passage (file and heading), its rewritten text in full, and the loader line that shows the applier reads it when the rule applies |
| move | the rule's trigger fits another list better than its own | the destination, and for each agent that applied the rule the loader line that shows it reads the destination at the same moment |
| merge | another bullet shares the rule's trigger | the merged bullet in full |
| keep | none of the above; a candidate lands as a new bullet in its place | the rule's trigger words |

A drop needs one of these grounds, and a ground holds only with its evidence; "seems covered" is
none:

1. The rule is already stated: quote the sentence, with file and line, from a file the applier reads
   at the same moment. A rule the `tpm` skill's phase text states is never repeated as a bullet.
2. A hook, a lint rule, or a test enforces it: name it, and show it failing on the rule's case by
   committing the violation in a copy of the tree under `mktemp -d` and quoting the run's output.
3. The rule is no longer true: the command that shows it, with its output.
4. The rule would not hold in another repository: name the file in that repository that
   `context/policy.md`'s "Where lessons go" sends it to, landed through that repository's own
   process, so the rule is not lost.
5. No evidence for it is on record: a candidate that came without the command, transcript line, or
   gate finding it rests on; an existing bullet whose landing change carries none (find the change
   with `git log -S '<phrase>'` and read it with the process file's Read change operation).

## 4. Edit rules

- Every rule you keep, fold, move, or merge keeps the words that say when it applies. A merge keeps
  the surviving bullet's trigger phrase; widening it to admit the other rule is a split by trigger,
  not a merge.
- The text states the rule, not the incident, in the register `context/policy.md`'s "Where lessons
  go" sets, prose included. Run `lesson-lint` on a bullet where it sits before you fold it, because
  prose leaves the list the linter reads.
- Edit only the bullet or the passage a row names: never reword a neighbour in passing, and never
  shorten a rule to fit a budget.
- Re-read each fragment of a split bullet alone; a leftover purpose clause becomes a false claim.
- A fold into the `tpm` skill keeps that file under ~350 lines.
- After the edits, search for each kept rule's trigger words
  (`git grep -n -i '<words>' plugins/dev-team`) and record the hit, which must be in a file its
  applier loads.

## 5. Budgets

Count again with step 1's command. A list over its budget after every fold, move, merge, and drop
its evidence supports is named in the change body with its count and a proposed split by trigger:
the bullets grouped by trigger phrase, each group's file or section, and the loader line that must
name it. The owner chooses the split.

## 6. Report and land

The change body carries the inventory tables and their total; the decision table, one row per rule
(its first words, decision, destination, evidence, trigger-word hit); the count per decision, which
sums to the total; each owner question with its answer; and each list still over its budget with its
proposed split. A request for the report only stops here.

Land it as one change in the plugin's repository through the `tpm` skill's Phases 3 to 5: the
decision table is the ticket's requirements, and each fold, move, and merge row carries its
resulting text in full. Run `lesson-lint` on every file the change touches. The version follows the
plugin repository's own rules. On a machine that cannot push to the plugin's repository, append each
candidate with its evidence to the lesson outbox and run this skill from a machine that can.
