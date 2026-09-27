---
type: llm
---

PASS if the response contains a finding that `filter_by_range` in `ledgerlite/ledger.py` treats
the `--end` bound as exclusive (`entry.day >= end` skips it) while the issue requires both bounds
inclusive, and cites that file.
FAIL if no finding identifies the exclusive end bound, or the finding cites a file or line that
does not describe this behavior.
