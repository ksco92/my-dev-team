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
- A green CI run is evidence only if it built the PR: with an unchanged lockfile and a cached
  `target/`, check the log for a `Compiling <crate>` line and a test count matching the branch.
- Never pre-assign versions to open PRs; a PR takes its version in the final rebase before its
  merge (main's plus one step, lockfile regenerated in the same commit). A branch cut before a new
  required workflow merged must rebase to run it.
- Two open PRs that both wrote the same next version rebase without a conflict and the second lands
  a zero bump, so the rebase brief names the new version as an edit to make; the proof that only
  the version files moved is per-path object-hash equality for every other PR file plus a three-dot
  diff against the base in which only the version files differ. Every oss-reviewer brief for one of
  those PRs states the decided merge order, or its same-target version check fails each sibling and
  each verdict needs a re-issue.
- Record each gate verdict in a Bash call of its own before the merge call: the merge-gate hook
  evaluates a compound line before any part of it runs, so a record chained onto the merge with
  `&&` is refused because the ledger does not yet hold that verdict (the hook reports that gate
  MISSING, no ledger, or a ledger at another head).
- Grep-verify a gate's decisive factual claims against the head before dispatching a fix round;
  grep-verify a gate's proposed repo rule against the repo it describes before prescribing it; run
  `git log --follow` on a PR body's root-cause narrative. An overrule of a gate's finding needs the
  same evidence, recorded and put into every gate's next brief, never the implementer's.
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
- GitHub host: a PR with no CI run and `mergeable: CONFLICTING` needs a rebase, not a retrigger:
  GitHub runs no `pull_request` workflow when it cannot build the merge ref. Brief the rebase to
  re-run gates on the rebased head, because the conflict resolution is new review surface.
- Concurrent gates that each `uv sync`/`maturin develop` share `~/.cache/uv` and stall on its
  lock for an hour; brief a light venv with a private `UV_CACHE_DIR` for test-only PRs, and accept
  CI's fresh run at the pinned head when it runs the same command sequence the local gate would.
- Brief the implementer to rebase onto main before opening the PR and before the first gate round,
  so the gates run once at the final head.
- A rebase under branch protection (before the merge and after every sibling merge) carries
  verdicts only by per-path object-hash equality (`git rev-parse <head>:<path>` for every PR file)
  onto a main that added no file or CI leg the PR must pass, never by re-review or a two-dot diff.
- A PR body's own preservation or fix checklist is not proof: reproduce it from the diff (every
  number-plus-unit token, every named symbol) before recording a verdict; the checklist lists what
  the author remembered to check.
- Brief every gate on a doc restructure or move to diff the set of sentences between base and head,
  not the layout: each dropped sentence has a new home or is a deletion the ticket asked for, and
  a figure another file cites is found at its new home.
- Check a PR against every issue-specific numeric criterion as well as the repo's general bar; the
  same computed figure can clear the general ceiling and miss the issue's tighter target.
- Two gates that read one delta differently (one as narrative, one as rule-mandated content) are
  not a contradiction for the owner: the repo rule decides, the orchestrator amends the issue's
  constraint with the reason, and the gate that cited the old constraint re-issues its verdict. A
  ticket-mandated sentence, figure, or verbatim copy of a named reference file, and a
  consumer-facing section's precedent for stating sibling throws, likewise outrank a gate's style
  preference or dedup, while a gate that shows ticket text false outranks the ticket, which is
  amended to the claim that holds.
- GitHub host: a merge run from a session whose cwd is not the target repository names it with
  `--repo <owner/name>`; the hook resolves the repository from the cwd.
- When a gate finding rests on a default heuristic with an "unless justified" clause and the
  owner's written requirement supplies the justification, amend the ticket once with the
  substantive checks that replace the heuristic before the first gate runs on the next
  dependency-adding PR; refining it round by round against one lockfile costs a round each time.
- A gate that flags a token from the harness's own conventions (the `# ponytail:` marker) is
  answered with the file that defines it, and the repo's `CLAUDE.md` states the convention on its
  first use so a reader without the harness can resolve it.
- When a fix round replaces a mechanism and the next round finds the same leak class in a
  neighbouring input, brief a fail-closed design (a placeholder for the whole input class) before
  the third attempt, and have the repo doc state the acceptance as a closed list of what is
  covered; later gates judge against that list, and a claim in it broader than the code reopens
  the loop.
- Read the head SHA for every gate brief from the host (the Head SHA operation), never from an
  implementer's report; a mistyped SHA voids every verdict of the round and costs a correction
  message per gate.
- Before briefing a test deletion that a gate asks for, check the test against the ticket's
  acceptance criteria; a test that pins a stated criterion stays even when the framework enforces
  the behaviour, because the criterion is the contract and the next gate will fail its absence.
  Then re-apply the mutation the test used to catch and require another test to fail before the
  deletion or fold is briefed.
- A gate finding that defers judgment to the orchestrator is ruled at once and the ruling stated in
  the fix brief and the re-review brief, so neither the implementer nor the re-review re-litigates
  it.
- A full-repository gate run on a repo whose lint or build config was copied from a sibling checks
  the sibling for the same defect in the same round and files its follow-up at once.
