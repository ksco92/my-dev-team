#!/usr/bin/env bash
# Lays a ledgerlite checkout under repo/ (one commit on main) carrying a guard in total() that
# read_entries makes unreachable through the CLI, a test of what the dataclass's annotations already
# guarantee, and a README statement about another tool's CSV export that no test asserts.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

mkdir -p repo
cp -R "$here/../fixtures/ledgerlite-base/." repo/

cat >>repo/pyproject.toml <<'EOF'

[tool.mypy]
strict = true
EOF

cat >repo/ledgerlite/ledger.py <<'EOF'
"""Ledger parsing and totals."""

import csv
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from pathlib import Path


@dataclass(frozen=True)
class Entry:
    day: date
    amount: Decimal


def read_entries(path: Path) -> list[Entry]:
    """Read `date,amount` rows from a CSV file."""
    with path.open(newline="") as handle:
        rows = csv.DictReader(handle)
        return [Entry(date.fromisoformat(row["date"]), Decimal(row["amount"])) for row in rows]


def total(entries: list[Entry]) -> Decimal:
    """Sum the amounts of the given entries."""
    if any(entry.amount is None for entry in entries):
        raise ValueError("every entry needs an amount")
    return sum((entry.amount for entry in entries), Decimal("0"))
EOF

cat >repo/tests/test_entry.py <<'EOF'
from datetime import date
from decimal import Decimal

from ledgerlite.ledger import Entry


def test_entry_holds_a_date_and_a_decimal() -> None:
    entry = Entry(date(2026, 1, 5), Decimal("10.50"))
    assert isinstance(entry.day, date)
    assert isinstance(entry.amount, Decimal)
EOF

cat >>repo/README.md <<'EOF'

## Spreadsheet exports

A ledger saved from LibreOffice Calc with its default Text CSV options (comma separator, text in
double quotes) reads unchanged, as long as the date column holds ISO dates.
EOF

git -C repo init -q -b main
git -C repo -c user.name=fixture -c user.email=fixture@example.com add -A
git -C repo -c user.name=fixture -c user.email=fixture@example.com \
  commit -qm "ledgerlite: sum a CSV ledger"
