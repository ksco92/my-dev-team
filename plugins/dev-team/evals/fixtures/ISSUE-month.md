# Issue #14 — Month filter for `ledgerlite`

**Difficulty:** low

## Context

Users keep one ledger CSV per year and want the total for a single month without splitting files.

## Requirements

- [ ] `ledgerlite <path> --month YYYY-MM` sums only the entries dated in that calendar month, its
      first and last day included.
- [ ] Without `--month`, the output is unchanged.

## Acceptance Criteria

- [ ] Tests drive the command-line entry point with entries on the first and the last day of a month
      and an entry outside it, and without the flag.

## Implementation Plan

Parse the flag in `cli.py` into the first day of the month and pass it to an optional argument of
`total` in `ledgerlite/ledger.py`; extend `tests/test_ledger.py`.

## Out of Scope

Date ranges; multiple files; README changes.
