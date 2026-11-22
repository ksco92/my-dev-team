---
difficulty: medium
priority: p1
status: done
---

## Context

Two orchestrator references are over the budget `lesson-lint` enforces:
`context/tpm/review-probes.md` (33 of 30) and `context/tpm/briefing.md` (31 of 30). The owner chose
the split by trigger the last lesson run proposed. A split changes where a rule lives and never who
reads it or when: each new file is read at every moment its source file is read.

## Requirements

- [x] New `plugins/dev-team/context/tpm/mutation-probes.md`, opening "# tpm mutation-probe rules"
      and the lead-in "Binding rules for the mutants a gate runs and the fixtures that must kill
      them. Read with `review-probes.md` before the first gate of a run." It holds these twelve
      bullets of `review-probes.md`, words unchanged, in their present order, and `review-probes.md`
      loses them:
  - "A symmetric check written as two one-directional clauses …"
  - "A sanitizer that strips a delimiter with one substitution pass …"
  - "Mutating a regex guard, change only the `RegExp` line …"
  - "When a fix replaces per-field reject tests with one fixture …"
  - "Mutate a widened range matcher to its single canonical member …"
  - "Mutate a result cache behind a worker pool …"
  - "A stub for a function whose return value …"
  - "When code filters one period with `==` …"
  - "A test that sends generated neighbours of a valid value …"
  - "When a PR wraps an existing per-run sequence in a loop …"
  - "When a compound condition adds an item to one bucket …"
  - "When a PR deletes tests, the correctness gate runs targeted mutants …"
- [x] `review-probes.md`: the second sentence of its lead-in becomes "Read with `gates.md` and
      `mutation-probes.md` before the first gate of a run." Nothing else in the file changes.
- [x] New `plugins/dev-team/context/tpm/fix-briefs.md`, opening "# tpm fix-brief rules" and the
      lead-in "Binding rules for fix briefs and fix rounds. Read with `briefing.md` before the first
      brief of a run (Phase 4) and again before each fix brief (5.2)." It holds these nine bullets
      of `briefing.md`, words unchanged, in their present order, and `briefing.md` loses them:
  - "A fix commit is new review surface …"
  - "A fix brief for a security finding prescribes the property …"
  - "When a fix brief asks for a test that kills a surviving mutant …"
  - "When a rule enumerates unguarded paths or the sources of a property …"
  - "When a fix adds an exception subclass of a builtin …"
  - "When a fix centralises a predicate into a helper …"
  - "When a sibling PR that closes a path merges mid-review …"
  - "When a fix brief lets the implementer choose between two forms …"
  - "When a fix brief prescribes a test's shape …"
- [x] `briefing.md`: the second sentence of its lead-in becomes "Read with `fix-briefs.md` before
      the first brief of a run (Phase 4) and again before each fix brief (5.2)." Nothing else in the
      file changes. "Fix-loop validation scales to the delta …" stays in `briefing.md`: its last
      sentence binds every implementer brief.
- [x] `skills/tpm/SKILL.md`, Phase 4, first sentence becomes: "Before the first brief of a run, read
      `${CLAUDE_PLUGIN_ROOT}/context/tpm/briefing.md`,
      `${CLAUDE_PLUGIN_ROOT}/context/tpm/fix-briefs.md` and
      `${CLAUDE_PLUGIN_ROOT}/context/tpm/operations.md`; all three are binding on every brief."
- [x] `skills/tpm/SKILL.md`, Phase 5, first sentence: "and
      `${CLAUDE_PLUGIN_ROOT}/context/tpm/review-probes.md` before the first gate of a run" becomes
      "`${CLAUDE_PLUGIN_ROOT}/context/tpm/review-probes.md` and
      `${CLAUDE_PLUGIN_ROOT}/context/tpm/mutation-probes.md` before the first gate of a run" (the
      "and" before `review-probes.md` becomes a comma after `findings.md`), and "re-read
      `${CLAUDE_PLUGIN_ROOT}/context/tpm/briefing.md` and `findings.md` before each fix brief"
      becomes "re-read `${CLAUDE_PLUGIN_ROOT}/context/tpm/briefing.md`, `fix-briefs.md` and
      `findings.md` before each fix brief". The file stays under about 350 lines.
- [x] Every other place that names `review-probes.md` or `briefing.md` as something to read
      (`git grep -n 'review-probes\|briefing\.md' -- . ':!docs/plan'`) is still true: a file read
      "with `briefing.md`" or "with `review-probes.md`" needs no edit, because the skill's two
      sentences above read the new file at the same moments. Say so per hit in the change body.
- [x] Counts after the edits, by the counting command in `skills/lessons/SKILL.md` section 1:
      `review-probes.md` 21, `mutation-probes.md` 12, `briefing.md` 22, `fix-briefs.md` 9.
- [x] The ticket `split-briefing-by-trigger` is committed with `status: done`.

## Acceptance Criteria

- [x] All requirements verifiable from the diff and the counting command
- [x] The sorted bullets of the two source files at the base equal the sorted bullets of the four
      files at the head (no bullet reworded, dropped or duplicated)
- [x] Every local check in `CLAUDE.md` passes; `lesson-lint --added origin/main` prints no budget
      warning and no fault
- [x] No eval run is needed; the change moves lesson text

## Implementation Plan

Lint both source files whole first (`plugins/dev-team/bin/lesson-lint <file>`); none of the
twenty-one bullets that move carries a fault. Move the bullets so the diff shows each one removed
once and added once. Change the two lead-in sentences and the two skill sentences exactly as given.
The version takes a patch bump in the final rebase.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Rewording, merging or dropping any bullet; any other lesson list; the candidates in the lesson
outbox.
