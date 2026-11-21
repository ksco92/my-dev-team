from datetime import date
from decimal import Decimal
from pathlib import Path

import pytest

from ledgerlite.cli import main
from ledgerlite.ledger import Entry, read_entries, total


@pytest.fixture
def ledger_csv(tmp_path: Path) -> Path:
    csv_file = tmp_path / "ledger.csv"
    csv_file.write_text("date,amount\n2025-12-31,8.00\n2026-01-01,1.00\n2026-01-31,2.00\n2026-02-01,4.00\n")
    return csv_file


def test_total_sums_amounts() -> None:
    entries = [Entry(date(2026, 1, 5), Decimal("10.50")), Entry(date(2026, 1, 6), Decimal("4.50"))]
    assert total(entries) == Decimal("15.00")


def test_total_of_nothing_is_zero() -> None:
    assert total([]) == Decimal("0")


def test_read_entries_parses_rows(tmp_path: Path) -> None:
    csv_file = tmp_path / "ledger.csv"
    csv_file.write_text("date,amount\n2026-01-05,10.50\n")
    assert read_entries(csv_file) == [Entry(date(2026, 1, 5), Decimal("10.50"))]


def test_cli_sums_one_month_with_its_first_and_last_day(
    ledger_csv: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    assert main([str(ledger_csv), "--month", "2026-01"]) == 0
    assert capsys.readouterr().out == "total: 3.00\n"


def test_cli_without_month_sums_everything(
    ledger_csv: Path, capsys: pytest.CaptureFixture[str]
) -> None:
    assert main([str(ledger_csv)]) == 0
    assert capsys.readouterr().out == "total: 15.00\n"


def test_cli_rejects_a_malformed_month(ledger_csv: Path) -> None:
    with pytest.raises(SystemExit) as exit_info:
        main([str(ledger_csv), "--month", "2026-13"])
    assert exit_info.value.code == 2
