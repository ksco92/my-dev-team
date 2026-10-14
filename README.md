# my-dev-team

![CI](https://github.com/ksco92/my-dev-team/actions/workflows/ci.yml/badge.svg)

Claude Code development harness: TPM orchestration, tiered implementers, five review gates, and stack guides; tracker, host, and workspace commands read from DEV_PROCESS.md

It reads `DEV_PROCESS.md` from the repository root, falling back to `~/.claude/DEV_PROCESS.md` and then to a built-in default.

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

For a Claude Code cloud environment, where neither command persists on its own, paste
`docs/cloud-environment/setup.sh` into the environment's setup script; `docs/cloud-environment/README.md`
says what it installs.

## DEV_PROCESS.md

`DEV_PROCESS.md` holds every tracker, code-host, and workspace command the skills and agents run;
they carry no commands of their own, and a lesson true only on a GitHub host keeps its command and
says so. The operations it covers, and the forms the merge hook guards, are listed in
`plugins/dev-team/context/dev-process-contract.md`; a blank copy is
`plugins/dev-team/templates/DEV_PROCESS.md`, with examples in `docs/examples/DEV_PROCESS.github.md`
and `docs/examples/DEV_PROCESS.asana.md`. Run `plugins/dev-team/bin/dev-process` with no arguments
for its usage.
