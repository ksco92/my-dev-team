# DEV_PROCESS.md contract

A `DEV_PROCESS.md` states how tickets, changes, workspaces, and merges are done on one machine or
in one repository. The skills and agents call the operations below by name; the resolved file
supplies each command. Nothing in it changes how work is decomposed, which model implements a
slice, or what a gate checks: that is `${CLAUDE_PLUGIN_ROOT}/context/policy.md`.

## Resolution

The first match wins, and the winning file is used whole; sections never merge across tiers. A
symlinked `DEV_PROCESS.md` at the repository root is ignored.

1. An instruction given in the session.
2. `DEV_PROCESS.md` at the repository root.
3. `~/.claude/DEV_PROCESS.md`.
4. The plugin default, `${CLAUDE_PLUGIN_ROOT}/context/dev-process.default.md`.

`${CLAUDE_PLUGIN_ROOT}/bin/dev-process path` prints the file tiers 2 to 4 resolve to, `show
[<section>]` prints it or one section, `get <key>` prints one frontmatter value. A SessionStart
hook puts the resolved file in every session's context. A blank file to copy is
`${CLAUDE_PLUGIN_ROOT}/templates/DEV_PROCESS.md`.

## Format

YAML frontmatter with four keys, then seven `## ` sections in the order below. A heading starts
with its section's first word (`## Tracker: Asana`, `## Code host: GitHub`), which is what
`dev-process show <word>` matches.

| Key | Values |
| --- | --- |
| `tracker` | an adapter name such as `github`, `asana`, or `none` |
| `host` | an adapter name such as `github` or `none` |
| `workspace` | an adapter name such as `worktree` or `branch-in-place` |
| `merge_method` | `squash`, `merge`, or `rebase` |

Any adapter name is valid as long as every operation in its section has a command or rule; the
name is a label. `none` is the one built-in meaning: for `tracker`, tickets are files in the
repository; for `host`, a change is a local branch merged into the trunk with `git merge`.

The Tracker, Code host, and Workspace sections are tables whose first column is the operation
name exactly as listed here and whose second is the command or rule; further columns are
ignored. An operation the process does not use keeps its row and says "Not used" or "Not
applicable" with where that concern lives instead. The other four sections are prose or a table
that states every rule listed for them. Values the owner fills in are written `<...>`. The Tracker
section carries the ticket body template and the Code host section the change body template.
Keep the file under about 9,500 characters: the hook inlines at most 10,000 characters of output
and replaces a longer file with a pointer to `dev-process show`.

## Tracker

| Operation | Called by | Inputs | The file states |
| --- | --- | --- | --- |
| ID format | every role citing a ticket | ticket | the ID's shape, its permalink, and how code and docs cite it |
| Create ticket | tpm, Phase 3 | title, difficulty, component, priority, body | the command; it yields the new ID; the ticket body template's minimum headings, or their native equivalents: Context, Requirements (testable, binary), Acceptance Criteria (lint passing and coverage on new code at or above the project standard among them), Implementation Plan, Dependencies (a tracker with native dependency links may omit it), Out of Scope |
| Read ticket | implementer and pr-reviewer before work; tpm | ID | the command printing title, body, state, difficulty |
| Set difficulty / priority | tpm, Phase 3 and on tier escalation | ID, `low\|medium\|high`, `p0`-`p2` | where each is stored and the command that changes it |
| Link dependencies | tpm, Phase 3 | ID, blocking and blocked IDs | how "blocked by" and "blocks" are recorded |
| Amend ticket | tpm, before dispatch or after escalation | ID, new body | the command that replaces the body |
| Comment | tpm | ID, text | the command, or "Not used" and where progress lives |
| Link to a change and close | implementer in the change body; tpm after merge | ID, change | the link the change carries, what closes the ticket, how the tpm confirms it closed |
| File a follow-up | tpm, on a gate finding outside the diff | title, body, originating change | the command; the body cites the originating change |

## Code host

| Operation | Called by | Inputs | The file states |
| --- | --- | --- | --- |
| Repo key | tpm, `gate-ledger`, the merge hook | repository | the ledger's repo key and what the change id is |
| Trunk | every role | none | the trunk's name and its protection |
| Protection check | oss-reviewer | repo key | the command reporting visibility and trunk protection, or "Not applicable" |
| Open change | implementer | branch, title, body | the command; what it returns |
| Read change | pr-reviewer, readme-reviewer | change id | the command printing title, body, and linked ticket |
| Head SHA | tpm, every gate | change id | the command |
| Diff | every gate; tpm under Pi | change id, or base and head | the command; three-dot against the base |
| Merge state | tpm before merge, gates | change id | the command, and what a conflict requires |
| CI status | tpm, pr-reviewer | change id, head SHA | the required checks, how to read them at that head, how to wait, what a repo with no CI records |
| Rebase | implementer | branch | when to rebase and how the result is pushed |
| Merge | tpm only | change id | the command, using `merge_method` |
| After merge | tpm | change id | the confirmation and cleanup steps |
| Repo description | readme-reviewer, tpm | text | the command that reads and sets the one-line description, or "Not applicable" |
| Experiment mode | tpm, Phase 1 | none | whether it is allowed and what it skips |

