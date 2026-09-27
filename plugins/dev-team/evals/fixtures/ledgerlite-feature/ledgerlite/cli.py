"""Command-line entry point."""

import argparse
from datetime import date
from pathlib import Path

from ledgerlite.ledger import filter_by_range, read_entries, total


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="ledgerlite", description="Sum a CSV ledger.")
    parser.add_argument("path", type=Path, help="CSV file with date,amount columns")
    parser.add_argument("--start", type=date.fromisoformat, default=None, help="first day (inclusive)")
    parser.add_argument("--end", type=date.fromisoformat, default=None, help="last day (inclusive)")
    args = parser.parse_args(argv)
    entries = filter_by_range(read_entries(args.path), args.start, args.end)
    print(f"total: {total(entries):.2f}")
    return 0
