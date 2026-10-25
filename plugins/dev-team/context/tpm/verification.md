# tpm verification rules

Evidence rules for slices whose deliverable is a live claim: deploys and data loads, post-publish
installs, interruption handling, CI floors and legs, broad UI-suite failures, tool flags a skill
relies on, live runs and their recorded inputs, live-proof claims after a policy change, response-
schema tests, and test counts and mutations. Read before writing the issue for such a slice and
again before its gates.

- A tool's preview/verify/dry-run flag is not assumed to produce the real run's side effects;
  verify against the tool's code path, and give a skill's central promised artifact a
  deterministic check (mtime, size) so a silent no-op fails loudly. Cross-check a new skill's
  steps against the repo's documented process before shipping it.
- When a full UI suite fails broadly on a PR, partition before any fix loop: each failing test alone
  on a fresh runtime, then the deterministic survivors on a reviewer probe at main's head. Only what
  passes on main is the PR's; the rest is its own issue.
- Any change that verifies Ctrl-C/trap behavior needs real pty-generated signals; `kill -INT`
  evidence is inadmissible and has false-validated a Critical through two fix rounds.
- A live run of a merge/upsert job into an empty target exercises only the insert path; require
  a second run against the populated target, and validate first loads with `COUNT(*)` vs
  `COUNT(DISTINCT <full composite key>)`.
- Before a deploy that follows a merged dependency bump, `git pull` (verify it advanced),
  restore any dirtied lockfile, then `npm ci`/`uv sync` — a stale `node_modules` synthesizes the
  old behavior with a green exit. A `file:` dependency reinstalled at an unchanged version keeps
  the old copy: delete the installed package first and grep its `dist` for the change before the
  deploy.
- Never derive a deploy's grant-principal list from the local identity alone; reconcile against
  the standing deployed list and abort on any `replace` of a permission resource in the diff.
- Validate a verify script's API assertions against the live API response, not the synthesized
  template — read APIs normalize shapes.
- When a PR body says a live run used any tool's exact output, compare the request CloudTrail
  recorded (`requestParameters`) field by field with that output, never the service's run record,
  which can copy or normalize fields the caller never sent. That proves the input only; a field
  absent from an event marked truncated or redacted proves nothing, and the result is still read
  from the live response.
- When live-testing interruption handling, signal the process group the way a terminal does and
  verify cleanup with evidence a process cannot fake (listings and mtimes after exit).
- A rotating subset of UI failures that pass in isolation points to per-runner session-length
  accumulation; bound session length with fresh runners, never with longer waits.
- Before filing a CI job for a floor interpreter or runtime version, probe the floor directly
  against the real dependency graph (`uv sync --python <floor>`, collect the suite): a declared
  floor is usually violated by transitive test dependencies and by newer syntax outside deferred
  annotations, and the issue's illustrative failure understates the work by an order of magnitude.
- A post-publish smoke install uses a fresh uv cache (`--no-cache` or a new UV_CACHE_DIR): a cache
  that served an earlier version keeps a stale simple-index page and reports the new version
  unsatisfiable even though PyPI lists its wheels.
- When the test command runs more than one invocation, a reviewer reports each suite's count
  copied from its own summary line; a single total invites arithmetic made to fit the change's
  stated number.
- A mutation is applied with an edit that fails when its pattern is absent and confirmed with
  `git diff` before a green run is trusted; BSD `sed '0,/re/'` leaves the file unchanged without an
  error.
- A test that compares a real response with its documented schema compares keys at every nested
  level, with data that makes each nested object non-null and each list non-empty, and checks each
  documented alternative against the caller that should receive it; top-level keys, a null, an
  empty list and overlapping alternatives all let drift pass.
- When a PR body offers one object or timestamp as live proof that delivery still works after a
  policy change, list the live resource read-only and require several later objects with no
  delivery error.
