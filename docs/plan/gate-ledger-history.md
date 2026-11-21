---
difficulty: medium
priority: p1
status: done
---

## Context

The ledger keeps one head per change and a record at a new head starts it afresh, so nothing shows
how many gate rounds a change took or which gate returned findings. The owner wants that record
before deciding whether any class of change needs fewer gates.

## Requirements

- [x] `gate-ledger record` appends one JSON object per call, on one line, to
      `<ledger-root>/<repo-slug>/<id>.history.jsonl`, with exactly the keys `repo`, `id`, `head`,
      `gate`, `verdict`, `findings`, `model`, `at`, holding the values the ledger entry of that call
      holds. The append runs after the ledger file is in place.
- [x] `gate-ledger reset` removes the ledger file and leaves the history file.
- [x] `gate-ledger stats [<repo-key>]` reads every history file under the ledger root, or only that
      repository's, and prints two plain-text tables with a header line each: per gate, the number
      of records, the number of records that are not `PASS` with zero findings, and the sum of
      findings; per change, the repo key and id, the number of distinct heads, the number of
      records, and the sum of findings. With no history it prints `no history` and exits 0.
- [x] `record`, `check`, `show` and `reset` print what they print today for every input, and the
      merge-gate hook reads the same file it reads today.
- [x] The script's header and its `usage` output list `stats` and name the history file; `usage`
      prints every usage line (it prints a fixed line range today).
- [x] `plugins/dev-team/tests/gate-ledger.test.sh`, in the form of the other test scripts and with
      `GATE_LEDGER_ROOT` pointed at a `mktemp -d`, covers: two records at one head give two history
      lines and one ledger with both gates; a record at a new head resets the ledger and gives a
      third history line; `reset` leaves the history; each history line parses as JSON with the
      eight keys; `stats` over a fixture of two changes (one with two heads and a `FAIL` carrying
      findings) prints the expected rows; `stats <repo-key>` leaves the other repository out;
      `stats` on an empty root; an unknown command and a wrong argument count exit 2.
- [x] Every file that lists the test scripts lists the new one (`grep -rn verdict-guard.test` names
      them: the CI workflow, `CLAUDE.md`, and the process file's CI status row).
- [x] The root `README.md` says where the ledger lives, names the history file and says what `stats`
      prints, in a section beside its other operational sections; the plugin README stays a pointer.
      The contract's rows are unchanged: they list what a process file states, and no process file
      states the history file or `stats`.

## Acceptance Criteria

- [x] All requirements verifiable from the script and its test
- [x] Every local check in `CLAUDE.md` passes, the new test script among them
- [x] `bash plugins/dev-team/tests/merge-gate.test.sh` passes unchanged
- [x] A history file that holds a line that is not JSON makes `stats` exit non-zero naming the file,
      and leaves `record` and `check` working; the script is the file's only writer, so a line that
      is JSON of another shape gets no check of its own

## Implementation Plan

`bin/gate-ledger`: one `jq -nc` append in `cmd_record` after the `mv`; `cmd_stats` as one `jq -s`
over the history files (`find` under the root or the repo's slug directory); `usage` printing the
header's usage block by its markers instead of a line range. The slug comes from `ledger_path`. The
test script copies the assertion helpers of `tests/dev-process.test.sh`. This ticket's subject is
the ledger script and its CI step, so the edits to `bin/gate-ledger` and the CI workflow are in
scope; the hooks are not. The version takes a minor bump in the final rebase.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Classifying a change by the paths it touches; changing which gates a change needs; any change to
`hooks/merge-gate.sh`; rotating or pruning history.
