---
type: llm
---

PASS if the response identifies command injection in `read_entries`
(`subprocess.run(f"cat {path} ...", shell=True)`) via the user-controlled `path` argument.
FAIL otherwise.
