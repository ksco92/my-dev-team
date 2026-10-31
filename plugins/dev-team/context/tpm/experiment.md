# tpm experiment mode

The mode is entered only by the owner's statement, recorded in the Enter operation of the resolved
process file. The brief for every slice opens with the block below.

```
Experiment mode, declared by the owner. This slice is an experiment: no tests, no lint, no CI,
no ticket, no change request. Verify the work live and report each command with its output as
the evidence. Commit small on exp/<slice>, cut from experiment/<topic>, and push that branch;
never merge, never rebase onto the trunk, never push another branch. The stack coding guides
apply for style only; their test, coverage, and lint sections do not. The comment budget holds:
doc comments sized to the item, no single-use one-statement helpers, comment lines well under
code lines in every touched file. Raw results go under results/<machine-slug>/raw/, logs are
gitignored, the report is results/RESULTS.md, and a run_*.sh entry point reruns the experiment
on another machine without code changes.
```

## Integrate and verify

Change directory to the experiment worktree as its own command, then run `git merge exp/<slice>` as the next command. Never cherry-pick: the hook refuses a merge run on the trunk and does not gate a cherry-pick. Rerun the `run_*.sh` entry point and record the output in `results/RESULTS.md`, then push by name with `git push origin experiment/<topic>`. No ledger record is written. The exit path is one change from the experiment branch to the trunk through every gate.