The merge hook refuses `gh pr merge` and a `gh api` call to a PR's merge endpoint unless the ledger
passes at the head and `gh pr checks` reports every check passed or skipped, treating a PR that
reports no checks as passing. It refuses `git merge` into `main` or `master` unless the ledger
passes for the merged branch (`-` is the previous branch); a bare `git merge` there passes only when
the upstream is a remote trunk. On the trunk it allows only a bare `git pull` whose `@{upstream}` is
a remote's `main` or `master`, or `git pull <remote> main|master` (`refs/heads/main` counts as the
trunk), either form with or without `--ff-only`, `--rebase`, `--no-rebase`, or a strategy option
given as a separate word (`-X theirs`), and denies any other pull. It always refuses a command with
more than one `git merge`, `git pull`, or `git push`, a GraphQL `mergePullRequest`, a `git merge`
from a working directory that is not a repository, a merge of two branches, and a `git merge` or
`git pull` in the same command as a `cd`, `pushd`, `git worktree add`, a checkout or switch to
`main`, `master`, `-`, or `@{-N}`, or a `rebase <branch> main`, or redirected with `-C`,
`--git-dir`, `--work-tree`, `GIT_DIR`, `GIT_WORK_TREE`, or `env -C`, or run in a subshell or
`$(...)`. A `git push` in any of those forms passes only when it names its remote and literal
refspecs whose destination is neither the trunk nor `HEAD`/`@`, with a non-empty source and no
delete, `--all`, or `--mirror` (force is allowed); one with no refspec is denied, since the other
directory's branch cannot be read. Push accepts only literal refspecs (a branch or `<src>:<dst>`,
one colon at most), refusing a pattern (`*`) or matching (`:`, `+:`) refspec; it matches long
options from the shortest prefix git accepts (`--prune` counts as a delete). Shell redirections (fd
numbers, `&N`, `&>`, `>&`, `>!`, `{fd}`) are dropped with their targets wherever they sit, including
between `git` and its subcommand, and again when a subcommand's arguments are read, which covers one
inside `$(...)`. It refuses a push of `<src>:main` (`heads/main` and `refs/heads/main` included)
unless `<src>` is main itself, and always refuses `--mirror`, an empty source onto main, a force or
delete of main (a bare `HEAD` or `@` resolved first), a forced `--all`, and a force push without a
refspec from the trunk. Not gated: git reached through shell constructs the matcher does not expand
(quoting, escapes, variables, `eval`, `bash -c`, backticks, aliases, git config, split strings,
argument-supplying commands such as `xargs`, `find -exec`, `parallel`), git or gh named other than
as the bare lowercase word (a path to the binary, a wrapper under another name, a case variant that
a case-insensitive filesystem still runs), and a trunk update with no merge or push (`reset --hard`,
`update-ref`). The hook checks CI for some forms only and passes a PR
with no reported checks or with skipped checks, so the tpm runs the Check ledger and CI status
operations before every Merge, including any form outside those, and the file's Merge row states
that its command runs only after both.

## Workspace

| Operation | Called by | Inputs | The file states |
| --- | --- | --- | --- |
| Branch name | tpm, implementer | type, ticket ID, short description | the pattern |
| Create workspace | implementer; tpm in a cross-repo brief | repository, branch | the command |
| Primary checkout | every role | none | what may and may not happen in it |
| Reviewer probe | every gate | head SHA, gate, change id | how a reviewer reads and runs the head without touching another checkout, and its cleanup |
| Parallelism | tpm, Phase 4 | none | how many slices run at once |
| Remove workspace | tpm after merge | branch | the command, and how stray processes are found |
| Gitignored `.claude` | tpm, cross-repo brief | repository | what to do when the repository ignores `.claude/*`, or "Not applicable" |

## Gates and ledger

| Operation | Called by | Inputs | The file states |
| --- | --- | --- | --- |
| Gate roster | tpm, Phase 5 | none | the gates run on every change, and that every finding blocks |
| Record verdict | tpm as each verdict lands | repo key, change id, gate, verdict, findings, head, model | the `gate-ledger record` invocation |
| Check ledger | tpm before merge; the merge hook | repo key, change id, head | the `gate-ledger check` invocation |
| Show ledger | tpm, final count | repo key, change id | the `gate-ledger show` invocation |

## Commits

| Operation | Called by | Inputs | The file states |
| --- | --- | --- | --- |
| Attribution | every role that commits or writes a change body | none | that no AI-attribution string appears |
| Granularity | implementer | none | how commits are grouped and what the merge does with them |
| Version bump | implementer, final rebase | none | when the bump is made and which policy sets it |

## Forbidden

| Operation | Called by | Inputs | The file states |
| --- | --- | --- | --- |
| Forbidden actions | every role | none | at least: moving a non-trunk ref onto the trunk; force or delete pushes of the trunk; a merge by anyone but the tpm; a reviewer commenting on, closing, or approving a change; editing the ledger, hooks, or CI inside a slice; deleting outside the workspace under work |

## Repository-specific constraints

| Operation | Called by | Inputs | The file states |
| --- | --- | --- | --- |
| Constraints | every role | none | what this repository does differently, or "None" |
