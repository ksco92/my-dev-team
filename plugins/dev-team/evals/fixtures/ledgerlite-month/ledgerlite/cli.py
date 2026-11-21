"""Command-line entry point."""

import argparse
from pathlib import Path

from ledgerlite.ledger import month, read_entries, total


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="ledgerlite", description="Sum a CSV ledger.")
    parser.add_argument("path", type=Path, help="CSV file with date,amount columns")
    parser.add_argument("--month", type=month, help="sum only this month (YYYY-MM)")
    args = parser.parse_args(argv)
    print(f"total: {total(read_entries(args.path), args.month):.2f}")
    return 0
