# tpm findings rules

Binding rules for judging what a gate reports and what a verdict rests on: checking a finding or a
PR body's claim against the head, ruling between gates and the ticket, and what a fix brief asks for
in answer to a finding. Read with `gates.md` before the first gate of a run and again before each
fix brief.

- Grep-verify a gate's decisive factual claims against the head before dispatching a fix round;
  grep-verify a gate's proposed repo rule against the repo it describes before prescribing it; run
  `git log --follow` on a PR body's root-cause narrative. An overrule of a gate's finding needs the
  same evidence, recorded and put into every gate's next brief, never the implementer's.
- When a CI failure is fixed by pinning at the root, do not also brief graceful degradation for the
  unpinned case; verify a new test path by running the project's own command and checking for
  unexpected SKIPs.
- A PR body's own preservation or fix checklist is not proof: reproduce it from the diff (every
  number-plus-unit token, every named symbol) before recording a verdict; the checklist lists what
  the author remembered to check, and the body's opening sentences are re-read against the lists and
  the ledger under them in the same body.
- Check a PR against every issue-specific numeric criterion as well as the repo's general bar; the
  same computed figure can clear the general ceiling and miss the issue's tighter target.
- Two gates that read one delta differently (one as narrative or fix-round accretion, one as
  rule-mandated or gate-prescribed content) are not a contradiction for the owner: the repo rule
  decides, the orchestrator amends the issue's constraint with the reason and names the sentences it
  keeps, and the gate that cited the old constraint re-issues its verdict from a brief that states
  the ruling. A ticket-mandated sentence, figure, or verbatim copy of a named reference file, and a
  consumer-facing section's precedent for stating sibling throws, likewise outrank a gate's style
  preference or dedup, while a gate that shows ticket text false outranks the ticket, which is
  amended to the claim that holds.
- When a gate finding rests on a default heuristic with an "unless justified" clause and the owner's
  written requirement supplies the justification, amend the ticket once with the substantive checks
  that replace the heuristic before the first gate runs on the next dependency-adding PR; refining
  it round by round against one lockfile costs a round each time.
- A gate that flags a token from the harness's own conventions (the `# ponytail:` marker) is
  answered with the file that defines it, and the repo's `CLAUDE.md` states the convention on its
  first use so a reader without the harness can resolve it.
- When a fix round replaces a mechanism and the next round finds the same leak class in a
  neighbouring input, brief a fail-closed design (a placeholder for the whole input class) before
  the third attempt, and have the repo doc state the acceptance as a closed list of what is covered;
  later gates judge against that list, and a claim in it broader than the code reopens the loop.
- Before briefing a test deletion that a gate asks for, check the test against the ticket's
  acceptance criteria; a test that pins a stated criterion stays even when the framework enforces
  the behaviour, because the criterion is the contract and the next gate will fail its absence. Then
  re-apply the mutation the test used to catch and require another test to fail before the deletion
  or fold is briefed.
- Before briefing a test for an uncovered branch behind a guard, list the guard's callers and what
  each passes; a branch no caller reaches is deleted with its guard, never covered through an
  `@internal` import, and the ticket is amended to the deletion.
- A gate finding that defers judgment to the orchestrator is ruled at once and the ruling stated in
  the fix brief and the re-review brief, so neither the implementer nor the re-review re-litigates
  it.
- When a PR folds a child process's stderr into an error message, brief the correctness gate to
  trigger one real failure of the actual child, never a fake: a real crash's piped stderr can arrive
  truncated, with a bundled library's minified source line first, so only the real text shows what
  the message carries.
- When a PR adds a shared validator that a construct calls, grep that construct's constructor for an
  older call checking the same inputs; two layers checking one value is the finding, and the fix
  validates at one layer.
- A full-repository gate run on a repo whose lint or build config was copied from a sibling checks
  the sibling for the same defect in the same round and files its follow-up at once.
- A PR body's claim that a log was taken before or after an event is checked against the log file's
  last-write time and the event's recorded time whenever the log carries no timestamp of its own.
