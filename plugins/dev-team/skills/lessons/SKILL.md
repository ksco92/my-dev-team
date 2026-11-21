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
- Read every list `lesson-lint` checks, the lesson outbox (`~/.claude/lesson-outbox.md`), and the
  `Proposed learned pattern:` bullets of the session.
- Work in a workspace of the plugin's repository (`ksco92/my-dev-team`) created by that repository's
  process file, and run its `plugins/dev-team/bin/lesson-lint`, never the installed copy under
  `${CLAUDE_PLUGIN_ROOT}`.

You do not:

- Change the plugin's files other than through one change in its repository, landed by the `tpm`
  skill's pipeline.
- Remove an outbox entry before the change that lands it has merged.
- Drop or weaken a bullet or a passage that records an owner decision without the owner's answer. It
  records one when its text says so or the change that first recorded the rule does; until the owner
  answers, its decision is keep.

## 1. Inventory

In the workspace, count each list's bullets the way `lesson-lint` does:

````
for f in $(git ls-files 'plugins/dev-team/*.md'); do
  awk '/^(```|~~~)/ { q = !q; next } q { next } /^# / { s = 0 }
    /^## / { s = /^## Learned patterns[[:space:]]*$/ }
    (s || FILENAME ~ /context\/tpm\//) && /^[[:space:]]*[-*] / { n++ }
    END { if (n) print n, FILENAME }' "$f"
done
````

A list's budget is set by the `case` on its path in `plugins/dev-team/bin/lesson-lint`. Then take
every candidate: each outbox entry (a suggested home in parentheses, its evidence after
`Evidence:`), each proposal of the session with the agent that returned it, and each lesson you
learned yourself with the command or transcript line it rests on.

## 2. Readers

A rule's applier is the agent that acts on it, not the list's current reader: a Python rule in an
orchestrator reference is applied by the implementer that writes the Python. Establish who reads a
file, and at what moment, from the text that loads it: run
`git grep -n '<file name>' plugins/dev-team` and read each hit. That search misses the stack guides,
which are loaded through a pattern (`context/agent-baseline.md`'s first steps load them for the
implementers, and the `pr-reviewer` agent's first steps and the `code-health` and `oss-reviewer`
skills' context-loading steps for the gates), and a skill that an agent file's `skills:` frontmatter
preloads by its directory name.

## 3. Decide

Before a candidate gets any decision but drop, verify its substance: run a command it prescribes
against the case it cites, and check each claim about a tool by a one-line reproduction or against
the tool's source. Before deciding any rule, search its destination and the files its applier also
reads for the same rule.

`context/policy.md`'s "Where lessons go" sends a rule true in one repository out of the plugin (drop
ground 4). Inside the plugin, a stack-agnostic rule goes to the `context/tpm/<topic>.md` whose
lead-in names its trigger, to the agent or skill file of the agent that applies it, or to
`context/policy.md` when it binds every session; a stack-specific rule goes to that stack's
`context/<stack>-coding-guide.md`. This test decides every candidate's place; a home the candidate
names is a suggestion the test confirms or overrides.

A bullet that carries rules with different homes (different files or different passages) is split,
and each fragment gets its own decision and row. Give every bullet, fragment, and candidate exactly
one decision, the first in this order that holds:

<!-- prettier-ignore -->
| Decision | Holds when | Evidence in the row |
| --- | --- | --- |
| drop | one of the five grounds below holds | the ground, in its words, and its evidence |
| fold | a section of a guide or of `context/policy.md`, a phase of a skill, or a check of an agent file already treats the rule's subject; a stack-specific rule folds into that stack's guide, a change to the procedure into the `tpm` skill's phase text; the passage gains the rule and loses nothing it stated | the passage (file and heading) quoted before and after, and for a fold into another file the evidence a move needs |
| move | the rule's trigger fits another list better than its own | the destination, and for each agent that applied the rule the loader line that shows it reads the destination at the same moment |
| merge | another bullet shares the rule's trigger | the merged bullet in full |
| keep | none of the above; a candidate lands as a new bullet in its place | the rule's trigger words |

A fold, a move, or a merge deletes the bullet where it sat.

A drop needs one of these grounds, and a ground holds only with its evidence; "seems covered" is
none:

1. The rule is already stated: quote the sentence, with file and line, from a file the applier reads
   at the same moment.
2. A hook, or a check that runs on every change in each repository where the applier works, enforces
   it: name it and what runs it, and show it failing on the rule's case by making the violation in a
   copy of the tree under `mktemp -d` and quoting the output. A check a session runs by hand does
   not count.
3. The rule is no longer true: the command that shows it, with its output.
4. The rule would not hold in another repository: cite the merged change that carries it in that
   repository's own rules. Without one, an existing bullet is kept; a candidate is landed in that
   repository's own rules through that repository's process, never as a plugin bullet, and its row
   becomes this drop once that change has merged.
5. A candidate has none of the evidence `context/policy.md`'s "Where lessons go" names.

An existing bullet's evidence comes from where its rule was first recorded: find the change that
landed it (`git log -S '<phrase>'`, read with the process file's Read change operation) and follow
every source that change cites. A bullet whose evidence is still not found is kept as it is, and the
session asks the owner about it; it changes only on the owner's answer.

## 4. Edit rules

- Every rule you keep, fold, move, or merge keeps the words that say when it applies. A merge keeps
  the surviving bullet's trigger phrase; widening it to admit the other rule is a split by trigger,
  not a merge.
- The text states the rule, not the incident, in the register `context/policy.md`'s "Where lessons
  go" sets, prose included. Before a fold, lint the bullet where it sits with
  `plugins/dev-team/bin/lesson-lint <file>`, which reports every bullet of the file (the
  `--added origin/main` form `CLAUDE.md` gives reports only new or changed ones), and carry no fault
  it reports on that bullet into the prose.
- Edit only the bullet or the passage a row names: never reword a neighbour in passing, and never
  shorten a rule to fit a budget.
- Re-read each fragment of a split bullet alone; a leftover purpose clause becomes a false claim.
- A fold into the `tpm` skill keeps that file under ~350 lines.
- After the edits, search for each kept rule's trigger words
  (`git grep -n -i '<words>' plugins/dev-team`) and record the hit, which must be in a file its
  applier loads.

## 5. Budgets

Count again with step 1's command. A list over its budget after every fold, move, merge, and drop
its evidence supports gets a proposed split by trigger: the bullets grouped by trigger phrase, each
group's file or section, and the loader line that must name it. The owner chooses the split.

## 6. Report and land

The change body carries the inventory, a table of the lists (file, bullets, budget) and one of the
candidates (text, source); the decision table, one row per bullet, fragment, and candidate (its
first words, decision, destination, evidence, trigger-word hit); the count per decision, which sums
to the inventory's bullets and candidates plus one for each fragment a split adds beyond the first;
and each list still over its budget, with its count and its proposed split.

Land it as one change in the plugin's repository through the `tpm` skill's Phases 3 to 5, with the
decision table as the ticket's requirements. On a machine that cannot push to the plugin's
repository, append each candidate with its evidence to the lesson outbox and run this skill from a
machine that can. After a change has merged, remove from the outbox each entry that change landed or
dropped with its evidence, and no other.
