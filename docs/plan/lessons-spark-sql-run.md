---
difficulty: low
priority: p2
status: done
---

## Context

A run whose gates probed a locally launched JVM server produced probe rules for servers, child
processes and class paths. `context/tpm/review-probes.md` is at its bullet budget, so the server
rules split out by trigger into `context/tpm/server-probes.md`, taking the three existing server
bullets with them; two unrelated probe rules join `review-probes.md`; two tooling facts fold into
the bullets whose subject they share.

## Requirements

- [x] `context/tpm/server-probes.md` holds the three server bullets moved from `review-probes.md`
      and the three new server rules (environment overrides of a bind, a session setting presented
      as a control, a plugin class path proven by a client session).
- [x] `review-probes.md` gains the hostname-partition rule and the distinct-stub rule and stays at
      or under 30 bullets.
- [x] The `verification.md` mutation bullet carries the stale-bytecode rule; the `operations.md`
      in-place-edit bullet carries the multi-file `perl` rule.
- [x] `skills/tpm/SKILL.md` names `server-probes.md` where it lists the files read before the first
      gate and in the learned-patterns topic list.
- [x] Version bumped one patch step.

## Acceptance Criteria

- [x] `lesson-lint --added origin/main` exits 0; prettier check and both plugin validations pass.

## Implementation Plan

Bullet-level edits only; moved bullets keep their text.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Splitting `gates.md`.
