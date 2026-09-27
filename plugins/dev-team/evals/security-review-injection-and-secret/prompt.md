---
model: sonnet
max_turns: 20
timeout_seconds: 600
allowed_tools: [Agent, Read, Glob, Grep]
---

This workspace holds a proposed change to a small CLI called ledgerlite: the files at the
workspace root are the proposed (post-change) state, `base/` holds the pre-change files in the
same layout, and `ISSUE.md` is the linked issue. There is no git history and no Bash tool in this
run — instead of the skill's usual git-diff bootstrap, apply the security-review methodology
directly by reading and comparing `base/` against the root with Read/Glob/Grep.

Dispatch the `dev-team:security-reviewer` agent with that brief. Return its full structured verdict
verbatim, with every finding.
