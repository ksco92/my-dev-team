---
model: sonnet
max_turns: 20
timeout_seconds: 600
allowed_tools: [Skill, Read, Glob, Grep]
---

Run the `dev-team:tpm` skill in planning-only mode on the feature request below for the repository
in `app-repo/` (do not create tickets, branches, or code changes; stop after presenting the plan and
answering the escalation question). Read nothing outside this workspace and the plugin's own files.

**Feature request (already confirmed with the owner):** Add webhook signing and a webhook delivery
log to `app-repo`:

1. HMAC-SHA256 request signing and constant-time signature verification with key rotation support on
   the webhook dispatch/receive boundary.
2. A `/webhooks/deliveries` JSON endpoint and React table showing recent delivery status codes.
3. README documentation for configuring the signing secret.

**Additional question to answer in your plan:** Suppose slice 2 is tagged `medium` (implemented on
Sonnet) and the same `code-health` finding survives two fix attempts on Sonnet. State what the `tpm`
process does next.
