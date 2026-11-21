---
difficulty: medium
priority: p2
status: done
---

## Context

Eighteen lesson candidates wait in the maintainer's lesson outbox: seven held back from earlier
changes because their target file was at its bullet budget, and eleven from a run that removed code
from a published library and restructured its README. The owner decided this batch lands whole, and
that a file may go over its budget here: a separate skill, `lessons`, redistributes the lists
afterwards.

## Requirements

- [x] Every candidate in the outbox lands as one bullet, or one clause of an existing bullet or
      paragraph, in the file the candidate names: the matching `context/tpm/<topic>.md`, the
      security-reviewer agent file, the `code-health` skill, or the Python guide. A candidate that
      names two possible homes lands in the one whose readers apply it, established from the text
      that loads each file.
- [x] The candidate about re-measuring a number, a grep result or a "prints nothing" claim quoted in
      a change body folds into the existing `context/tpm/gates.md` bullet on re-running grep-shaped
      acceptance criteria at each fix head, which shares its trigger.
- [x] Each lesson states the rule, not the incident: one sentence, two at most, with no date and no
      repository, project, package, pull request or person name.
- [x] Every factual claim about a tool that a lesson makes is checked by a one-line reproduction or
      against the tool's source before it lands, and the evidence is recorded in this file under the
      Implementation Plan; a claim that cannot be checked is dropped and named in the change body.
- [x] Before a candidate lands, the target file and its neighbours are searched for the same lesson;
      a candidate an existing bullet covers refines that bullet and is named in the change body with
      the line it joined.
- [x] The change body lists each file this change leaves over its bullet budget with its count.
- [x] `skills/tpm/SKILL.md` does not grow.

## Acceptance Criteria

- [x] All requirements verifiable from the files
- [x] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')`
      exits 0; its budget warnings name only the files the change body lists
- [x] The prettier Markdown check passes, both manifests validate, and every test script passes
- [x] The count of candidates landed, folded and dropped in the change body sums to eighteen

## Implementation Plan

Take the candidates from the outbox snapshot the brief names; each line gives its home in
parentheses and its evidence after "Evidence:". Land them file by file, at bullet level only, with
`lesson-lint` run on each file after its edits. Rewrite the evidence of each candidate into the list
below in neutral words (no repository, project or pull request names), with the reproduction for
each tool claim. The version takes a patch bump in the final rebase.

Evidence:

Tool claims, reproduced before landing.

- `str.isdecimal()`, `isdigit()` and `int()` (Python 3.15): `'٣'.isdecimal()` and `'٣'.isdigit()`
  print `True`, `int('٣')` is `3`, and `re.fullmatch(r'\d{1,9}', '٣', re.ASCII)` and
  `re.fullmatch(r'[0-9]{1,9}', '٣')` both print `None` while the same `\d` pattern without
  `re.ASCII` matches. `int('1'*4301)` raises
  `ValueError: Exceeds the limit (4300 digits) for integer string conversion: value has 4301 digits; ...`
  and `len(str(int('1'*4300)))` prints `4300`.
- A `ts-jest` mutant that fails type-checking (29.4, strict config, a two-test file, the mutant
  `return value.length` on a `number`): with default diagnostics the run prints
  `Test suite failed to run`, a `TS2339` error and `Tests: 0 total`; with `diagnostics: false` in
  the transform options the same mutant prints `Tests: 1 failed, 1 passed, 2 total` and names the
  failing test.
- Stacked-PR move: in a scratch repository, a branch `next` one commit above a branch `pred`, `main`
  given a commit whose tree equals `pred`'s (the squash simulated with `git checkout pred -- .`,
  after the merge gate refused `git merge --squash` in a compound line), then
  `git rebase --onto main <pred head>` on `next`. `git rev-parse 'HEAD^{tree}'` printed the same
  tree id before and after the move, and `main`'s tree id equalled `pred`'s; the log showed `next`
  alone above `main`.
