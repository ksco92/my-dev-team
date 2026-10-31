---
tracker: none
host: github
workspace: worktree
merge_method: squash
---

# Development process

How changes reach `ksco92/my-dev-team`. The format is
`plugins/dev-team/context/dev-process-contract.md`.

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
| Link to a change and close | The implementing branch commits the ticket file with `status: done`; the change body names `docs/plan/<slug>.md`; after merging confirm with `git fetch origin && git show origin/main:docs/plan/<slug>.md \| grep -x 'status: done'` |
| File a follow-up | Create ticket as above; the body opens with the originating PR URL |

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

## Code host: GitHub

| Operation | Command / rule |
| --- | --- |
| Repo key | `ksco92/my-dev-team`; this is the ledger's repo key, and the change id is the PR number |
| Trunk | `main`, protected: the `validate` check required, branch up to date with `main` required, no approving review required, no direct pushes |
| Protection check | `gh api repos/ksco92/my-dev-team --jq .visibility`, then `gh api repos/ksco92/my-dev-team/branches/main/protection` and `gh api repos/ksco92/my-dev-team/rules/branches/main --jq '[.[].type]'`; a public repo without either is a blocker |
| Open change | `git push -u origin <branch>` then `gh pr create --base main --title "<title>" --body-file <file>`; returns the PR URL |
| Read change | `gh pr view <n> --json title,body`; the plan file is named under Issues Closed |
| Head SHA | `gh pr view <n> --json headRefOid -q .headRefOid` |
| Diff | `gh pr diff <n>`, or three-dot `git diff origin/main...HEAD` in a checkout; never a two-dot diff once the base has moved |
| Merge state | `gh pr view <n> --json mergeStateStatus -q .mergeStateStatus`; `CONFLICTING` means rebase, not retrigger |
| CI status | `gh pr checks <n>`; the required check is `validate` (both manifests validate, shellcheck, the `dev-process`, `lesson-lint`, and `merge-gate` test scripts, `lesson-lint` on added bullets, the version bump); pin them to the head with `gh api repos/ksco92/my-dev-team/commits/<sha>/check-suites`; wait with one `gh pr checks <n> --watch` waiter |
| Rebase | Rebase onto `origin/main` before opening, before the final push, and after every sibling merge (the branch must be up to date); push with `--force-with-lease` after checking the remote tip is the last SHA pushed; the version bump happens in the final rebase |
| Merge | Orchestrator only: `gh pr merge <n> --repo ksco92/my-dev-team --squash --delete-branch`, only after `gate-ledger check` passes and the CI status is terminal-green at the head; the hook also refuses it unless the ledger check passes and `gh pr checks` reports every check passed or skipped |
| After merge | Confirm the plan file reads `status: done` on `origin/main` (Tracker above); remove the workspace (below) |
| Repo description | `gh repo view --json description -q .description`; set with `gh repo edit --description "<text>"` |

Change request body template:

```markdown
## Summary
- [1-3 bullets describing the change]

## Issues Closed
- docs/plan/<slug>.md, or "None (tracker-less repo)" when the slice has no plan file

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

## Experiment

| Operation | Command / rule |
| --- | --- |
| Enter | Only when the owner says so; record it once in the session |
| Branch name | `experiment/<topic>` |
| Slice branch | `exp/<slice>`, cut from the experiment branch |
| Integrate | With the experiment worktree as the working directory (the `cd` is its own command), `git merge exp/<slice>`; a merge run from the primary checkout on `main` is refused by the hook |
| Skipped | Tickets, change requests, the five gates, tests, lint, CI, the version bump |
| Required | Live verification with its evidence, small commits, no attribution lines, a push of the experiment branch by name (`git push origin experiment/<topic>`) |
| Results | Raw data under `results/<machine-slug>/raw/`, logs gitignored, the report at `results/RESULTS.md`, and a `run_*.sh` entry point that reruns on another machine without code changes |
| Exit | One change from the experiment branch to the trunk, tagged at the highest slice difficulty, through every gate |

## Workspace: git worktree

| Operation | Command / rule |
| --- | --- |
| Branch name | `<type>/<slug>` with `<type>` in `feature\|fix\|chore\|refactor\|docs` and `<slug>` the plan file's |
| Create workspace | `git -C ~/projects/my-dev-team fetch origin && git -C ~/projects/my-dev-team worktree add ~/worktrees/my-dev-team/<branch> -b <branch> origin/main`; for a same-repo subagent brief, `isolation: "worktree"` is equivalent |
| Primary checkout | Stays on `main` and is never checked out to a branch; it may be running a dev server or another gate |
| Reviewer probe | Each reviewer round gets its own detached worktree at the head: `git worktree add --detach <scratchpad>/<gate>-<pr>-<suffix> <sha>`; a reviewer removes only the worktree it created |
| Parallelism | Independent slices run in parallel, each in its own workspace |
| Remove workspace | After the merge: `git -C ~/projects/my-dev-team worktree remove ~/worktrees/my-dev-team/<branch>`, then a full-line `ps` scan for the path and kill what still runs from it |
| Gitignored `.claude` | Not applicable; this repository does not ignore it |

## Gates and ledger

All five gates run on every change: `pr-reviewer`, `code-health`, `oss-reviewer`,
`security-review`, `readme-writer`. Every finding at any severity blocks; nits included. Verdicts
are recorded with `${CLAUDE_PLUGIN_ROOT}/bin/gate-ledger record ksco92/my-dev-team <pr> <gate>
<PASS|FAIL|BLOCKED> <findings> <head-sha> <model>`, checked with `gate-ledger check ksco92/my-dev-team <pr> <head-sha>`, and listed
with `gate-ledger show ksco92/my-dev-team <pr>`; a record at a new head resets the others.

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

Every change bumps `plugins/dev-team/.claude-plugin/plugin.json` `version`; the `validate` check
fails without it. The plugin's one-line description is one string, identical in the GitHub repo
description, the root README, both marketplace descriptions, `plugin.json`, and the plugin
README. Local checks before opening a change are the ones listed in `CLAUDE.md`.
