# tpm gates rules

Binding rules for running the five review gates, the ledger, CI, rebases, and the merge (Phase 5).
Read before the first gate of a run.

- When a PR replaces one automated gate with another (CI → hook, one runner → another), read the
  replacement's blocking semantics (a Claude Code hook blocks only on exit 2; a `Stop` hook never
  fires on push or merge) and enumerate every step the old gate ran; pair a session hook with a
  tracked `.githooks/pre-push` where pushes must be gated.
- Before merging, poll the CI status operation until every required check is terminal and confirm
  every gate for that PR has returned; a verdict on a pre-rebase head is void once a re-review runs
  on the new head. The ledger keeps one head per PR and a record at any other head, an older one
  included, starts it afresh: record a late verdict at the current head only, with the diff proof,
  and finish with `gate-ledger show` counting five PASS.
- Brief every gate to wait once for a running required check with the CI status operation's wait and
  report its result, with the hand-back of `briefing.md` for a run that outlasts its foreground cap;
  a gate that returns BLOCKED for a run in progress costs a round.
- A green CI run is evidence only if it built the PR: with an unchanged lockfile and a cached
  `target/`, check the log for a `Compiling <crate>` line and a test count matching the branch.
- Where the repository bumps per change, never pre-assign versions to open PRs; a PR takes its
  version in the final rebase before its merge (main's plus one step, lockfile regenerated in the
  same commit); a batching repository follows `releases.md`. A branch cut before a new required
  workflow merged must rebase to run it.
- Two open PRs that both wrote the same next version rebase without a conflict and the second lands
  a zero bump, so the rebase brief names the new version as an edit to make; the proof that only the
  version files moved is per-path object-hash equality for every other PR file plus a three-dot diff
  against the base in which only the version files differ. Every oss-reviewer brief for one of those
  PRs states the decided merge order, or its same-target version check fails each sibling and each
  verdict needs a re-issue.
- Record each gate verdict in a Bash call of its own before the merge call: the merge-gate hook
  evaluates a compound line before any part of it runs, so a record chained onto the merge with `&&`
  is refused because the ledger does not yet hold that verdict (the hook reports that gate MISSING,
  no ledger, or a ledger at another head). Run the merge itself as the only command of its call; a
  `;` after it is read into the `--repo` value, and the refusal reads as a failed `gh pr view`.
- Every gate brief on a PR whose base has moved names the diff form (the Diff operation, or
  three-dot `origin/main...HEAD`); a two-dot diff attributes base commits to the PR. For a fix-round
  delta across a rebase, diff the two heads restricted to the PR's own paths
  (`git diff <old> <new> -- <paths>`), and when a sibling merge touched one of those same files,
  only the Diff operation (or a three-dot diff against the base) separates the PR's edits from the
  replayed ones.
- Every security gate brief names the explicit three-dot range (`origin/HEAD` does not exist on a
  no-remote repo); the security-reviewer agent file's step 2 says where the diff runs.
- GitHub host: a PR with no CI run and `mergeable: CONFLICTING` needs a rebase, not a retrigger:
  GitHub runs no `pull_request` workflow when it cannot build the merge ref. Brief the rebase to
  re-run gates on the rebased head, because the conflict resolution is new review surface.
- GitHub host: in a workflow `concurrency` group a newly queued run cancels any pending run of the
  group and takes its place (`queue: single`, the default), and `cancel-in-progress: true` cancels
  the running one as well. Under such a group the orchestrator alone triggers the workflow, one PR
  at a time with at most one run pending, and every brief says never to add the trigger label or
  watch the run.
- Concurrent gates that each `maturin develop` against one uv cache stall on its lock; brief a light
  venv with the run's shared `UV_CACHE_DIR` (operations.md) for test-only PRs, a private one for
  each gate that builds a native extension, and accept CI's fresh run at the pinned head when it
  runs the same command sequence the local gate would.
- Brief the implementer to rebase onto main before opening the PR and before the first gate round,
  so the gates run once at the final head.
- A rebase under branch protection (before the merge and after every sibling merge) carries verdicts
  only by per-path object-hash equality (`git rev-parse <head>:<path>` for every PR file) onto a
  main that added no file or CI leg the PR must pass, never by re-review or a two-dot diff.
- When PRs must merge in sequence and each needs a long external run, stage the next PR as a local
  commit on the predecessor's head, gate it with that head as the diff base, and after the
  predecessor's squash move it with `git rebase --onto <main> <predecessor head>`; record the
  verdicts at the pushed head only when `git rev-parse 'HEAD^{tree}'` equals the reviewed tree and
  main's tree equals the tree of the predecessor head the gates diffed against.
- GitHub host: a merge run from a session whose cwd is not the target repository names it with
  `--repo <owner/name>`; the hook resolves the repository from the cwd.
- Read the head SHA for every gate brief from the host (the Head SHA operation), never from an
  implementer's report, and `grep -n` the head for each prescribed code change the report says
  landed before launching the re-gate round; a mistyped SHA voids every verdict of the round and
  costs a correction message per gate.
- Re-run every grep-shaped acceptance criterion of the ticket at each fix head before dispatching
  gates, and re-check every test id the PR body cites against the collected ids; the implementer
  re-measures every number, grep result and "prints nothing" claim the PR body quotes at each fix
  head and after each rebase in its report, and the orchestrator re-measures them before the gate
  round.
- A gate reads a ticket body whole through the Read ticket operation, never through `head -N`; a
  truncated read reports a recorded accepted risk as missing.
- A gate result that lacks the verdict block is void until the gate resends it; the `SubagentStop`
  hook asks the gate once. Stop a gate whose transcript has not advanced for twenty minutes on its
  final cleanup command, remove its probe yourself, and relaunch it at the same head.
- Brief the economy gate to apply its whole checklist once and report everything in that round, and
  in a later round to raise nothing on lines it read and passed unless it quotes the rule text and
  the line.
- In a run whose purpose is removal, brief every gate that a request to add or restore a guard, a
  test or prose is a proposed addition for the orchestrator's ruling, stated with who can trigger
  the case, unless the owner's threat model covers the case or an untrusted caller can reach it, in
  which case the reviewer baseline's reproducer rule decides it as in any other run; put the threat
  model in the brief.
- A verdict block whose `FINDINGS` count is not matched by listed findings is void; message the gate
  for them, since the hook checks only the block's lines.
- Send a change you already know you will ask for (an implementer's open question, a stale test
  name) before dispatching gates on that head; a round on a head you will change is spent twice.
- Two open changes that touch the same file merge in the order that costs one review: the one that
  is clean first merges first, and the other takes the next version in the fix round it already
  needs; a planned order is not a reason to hold a clean change.
