---
difficulty: low
priority: p2
status: done
---

## Context

An implementer's project memory in one CDK library was read note by note when its owner chose to
git-ignore the directory. Most of its stack lessons were already in the CDK guide. Four were not;
each is checked here against the library's code or README at its trunk.

## Requirements

- [x] The Glue job asset bullet of `context/cdk-coding-guide.md` names the ignore mode the exclude
      list needs (evidence: the library's asset call passes `exclude: ['*', '!*/', '!*.py', ...]`
      with `ignoreMode: IgnoreMode.GIT`, and the note records that the same list staged nothing in
      the default glob mode on a test deploy).
- [x] `context/cdk-coding-guide.md` carries the `Cause` shape of a failed `glue:startJobRun.sync`
      task (evidence: a probe on a deployed state machine returned the flat `GetJobRun` `JobRun`
      object under `States.TaskFailed` where the ticket had assumed a `JobRun` wrapper key, and a
      missing job returned `Glue.EntityNotFoundException` with a plain-text `Cause`; the library's
      failure function reads a top-level `JobRunState` and publishes any other `Cause` raw, each
      with a test).
- [x] `context/cdk-coding-guide.md` carries the raw object key of an EventBridge S3 event (evidence:
      a deployed rule delivered `run_date=<day>T02:00:00Z` with literal colons; the library's
      dispatcher matches the key against its pattern with no unquoting, and its tests send keys in
      that form).
- [x] `context/cdk-coding-guide.md` carries the size rule for a statement that grows per resource
      (evidence: a synthesized stack of one database with 20-character table names, whose Data
      Quality statement lists one ruleset ARN per table at 91 characters each, measured 6,074
      characters at 64 tables and passed the 6,144-character managed-policy cap at 65; the library's
      README states the count).

## Acceptance Criteria

- [x] `plugins/dev-team/bin/lesson-lint --added origin/docs/lessons-followup-sweep-run     plugins/dev-team/context/cdk-coding-guide.md`
      exits 0
- [x] The five test scripts at the repository root pass
- [x] Plugin version 0.10.8

## Out of Scope

Splitting the guide's `## Learned patterns` section, which was past its bullet budget before this
change.
