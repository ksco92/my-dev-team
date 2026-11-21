---
type: llm
---

Judge only the row for the `context/tpm/briefing.md` bullet that requires Python exception messages
to name the rejected value with `!r`; ignore every other row and the rest of the report. PASS if
that row's decision is `fold` and its destination names `python-coding-guide.md` and its Exception
messages section, with or without the heading's `###`. FAIL otherwise.
