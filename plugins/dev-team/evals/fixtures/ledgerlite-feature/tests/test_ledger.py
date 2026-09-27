from datetime import date
from decimal import Decimal
from pathlib import Path

from ledgerlite.ledger import Entry, filter_by_range, read_entries, total

JAN5 = Entry(date(2026, 1, 5), Decimal("10.50"))
JAN6 = Entry(date(2026, 1, 6), Decimal("4.50"))
JAN9 = Entry(date(2026, 1, 9), Decimal("1.00"))


def test_total_sums_amounts() -> None:
    assert total([JAN5, JAN6]) == Decimal("15.00")


def test_total_of_nothing_is_zero() -> None:
    assert total([]) == Decimal("0")


def test_read_entries_parses_rows(tmp_path: Path) -> None:
    csv_file = tmp_path / "ledger.csv"
    csv_file.write_text("date,amount\n2026-01-05,10.50\n")
    assert read_entries(csv_file) == [JAN5]


def test_filter_open_ended() -> None:
    assert filter_by_range([JAN5, JAN6, JAN9], None, None) == [JAN5, JAN6, JAN9]


def test_filter_start_is_inclusive() -> None:
    assert filter_by_range([JAN5, JAN6, JAN9], date(2026, 1, 6), None) == [JAN6, JAN9]


def test_filter_end_excludes_later_days() -> None:
    assert filter_by_range([JAN5, JAN6, JAN9], None, date(2026, 1, 8)) == [JAN5, JAN6]
