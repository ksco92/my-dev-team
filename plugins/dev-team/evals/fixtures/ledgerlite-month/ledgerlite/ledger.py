"""Ledger parsing and totals."""

import csv
from calendar import monthrange
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


def month(text: str) -> date:
    """Parse `YYYY-MM` into the first day of that month."""
    return date.fromisoformat(f"{text}-01")


def total(entries: list[Entry], of_month: date | None = None) -> Decimal:
    """Sum the amounts of the given entries; with `of_month`, only those in its calendar month."""
    if of_month is not None:
        entries = _in_month(entries, of_month)
    return sum((entry.amount for entry in entries), Decimal("0"))


def _in_month(entries: list[Entry], day: date) -> list[Entry]:
    """Keep the entries dated in the calendar month that contains `day`."""
    first = day.replace(day=1)
    last = day.replace(day=monthrange(day.year, day.month)[1])
    return [entry for entry in entries if first <= entry.day < last]
