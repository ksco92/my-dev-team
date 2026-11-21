---
difficulty: medium
priority: p2
status: done
---

## Context

Under a bump-per-change policy every merged change publishes a version, and parallel changes rebase
onto each other's version line. A published library run under that policy put twenty versions on its
registry in two days. The owner decided that a repository may batch: changes carry a changelog line,
and a release change made on the owner's word sets the version.

## Requirements

- [x] `plugins/dev-team/context/tpm/releases.md`, a tpm reference in the form of the others (binding
      bullets, one or two sentences each), read when the repository's rules batch releases or a
      slice is a release. It states:
  - a change in a batching repository never edits the version; it adds one line under the
    changelog's unreleased heading, tagged with its level by the semver policy;
  - a release is made when the owner asks, or at once for a fix the repository's rules name as
    urgent; the release change edits the version, the changelog heading and whatever the previous
    release's commit shows (`git show <sha> --stat`), and nothing else;
  - the version is set by the largest pending level, under the major-zero rule;
  - after the publish is confirmed on the registry, the released commit is tagged `v<version>` and
    the host's release is created from that changelog section, then the consumer pin follow-up runs
    where the repository has one;
  - before a release that bumps the minor, the `audit` skill's claims and cold-read lenses run on
    the repository, and their decision list goes to the owner before the release change opens;
  - an old version is patched from a branch cut at its tag, never from the trunk.
- [x] `skills/tpm/SKILL.md` names the new file in its list of conditional references, and the file
      stays under its limit of about 350 lines.
- [x] Every statement in the plugin that a change takes its version in the final rebase is
      conditioned on a bump-per-change policy and points at `releases.md` for the other case:
      `grep -rniE "version bump|final rebase|bump-per|pre-assign versions" plugins/dev-team` lists
      them (the gates reference, the tpm skill's Git conventions, the contract's Version bump row,
      the default process file, the template, and any gate skill or agent that fails a change for a
      missing bump).
- [x] The contract's Version bump row says the file states whether the repository bumps per change
      or per release; `tests/dev-process.test.sh` still passes, with a case added if the row's text
      is tested.
- [x] `context/tpm/releases.md` passes `lesson-lint`.

## Acceptance Criteria

- [x] All requirements verifiable from the files and the test scripts
- [x] Every local check in `CLAUDE.md` passes
- [x] No file under `plugins/dev-team` still tells a gate to fail a change for a missing version
      bump without the condition
- [x] `context/policy.md` is unchanged

## Implementation Plan

Write `context/tpm/releases.md` from the bullets above, each as a rule. Run the grep in the third
requirement and edit each hit at clause level: add the condition, keep the sentence. Add the file to
the conditional-reference list in `skills/tpm/SKILL.md`. The docs examples under `docs/examples/`
are process files too; give each the same condition in its Version bump rule. This repository itself
keeps bump-per-change. The version takes a minor bump in the final rebase.

## Dependencies

- Blocked by: audit-skill-and-cold-reader (names its lenses), lesson-distribution-skill (edits the
  same skill file) · Blocks: none

## Out of Scope

A release command or script; any change to the merge hook or the ledger; changing this repository's
own versioning; the semver policy in `context/policy.md`.
