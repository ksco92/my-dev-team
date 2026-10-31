---
difficulty: low
priority: p1
status: done
---

## Context
Every implementer brief in an experiment run carried hand-written text about what to skip, and the
implementer agents read a baseline whose Testing section contradicts it. This ticket gives the
preamble one home the `tpm` skill pastes from, and tells the agent files that the mode exists.

## Requirements
- [ ] New file `plugins/dev-team/context/tpm/experiment.md`, titled `# tpm experiment mode`, with:
      one lead paragraph (the mode is entered only by the owner's statement, recorded in the Enter
      operation of the resolved process file; the brief for every slice opens with the block below);
      a fenced block holding the preamble; and a second heading `## Integrate and verify` with the
      orchestrator's steps as prose sentences, not bullets. The preamble block reads exactly:

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

      The Integrate and verify prose states: change directory to the experiment worktree as its own
      command, then `git merge exp/<slice>` as the next command (never a cherry-pick: the hook refuses a
      merge run on the trunk and does not gate a cherry-pick); rerun
      the `run_*.sh` entry point and record the output in `results/RESULTS.md`; push
      `experiment/<topic>`; no ledger record is written; the exit path is one change from the
      experiment branch to the trunk through every gate.
- [ ] `plugins/dev-team/agents/implementer.md`, `backend.md`, and `frontend.md` each gain one
      sentence immediately after their "Read agent-baseline.md now" paragraph: "In experiment mode,
      which the brief declares with the preamble from `${CLAUDE_PLUGIN_ROOT}/context/tpm/experiment.md`,
      the baseline's Testing section and the coding guides' test, coverage, and lint rules do not
      apply; the comment budget does."
- [ ] `plugins/dev-team/context/agent-baseline.md` Testing section opens with one sentence: "In
      experiment mode, declared by the brief, this section does not apply and the comment budget
      still does."
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` version bumps patch

## Acceptance Criteria
- [ ] All requirements verifiable from the diff
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main plugins/dev-team/context/tpm/experiment.md
      plugins/dev-team/context/agent-baseline.md plugins/dev-team/agents/implementer.md
      plugins/dev-team/agents/backend.md plugins/dev-team/agents/frontend.md` exits 0 with no budget
      warning
- [ ] `bash plugins/dev-team/tests/lesson-lint.test.sh` passes
- [ ] `claude plugin validate plugins/dev-team --strict` passes
- [ ] `grep -c 'experiment.md' plugins/dev-team/agents/implementer.md plugins/dev-team/agents/backend.md
      plugins/dev-team/agents/frontend.md` prints 1 for each file
- [ ] No sentence in any edited file names a private repository, a date, or a PR

## Implementation Plan
Create the file with a heredoc, add the four sentences with the Edit tool, run the four checks,
bump the version, open the change.

## Dependencies
- Blocked by: experiment-process-section · Blocks: tpm-experiment-variant

## Out of Scope
Any change to `plugins/dev-team/context/tpm/briefing.md` (over budget; split pending) or to the
`tpm` skill (tpm-experiment-variant).
