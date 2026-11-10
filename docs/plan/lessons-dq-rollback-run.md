---
difficulty: low
priority: p2
status: done
---

## Context

A run that proved a rollback live and recorded the proof in a PR body cost three description rounds
on rules that hold in any repo, and two tooling facts surfaced beside it. Each lands as a bullet in
the context file whose trigger it matches.

## Requirements

- [x] `context/tpm/verification.md` carries the closed-list evidence rule (evidence: a correctness
      gate failed a body under "every command and its output" for an abridged diff and unshown
      commands, then failed the closed list's plural item for a third listing command present in the
      saved log and absent from the body), the scripted-body rule (evidence: the same gate compared
      a command line with a label the log had echoed in its place; the rebuilt body closed on a diff
      against its file), the prose-numbers rule (evidence: an interval of 66 s that the shown start
      and stop times give as 68 s, and a latency range the run's own stream exceeded, both in
      sentences no criterion asked for) and the expected-values rule (evidence: a ticket's log order
      and a row-count baseline were amended after the run, the first against the code path and the
      second after a repeated step left its rows).
- [x] `context/tpm/operations.md` carries the lone-merge rule (evidence: a merge followed by
      `; echo` was refused with `gh pr view <n> failed for <owner>/<repo>;` and passed alone).
- [x] `context/python-coding-guide.md` learned patterns carry the shared-`time` patch rule
      (evidence: a test that patched `<module>.time.sleep` failed once in CI when another thread
      slept, and passed after patching the module's `time` name).
- [x] Version bumped one patch step.

## Acceptance Criteria

- [x] `lesson-lint --added` exits 0; prettier check passes.

## Implementation Plan

Bullet-level edits only.

## Dependencies

- Blocked by: lessons-spark-sql-mirror-run (stacked on it) · Blocks: none

## Out of Scope

Splitting `briefing.md` or `gates.md`; the merge gate's parsing of a command separator.
