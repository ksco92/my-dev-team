# Issue #12 — Date-range filter for `ledgerlite`

**Difficulty:** low

## Context
Users keep one ledger CSV per year and want the total for a sub-range without splitting files.

## Requirements
- [ ] `ledgerlite <path> --start YYYY-MM-DD --end YYYY-MM-DD` sums only entries within the range.
- [ ] Both bounds are **inclusive**: an entry dated exactly `--end` is counted.
- [ ] Either bound may be omitted (open-ended range).
- [ ] The README documents the new flags with a working example.

## Acceptance Criteria
- [ ] Unit tests cover both inclusive boundaries and the open-ended cases.
- [ ] Lint passes; coverage on new code ≥ 95%.
- [ ] No behavior change when neither flag is given.

## Implementation Plan
Add `filter_by_range(entries, start, end)` in `ledgerlite/ledger.py`; parse the two optional
`date` args in `cli.py`; extend `tests/test_ledger.py`; update the README quickstart.

## Out of Scope
Category filtering; multiple files.
