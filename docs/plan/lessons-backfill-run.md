---
difficulty: medium
priority: p2
status: done
---

## Context

One orchestrated run of a multi-period feature in a library, with its live proof in a consumer app,
left twelve lessons that would hold in another repository and that no file states yet, one of them
waiting in the lesson outbox from an earlier run. They land in one change.

## Requirements

- [ ] Each lesson lands as one bullet (or one clause of an existing bullet) in the file its trigger
      belongs to: Python lessons in `context/python-coding-guide.md`, CDK lessons in
      `context/cdk-coding-guide.md`, AWS service behaviour in
      `context/cdk-services-coding-guide.md`, the rest in the matching `context/tpm/<topic>.md` or
      the phase text of `skills/tpm/SKILL.md`.
- [ ] Each lesson states the rule, not the incident: one sentence, two at most, with no date and no
      repository, pull request, person, account or path name.
- [ ] The change body gives the evidence each lesson came from and names every proposal that was
      dropped, with the reason.
- [ ] No file this change adds to goes over its bullet budget.
- [ ] The plugin version is 0.11.1.

## Acceptance Criteria

- [ ] All requirements verifiable from code/tests
- [ ] Lint passes · coverage on new code ≥ project standard (default 95%)
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')`
      exits 0 and warns about no file this change adds to
- [ ] The prettier Markdown check passes and both manifests validate
- [ ] `skills/tpm/SKILL.md` stays under 350 lines

## Implementation Plan

Grep each target file for the same lesson first and refine an existing bullet where one covers it;
append the rest at bullet level; reformat with prettier; run `lesson-lint`; bump the patch version.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

The three files `lesson-lint` already reports over budget on `main` (`agents/pr-reviewer.md`,
`context/rust-coding-guide.md`, the code-health skill). A split of `context/tpm/review-probes.md`,
which stays at its budget of 30; the one probe lesson that needs it waits in the lesson outbox.
