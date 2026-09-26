---
tracker: github
host: github
workspace: worktree
merge_method: squash
---

# Development process

Example for a machine whose tickets and code live on GitHub and whose slices run in git
worktrees. Place the file at a repository root or at `~/.claude/DEV_PROCESS.md`.

## Tracker: GitHub Issues

| Operation | Command / rule |
| --- | --- |
| ID format | `#<n>`; permalink `https://github.com/<owner>/<repo>/issues/<n>`; in code and docs cite as `issue #<n>`, never an ordinal |
| Create ticket | `gh issue create --title "<title>" --label tpm-managed --label "difficulty:<low\|medium\|high>" --label "<component>" --label "p<0-2>" --body-file <file>`; the body follows the template below |
| Read ticket | `gh issue view <n>` (add `--json title,body,labels,state` for fields); the acceptance criteria are the implementer's contract |
| Set difficulty / priority | Labels `difficulty:<tag>` and `p0`–`p2`; change with `gh issue edit <n> --add-label … --remove-label …` |
| Link dependencies | `Blocked by: #XX · Blocks: #YY` under the ticket's Dependencies heading |
| Amend ticket | `gh issue edit <n> --body-file <file>`; a fuller spec for an escalated slice or a recomputed numeric target is amended before the implementer starts |
| Comment | Not used; progress and evidence live in the change request, not on the ticket |
| Link to a change and close | The change request body carries `Closes #<n>`; the host closes the ticket on merge; after merging confirm with `gh issue view <n> --json state -q .state` = `CLOSED` |
| File a follow-up | Create ticket as above, body opens with the originating change URL; used for out-of-diff findings a gate surfaces |

Ticket body template:

```markdown
**Difficulty:** low | medium | high

## Context
[1-2 sentences: why this exists, what need it serves]

## Requirements
- [ ] Concrete requirement (testable, binary)

## Acceptance Criteria
- [ ] All requirements verifiable from code/tests
- [ ] Lint passes · coverage on new code ≥ project standard (default 95%)
- [ ] [Specific behavioral criterion] · [Specific edge case]

## Implementation Plan
[Depth scaled to difficulty]

## Dependencies
- Blocked by: #XX · Blocks: #YY

## Out of Scope
[What this ticket does not cover]
```

## Code host: GitHub

| Operation | Command / rule |
| --- | --- |
| Repo key | `<owner>/<repo>` from `gh repo view --json nameWithOwner -q .nameWithOwner`; this is the ledger's repo key, and the change id is the PR number |
| Trunk | `main`, protected: status checks required, no approving review required, no direct pushes |
| Protection check | `gh api repos/<owner>/<repo> --jq .visibility`, then `gh api repos/<owner>/<repo>/branches/main/protection` and `gh api repos/<owner>/<repo>/rules/branches/main --jq '[.[].type]'`; a public repo without either is a blocker |
| Open change | `git push -u origin <branch>` then `gh pr create --base main --title "<title>" --body-file <file>`; returns the PR URL |
| Read change | `gh pr view <n> --json title,body,closingIssuesReferences` |
| Head SHA | `gh pr view <n> --json headRefOid -q .headRefOid` |
| Diff | `gh pr diff <n>`, or three-dot `git diff origin/main...HEAD` in a checkout; never a two-dot diff once the base has moved |
| Merge state | `gh pr view <n> --json mergeStateStatus -q .mergeStateStatus`; `CONFLICTING` means rebase, not retrigger |
| CI status | `gh pr checks <n>`; required checks are the repo's (default lint · tests · coverage ≥ standard · build · package dry-run where applicable); pin them to the head with `gh api repos/<owner>/<repo>/commits/<sha>/check-suites`; wait with one `gh pr checks <n> --watch` waiter; a repo with no CI runs lint/tests/build locally and records the output in the PR body |
| Rebase | Rebase onto `origin/main` before opening and before the final push; push with `--force-with-lease` after checking the remote tip is the last SHA pushed; the version bump happens in the final rebase |
| Merge | Orchestrator only: `gh pr merge <n> --squash --delete-branch`, only after `gate-ledger check` passes and the CI status is terminal-green at the head; the hook also refuses it unless the ledger check passes and `gh pr checks` reports every check passed or skipped |
| After merge | Confirm the ticket closed; remove the workspace (below) |
| Repo description | `gh repo view --json description -q .description`; set with `gh repo edit --description "<text>"` |
| Experiment mode | Only when the user says so: one branch, direct commits, no change request and no gates; never merged to `main` without going through the normal path |

Change request body template:

```markdown
## Summary
- [1-3 bullets describing the change]

## Issues Closed
- Closes #<n>

## Test Results
- Lint: PASS
- Tests: X passed, Y total
- Coverage: XX.XX% on changed lines

## Skipped
- [What was deliberately not built or was cut to a simpler form, and the trigger to add it;
  "Nothing skipped" if so]

## Notes
[Non-obvious trade-offs, assumptions made, follow-ups found]
```

## Workspace: git worktree

| Operation | Command / rule |
| --- | --- |
| Branch name | `<type>/<n>-<short-desc>` with `<type>` in `feature\|fix\|chore\|refactor\|docs` and `<n>` the ticket number |
| Create workspace | `git -C <repo> fetch origin && git -C <repo> worktree add ~/worktrees/<repo-name>/<branch> -b <branch> origin/main`; for a same-repo subagent brief, `isolation: "worktree"` is equivalent |
| Primary checkout | Stays on `main` and is never checked out to a branch; it may be running a dev server or another gate |
| Reviewer probe | Each reviewer round gets its own detached worktree at the head: `git worktree add --detach <scratchpad>/<gate>-<pr>-<suffix> <sha>`; a reviewer removes only the worktree it created |
| Parallelism | Independent slices run in parallel, each in its own workspace |
| Remove workspace | After the merge: `git -C <repo> worktree remove ~/worktrees/<repo-name>/<branch>`, then a full-line `ps` scan for the path and kill what still runs from it |
| Gitignored `.claude` | A repo that gitignores `.claude/*` gets an overlay instead of a worktree; verify `.git` resolves before any git operation |

## Gates and ledger

All five gates run on every change: `pr-reviewer`, `code-health`, `oss-reviewer`,
`security-review`, `readme-writer`. Every finding at any severity blocks; nits included. Verdicts
are recorded with `gate-ledger record <owner/repo> <pr> <gate> <PASS|FAIL|BLOCKED> <findings>
<head-sha> <model>`, checked with `gate-ledger check <owner/repo> <pr> <head-sha>`, and listed
with `gate-ledger show <owner/repo> <pr>`; a record at a new head resets the others.

## Commits

No AI-attribution strings in commit messages or change bodies; a hook rejects them. Small,
logically grouped commits on the branch; the merge squashes them. The version bump follows the
semver policy in the harness (major zero: breaking or feature → minor, otherwise patch) and is
made once, in the final rebase before the merge.

## Forbidden

Pushing any non-`main` ref onto `main`; force or delete pushes of `main`; merging by anyone but
the orchestrator; commenting on, closing, or approving a change from a reviewer; editing the gate
ledger, the hooks, or CI configuration inside a slice; deleting outside the workspace under work.

## Repository-specific constraints

None at machine level. A repository states its own under this heading in its root
`DEV_PROCESS.md` (a build tool that pins absolute paths, a monorepo that forbids worktrees, a
different trunk name).
