# my-dev-team

![CI](https://github.com/ksco92/my-dev-team/actions/workflows/ci.yml/badge.svg)

Claude Code development harness: TPM orchestration, tiered implementers, five review gates, and
stack guides; tracker, host, and workspace commands read from DEV_PROCESS.md

It reads `DEV_PROCESS.md` from the repository root, falling back to `~/.claude/DEV_PROCESS.md` and
then to a built-in default.

## Installation

From this marketplace:

```
claude plugin marketplace add ksco92/my-dev-team
claude plugin install dev-team@ksco92
```

Or from a local clone, kept current with `git pull`:

```
claude plugin marketplace add /path/to/clone
```

## DEV_PROCESS.md

`DEV_PROCESS.md` holds every tracker, code-host, experiment, and workspace command the skills and
agents run; they carry no commands of their own, and a lesson true only on a GitHub host keeps its
command and says so. The operations it covers, and the forms the merge hook guards, are listed in
`plugins/dev-team/context/dev-process-contract.md`; a blank copy is
`plugins/dev-team/templates/DEV_PROCESS.md`, with examples in `docs/examples/DEV_PROCESS.github.md`
and `docs/examples/DEV_PROCESS.asana.md`. Run `plugins/dev-team/bin/dev-process` with no arguments
for its usage.

The Experiment section turns on an experiment mode when the owner asks for one: slice branches are
merged into one experiment branch with no tickets, change requests, gates, tests, or CI, and its
Results row names where raw data, logs, and the report live. The work re-enters the trunk as one
gated change; a file whose section is absent or reads `Not allowed.` keeps the mode off.

## Verdict guard

The plugin registers a `SubagentStop` hook that refuses a review gate's first stop when its final
message lacks the verdict block and asks it to resend once. The block is the one the five reviewer
agent files under [`plugins/dev-team/agents/`](plugins/dev-team/agents/) require. The hook needs
`jq` and does nothing without it; the exact patterns are in
[`plugins/dev-team/hooks/verdict-guard.sh`](plugins/dev-team/hooks/verdict-guard.sh).

## Gate ledger

`plugins/dev-team/bin/gate-ledger` records each review gate's verdict per change for the merge hook
to check; run it with no arguments for its commands and arguments. The ledger root is
`~/.claude/gate-ledger`, or the directory `GATE_LEDGER_ROOT` names. A change's ledger is
`<root>/<repo-slug>/<id>.json`, where the slug is the repo key with a leading `/` removed and each
`/` or `:` replaced by `__`.

Every record is also appended as one JSON line to `<root>/<repo-slug>/<id>.history.jsonl`, which a
record at a new head and `reset` leave alone. `stats [<repo-key>]` reads the history files under the
root, or the one repository's, and prints two tab-separated tables: per gate, the records, the
records that are not `PASS` with zero findings (`not_clean`), and the findings; per change, the
distinct heads, the records, and the findings. It prints `no history` when there is none.

## License

Apache License 2.0; see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
