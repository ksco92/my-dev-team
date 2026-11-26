# my-dev-team

![CI](https://github.com/ksco92/my-dev-team/actions/workflows/ci.yml/badge.svg)

Claude Code development harness: TPM orchestration, tiered implementers, five review gates, and
stack guides; tracker, host, and workspace commands read from DEV_PROCESS.md

It reads `DEV_PROCESS.md` from the repository root, falling back to `~/.claude/DEV_PROCESS.md` and
then to a built-in default.

Status (November 2026): active development (v0.20.0); supports Claude Code, Antigravity, and Pi.

## Contents

- [Installation](#installation)
- [Usage](#usage)
- [DEV_PROCESS.md](#dev_processmd)
- [Verdict guard](#verdict-guard)
- [Preflight scan](#preflight-scan)
- [Gate ledger](#gate-ledger)
- [Contributing](#contributing)
- [License](#license)

## Installation

### Claude Code

From this marketplace:

```
claude plugin marketplace add ksco92/my-dev-team
claude plugin install dev-team@ksco92
```

Or from a local clone, kept current with `git pull`:

```
claude plugin marketplace add /path/to/clone
```

### Antigravity

Clone this repository once and run the adapter installer:

```
git clone https://github.com/ksco92/my-dev-team
./my-dev-team/plugins/dev-team/bin/install-agy
```

`install-agy` installs into `~/.gemini/config/plugins/dev-team` (override with `--target <dir>`) by
symlinking `skills/`, `context/`, `bin/`, `templates/`, `hooks/`, and `README.md` directly to your
local clone and generating only the thin Antigravity `plugin.json`, `hooks.json` (wired through
`hooks/agy-hook.sh`), and `agents/*.md` pointer stubs. Edits to symlinked files and `git pull`
updates take effect in both Claude Code and Antigravity immediately with no duplicated files; re-run
`install-agy` when agents are added, removed, or have their frontmatter changed, when `plugin.json`
changes, or when `hooks.json` wiring in `install-agy` changes. Pass `--uninstall` to remove it
cleanly.

### Pi

Install the root native Pi package (`package.json`) from a local clone:

```
pi install /path/to/clone
```

Or directly from GitHub:

```
pi install git:github.com/ksco92/my-dev-team
```

The package registers [`plugins/dev-team/pi/dev-team.ts`](plugins/dev-team/pi/dev-team.ts) and
exposes [`plugins/dev-team/skills/`](plugins/dev-team/skills/). The extension delegates session
context (`session-context.sh`) and Bash guards (`merge-gate.sh`, `attribution-guard.sh`) to the
canonical hooks and provides the `run_agent` tool (see [Usage](#usage)).

## Usage

In Claude Code or Antigravity, open a repository and invoke a skill directly:

```
/tpm Add CSV export to the report command
```

Other entry points are `/pm` (product brief), `/audit` (repository audit), and `/lessons` (pattern
distribution).

In Pi, invoke the TPM skill with `/skill:tpm` or delegate a canonical agent through the registered
`run_agent` tool:

```
/skill:tpm Add CSV export to the report command
```

Use `backend: "pi"` for local subagents (`implementer`, `cold-reader`) and non-authoritative
pre-submission self-checks; use `backend: "claude"` or `backend: "agy"` for authoritative
merge-blocking review gates.

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

Under Claude Code, the plugin registers a `SubagentStop` hook that refuses a review gate's first
stop when its final message lacks the verdict block, reports a mismatched `GATE:` name for that
subagent, or reports an inconsistent `VERDICT:`/`FINDINGS:` pair (`PASS` requires `0`, `FAIL`
requires `>= 1`), and asks it to resend once. Under Antigravity (which has no `SubagentStop` event),
the orchestrator verifies the same verdict block before calling `gate-ledger record`. Under Pi,
`run_agent` validates review-gate output on exit code `0` by invoking `verdict-guard.sh` (failing
closed with `verdictValid: false` when output is empty or `jq` is absent on `PATH`), reports
`verdictValid`, and prepends a violation banner when invalid. The block is the one the five reviewer
agent files under [`plugins/dev-team/agents/`](plugins/dev-team/agents/) require. Under Claude
Code's `SubagentStop` hook,
[`plugins/dev-team/hooks/verdict-guard.sh`](plugins/dev-team/hooks/verdict-guard.sh) needs `jq` and
does nothing without it; the exact patterns are defined in that script.

## Preflight scan

`plugins/dev-team/bin/preflight-scan` runs deterministic mechanical checks (`AI001`–`AI009` AI
tells, `CH001`–`CH006` code-health checks, `DOC001`–`DOC004` README/doc checks) over a diff
(`--scope=diff`) or tracked tree (`--scope=full`) so implementers and review gates catch mechanical
defects before semantic review.

## Gate ledger

`plugins/dev-team/bin/gate-ledger` records each review gate's verdict per change with atomic locked
writes for the merge hook to check; run it with no arguments for its commands and arguments. The
required gate roster defaults to all five gates and can be narrowed per repository with the optional
`gates:` frontmatter key in `DEV_PROCESS.md` (read by `check --repo-dir <dir>`). The ledger root is
`~/.claude/gate-ledger`, or the directory `GATE_LEDGER_ROOT` names. A change's ledger is
`<root>/<repo-slug>/<id>.json`, where the slug is the repo key with a leading `/` removed and each
`/` or `:` replaced by `__`.

Every record is also appended as one JSON line to `<root>/<repo-slug>/<id>.history.jsonl`, which a
record at a new head and `reset` leave alone. `stats [<repo-key>]` reads the history files under the
root, or the one repository's, and prints two tab-separated tables: per gate, the records, the
records that are not `PASS` with zero findings (`not_clean`), and the findings; per change, the
distinct heads, the records, and the findings. It prints `no history` when there is none.

## Contributing

Report bugs and open feature discussions in
[GitHub Issues](https://github.com/ksco92/my-dev-team/issues). See [`CLAUDE.md`](CLAUDE.md) for
local validation checks and [`DEV_PROCESS.md`](DEV_PROCESS.md) for the branch, review-gate, and
merge workflow.

## License

Apache License 2.0; see [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).
