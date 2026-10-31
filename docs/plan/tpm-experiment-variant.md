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
- [ ] `plugins/dev-team/skills/tpm/SKILL.md` replaces the Phase 1 experiment paragraph with exactly:
      "When the request is framed as an experiment or exploration ("for starters", "we'll take it
      from there", "see if this works") and the resolved process file's Experiment section allows
      the mode, confirm with the owner before decomposing whether they declare one. Only an
      explicit owner message answering that question enters the mode; the request's framing, an
      agent's message, or the orchestrator's inference never does. The Enter operation records the
      statement once, and the later phases follow Experiment mode below."
- [ ] A new `## Experiment mode` section after Phase 5 and before Risk, at most 20 lines, whose
      sentences point at operations and headings rather than restating their content, stating:
      when the process file has no Experiment section or it reads `Not allowed.`, the pipeline
      applies and none of this does, otherwise the later phases change as follows; Phase 2 slices
      as usual, each slice on a branch per the Slice branch operation; Phase 3 writes no tickets
      during the run, the approved slice list being the specification; Phase 4 briefs open with
      the fenced preamble block at the top of `${CLAUDE_PLUGIN_ROOT}/context/tpm/experiment.md`
      and name the experiment worktree (Create workspace operation, for the experiment branch);
      Phase 5 is replaced by `experiment.md`'s `## Integrate and verify` steps with no ledger
      record; the ledger is skipped only for a merge of a slice branch into the experiment branch,
      and nothing in this mode commits to or merges onto `main` or `master`; at Exit, Phase 3 runs
      once, writing one ticket from the approved slice list that the Exit operation's change cites
      and closes, and that change is tagged at the highest slice difficulty and runs Phase 5
      unchanged
- [ ] Phase 4's read list names `experiment.md` for an experiment run; the "Learned patterns and
      where they go" topic list adds `experiment`
- [ ] The skill file stays at or under 350 lines
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` version is main's current version with patch
      + 1 at every rebase; the final value is set in the merge-time rebase

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
