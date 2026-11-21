---
type: llm
---

Judge only the row for the `python-coding-guide.md` learned-patterns bullet "Never write a bare
`except:`; catch the narrowest exception type the block raises"; ignore every other row and the rest
of the report. PASS if that row's decision is `drop` and the row, in any column, quotes the guide
sentence "Catch the narrowest exception type the block can raise, and never write a bare `except:`".
FAIL otherwise.
