from datetime import date
from decimal import Decimal
from pathlib import Path

from ledgerlite.ledger import Entry, read_entries, total


def test_total_sums_amounts() -> None:
    entries = [Entry(date(2026, 1, 5), Decimal("10.50")), Entry(date(2026, 1, 6), Decimal("4.50"))]
    assert total(entries) == Decimal("15.00")


def test_total_of_nothing_is_zero() -> None:
    assert total([]) == Decimal("0")


def test_read_entries_parses_rows(tmp_path: Path) -> None:
    csv_file = tmp_path / "ledger.csv"
    csv_file.write_text("date,amount\n2026-01-05,10.50\n")
    assert read_entries(csv_file) == [Entry(date(2026, 1, 5), Decimal("10.50"))]
