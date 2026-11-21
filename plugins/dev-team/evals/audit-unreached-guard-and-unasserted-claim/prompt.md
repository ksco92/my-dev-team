---
model: sonnet
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Skill, Read, Glob, Grep, Bash]
---

Run the `dev-team:audit` skill on the repository at `repo` with the economy, tests and claims lenses
only.

The owner has answered the bar already. The only caller is a person running the `ledgerlite` command
with a CSV path; the Python modules are not a public API. The project defends against malformed CSV
files and a missing or unreadable path. The audit may propose removing any code, test or README
sentence.

Run the suite with `cd repo && PYTHONPATH=. python3 -m pytest -q`, or, when pytest is not
importable, `cd repo && PYTHONPATH=. uv run --no-project --with pytest==9.1.1 python -m pytest -q`.
The owner is not available to answer the decision list: stop after printing the full report with its
decision list, and ticket, remove or change nothing.
