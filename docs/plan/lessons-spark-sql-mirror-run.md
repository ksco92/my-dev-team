---
difficulty: low
priority: p2
status: done
---

## Context

A run that mirrored a Spark catalog into a Thrift server's session catalog cost three review rounds
on six rules that hold in any repo. Each lands as a bullet in the context file whose trigger it
matches; two refine an existing bullet's neighbourhood instead of standing alone.

## Requirements

- [x] `context/tpm/review-probes.md` carries the foreign-runtime exception-type rule (evidence: a
      Spark namespace refusal raised a raw Py4J error, not the converted type the handler caught,
      while every test fake subclassed the converted type) and the dedupe-key collision rule, folded
      into the existing collision-probe bullet (evidence: a catalog-level failure keyed by the
      catalog name collided with a database of that name, so a second failure was never logged); the
      file stays at 30 bullets.
- [x] `context/tpm/server-probes.md` carries the child-process output-stream rule (evidence: the
      real binary's stdout file held the failure line a unit test's captured stderr showed on
      stderr).
- [x] `context/python-coding-guide.md` learned patterns carry the mutation-run bytecode rule
      (evidence: a first mutation pass reported false survivors until re-run with a clean cache).
- [x] `context/tpm/verification.md` carries the live-failure-fixture rule (evidence: a list call
      returned an empty list while the get call failed on the same object, so the ticket's criterion
      had to be amended).
- [x] `skills/code-health/SKILL.md` Part C carries the mutation-tested-is-not-provenance rule
      (evidence: a finding on keep-on-failure branches, resolved by naming real production inputs).
- [x] Version bumped one patch step.

## Acceptance Criteria

- [x] `lesson-lint --added` exits 0; prettier check passes.

## Implementation Plan

Bullet-level edits only.

## Dependencies

- Blocked by: the server-probes lesson PR (stacked on it) · Blocks: none

## Out of Scope

Splitting `review-probes.md`.
