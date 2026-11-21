---
type: llm
---

Judge only the decision for the `python-coding-guide.md` learned-patterns bullet "Never write a bare
`except:`; catch the narrowest exception type the block raises"; ignore every other row and the rest
of the report. PASS if that decision is `drop` on the ground that the rule is already stated and the
row quotes the guide's "Exception clauses" sentence that states it ("Catch the narrowest exception
type the block can raise, and never write a bare `except:`"). FAIL otherwise.
