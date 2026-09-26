# my-dev-team

![CI](https://github.com/ksco92/my-dev-team/actions/workflows/ci.yml/badge.svg)

Claude Code plugin marketplace: TPM orchestration, tiered implementers, five review gates, stack guides; tracker, host and workspace read from DEV_PROCESS.md

The plugin reads `DEV_PROCESS.md` from the repository root, falling back to `~/.claude/DEV_PROCESS.md`.

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
