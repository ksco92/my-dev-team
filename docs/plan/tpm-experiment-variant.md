---
difficulty: medium
priority: p1
status: done
---

## Context
The `tpm` skill tells the orchestrator to confirm in Phase 1 whether the pipeline applies to an
experiment, then says nothing about how the later phases change. This ticket adds the variant,
pointing at the process file's Experiment section and the preamble file so the skill stays short.

## Requirements
- [ ] `plugins/dev-team/skills/tpm/SKILL.md` replaces the Phase 1 experiment paragraph with one
      that records the owner's statement once (the Enter operation) and points at a new
      `## Experiment mode` section placed after Phase 5 and before Risk
- [ ] That section, at most 20 lines, states per phase: Phase 1 records the choice; Phase 2 slices
      as usual, each slice getting an `exp/<slice>` branch from `experiment/<topic>`; Phase 3 writes
      no tickets (the approved slice list is the specification); Phase 4 briefs open with the
      preamble from `${CLAUDE_PLUGIN_ROOT}/context/tpm/experiment.md` and name the experiment
      worktree; Phase 5 is replaced by that file's Integrate and verify steps with no ledger record;
      the exit path is one change from the experiment branch to the trunk at the highest slice
      difficulty through all five gates; a process file whose Experiment section is absent or
      reads "Not allowed" means the pipeline applies
- [ ] Phase 4's read list names `experiment.md` for an experiment run; the "Learned patterns and
      where they go" topic list adds `experiment`
- [ ] The skill file stays at or under 350 lines
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` version bumps patch

## Acceptance Criteria
- [ ] All requirements verifiable from the diff
- [ ] `wc -l plugins/dev-team/skills/tpm/SKILL.md` is at most 350
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main plugins/dev-team/skills/tpm/SKILL.md`
      exits 0
- [ ] `claude plugin validate plugins/dev-team --strict` passes
- [ ] The orchestrator's dry run on an experiment-phrased request, recorded in the change body,
      produces a brief opening with the preamble and no ticket or change-request step
- [ ] No sentence in any edited file names a private repository, a date, or a PR

## Implementation Plan
Write the section from the process contract's Experiment rows and the preamble file's headings;
every sentence points rather than repeats. Trim the Phase 1 paragraph to make room.

## Dependencies
- Blocked by: experiment-process-section, experiment-brief-preamble · Blocks: none

## Out of Scope
A paid eval case for the variant; any change to gate behaviour on the exit-path change.
