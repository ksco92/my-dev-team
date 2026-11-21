# tpm release rules

Binding rules for a repository that batches its releases and for a slice that is a release. Read
with `briefing.md` before the first brief of such a run.

- A repository batches only when its process file's Version bump rule or its own rules say so on the
  trunk when the change opens; a change that adds, removes or alters that statement is a
  release-policy change and follows the rule on its base.
- An ordinary change in a batching repository never edits the version or any line a release edits;
  it adds one line under the changelog's unreleased heading, tagged with its level by the semver
  policy.
- Make a release only on the owner's word in the session. When a fix falls in a class the
  repository's rules call urgent, tell the owner at once and wait.
- A release is a change of its own, gated like any other. It edits only the lines the previous
  release changed for the version alone, and its brief tells every gate that any other line is a
  finding.
- The version is the current one raised by the largest level among the unreleased lines at the
  release change's head, under the major-zero rule; merge no other change from the release change's
  opening until its tag is pushed.
- Before a release that bumps the minor, run the `audit` skill on the repository with
  `--lenses=claims,cold-read` and put its decision list to the owner, who answers it before the
  release change opens.
- After the release change merges, record its merge commit. Where the merge publishes, confirm on
  the registry that the version exists and, where the registry records a source commit, that it
  names that commit, before tagging; where the tag publishes, tag first and confirm after.
- When a confirmation fails, stop the release step and tell the owner.
- The orchestrator tags exactly that commit `v<version>`, pushes the tag, and creates the host's
  release for that existing tag from the version's changelog section where no workflow does, with
  the commands the repository's rules give; where they give none, ask the owner and wait for the
  answer before tagging.
- A pushed release tag is never moved or deleted, and no tag push uses force; report a tag on the
  wrong commit to the owner and correct it with a new patch release.
- After the host's release, move any consumer fixture the repository pins to its published version
  in a follow-up change.
- Patch an old version from a branch cut at its tag, never from the trunk. This process covers the
  trunk only, so put the plan to the owner and start no such work until the owner agrees it: the
  branch, the base that replaces the trunk in every brief and gate diff, how the fix reaches the
  trunk, and how it is published.
- An old line is never published as the registry's latest: it is published under its own
  distribution tag, and its host release carries no latest marker.
