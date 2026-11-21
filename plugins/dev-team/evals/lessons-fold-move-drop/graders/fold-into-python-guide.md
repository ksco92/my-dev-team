---
type: llm
---

Judge only the row for the `context/tpm/briefing.md` bullet that requires Python exception messages
to name the rejected value with `!r`; ignore every other row and the rest of the report. PASS if
that row's decision is `fold` and its destination is the "Exception messages" section of
`python-coding-guide.md`. FAIL otherwise.
