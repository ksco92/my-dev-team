---
model: sonnet
max_turns: 40
timeout_seconds: 900
allowed_tools: [Skill, Read, Glob, Grep, Bash]
---

`plugin-repo` is a checkout of a small plugin repository laid out like the dev-team plugin; its
lesson lists are under `plugin-repo/plugins/dev-team/`. Run the `dev-team:lessons` skill on it as a
report-only run: treat `plugin-repo` as the plugin repository's workspace, change nothing in it (a
violation you need to show goes in a scratch copy under `mktemp -d`), and stop after the report. For
this run the lesson outbox is empty, the session returned no proposals, and every bullet in the tree
landed with its evidence on record. Read nothing outside this workspace and the plugin's own files.

Reply with the report: the inventory, the decision table (rule, decision, destination, evidence),
and the count per decision.
