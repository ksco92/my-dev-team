---
type: llm
---

PASS if the response names a missing test: an entry dated exactly on the `--end` boundary is never
asserted as counted (the existing boundary test in `tests/test_ledger.py` only checks a date
between entries).
FAIL if no finding names this missing boundary test.
