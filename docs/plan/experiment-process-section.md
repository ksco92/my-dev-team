---
difficulty: medium
priority: p1
status: done
---

## Context
Experiment mode exists today as one Code-host row in every process file and a Phase 1 hint in the
`tpm` skill; nothing downstream states how the mode is entered, how slice branches are integrated,
what is skipped, where results live, or how the work re-enters the gated pipeline. A benchmark run
in a private repository under the mode improvised all of that. This ticket makes Experiment a
section of the `DEV_PROCESS.md` contract so every process file states it.

## Requirements
- [ ] `plugins/dev-team/context/dev-process-contract.md` gains a `## Experiment` section between
      Code host and Workspace, in the same four-column table shape, with these operations:
      `Enter` (tpm, Phase 1: the owner's statement enters the mode, recorded once in the session,
      or "Not allowed"), `Branch name` (`experiment/<topic>`), `Slice branch` (`exp/<slice>`, cut
      from the experiment branch), `Integrate` (the merge or cherry-pick of a slice branch into the
      experiment branch, run with the experiment worktree as the session's working directory: the
      directory change is its own command and the merge the next, since the hook refuses a merge
      combined with `cd`), `Skipped` (tickets, change requests, the five gates, tests, lint, CI, the
      version bump), `Required` (live verification with its evidence, small commits, no
      attribution lines, a push of the experiment branch), `Results` (raw data under
      `results/<machine-slug>/raw/`, logs gitignored, the report at `results/RESULTS.md`, a
      `run_*.sh` entry point that reruns on another machine without code changes), `Exit` (one
      change from the experiment branch to the trunk, tagged at the highest slice difficulty, through
      every gate)
- [ ] The contract states that a process file whose Experiment section is absent or reads
      "Not allowed" turns the mode off, and its Format paragraph counts eight sections
- [ ] The `Experiment mode` row leaves the Code host table of the contract, the template, the
      default, this repository's `DEV_PROCESS.md`, and both examples
- [ ] The section is filled in `plugins/dev-team/context/dev-process.default.md`,
      `plugins/dev-team/templates/DEV_PROCESS.md` (blank cells with hints), this repository's
      `DEV_PROCESS.md`, `docs/examples/DEV_PROCESS.github.md`, and `docs/examples/DEV_PROCESS.asana.md`;
      every one of those files stays under 9,500 characters (the asana example is at 9,482 today, so
      it either takes the "Not allowed" form or loses an equal number of characters elsewhere)
- [ ] `plugins/dev-team/tests/dev-process.test.sh` checks the Experiment operations in every file
      that fills the table, the same way it checks Tracker, Code, and Workspace
- [ ] The root `README.md` documents the mode in one paragraph under its `DEV_PROCESS.md` section;
      the plugin README keeps pointing at the root README
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` version is `0.9.0` (a feature on major zero)

## Acceptance Criteria
- [ ] All requirements verifiable from the diff
- [ ] `bash plugins/dev-team/tests/dev-process.test.sh` passes, including the new Experiment checks
- [ ] `plugins/dev-team/bin/dev-process show Experiment --repo <dir>` prints the section for each
      filled file
- [ ] Every process file is under 9,500 characters, measured with `LC_ALL=C.UTF-8 wc -m`
- [ ] `claude plugin validate plugins/dev-team --strict` and `shellcheck` on the test pass
- [ ] No sentence in any edited file names a private repository, a date, or a PR

## Implementation Plan
Write the contract section first and derive each file's rows from it. Keep every rule to one
sentence; the character cap binds. Extend the test's section loop, then measure every file.

## Dependencies
- Blocked by: none · Blocks: experiment-brief-preamble, tpm-experiment-variant

## Out of Scope
The hook change for `-C` merges (merge-gate-redirected-merge); the brief preamble and agent-file
sentences (experiment-brief-preamble); the `tpm` skill text (tpm-experiment-variant).
