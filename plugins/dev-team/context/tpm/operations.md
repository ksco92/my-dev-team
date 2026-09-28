# tpm operations rules

Binding rules for processes, workspaces, and the shared machine: background runs, resuming
subagents, and heavy jobs. Read with `briefing.md` before the first brief of a run.

- Never pipe a backgrounded command through `tail`/`head` — the pipe reports the filter's exit,
  not the command's. Redirect to a file, echo `EXIT=$?`, and read that line first; success lines
  also appear during rollbacks.
- A subagent that backgrounds a long run with a self-notifying waiter returns to you and does not
  auto-resume — its work sits uncommitted. Recognize it from its own "kicked off in the
  background" ping; verify from your side (`ps`, `git status`), then `SendMessage` the same agent
  with fast-ops-only instructions. Plan for gates that outlast a foreground call: the implementer
  hands the run back, you watch the process, you resume it.
- When a delegated fan-out is blocked by a recoverable environment issue, fix it and
  `SendMessage`-resume each finished agent rather than relaunching — they keep their context.
- Serialize heavy local jobs (Spark, simulators, multi-hour training) on the shared box; a
  concurrent heap kills the longest-running one, and `pgrep -f` false-negatives on long command
  lines, so guard with a full-line `ps` scan.
- `mkdir -p` the log dir before a backgrounded compound command and verify the log exists after
  launch; a failed `cd` writes the EXIT marker elsewhere and reports success.
- A server a probe starts detached from the GUI session cannot answer a desktop database app's
  per-client permission dialog (Postgres.app on macOS), so it fails only on requests that open a
  connection; start it with the tool's own background mode, and ask the owner to approve the
  interpreter binary once rather than editing the app's preferences from a probe.
- When a probe or implementer mutation-tests a file that carries uncommitted edits, it reverts the
  mutant from a copy saved beforehand, never with `git checkout -- <file>`, which discards the
  edit under test along with the mutant.
- The auto-mode classifier refuses `gate-ledger record ... PASS` written from a diff proof without a
  gate run; re-run the gates on the head (a docs-only delta is a short round) instead of arguing the
  proof.
