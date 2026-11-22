# tpm fix-brief rules

Binding rules for fix briefs and fix rounds. Read with `briefing.md` before the first brief of a run
(Phase 4) and again before each fix brief (5.2).

- A fix commit is new review surface: re-run gates on the fix delta, brief against review-pipeline
  and ticket-referential wording leaking into comments and PR bodies, and, when a brief widens a
  test case, have it name the identifiers to rename. Fix briefs describe defects by content, never
  by round or finding number; implementers copy the brief's words into public content.
- A fix brief for a security finding prescribes the property ("decode and parse exactly as the
  consuming parser does, or store a placeholder"), never the mechanism that closes one case; a
  mechanism written from one example opens the sibling case the next gate finds.
- When a fix brief asks for a test that kills a surviving mutant and the implementer instead deletes
  the guarded code on an equivalence argument, treat the deletion as a design change that needs its
  own gate round, not as the test fix; two gates disproved one such argument in a round.
- When a rule enumerates unguarded paths or the sources of a property and each gate round finds one
  more instance, restate the rule as the class defined by the mechanism with the known instances as
  examples; listing instances costs a round per instance.
- When a fix adds an exception subclass of a builtin to a shared primitive, check every sibling open
  PR that catches the base class; the rebase brief names the new condition and re-derives its
  reachability from the caller's preconditions.
- When a fix centralises a predicate into a helper, brief the correctness gate to break the helper's
  definition and to remove its use at each call site in turn; a test that fails on the broken
  definition proves one call site only.
- When a sibling PR that closes a path merges mid-review, brief the next round to grep the open PR's
  code, tests and body for statements that the path is still open; a brief that rewrites a mechanism
  likewise names the PR body sentences that describe the old form and, where the squash message is
  built from the commit messages, the PR title and each earlier commit message that does.
- When a fix brief lets the implementer choose between two forms, name the file's existing shape as
  the tie-breaker, never a line count; the shorter form with a side effect is the next round's
  finding.
- When a fix brief prescribes a test's shape, check the block for a helper that already builds that
  shape first; a prescribed hand-built row is the next round's reuse finding.
