---
type: llm
---

Judge only the decision for the `context/tpm/briefing.md` bullet that requires Python exception
messages to name the rejected value with `!r`; ignore every other row and the rest of the report.
PASS if that decision is `fold` and its destination is the "Exception messages" section of
`python-coding-guide.md`, rewritten to state the rule. FAIL if the bullet is kept, moved as a
bullet, or dropped.
