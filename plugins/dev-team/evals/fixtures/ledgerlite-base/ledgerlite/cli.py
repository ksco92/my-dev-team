"""Command-line entry point."""

import argparse
from pathlib import Path

from ledgerlite.ledger import read_entries, total


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="ledgerlite", description="Sum a CSV ledger.")
    parser.add_argument("path", type=Path, help="CSV file with date,amount columns")
    args = parser.parse_args(argv)
    print(f"total: {total(read_entries(args.path)):.2f}")
    return 0
