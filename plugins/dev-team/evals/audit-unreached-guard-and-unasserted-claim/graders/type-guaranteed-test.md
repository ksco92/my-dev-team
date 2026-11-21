---
type: llm
---

Judge only this item; ignore every other finding, omission or error in the response. PASS if the
response names `tests/test_entry.py` or `test_entry_holds_a_date_and_a_decimal` as a removal
candidate because it asserts nothing beyond what the dataclass and the values it was built with
already guarantee, and quotes a command it ran that bears on that test with the command's output or
exit status (a suite run with the test excluded or alone, a mutation, or a type check). FAIL
otherwise.
