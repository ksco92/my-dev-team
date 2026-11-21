# tpm release rules

Binding rules for a repository whose own rules batch releases and for a slice that is a release.
Read with `briefing.md` before the first brief of such a run; a repository that bumps per change
never reads it.

- A repository batches only when its own rules or its process file's Version bump rule say so;
  without that statement every change bumps, as `gates.md` says.
- A change in a batching repository never edits the version, the lockfile's version or any other
  file the last release's commit moved for the version alone. It adds one line under the changelog's
  unreleased heading, tagged with its level by the semver policy.
- Make a release only when the owner asks, or at once for a fix the repository's rules name as
  urgent, never because lines are pending.
- A release is a change of its own, opened, gated and merged like any other. It edits the version,
  the changelog heading and whatever the previous release's commit shows (`git show <sha> --stat`),
  and nothing else.
- The version is the current one raised by the largest level among the unreleased lines, under the
  major-zero rule.
- Before a release that bumps the minor, run the `audit` skill on the repository with
  `--lenses=claims,cold-read`, and put its decision list to the owner, who answers it before the
  release change opens.
- Create the tag and the host's release only after the publish is confirmed on the registry: tag the
  released commit `v<version>`, then create the release from that changelog section, with the
  commands the process file gives.
- Pushing the tag is the release step's only write to the remote outside the gated merge.
- After the tag and the host release, run the consumer pin follow-up where the repository has one.
- A release is a tagged commit and the trunk is always the next version, so an old version is
  patched from a branch cut at its tag, never from the trunk.
- A publishing workflow that publishes whatever version it is given as the registry's latest is
  never run from a patch branch; the fix is published under its own distribution tag.
