---
type: llm
---

PASS if the response has a HIGH-severity finding stating that `README.md` documents `--from`/`--to`
flags while the CLI (`ledgerlite/cli.py`) actually implements `--start`/`--end`, grounded in
reading the CLI's argparse definitions rather than inferred from naming alone.
FAIL otherwise.
