---
name: audit
description: Whole-repository audit by measurement and execution, ending in a numbered decision list for the owner. Use when asked whether a codebase is over-built, over-tested, under-tested or over-claimed (guards nothing reaches, tests nothing needs, documented claims no test asserts, exports nobody uses), when asked for a fresh reader's view of a README, and before a release that bumps the minor version. Lenses economy, tests, claims, surface and cold read, all run by default. Changes no file in the audited repository; nothing is removed or ticketed until the owner answers.
user-invocable: true
argument-hint: "[repo path] [--lenses=economy,tests,claims,surface,cold-read]"
---

# Repository Audit

The review gates judge one change at a time. This audit asks whether the repository as a whole
carries code, tests or documented claims that nothing needs, and whether a stranger reading its
README would adopt it. It proposes; the owner decides.

## Operating boundaries

- Run in the main session and do the measuring and probing yourself; the cold read is the only
  delegated step. The audit needs the owner's answers and the whole run's context, which a subagent
  does not have.
- Every conclusion rests on a command that was run, quoted exactly as typed (a line the owner can
  paste, never a description of it) with the output lines that decide it. A conclusion reached by
  reading code is a question for the owner, labelled unverified, never a finding; when a command
  cannot be run, the item says which and why.
- Change no file in the repository under audit. Every mutation and probe runs in a scratch copy: a
  detached worktree at the audited head
  (`git -C <repo> worktree add --detach <scratch>/audit-<suffix> HEAD`), or a `cp -R` when the tree
  is not a git repository. Print `git -C <repo> status --porcelain` at the start and the end of the
  run; both are empty or identical. Remove only the scratch copies you created.
- Nothing is ticketed, removed or briefed before the owner answers the decision list.
- Implementation of the decided items goes through the `tpm` skill.

## Lens selection

The lenses are `economy`, `tests`, `claims`, `surface` and `cold-read`; all five run unless the
request names a subset (`--lenses=economy,tests`). The bar, measure and decisions phases always run;
plan and after run once the owner has answered.

## Phase 1: bar

Before measuring, settle with the owner:

1. Who calls the code: each caller class, typed or untyped, internal or external (a command-line
   user, a typed library consumer, an untyped script, another module of the same repository).
2. Which inputs the project defends against, and from which caller.
3. What the audit may propose removing: code, tests, documentation, exports, and anything off
   limits.

Answer each from the request, the repository's `CLAUDE.md` and rules files, the product brief under
`docs/product/` and the session's memory first, and cite the source; ask the owner only what none of
them answers, in one message. The answers open the report. The caller classes are the units the
economy lens probes with.

## Phase 2: measure

Build a table of facts: each row a fact, its number and the command that produced it, with no
judgment column. Save the commands in a scratch file so the after phase reruns them unchanged.

- Source and test lines per module and their ratio, from the repository's own line counter when it
  has one, otherwise `wc -l` over `git ls-files` with the globs stated.
- Guard sites: every path that rejects input (`throw`, `raise`, `panic!`, an early exit such as
  `process.exit`, `sys.exit` or `return Err`), found with a grep whose pattern is quoted, and listed
  as `file:line`. This list feeds the economy and tests lenses.
- Exported names: every name the public entry points export (the package index, `__all__`, `pub`
  items of the crate root, command-line flags and subcommands).
- Documented statements about an external system (a service's behaviour, a format another tool
  writes, a supported version) or about the project's own guarantees ("never", "always", a number, a
  compatibility promise), from the README and every tracked doc, each with an ID and its
  `file:line`.
- Releases with their dates
  (`git tag --sort=-creatordate --format='%(creatordate:short) %(refname:short)'`, or the registry's
  publish times).
- Open tickets whose title starts `Audit:`, listed with the tracker the resolved `DEV_PROCESS.md`
  names. The prefix marks a ticket filed for this skill: an item a review gate could not reproduce
  on its change, or a suspicion outside a change's diff, filed through the File a follow-up
  operation. Each is an input routed to the lens it concerns, and the decision list says what became
  of it.

## Phase 3: lenses

### Economy

For every guard site, validation layer, defensive copy and abstraction with a single caller, reach
it through the public interface as each caller class from the bar: run the command, call the entry
point from a scratch script, or type-check a scratch consumer that passes the rejected input (a type
error proves a typed caller cannot reach it). Record per site and caller class whether the guard
fired.

- What no caller reaches is a removal candidate.
- What only a caller outside the bar reaches is a decision for the owner.
- A check made at two layers is one finding naming both sites and the layer that stays.
- A single-caller abstraction is counted with a quoted grep of its call sites.

### Tests

