---
difficulty: high
priority: p1
status: done
---

## Context
`hooks/merge-gate.sh` refuses every `git merge` redirected with `-C`, grouped with the forms whose
target branch cannot be read before the command runs (`cd`, `GIT_DIR`, `env -C`, `worktree add`).
For `git -C <dir> merge`, `<dir>` is a literal directory whose HEAD the hook can read, so the merge
can be gated exactly as if `<dir>` were the working directory. An integration merge into a
non-trunk experiment branch through `-C` was refused during an experiment run, and the orchestrator
fell back to `reset --hard` and `cherry-pick`.

## Requirements
- [ ] `git -C <dir> merge [options] <branch>`, with any `-c k=v` or `--no-pager` style options
      before the subcommand and `<dir>` quoted or bare, is gated as if the hook's `cwd` were
      `<dir>`: HEAD of `<dir>` not the trunk → allowed; HEAD the trunk → the ledger check that a
      plain `git merge` on the trunk gets today; `<dir>` not an existing repository (including a
      value the matcher cannot expand, such as a variable or substitution) → denied
- [ ] Every other combined form stays denied for merge and pull: `cd`, `pushd`, `git worktree add`,
      a checkout or switch to the trunk, `-`, or `@{-N}`, a rebase onto the trunk, `--git-dir`,
      `--work-tree`, `GIT_DIR`, `GIT_WORK_TREE`, `env -C`, a subshell or `$(...)`, and a `-C` merge
      that also carries one of those forms in the same command
- [ ] `git -C <dir> pull` is unchanged (still denied as a combined form)
- [ ] Every push rule is unchanged: a `-C` push of `<src>:main`, `HEAD:main`, a force or delete of
      main, or one with no refspec is still denied
- [ ] The hook's header comment and the merge-hook paragraph of
      `plugins/dev-team/context/dev-process-contract.md` state the new per-form behaviour exactly,
      per `.claude/rules/merge-gate.md`; the combined-form denial message no longer lists `-C` for a
      merge but still does for a pull
- [ ] `plugins/dev-team/tests/merge-gate.test.sh` adds: `-C` merge into a non-trunk branch allowed
      (from a cwd that is a different repository and from one that is no repository); `-C` merge
      into main without a ledger denied with the ledger message; `-C` merge into main with five PASS
      records allowed; `-C` merge whose directory does not exist denied; `-C $DIR` merge denied;
      `cd <dir> && git merge` still denied; `git -C <dir> pull . <branch>` still denied; `-C` push
      onto main still denied
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` version bumps patch

## Acceptance Criteria
- [ ] All requirements verifiable from the diff
- [ ] `bash plugins/dev-team/tests/merge-gate.test.sh` passes with the new cases and every
      existing one
- [ ] `shellcheck plugins/dev-team/hooks/*.sh plugins/dev-team/tests/*.sh` passes
- [ ] Mutation check recorded in the change body: with the new `-C` resolution reverted, the new
      allowed-case tests fail; with the trunk check removed from the `-C` path, the denied-case
      tests fail
- [ ] The trunk-protection property is stated in the change body as a closed list: every form that
      lands a ref on `main` or `master` is listed with the check that gates it, and no form in the
      list is gated by less than before
- [ ] No sentence in any edited file names a private repository, a date, or a PR

## Implementation Plan
Resolve the `-C` value from the merge segment's words before `combined` runs; when it is a literal
existing repository, substitute it for `cwd` for the rest of the merge path and drop the `-C`
clause from the combined test for merge only. Fail closed on anything else. Restate the contract
paragraph and the header from the final code, not from the plan.

## Dependencies
- Blocked by: none · Blocks: none

## Out of Scope
Allowing `-C` for pull or any push form; gating `cherry-pick` (it is not gated today and stays
ungated); the process-file Experiment section (experiment-process-section).
