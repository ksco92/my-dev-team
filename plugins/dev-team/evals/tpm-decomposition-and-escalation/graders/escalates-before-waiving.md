---
type: llm
---

Judge only the answer to the escalation question for a finding surviving two fix attempts on Sonnet;
ignore the slice list and design checkpoint. PASS if the reply states that the slice escalates from
Sonnet to Opus rather than waiving, softening, or deferring the finding (and escalates to the user
only after three failed attempts at Opus, a BLOCKED gate, or contradictory findings). FAIL
otherwise.