Disable each guard site in turn in the scratch copy and run the whole suite: replace the rejection
with a no-op of the same shape (`throw new Error(...)` becomes `void new Error(...)`, `raise X(...)`
becomes `X(...)`, an early return falls through), record the failing tests, and restore the file
before the next site, clearing any build cache that keys on file time and size (Python's
`__pycache__`) so a restored file is not read stale. Time one suite run first, and split by file
when a run will not fit one command.

- A site whose removal fails no test is untested when the economy lens reached it and dead when it
  did not.
- A mutant that does not build proves nothing: rerun it with type diagnostics off (for example
  `ts-jest` with `diagnostics: false`), and where the toolchain has no such switch, write a mutant
  of the same effect that builds.
- Paths that reject nothing (rendering, transformation) get one targeted mutant per branch: flip the
  condition or drop the arm, run the suite, record the result.

A test is a removal candidate when it asserts what the type system or the framework guarantees
(shown by a type-check or a framework behaviour run in scratch), repeats another test with other
literals and no new branch, or covers a removed feature. Before any deletion is proposed, re-apply
the mutation that test catches with that test excluded (`pytest --deselect`, `cargo test -- --skip`,
or the runner's equivalent): another test must fail. A test whose mutation only it catches stays.

### Claims

Map every documented statement from the measure table to the test or suite that asserts it, by name,
with a run in which it passes and, in scratch, a mutation of the behaviour that makes it fail. A
statement about an external system is asserted only by a suite that talks to that system or by a
fixture copied from its real output. A statement with no such test, shown by a quoted grep of the
test tree that finds none, becomes a decision: add the test, narrow the sentence, or remove it.

### Surface

For every exported name, find a consumer (a fixture, an example, or a test that imports through the
public entry point, not the module) and its documentation, each with a quoted grep. A documented
name that does not exist is a defect; an export with neither a consumer nor documentation is a
decision.

### Cold read

1. Write the persona from the README's own first paragraph and the owner's stated target user (the
   bar, or the product brief): who the person is, the need that brought them here, what they already
   know, and what a bad choice would cost them. One paragraph, no knowledge of the project.
2. Dispatch `Agent(subagent_type="cold-reader", …)` with the persona and the README's absolute path,
   and nothing the session has learned: no measure table, no lens result, no source file, no hint of
   what you expect. The agent file sets its model, effort and read-only tools.
3. Check every factual statement in the agent's proposed text (each replacement and the restructure
   draft) against the repository with a command, and fill or keep each `[MISSING: …]` placeholder
   from the repository; a proposal the repository contradicts is dropped and noted. Only checked
   proposals enter the decision list; the reader's Part 1 goes into the report as written.

## Phase 4: decisions

One numbered list for the owner, defects first. Each item states:

- the finding, and the evidence: the command and the lines of its output that decide it;
- the options, and the recommended one;
- what the recommended option removes or adds, in lines, measured on the scratch copy
  (`git diff --stat` after applying it there);
- what could go wrong if it is applied.

Stop and wait for the owner. Record the answers in the report, item by item, as the bar the
following run's gate briefs quote.

## Phase 5: plan

Hand the decided items to the `tpm` skill as slices. That skill's text governs the run; add only
what a removal run needs:

- Order the removals so each change merges on its own: a guard leaves with the tests that assert it,
  and a doc sentence with the code it describes.
- Settle "nothing changed for valid input" by running the base commit and the head commit over an
  input matrix (valid inputs for every caller class in the bar) and diffing the whole outputs, not
  selected fields; the empty diff and its command go in the change body.
- Brief every gate that a request to restore a removed guard, test or sentence is a proposal for the
  orchestrator's ruling, and quote the owner's recorded answers in the brief.

## Phase 6: after

At the final head, rerun the measure commands and print the new table beside the first, one row per
fact. Rerun the guard-disabling method over every remaining guard site: each one has a test that
fails when it is disabled. A site without one gets that test as one more slice, and the run is not
done until it merges.

## Report

Print the whole report in your reply, the commands and their output lines included, and save a copy
in the session's scratch directory, never in the audited repository. The owner decides from the
reply, so a summary that drops the commands is not the report:

```markdown
# Audit: <repository> at <short sha>

## Bar
<each answer, with its source: the owner, a rules file, memory>

## Measure
| fact | number | command |

## Lenses
### <lens>
| site or statement | command | output that decides it | result |

## Cold read
<the reader's part as written; the editor's proposals with the check made on each>

## Decisions
1. <finding>
   evidence: `<command>` → <the output lines that decide it>
   options · recommendation · lines removed/added · risk

## Owner's answers
<item number: the answer>

## After
| fact | before | after | command |
```
