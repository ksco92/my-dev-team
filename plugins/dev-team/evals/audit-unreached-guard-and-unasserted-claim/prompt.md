---
model: sonnet
max_turns: 60
timeout_seconds: 1200
allowed_tools: [Skill, Read, Glob, Grep, Bash]
---

Run the `dev-team:audit` skill on the repository at `repo` with the economy, tests and claims lenses
only.

The owner has answered the bar already. The only caller is a person running the `ledgerlite` command
with a CSV path; the Python modules are not a public API. The project defends against no input
itself: on a malformed CSV file or a bad path, the error the standard library raises is the accepted
response. The audit may propose removing any code, test or README sentence.

The suite uses only the standard library: run it with
`PYTHONPATH=. python3 -m unittest discover -s tests -v` from the repository root or from a scratch
copy of it. The owner is not available to answer the decision list: stop after printing the full
report with its decision list, and ticket, remove or change nothing.
