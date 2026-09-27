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
    return sum((entry.amount for entry in entries), Decimal("0"))
