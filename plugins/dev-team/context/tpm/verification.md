# tpm verification rules

Evidence rules for slices whose deliverable is a live claim: deploys and data loads, post-publish
installs, interruption handling, CI floors and legs, broad UI-suite failures, tool flags a skill
relies on, live runs and their recorded inputs, live-proof claims after a policy change,
response-schema tests, test counts and mutations, equivalence proofs for a dependency swap, and the
diagnosis of a vague authorization denial. Read before writing the issue for such a slice and again
before its gates.

- A tool's preview/verify/dry-run flag is not assumed to produce the real run's side effects; verify
  against the tool's code path, and give a skill's central promised artifact a deterministic check
  (mtime, size) so a silent no-op fails loudly. Cross-check a new skill's steps against the repo's
  documented process before shipping it.
- When a full UI suite fails broadly on a PR, partition before any fix loop: each failing test alone
  on a fresh runtime, then the deterministic survivors on a reviewer probe at main's head. Only what
  passes on main is the PR's; the rest is its own issue.
- Any change that verifies Ctrl-C/trap behavior needs real pty-generated signals; `kill -INT`
  evidence is inadmissible and has false-validated a Critical through two fix rounds.
- A live run of a merge/upsert job into an empty target exercises only the insert path; require a
  second run against the populated target, and validate first loads with `COUNT(*)` vs
  `COUNT(DISTINCT <full composite key>)`.
- Before a deploy that follows a merged dependency bump, `git pull` (verify it advanced), restore
  any dirtied lockfile, then `npm ci`/`uv sync` — a stale `node_modules` synthesizes the old
  behavior with a green exit. A `file:` dependency reinstalled at an unchanged version keeps the old
  copy: delete the installed package first and grep its `dist` for the change before the deploy.
- Never derive a deploy's grant-principal list from the local identity alone; reconcile against the
  standing deployed list and abort on any `replace` of a permission resource in the diff.
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
- When the test command runs more than one invocation, a reviewer reports each suite's count copied
  from its own summary line; a single total invites arithmetic made to fit the change's stated
  number.
- A mutation is applied with an edit that fails when its pattern is absent and confirmed with
  `git diff` before a green run is trusted; BSD `sed '0,/re/'` leaves the file unchanged without an
  error, and a Python mutant runs with `PYTHONDONTWRITEBYTECODE=1` or a cleared `__pycache__`, since
  a same-size mutant restored within a second leaves a stale `.pyc` that keeps loading.
- A mutant's count of failed tests is taken only from a run that ends with no collection or fixture
  error and no deselected test; a `-k` filter that skips the slow tests reports fewer failures than
  the full suite a reviewer runs.
- A test that compares a real response with its documented schema compares keys at every nested
  level, with data that makes each nested object non-null and each list non-empty, and checks each
  documented alternative against the caller that should receive it; top-level keys, a null, an empty
  list and overlapping alternatives all let drift pass.
- When a PR body offers one object or timestamp as live proof that delivery still works after a
  policy change, list the live resource read-only and require several later objects with no delivery
  error.
- A dependency swap that claims no behaviour change is proved by synthesizing base and head in
  separate `git archive` copies, each with its own `npm ci`, and diffing the sorted JSON of every
  template and asset file with the `aws:asset:path` metadata (a per-synth temp directory) stripped;
  an empty diff settles shape, grants, `DependsOn` and "no new IAM" at once.
- When a cloud call fails with a vague authorization error, pull the denied event from the audit log
  and compare its request parameters and caller context with a call that succeeded; and when
  changing the grant leaves the request and the denial identical, stop varying grants, the denial is
  not from the grant.
- An acceptance criterion that depends on a live failure fixture ("show the skip line for the
  unreadable X") names the API call that fails on X, checked before dispatch; a refused
  `GetDatabase` leaves `GetTables` returning an empty list, so a list-only path never trips it.
- A ticket that asks for live evidence in the PR body names the commands whose output the body
  carries as a closed list, and every command a plural item covers is counted from the run's saved
  logs before the body is posted; "every command and its output" is a universal each read extends.
- Build a PR body that carries command output by script from the saved outputs, with exact-once
  replacements and each command line taken from the command that ran, never from a label the log
  echoed, and apply it from a file; a fix round then closes on a diff of the host's copy against
  that file.
- Every number or observation in the prose between a PR body's evidence blocks (an interval, a
  latency range, a count of earlier runs) is recomputed from the outputs shown or left out, and the
  first gate read of the body is briefed to recompute each.
- Expected values in a live-proof ticket (the order of a run's log lines, a row count after a step
  that may repeat) are copied from the code path at the head, and a "repeat when" step states the
  values for both outcomes.
- GitHub host: a PR body holds 65,536 characters, so before a live proof whose outputs go in the
  body, run the largest block's command first (a `cdk diff`), add the block sizes up against the
  cap, and have the ticket name the author comment that carries what does not fit.
- A helper script whose output a PR body cites prints each command it runs, or its source is posted
  with the PR, and it is frozen before its first saved output; a later edit is recorded beside the
  outputs it produced.
