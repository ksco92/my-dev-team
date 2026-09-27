# tpm briefing rules

Binding rules for every implementer, reviewer, fix-round, and headless brief the `tpm`
orchestrator writes. Read before the first brief of a run (Phase 4) and again before each fix
brief (5.2).

- Brief the `pr-reviewer` to simulate the pre-fix code path against the exact fixture literals
  whenever a change consolidates or reshapes a regression fixture — a merged fixture can pass a
  count-based guard under both the bug and the fix.
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
- Reviewer briefs name a uniquely named reviewer probe per round (Reviewer probe operation), never
  the scratchpad root and never the live checkout; never detach, move, or remove a reviewer's probe
  while it may be running. After removing any workspace or probe, full-line `ps` scan for its path
  and kill what remains.
- When a required gate command outlasts a subagent's foreground cap, brief the hand-back up front
  (return pid and log path; the orchestrator watches and resumes with fast-ops-only instructions)
  instead of demanding a foreground run that cannot happen.
- A fix commit is new review surface: re-run gates on the fix delta and brief against
  review-pipeline vocabulary leaking into comments and PR bodies. Fix briefs describe defects by
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
- When prescribing a doc reword to remove narration, prescribe the rule sentence only: never
  "pinned by <test name>" or "confirmed against <version>", which trade one code-economy
  violation for another; the suite is the evidence and the doc states the behavior.
- When an implementer defers half a slice citing environment limits, check the claim against the
  machine and the repo's own history before accepting it (memory, disk, what earlier slices ran
  here); a wrong capacity claim is a stopping-short signal, and the answer is "proceed, here is
  the evidence", not a re-plan. Accept a scope split only when the shipped half is mergeable on
  its own and the second half starts immediately.
- A numeric per-file target in an issue (a comment ratio, a line count) is recomputed against
  current main at dispatch when a dependency merged after the issue was written, and the brief
  states whether the target is reachable through the issue's in-scope edits alone; an unreachable
  target is amended before the implementer starts, not argued in the PR body.
- A fix brief that includes a rebase of an already-pushed branch says the push is
  `--force-with-lease` after checking the remote tip is the last SHA the implementer pushed; a
  plain push after a rebase fails as non-fast-forward and reads as a permission refusal.
- A fix brief for a security finding prescribes the property ("decode and parse exactly as the
  consuming parser does, or store a placeholder"), never the mechanism that closes one case; a
  mechanism written from one example opens the sibling case the next gate finds.
- Every brief that touches a shared local resource (a database, a port) names a value unique to
  that agent, PR and round and forbids running any script whose default targets the owner's own
  resource; two gates for different PRs briefed with the same port collide.
- Implementer briefs say to push from a worktree with an explicit refspec
  (`git -C <worktree> push origin <branch>:<branch>`): the merge gate refuses a bare push run
  through `-C`, and the refusal reads as a permission error.
- When a fix brief asks for a test that kills a surviving mutant and the implementer instead
  deletes the guarded code on an equivalence argument, treat the deletion as a design change that
  needs its own gate round, not as the test fix; two gates disproved one such argument in a round.
- Parallel reviewer briefs that share one scratchpad tell each gate to keep its probe path in a
  shell variable or a file named for the gate, PR and round; a filename shared by two gates let
  one remove another's worktree, and one shared across PRs redirected a gate into the wrong tree.
