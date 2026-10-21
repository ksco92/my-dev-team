# tpm briefing rules

Binding rules for every implementer, reviewer, fix-round, and headless brief the `tpm`
orchestrator writes. Read before the first brief of a run (Phase 4) and again before each fix
brief (5.2).

- Brief the `pr-reviewer` to simulate the pre-fix code path against the exact fixture literals
  whenever a change consolidates or reshapes a regression fixture — a merged fixture can pass a
  count-based guard under both the bug and the fix. When inline fixtures are replaced by one shared
  constant, require each replaced literal compared field by field with the constant and the guard
  mutated wherever a field differs; a swap that resets a deliberately inconsistent flag silently
  drops that test's coverage.
- Every gate and subagent brief forbids deleting outside the repo under work — no `/tmp` sweeps,
  no `*.log` sweeps; a sibling gate's `-p` report is written only at exit.
- Every headless `claude -p` brief states that the entire report goes in the single final message,
  forbids backgrounding anything to wait for a notification (a headless session never receives
  one), runs long commands in the foreground with a generous timeout, launches from a cwd with no
  Stop hook, and opens with a sanity check (`git log -1` shows the expected head and the diff holds
  the expected symbols, else stop). A buried report is recoverable from
  `~/.claude/projects/<cwd-slug>/<session>.jsonl`.
- Headless `claude -p`: `--allowedTools` is variadic and swallows a trailing prompt, so pass the
  prompt on stdin; a PreToolUse hook parsing a number out of a compound line takes the first match
  before stripping whitespace.
- Every cross-repo implementer brief opens with explicit workspace creation in the target repo
  (Create workspace operation) and states the process file's Primary checkout rule for the target.
  A repo that gitignores `.claude/*` follows the Gitignored `.claude` operation: verify `.git`
  resolves before any git op and keep runner scripts and logs inside the workspace, not the
  reapable scratchpad.
- Reviewer briefs name a uniquely named reviewer probe per gate, PR, and round (Reviewer probe
  operation), kept in a shell variable or a file named the same way, never the scratchpad root and
  never the live checkout; never detach, move, or remove a reviewer's probe, or a sibling gate's,
  while it may be running. After removing any workspace or probe, full-line `ps` scan for its path
  and kill what remains.
- When a required gate command outlasts a subagent's foreground cap, brief the hand-back up front
  (return pid and log path; the orchestrator watches and resumes with fast-ops-only instructions)
  instead of demanding a foreground run that cannot happen.
- A fix commit is new review surface: re-run gates on the fix delta, brief against
  review-pipeline and ticket-referential wording leaking into comments and PR bodies, and, when a
  brief widens a test case, have it name the identifiers to rename. Fix briefs describe defects by
  content, never by round or finding number; implementers copy the brief's words into public
  content.
- Never write `\b` into an acceptance grep; specify substrings with plain `grep -rniE` and have the
  reviewer re-run the command as written.
- When the permission classifier denies a subagent the same benign edit three times, hand the step
  to a fresh implementer in the same workspace; never let the blocked agent route around the denial.
- Fix-loop validation scales to the delta: each round re-runs the fast suite plus mutants on touched
  files; the full mutation run, the largest parity case, and memory measurements run once on the
  merging head. Never hold a push for pending verdicts; reviewers verify the final head once. No
  pre-push self-check list for implementers (owner decision).
- When briefing a recurring mechanical chore (version bump, release prep, changelog roll),
  derive the file checklist from the previous instance's actual commit (`git show <sha> --stat`),
  never from the documented convention alone; the precedent commit shows every real touch-point.
- When prescribing a doc reword, give the exact old and new text so the round closes on a diff
  proof; the new text states the rule only, never "pinned by <test>" or "confirmed against
  <version>"; any observed state it asserts (a package list, a count) is reproduced at the head
  first, not typed from the previous head; and a fragment replacement is written out as the whole
  resulting line, so a phrase the sentence already carries is not spliced in twice.