- `gh pr checks --help` lists `--watch` ("Watch checks until they finish") and `--interval`.
- Dependency pin: for a published package version, `npm view <pkg>@<version> dist --json` gives
  `integrity` and an `attestations.provenance` URL; `npm pack <pkg>@<version>` and
  `openssl dgst -sha512 -binary <tarball> | base64` print the same `sha512-...` value as
  `integrity`; the attestation URL returns a SLSA provenance statement whose
  `resolvedDependencies[0].digest.gitCommit` is the publish workflow's commit; the tarball's
  `package/package.json` is readable with `tar -xzOf`. That registry metadata can omit an install
  script the tarball carries is documented in the npm manifest-confusion write-up (the registry
  "does not validate manifest information with the contents of the package tarball"; npm 6, yarn 1
  and pnpm 7 ran tarball scripts the manifest did not list).
- The hand-back tool's own description says to use it once and that the call ends the run; the
  resumed-agent lesson rests on that contract and on three observed refusals, and no reproduction
  was possible from inside a leaf run.

Per candidate, in outbox order.

1. A step of a per-run sequence moved into a loop: a mutant running one step on the last pass only
   survived until a test collected that step per pass, and a first-pass-only mutant was needed for a
   step whose earlier effect is overwritten. An earlier lessons change held it back after its
   correctness gate ruled the Python guide the wrong home for it.
2. Four gates failed a lesson-move change for bullets moved into files no reviewer loads, and a
   bullet with a `sentences` fault left the fault list after moving out of `## Learned patterns`.
3. Removing `runDate === period` from a per-period match failed none of 170 tests until a two-period
   fixture existed.
4. A security gate showed `'٣'.isdecimal()` true and `int('1'*4301)` raising the limit error ahead
   of the handler's own message (reproduced above).
5. A correctness gate with no content finding returned BLOCKED on a pending CI run.
6. Two PRs briefed with a four-file version-bump list missed the lockfile and a project manifest
   that the previous bump commit shows.
7. A prescribed `it.each` row of argument objects was failed by the economy gate for duplicating a
   helper ten lines above.
8. An integration run finished green 40 minutes before the orchestrator looked, with all five gates
   already passed at that head; a waiter on the later runs brought each merge within a minute of the
   result.
9. Two dependent PRs each started their external run within two minutes of the predecessor's merge,
   with five verdicts carried by tree-hash equality and no extra gate round.
10. Three resumed agents reported that the hand-back tool refused because the first report had
    already used it, and two verdicts and three reports had to be recovered from transcripts.
11. After about 300 test deletions every throw site still had a failing test, yet a mutant that
    rendered a nested field's kind instead of its type passed both suites until one deleted test was
    restored.
12. Eight guard sites that narrow a type reported zero failing tests with a suite error under
    `ts-jest`; with `diagnostics: false` each failed exactly one named test (reproduced above).
13. Four gate rounds across three PRs failed on nothing but a stale count or a stale grep claim in
    the PR body after a later commit moved it.
14. Across five removal PRs the gates raised eleven requests to add code as proposals and none as
    findings, and no round re-added code the run had removed.
15. 5,760 grant cases and 861 typed inputs compared byte for byte at both commits found every
    difference, each one stated or decided, where reading the diff had found none.
16. The bootstrap of the security review returned an empty diff on six rounds of four PRs because
    the primary checkout stays on the trunk.
17. A pin review traced the tarball to the publish workflow's commit by its attestation and found
    the packed manifest byte-identical to the source (commands reproduced above).
18. An exported helper and an `@internal public` method each kept one caller after their second
    consumer was deleted, and both were found a round later.

Landing: candidates 1, 3, 11, 12, 15 and 17 are bullets of the probe file, 7 a bullet of the
briefing file, 8 and 10 bullets of the operations file, 5, 9 and 14 bullets of the gates file, 4 a
bullet of the Python guide, 18 a bullet of the code-health skill, 2 a bullet of the correctness
gate's learned patterns; 6 joins the recurring-chore bullet of the briefing file, 13 joins the
grep-shaped acceptance criteria bullet of the gates file, and 16 joins step 2 of the security gate's
agent file. Bullet counts after the change: probe file 36, briefing file 31, code-health skill 21,
correctness gate 21; each is over its budget of 30, 30, 20 and 20.

## Dependencies

- Blocked by: none · Blocks: lesson-distribution-skill's first run

## Out of Scope

Splitting, trimming or moving any existing bullet; the `lessons` skill; emptying the outbox, which
the maintainer does after the merge.
