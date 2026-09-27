# tpm gates rules

Binding rules for running the five review gates, the ledger, CI, rebases, and the merge (Phase 5).
Read before the first gate of a run.

- When a PR replaces one automated gate with another (CI → hook, one runner → another), read the
  replacement's blocking semantics (a Claude Code hook blocks only on exit 2; a `Stop` hook never
  fires on push or merge) and enumerate every step the old gate ran; pair a session hook with a
  tracked `.githooks/pre-push` where pushes must be gated.
- Before merging, poll the CI status operation until every required check is terminal and confirm
  every gate for that PR has returned; a verdict on a pre-rebase head is void once a re-review runs
  on the new head. The ledger keeps one head per PR: record a late verdict at the current head only,
  with the diff proof, and finish with `gate-ledger show` counting five PASS.
- A green CI run is evidence only if it built the PR: with an unchanged lockfile and a cached
  `target/`, check the log for a `Compiling <crate>` line and a test count matching the branch.
- Never pre-assign versions to open PRs; a PR takes its version in the final rebase before its
  merge (main's plus one step, lockfile regenerated in the same commit). A branch cut before a new
  required workflow merged must rebase to run it.
- Grep-verify a gate's decisive factual claims against the head before dispatching a fix round, and
  verify a PR body's root-cause narrative with `git log --follow`; the duty runs both ways, and an
  overruled finding is recorded with its evidence rather than sent to the implementer.
- Every gate brief on a PR whose base has moved names the diff form (the Diff operation, or
  three-dot `origin/main...HEAD`); a two-dot diff attributes base commits to the PR. For a fix-round
  delta across a rebase, diff the two heads restricted to the PR's own paths (`git diff <old> <new>
  -- <paths>`), and when a sibling merge touched one of those same files, only the Diff operation
  (or a three-dot diff against the base) separates the PR's edits from the replayed ones.
- On a no-remote repo, the security gate gets an explicit commit range; `origin/HEAD` does not
  exist there.
- When a CI failure is fixed by pinning at the root, do not also brief graceful degradation for the
  unpinned case; verify a new test path by running the project's own command and checking for
  unexpected SKIPs.
- A rebase that merges textually can still fail to compile: tests merged in from main
  construct a type the branch just wrapped. Every rebase brief says "run the full `make check`
  (all targets, clippy included) on the rebased head before pushing", and the reviewer's per-path
  object-hash proof does not cover files main added.
- GitHub host: a PR with no CI run and `mergeable: CONFLICTING` needs a rebase, not a retrigger:
  GitHub runs no `pull_request` workflow when it cannot build the merge ref. Brief the rebase to
  re-run gates on the rebased head, because the conflict resolution is new review surface.
- Concurrent gates that each `uv sync`/`maturin develop` share `~/.cache/uv` and stall on its
  lock for an hour; brief a light venv with a private `UV_CACHE_DIR` for test-only PRs, and accept
  CI's fresh run at the pinned head when it runs the same command sequence the local gate would.
- A branch cut before a new CI leg merged runs that leg on its first pull_request run against
  the merged main; brief the implementer to rebase onto main before opening the PR so a new
  interpreter or platform leg is exercised locally first, not discovered by CI.
- When branch protection requires the branch up to date with main, every PR rebases before its
  merge and after every sibling merge: brief implementers to rebase before opening and before the
  final push, and carry verdicts across a clean rebase by per-path object-hash proof
  (`git rev-parse <head>:<path>` equal for every PR file), never by re-review or a two-dot diff.
- A PR body's own preservation or fix checklist is not proof: reproduce it from the diff (every
  number-plus-unit token, every named symbol) before recording a verdict; the checklist lists what
  the author remembered to check.
- Check a PR against every issue-specific numeric criterion as well as the repo's general bar; the
  same computed figure can clear the general ceiling and miss the issue's tighter target.
- Two gates that read one delta differently (one as narrative, one as rule-mandated content) are
  not a contradiction for the owner: the repo rule decides, the orchestrator amends the issue's
  constraint with the reason, and the gate that cited the old constraint re-issues its verdict.
- GitHub host: a merge run from a session whose cwd is not the target repository names it with
  `--repo <owner/name>`; the hook resolves the repository from the cwd.
- When a gate finding rests on a default heuristic with an "unless justified" clause and the
  owner's written requirement supplies the justification, amend the ticket once with the
  substantive checks that replace the heuristic before the first gate runs on the next
  dependency-adding PR; refining it round by round against one lockfile costs a round each time.
- A gate that flags a token from the harness's own conventions (the `# ponytail:` marker) is
  answered with the file that defines it, and the repo's `CLAUDE.md` states the convention on its
  first use so a reader without the harness can resolve it.
- Reviewing a redactor or parser fix, re-run every earlier regression input with the parser's
  delimiters placed inside the secret and with the payload at every position the parser splits (a
  later field, a value, the query string); after a normalising step is added in front of a check
  that matched several representations, run the mutant that deletes each existing representation;
  and execute each parametrised security case through the library call the check reads before
  trusting its count.
- When a fix round replaces a mechanism and the next round finds the same leak class in a
  neighbouring input, brief a fail-closed design (a placeholder for the whole input class) before
  the third attempt, and have the repo doc state the acceptance as a closed list of what is
  covered; later gates judge against that list, and a claim in it broader than the code reopens
  the loop.
