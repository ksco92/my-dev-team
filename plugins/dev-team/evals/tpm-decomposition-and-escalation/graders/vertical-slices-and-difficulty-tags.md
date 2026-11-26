---
type: llm
---

Judge only the slice decomposition and difficulty tags; ignore the design sketch and escalation
answer. PASS if the webhook HMAC signing/verification slice is tagged `high` (never `low`) and the
slices are organized as vertical user-facing or contract slices rather than horizontal "all models /
all endpoints / all UI" layers. FAIL otherwise.
