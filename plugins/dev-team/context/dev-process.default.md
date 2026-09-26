---
tracker: none
host: none
workspace: branch-in-place
merge_method: merge
---

# Development process

The dev-team plugin's built-in default, used when neither the repository root nor `~/.claude/`
has a `DEV_PROCESS.md`. Tickets are files in the repository, a change is a local branch merged
into `main`, and one checkout holds one slice at a time. The format is
`${CLAUDE_PLUGIN_ROOT}/context/dev-process-contract.md`.

## Tracker: files in the repository

| Operation | Command / rule |
| --- | --- |
| ID format | The slug of `docs/plan/<slug>.md` (lowercase, hyphenated); cite as `plan <slug>`, never an ordinal |
| Create ticket | Write `docs/plan/<slug>.md` from the template below, `status: open`; the file stays untracked until the change that implements it commits it |
| Read ticket | `cat docs/plan/<slug>.md`; the acceptance criteria are the implementer's contract |
| Set difficulty / priority | Edit the frontmatter keys `difficulty` (`low\|medium\|high`) and `priority` (`p0`-`p2`) |
| Link dependencies | `Blocked by: <slug> · Blocks: <slug>` under the ticket's Dependencies heading |
| Amend ticket | Edit the body of `docs/plan/<slug>.md` before the implementer starts |
| Comment | Not used; progress and evidence live in the change body and the commits |
| Link to a change and close | The implementing branch commits the ticket file with `status: done`; the change body names `docs/plan/<slug>.md`; after merging confirm with `git show main:docs/plan/<slug>.md \| grep -x 'status: done'` |
| File a follow-up | Create ticket as above; the body opens with the originating branch and head SHA |

Ticket body template:

```markdown
---
difficulty: low | medium | high
priority: p0 | p1 | p2
status: open
---

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
- Blocked by: <slug> · Blocks: <slug>

## Out of Scope
[What this ticket does not cover]
```

## Code host: none (local branch)

| Operation | Command / rule |
| --- | --- |
| Repo key | The absolute path from `git rev-parse --show-toplevel`; this is the ledger's repo key, and the change id is the branch name |
| Trunk | `main`; advanced only by the gated `git merge` below, never by a direct commit |
| Protection check | Not applicable; the merge hook is the only protection a local trunk has |
| Open change | Commit on the branch, then write the change body from the template below to `"$(git rev-parse --git-common-dir)/changes/<branch>.md"` (`mkdir -p` its directory); the change id is the branch name |
| Read change | `cat "$(git rev-parse --git-common-dir)/changes/<branch>.md"` |
| Head SHA | `git rev-parse <branch>` |
| Diff | `git diff main...<branch>`; never a two-dot diff once `main` has moved |
| Merge state | `git merge-tree --write-tree main <branch> >/dev/null`; a non-zero exit means rebase before merging |
| CI status | No CI: run the project's own lint, test, and build commands (from its `CLAUDE.md`) on the head and record each command and its result under Test Results in the change body; the merge hook checks the ledger only |
| Rebase | `git rebase main` on the branch before requesting gates and before the merge; nothing is pushed |
| Merge | Orchestrator only, as two separate commands because the hook reads the current branch before the command runs: `git checkout main`, then `git merge --no-ff <branch> -F "$(git rev-parse --git-common-dir)/changes/<branch>.md"` with the branch as the first non-option argument, only after every CI status command recorded for the head passed; the hook refuses it unless the ledger shows every gate PASS at the branch head |
| After merge | Confirm the ticket file reads `status: done` on `main`; delete the change body file; remove the workspace (below) |
| Repo description | Not applicable; the README's opening line is the only description |
| Experiment mode | Only when the user says so: one branch, direct commits, no change body and no gates; never merged to `main` without going through the normal path |

Change body template:

```markdown
## Summary
- [1-3 bullets describing the change]

## Issues Closed
- docs/plan/<slug>.md

## Test Results
- Lint: PASS (`<command>`)
- Tests: X passed, Y total (`<command>`)
- Coverage: XX.XX% on changed lines

## Skipped
- [What was deliberately not built or was cut to a simpler form, and the trigger to add it;
  "Nothing skipped" if so]

## Notes
[Non-obvious trade-offs, assumptions made, follow-ups found]
```

## Workspace: branch-in-place

| Operation | Command / rule |
| --- | --- |
| Branch name | `<type>/<slug>` with `<type>` in `feature\|fix\|chore\|refactor\|docs` and `<slug>` the ticket's |
| Create workspace | `git -C <repo> status --porcelain --untracked-files=no` prints nothing, then `git -C <repo> checkout main && git -C <repo> checkout -b <branch>` |
| Primary checkout | It is the only workspace: one slice at a time, no uncommitted tracked changes when switching branches, back on `main` after each merge |
| Reviewer probe | Read the head in place without checking anything out: `git diff main...<sha>`, `git show <sha>:<path>`, `git grep <pattern> <sha>`; to run anything, `mkdir -p <scratchpad>/<gate>-<branch-slug>-<suffix> && git archive <sha> \| tar -x -C` that directory, and delete only that directory afterwards |
| Parallelism | One slice at a time; the gates of that slice may run in parallel because none writes to the checkout |
| Remove workspace | After the merge, on `main`: `git branch -d <branch>`, then stop any process the slice started (full-line `ps` scan for its scratch paths) |
| Gitignored `.claude` | Not applicable; work never leaves the checkout |

## Gates and ledger

All five gates run on every change: `pr-reviewer`, `code-health`, `oss-reviewer`,
`security-review`, `readme-writer`. Every finding at any severity blocks; nits included. Verdicts
are recorded with `${CLAUDE_PLUGIN_ROOT}/bin/gate-ledger record <repo-path> <branch> <gate>
<PASS|FAIL|BLOCKED> <findings> <head-sha> <model>`, checked with `gate-ledger check <repo-path>
<branch> <head-sha>`, and listed with `gate-ledger show <repo-path> <branch>`; a record at a new
head resets the others.

## Commits

No AI-attribution strings in commit messages or change bodies; a hook rejects them. Small,
logically grouped commits on the branch; the merge keeps them under one merge commit. The version
bump follows the semver policy in the harness (major zero: breaking or feature → minor, otherwise
patch) and is made once, in the final rebase before the merge.

## Forbidden

Moving any other ref onto `main` except by the gated `git merge`, a direct commit on `main`
included; force or delete pushes of `main` where a remote exists; merging by anyone but the
orchestrator; commenting on, closing, or approving a change from a reviewer; editing the gate
ledger, the hooks, or CI configuration inside a slice; deleting outside the workspace under work.

## Repository-specific constraints

None in the default. A repository states its own under this heading in its root
`DEV_PROCESS.md`.
