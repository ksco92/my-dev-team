# Cloud environment for the psyduck repositories

`setup.sh` is the setup script for a Claude Code cloud environment that works on
`psyduck_backend`, `psyduck_frontend`, `psyduck_cdk`, and this repository with the dev-team
plugin installed. The plugin never reads this directory.

## Install it on an environment

1. At [claude.ai/code](https://claude.ai/code), open the environment selector above the message
   box and pick **Add cloud environment**, or the settings icon on an existing one.
2. Leave **Network access** on **Trusted**; every host the script downloads from is on the
   default allowlist.
3. Paste the whole of `setup.sh` into **Setup script** and save.

The script runs the first time a session starts in the environment. When it finishes within
about five minutes the filesystem is snapshotted and later sessions start from the snapshot
without re-running it. The snapshot is rebuilt when the script changes and roughly every seven
days, so the plugin copy it keeps is at most that stale.

Environments are personal to a claude.ai account, so another person installs the same script on
an environment of their own. Sharing an environment itself is only possible inside a Team or
Enterprise organization, where an Owner shares it from the environment's **Who can use it** row.

## What a session gets

| Need | Provided by |
| --- | --- |
| PostgreSQL 18 on 127.0.0.1:5432, role `postgres` / `postgres`, database `psyduck_db` | `apt.postgresql.org`; the stock PostgreSQL 16 cluster is dropped so 18 takes port 5432 |
| Node.js 24 (`psyduck_frontend/.nvmrc`) at `/opt/node24`, first on `PATH`; Node 22 stays available | `nodejs.org` tarball |
| Python 3.14 (`psyduck_backend/.python-version`) and `uv` | `uv python install` |
| AWS CLI v2 and the `cdk` command | `awscli.amazonaws.com`, `npm install -g aws-cdk` |
| The dev-team plugin, enabled at user scope | A copy of this repository at `/opt/dev-team-marketplace` |
| `uv sync` and `npm ci` already run, `.env` copied from `.env.example` | Only when the repositories are checked out under `/home/user` when the script runs; otherwise run them per each repository's README |

The snapshot keeps files, not processes, so PostgreSQL is stopped when a session starts. Ask
Claude to run `psyduck-db start` first, then `./scripts/reset_db.sh` in the backend to migrate
and seed.

## Prerequisites for another person

- Their GitHub account has access to the four repositories, and the Claude GitHub App is
  installed on each (the repository owner does this at
  [github.com/apps/claude](https://github.com/apps/claude)).
- They connected GitHub on claude.ai and pick all four repositories when starting a session.
- A session with several repositories does not run any repository's hooks or permission rules,
  which is why every install lives in the setup script rather than in a `SessionStart` hook.

Verified in a cloud session: the script ran in 33 seconds, then the backend's `reset_db.sh`
and all three repositories' test suites passed on the installed toolchain.

## Limits

- This repository is private. The script copies the plugin from the session's checkout of
  `my-dev-team`; when no checkout is present it tries a `git clone`, which only works once the
  repository is public. A session without the plugin shows no `tpm` or `pm` skill; the fix is to
  include `my-dev-team` in the session or make the repository public.
- AWS SSO sign-in does not work in cloud sessions, and environment variables are readable by
  everyone who uses the environment, so the environment carries no AWS credentials. Sessions
  build, test, and `cdk synth`; deploys stay on a workstation.
- Playwright uses the Chromium the image ships; `npx playwright install` is not run.
