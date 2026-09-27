---
model: sonnet
max_turns: 40
timeout_seconds: 900
allowed_tools: [Agent, Read, Write, Edit, Glob, Grep, Bash]
---

Dispatch the `dev-team:implementer` agent with this brief: implement the issue at `ISSUE.md` in
the repository at `repo` (no remote, no CLAUDE.md; the test command is `pytest`, no linter is
configured). Create a worktree with `git -C repo worktree add ../repo-wt -b feature/12-date-range-filter
main`, work only there, and commit on that branch. Do not push, do not open a pull request, and do
not touch the primary checkout (`repo` itself must stay on `main`).

After the agent reports back, run `bash grade-implementer.sh repo-wt > grading-output.txt 2>&1`
yourself, then reply with the agent's summary (worktree path, branch name, test result) followed by
the full contents of `grading-output.txt`.
