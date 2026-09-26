---
tracker: asana
host: github
workspace: branch-in-place
merge_method: squash
---

# Development process

Example for a machine whose tickets live in Asana, whose code lives on GitHub, and where
worktrees cannot be used. Fill every `<...>` value, then place the file at a repository root or
at `~/.claude/DEV_PROCESS.md`.

Asana is reached through its official MCP server (OAuth), added once per machine:

```
claude mcp add --transport http --client-id <client_id> --client-secret --callback-port 8080 \
  asana https://mcp.asana.com/v2/mcp
```

MCP tokens do not work against the REST API. The bash fallback in the tables needs a separate
personal access token in `ASANA_ACCESS_TOKEN` and this helper, which takes the API path first;
request bodies are wrapped in `{"data":{...}}`:

```bash
asana_api() {
  curl -sS --fail-with-body --max-time 30 -H "Authorization: Bearer $ASANA_ACCESS_TOKEN" \
    -H "Content-Type: application/json" "https://app.asana.com/api/1.0$1" "${@:2}"
}
```

## Tracker: Asana

Project `<project_gid>`. Custom fields: difficulty `<difficulty_field_gid>` with options `low`
`<low_option_gid>`, `medium` `<medium_option_gid>`, `high` `<high_option_gid>`; priority
`<priority_field_gid>` with options `p0` `<p0_option_gid>`, `p1` `<p1_option_gid>`, `p2`
`<p2_option_gid>`. Sections: in review `<in_review_section_gid>`.

| Operation | Command / rule |
| --- | --- |
| ID format | The task GID, a numeric string never parsed as an integer; cite as `task <gid>`; permalinks `https://app.asana.com/0/<project_gid>/<task_gid>` or `https://app.asana.com/1/<workspace_gid>/project/<project_gid>/task/<task_gid>` are for display only |
| Create ticket | MCP `create_tasks` with `projects: ["<project_gid>"]`, `name`, `notes` (the body below), and `custom_fields` for difficulty and priority set by option GID; returns the GID. Fallback: `jq -n --arg name "<title>" --rawfile notes <file> '{data:{name:$name,notes:$notes,projects:["<project_gid>"],custom_fields:{"<difficulty_field_gid>":"<option_gid>","<priority_field_gid>":"<option_gid>"}}}' \| asana_api /tasks -X POST -d @-` |
| Read ticket | MCP `get_task` with the GID. To list the project: `get_tasks`, or `search_tasks` (premium) or `search_objects`. Fallback: `asana_api "/tasks/<gid>?opt_fields=name,notes,completed,custom_fields,dependencies,permalink_url"`; list with `asana_api "/tasks?project=<project_gid>&opt_fields=name,completed,permalink_url"` |
| Set difficulty / priority | MCP `update_tasks` with `custom_fields` `{"<difficulty_field_gid>": "<option_gid>"}` or `{"<priority_field_gid>": "<option_gid>"}`. Fallback: `asana_api /tasks/<gid> -X PUT -d '{"data":{"custom_fields":{"<field_gid>":"<option_gid>"}}}'` |
| Link dependencies | MCP `update_tasks` with `dependencies` set to the blocking GIDs. Fallback: `asana_api /tasks/<gid>/addDependencies -X POST -d '{"data":{"dependencies":["<blocking_gid>"]}}'` |
| Amend ticket | MCP `update_tasks` with new `notes`. Fallback: `jq -n --rawfile notes <file> '{data:{notes:$notes}}' \| asana_api /tasks/<gid> -X PUT -d @-` |
| Comment | MCP `add_comment` with the change URL when the change opens and when it merges. Fallback: `asana_api /tasks/<gid>/stories -X POST -d '{"data":{"text":"<text>"}}'` |
| Link to a change and close | The change body lists the task permalink under Issues Closed; on opening, comment the PR URL and move the task to review (fallback `asana_api /sections/<in_review_section_gid>/addTask -X POST -d '{"data":{"task":"<gid>"}}'`). GitHub does not close Asana tasks: after merging, MCP `update_tasks` with `completed: true` (fallback `asana_api /tasks/<gid> -X PUT -d '{"data":{"completed":true}}'`), then confirm `completed` is true with `get_task` |
| File a follow-up | MCP `create_tasks` with `parent: "<originating_gid>"` so it lands as a subtask, notes opening with the originating PR URL; outside a task, create ticket as above |

