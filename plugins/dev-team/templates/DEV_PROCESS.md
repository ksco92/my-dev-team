---
tracker:
host:
workspace:
merge_method:
---

# Development process

<!-- Fill every empty cell with a command or a rule; write "Not used" or "Not applicable" with
where that concern lives instead. The format is ${CLAUDE_PLUGIN_ROOT}/context/dev-process-contract.md.
Place this file at a repository root or at ~/.claude/DEV_PROCESS.md. -->

## Tracker: <name>

| Operation | Command / rule | Hint |
| --- | --- | --- |
| ID format | | the ID's shape, its permalink, how code and docs cite it |
| Create ticket | | command taking title, difficulty, component, priority, body; yields the ID |
| Read ticket | | command printing title, body, state, difficulty |
| Set difficulty / priority | | where `low\|medium\|high` and `p0`-`p2` are stored, and how to change them |
| Link dependencies | | how "blocked by" and "blocks" are recorded |
| Amend ticket | | command replacing a ticket's body |
| Comment | | command adding a comment, or "Not used" and where progress lives |
| Link to a change and close | | link the change carries, what closes the ticket, how closure is confirmed |
| File a follow-up | | create a ticket whose body cites the originating change |

Ticket body template:

```markdown
<the body every ticket carries; at least the headings in the contract's Create ticket row>
```

## Code host: <name>

| Operation | Command / rule | Hint |
| --- | --- | --- |
| Repo key | | the ledger's repo key, and what the change id is |
| Trunk | | the trunk's name and its protection |
| Protection check | | command reporting visibility and trunk protection |
| Open change | | command opening a change from a branch, title, body; what it returns |
| Read change | | command printing a change's title, body, linked ticket |
| Head SHA | | command printing the change's head commit |
| Diff | | three-dot diff of the change against its base |
| Merge state | | command reporting conflicts, and what a conflict requires |
| CI status | | required checks, reading them at the head, waiting, no-CI fallback |
| Rebase | | when to rebase and how the result is pushed |
| Merge | | orchestrator-only merge command using `merge_method`; runs only after `gate-ledger check` passes and the CI status is terminal-green |
| After merge | | confirmation and cleanup steps |
| Repo description | | command reading and setting the one-line description |

Change body template:

```markdown
<the body every change carries: summary, tickets closed, test results, skipped, notes>
```

## Experiment

<!-- Or the single line "Not allowed." when the mode is off. -->

| Operation | Command / rule | Hint |
| --- | --- | --- |
| Enter |  | how the owner's statement enters the mode, or "Not allowed" |
| Branch name |  | pattern of the experiment branch |
| Slice branch |  | pattern of a slice branch and where it is cut from |
| Integrate |  | merge of a slice branch into the experiment branch; a form the hook does not gate is not accepted |
| Skipped |  | what the mode skips |
| Required |  | what the mode still requires, including the push of the experiment branch by name |
| Results |  | where raw data, logs, the report, and the rerun script live |
| Exit |  | how the work re-enters the trunk through the gates |

## Workspace: <name>

| Operation | Command / rule | Hint |
| --- | --- | --- |
| Branch name | | pattern from type, ticket ID, short description |
| Create workspace | | command preparing a workspace for a branch |
| Primary checkout | | what may and may not happen in it |
| Reviewer probe | | how a reviewer reads and runs the head without touching another checkout |
| Parallelism | | how many slices run at once |
| Remove workspace | | cleanup after merge, and how stray processes are found |
| Gitignored `.claude` | | what to do when the repository ignores `.claude/*` |

## Gates and ledger

| Operation | Command / rule | Hint |
| --- | --- | --- |
| Gate roster | | gates run on every change; every finding blocks |
| Record verdict | | `gate-ledger record <repo-key> <change-id> <gate> <verdict> <findings> <head> <model>` |
| Check ledger | | `gate-ledger check <repo-key> <change-id> <head>` |
| Show ledger | | `gate-ledger show <repo-key> <change-id>` |

## Commits

| Operation | Command / rule | Hint |
| --- | --- | --- |
| Attribution | | no AI-attribution strings in commits or change bodies |
| Granularity | | how commits are grouped and what the merge does with them |
| Version bump | | when the bump is made and which policy sets it |

## Forbidden

| Operation | Command / rule | Hint |
| --- | --- | --- |
| Forbidden actions | | actions no role takes; see the contract's minimum list |

## Repository-specific constraints

| Operation | Command / rule | Hint |
| --- | --- | --- |
| Constraints | | what this repository does differently, or "None" |
