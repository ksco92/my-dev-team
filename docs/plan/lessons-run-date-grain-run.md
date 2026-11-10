---
difficulty: low
priority: p2
status: done
---

## Context

A run that shipped a grain-aware dispatcher in three library PRs and proved it live from a consumer
app returned ten lessons, which land as eight new bullets and one refined bullet. Three of them
govern doc rewords, and `context/tpm/briefing.md`, `gates.md` and `review-probes.md` are at or over
their bullet budget, so the doc rules split out by trigger into `context/tpm/doc-edits.md`, taking
nine existing bullets with them.

## Requirements

- [x] `context/tpm/doc-edits.md` holds the nine doc bullets moved from `briefing.md` (five),
      `gates.md` (one) and `review-probes.md` (three), eight of them word for word.
- [x] The moved doc-reword bullet gains the length-and-owner rule (evidence: a code-economy gate
      failed a prescribed README line twice, once for growing a sentence with a mechanism another
      section stated and once for restating two value forms that a paragraph fourteen lines above
      already held).
- [x] `doc-edits.md` carries the pre-agreement rule (evidence: a candidate line checked only with
      the gates that had failed drew a finding from a gate that had passed; the next candidate,
      agreed by all four prose-reading gates, closed on a diff proof) and the form-and-setting rule
      (evidence: a code-economy gate found the same claim, true for scheduled runs only, in README
      bullets, doc comments and a skill line that the hunks did not touch, and a later gate found a
      rewritten sentence citing a section that did not carry the claim).
- [x] `briefing.md` carries the brief-fact rule (evidence: a gate brief stated that each helper
      script line in a PR body was followed by the commands the script ran; the body showed only the
      scripts' formatted output, and the correctness gate reported the brief's statement false).
- [x] `review-probes.md` carries the `>=` mutant rule (evidence: changing either period filter of a
      job from `==` to `>=` left all 30 tests passing, because the fixture's only other day was
      earlier and created later) and the report-records rule (evidence: an implementer sized a
      24-start fan-out from the deployed function's `platform.report` records, and the correctness
      gate pulled the same window and found the quoted duration range came from a subset; the
      command `aws logs filter-log-events --filter-pattern '"platform.report"'` returns those
      records for a function on the JSON log format).
- [x] `verification.md` carries the body-cap rule (evidence: a `cdk diff` of 32,208 characters and
      start commands of 11,749 used two thirds of the cap before any proof output, the first body
      was built at 101,362 characters, and the ticket was amended to move blocks to author comments)
      and the helper-script rule (evidence: two gates failed a body whose evidence lines ran four
      untracked helper scripts, three of which showed none of the `aws` calls behind their output
      and two of which were rewritten between saved outputs).
- [x] `context/cdk-coding-guide.md` learned patterns carry the `Choice` rule (evidence:
      `aws stepfunctions test-state` on a `Choice` with a bare `StringEquals` and input `{}` returns
      `States.Runtime`, "Invalid path", and returns `Default` once the comparison sits in an `And`
      with `IsPresent`).
- [x] `skills/tpm/SKILL.md` names `doc-edits.md` in the Phase 4 and Phase 5 reading lists and in the
      list of topic files.
- [x] Version bumped one patch step.

## Acceptance Criteria

- [x] `lesson-lint --added` exits 0; prettier check passes.
- [x] `briefing.md` and `review-probes.md` are under 30 bullets.

## Implementation Plan

Whole bullets move; bullet-level edits otherwise.

## Dependencies

- Blocked by: lessons-dq-rollback-run (stacked on it) · Blocks: none

## Out of Scope

Splitting `gates.md` (32 bullets after the move) and the learned patterns of `cdk-coding-guide.md`
(35).