Ticket body template (the task's notes):

```markdown
Difficulty: low | medium | high

Context
[1-2 sentences: why this exists, what need it serves]

Requirements
- [ ] Concrete requirement (testable, binary)

Acceptance Criteria
- [ ] All requirements verifiable from code/tests
- [ ] Lint passes · coverage on new code ≥ project standard (default 95%)
- [ ] [Specific behavioral criterion] · [Specific edge case]

Implementation Plan
[Depth scaled to difficulty]

Out of Scope
[What this ticket does not cover]
```

## Code host: GitHub

| Operation | Command / rule |
| --- | --- |
| Repo key | `<owner>/<repo>` from `gh repo view --json nameWithOwner -q .nameWithOwner`; this is the ledger's repo key, and the change id is the PR number |
| Trunk | `main`, protected: status checks required, no approving review required, no direct pushes |
| Protection check | `gh api repos/<owner>/<repo> --jq .visibility`, then `gh api repos/<owner>/<repo>/branches/main/protection` and `gh api repos/<owner>/<repo>/rules/branches/main --jq '[.[].type]'`; a public repo without either is a blocker |
| Open change | `git push -u origin <branch>` then `gh pr create --base main --title "<title>" --body-file <file>`; returns the PR URL |
| Read change | `gh pr view <n> --json title,body`; the linked task is the permalink under Issues Closed |
| Head SHA | `gh pr view <n> --json headRefOid -q .headRefOid` |
| Diff | `gh pr diff <n>`, or three-dot `git diff origin/main...<sha>`; never a two-dot diff once the base has moved |
| Merge state | `gh pr view <n> --json mergeStateStatus -q .mergeStateStatus`; `CONFLICTING` means rebase, not retrigger |
| CI status | `gh pr checks <n>`; required checks are the repo's; pin them to the head with `gh api repos/<owner>/<repo>/commits/<sha>/check-suites`; wait with one `gh pr checks <n> --watch` waiter; a repo with no CI runs lint/tests/build locally and records the output in the PR body |
| Rebase | Rebase onto `origin/main` before opening and before the final push; push with `--force-with-lease` after checking the remote tip is the last SHA pushed; the version bump happens in the final rebase |
| Merge | Orchestrator only: `gh pr merge <n> --squash --delete-branch`, only after `gate-ledger check` passes and the CI status is terminal-green at the head; a hook also refuses it otherwise |
| After merge | Complete the task (Tracker above); remove the workspace (below) |
| Repo description | `gh repo view --json description -q .description`; set with `gh repo edit --description "<text>"` |
| Experiment mode | Only when the user says so: one branch, direct commits, no PR and no gates; never merged to `main` outside the normal path |

Change body template:

```markdown
## Summary
- [1-3 bullets describing the change]

## Issues Closed
- Asana task <permalink>

## Test Results
- Lint: PASS
- Tests: X passed, Y total
- Coverage: XX.XX% on changed lines

## Skipped
- [What was cut, and the trigger to add it; "Nothing skipped" if so]

## Notes
[Non-obvious trade-offs, assumptions made, follow-ups found]
```

## Workspace: branch-in-place

| Operation | Command / rule |
| --- | --- |
| Branch name | `<type>/<task_gid>-<short-desc>` with `<type>` in `feature\|fix\|chore\|refactor\|docs` |
| Create workspace | `git -C <repo> status --porcelain --untracked-files=no` prints nothing, then `git -C <repo> fetch origin && git -C <repo> checkout -b <branch> origin/main` |
| Primary checkout | It is the only workspace: one slice at a time, no uncommitted tracked changes when switching branches, back on `main` after each merge |
| Reviewer probe | Read in place, checking nothing out: `git diff origin/main...<sha>`, `git show <sha>:<path>`; to run anything, `git archive <sha> \| tar -x -C <dir>` into a new `<scratchpad>/<gate>-<pr>-<suffix>`, deleted afterwards |
| Parallelism | One slice at a time; the gates of that slice may run in parallel because none writes to the checkout |
| Remove workspace | After the merge: `git -C <repo> checkout main && git -C <repo> pull --ff-only && git -C <repo> branch -D <branch>`; stop what the slice started (full-line `ps` scan) |
| Gitignored `.claude` | Not applicable; work never leaves the checkout |

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
ledger, the hooks, or CI configuration inside a slice; deleting outside the workspace under work;
parsing an Asana GID as an integer.

## Repository-specific constraints

None at machine level. A repository states its own under this heading in its root
`DEV_PROCESS.md`.
