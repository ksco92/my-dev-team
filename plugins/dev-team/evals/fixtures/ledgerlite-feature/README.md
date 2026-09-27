# ledgerlite

**ledgerlite sums a CSV ledger from the command line — one file in, one total out, no config.**

Status (August 2026): stable for the single-file use case; published to no registry yet (install from source).

## Install

```sh
pip install -e .
```

## Quickstart

```sh
printf 'date,amount\n2026-01-05,10.50\n2026-01-06,4.50\n' > ledger.csv
ledgerlite ledger.csv
```

prints:

```
total: 15.00
```

Restrict to a date range with `--from` / `--to` (both inclusive):

```sh
ledgerlite ledger.csv --from 2026-01-06 --to 2026-01-06
```

prints `total: 4.50`.

## Contributing

Open an issue first; PRs need a passing `pytest`.

## License

MIT — see `LICENSE`.
