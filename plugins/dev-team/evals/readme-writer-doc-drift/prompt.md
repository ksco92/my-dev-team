---
model: sonnet
max_turns: 20
timeout_seconds: 600
allowed_tools: [Agent, Read, Glob, Grep]
---

This workspace holds a proposed change to a small CLI called ledgerlite: the files at the
workspace root are the proposed (post-change) state, `base/` holds the pre-change files in the
same layout, and `ISSUE.md` is the linked issue. There is no git history here — compare `base/`
against the root directly with Read/Glob/Grep instead of a diff command.

Dispatch the `dev-team:readme-reviewer` agent in REVIEW mode with that brief. Scope: `README.md`
plus every change that touches behavior it describes. Return its full structured verdict verbatim,
with every finding.