- When an implementer defers half a slice citing environment limits, check the claim against the
  machine and the repo's own history before accepting it (memory, disk, what earlier slices ran
  here); a wrong capacity claim is a stopping-short signal, and the answer is "proceed, here is
  the evidence", not a re-plan. Accept a scope split only when the shipped half is mergeable on
  its own and the second half starts immediately.
- A numeric per-file target in an issue (a comment ratio, a line count) is recomputed at current
  main with the issue's own counting method at dispatch, the brief has the implementer reproduce
  that baseline with its counter before editing, and it states whether the target is reachable
  through the issue's in-scope edits alone; an unreachable target is amended before the
  implementer starts, not argued in the PR body.
- A fix brief for a security finding prescribes the property ("decode and parse exactly as the
  consuming parser does, or store a placeholder"), never the mechanism that closes one case; a
  mechanism written from one example opens the sibling case the next gate finds.
- Every brief that touches a shared local resource (a database, a port) names a value unique to
  that agent, PR and round and forbids running any script whose default targets the owner's own
  resource; two gates for different PRs briefed with the same port collide.
- Implementer briefs push from a worktree as `git -C <wt> push --force-with-lease=<branch>:<sha>
  origin <branch>`, with `<sha>` the last SHA pushed (plain `-u origin <branch>` on the first
  push): the merge gate refuses a `-C` push that names no remote and literal non-trunk refspec, and
  its refusal reads as a permission error.
- Every rebase brief says: run the full `make check` (all targets, clippy included) and any CI leg
  that main added on the rebased head before the push.
- When a fix brief asks for a test that kills a surviving mutant and the implementer instead
  deletes the guarded code on an equivalence argument, treat the deletion as a design change that
  needs its own gate round, not as the test fix; two gates disproved one such argument in a round.
- When a rule enumerates unguarded paths or the sources of a property and each gate round finds one
  more instance, restate the rule as the class defined by the mechanism with the known instances as
  examples; listing instances costs a round per instance.
- When a fix adds an exception subclass of a builtin to a shared primitive, check every sibling open
  PR that catches the base class; the rebase brief names the new condition and re-derives its
  reachability from the caller's preconditions.
- An explanatory clause added in a fix round to make a sample output fit is where an invented
  mechanism slips in; the brief prescribes the rule sentence from the code, and the reviewer checks
  the database state at that step, not only the final output.
- When a fix centralises a predicate into a helper, brief the correctness gate to break the helper's
  definition and to remove its use at each call site in turn; a test that fails on the broken
  definition proves one call site only.
- Brief every mutation run to check the mutant for undefined names, and that it compiles under the
  project's own settings, before trusting a failure; a mutant that swaps in an unimported symbol or
  fails the compile fails every test and reads as killed.
- When a code-economy finding trims a rules paragraph to a pointer, list the facts the pointed-to
  file does not hold and brief them kept; a rules file names every change that needs review, even a
  field that a description elsewhere already mentions.
- Send a change you already know you will ask for (an implementer's open question, a stale test
  name) before dispatching gates on that head; a round on a head you will change is spent twice.
- When a sibling PR that closes a path merges mid-review, brief the next round to grep the open PR's
  code, tests and body for statements that the path is still open; a brief that rewrites a
  mechanism likewise names the PR body sentences that describe the old form.
- Brief every doc and rules-file edit to state what the code does without a cause clause
  (`because`, `which makes`, `as for any`) unless the cause was checked against the source; an
  unverified explanation is the next round's finding.
- Every doc-trim brief requires an empty diff once comment and doc lines are stripped, a moved
  list's new home that does not point back at the old one, and a re-read of the lead-in of every
  list it shortens; a brief that adds rule sentences to a README states each rule once, in the
  section that owns the type, with pointer bullets elsewhere.
- When a fix brief lets the implementer choose between two forms, name the file's existing shape as
  the tie-breaker, never a line count; the shorter form with a side effect is the next round's
  finding.
