---
type: llm
---

Judge only the decision for the `context/tpm/review-probes.md` bullet about each `skills/*/SKILL.md`
carrying a `description:` line; ignore every other row and the rest of the report. PASS if that
decision is `drop` on the ground that a check run on every change enforces the rule, and the row
names `tests/skill-frontmatter.test.sh`. FAIL otherwise.
