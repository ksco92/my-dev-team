---
type: llm
---

Judge only the row for the `context/tpm/review-probes.md` bullet about each skill file carrying a
`description:` line; ignore every other row and the rest of the report. PASS if that row's decision
is `drop` and the row, in any column, names `tests/skill-frontmatter.test.sh`. FAIL otherwise.
