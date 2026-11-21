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

Add a `month` parser in `ledgerlite/ledger.py` that turns the flag into the first day of the month,
use it as the flag's argparse type in `cli.py`, and pass the result to an optional argument of
`total`; extend `tests/test_ledger.py`.

## Out of Scope

Date ranges; multiple files; README changes.
