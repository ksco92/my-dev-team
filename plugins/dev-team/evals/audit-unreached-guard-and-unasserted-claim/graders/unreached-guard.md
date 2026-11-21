---
type: llm
---

Judge only this item; ignore every other finding, omission or error in the response. PASS if the
response names the `entry.amount is None` guard in `total()` (`ledgerlite/ledger.py`) as reached by
no caller through the `ledgerlite` command (a removal candidate, or dead code), and quotes a command
it ran for that conclusion with the command's output or exit status. FAIL otherwise.
