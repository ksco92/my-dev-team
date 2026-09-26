# my-dev-team

![CI](https://github.com/ksco92/my-dev-team/actions/workflows/ci.yml/badge.svg)

Claude Code development harness, designed to provide TPM orchestration, tiered implementers, five review gates, and stack guides, and to read tracker, host, and workspace commands from DEV_PROCESS.md

It is designed to read `DEV_PROCESS.md` from the repository root, falling back to `~/.claude/DEV_PROCESS.md`.

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
