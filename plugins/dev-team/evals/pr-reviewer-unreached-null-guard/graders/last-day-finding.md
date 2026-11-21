---
type: llm
---

PASS if a finding in the verdict's Findings section states that `_in_month` in
`ledgerlite/ledger.py` drops an entry dated on the last day of the month (`entry.day < last`) while
the issue includes that day. Text under an `UNREPRODUCED` heading is not a finding. FAIL if no
finding in the Findings section identifies this defect.
