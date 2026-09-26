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

## DEV_PROCESS.md

`DEV_PROCESS.md` holds the commands for every tracker, code-host, and workspace operation the
harness performs, so the plugin carries none of its own. The first file found wins:

1. an instruction given in the session;
2. `DEV_PROCESS.md` at the repository root;
3. `~/.claude/DEV_PROCESS.md`;
4. the built-in default, `plugins/dev-team/context/dev-process.default.md`: tickets as files under
   `docs/plan/`, a local branch merged into `main`, one checkout.

The format is `plugins/dev-team/context/dev-process-contract.md`; a blank copy to fill in is
`plugins/dev-team/templates/DEV_PROCESS.md`. Two worked examples:
`docs/examples/DEV_PROCESS.github.md` (GitHub Issues, pull requests, worktrees) and
`docs/examples/DEV_PROCESS.asana.md` (Asana, pull requests, one checkout). A SessionStart hook puts the resolved file in each session's context.

`plugins/dev-team/bin/dev-process` prints it:

- `dev-process path [--repo <dir>]`: the resolved file's path.
- `dev-process show [<section>] [--repo <dir>]`: the file, or one section by its first word.
- `dev-process get <key> [--repo <dir>]`: one frontmatter value.
