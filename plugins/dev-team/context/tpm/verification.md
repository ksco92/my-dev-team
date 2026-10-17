# tpm verification rules

Evidence rules for slices whose deliverable is a measurement or a claim: benchmarks and published
numbers, performance or complexity fixes, ports and parity targets, deploys and data loads,
interruption handling, CI floors and legs, broad UI-suite failures, and tool flags a skill relies
on. Read before writing the issue for such a slice and again before its gates.

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
  old behavior with a green exit.
- Never derive a deploy's grant-principal list from the local identity alone; reconcile against
  the standing deployed list and abort on any `replace` of a permission resource in the diff.
- Validate a verify script's API assertions against the live API response, not the synthesized
  template — read APIs normalize shapes.
- When a benchmark or results deliverable is gated, check its headline metric against the spec's
  own stats rules (medians, N runs, same inputs) and that numbers trace to committed raw data.
- On a "faithful port" slice, require seeded differential fuzzing against the real reference and
  a read of the reference's call graph one level up; a divergence "believed inherent" is not
  accepted — minimize, instrument, diff term by term. Two implementations of one upstream quirk in
  the same codebase are the first place to look.
- When live-testing interruption handling, signal the process group the way a terminal does and
  verify cleanup with evidence a process cannot fake (listings and mtimes after exit).
- For a claimed complexity fix, measure at two or more sizes for old and new and compare the scaling
  ratio; for a "pure refactor" claim, byte-compare outputs across generated cases.
- On a faithful-port fix round, the implementer and the correctness reviewer build the previous
  head as a control and run the new repro plus the prior battery on both; regressions land one
  nesting level deeper than the reported shape. A differential-fuzz harness passes the same output
  options the goldens use and screens the reference's self-consistency.
- When a port disables an upstream heuristic for parity, the documented worst case is the shape
  that heuristic tamed; measure low-cardinality and all-equal inputs before writing a complexity
  caveat, and have the security gate re-measure.
- A new binding or FFI layer's own recursive walk does not inherit the core's depth safety; probe
  the public API at a raised `max_depth`. A live-object benchmark whose fixture shallow-copies hands
  the reference an identity fast path; A/B identity-shared against freshly built fixtures.
- A rotating subset of UI failures that pass in isolation points to per-runner session-length
  accumulation; bound session length with fresh runners, never with longer waits.
- Rebuilding a Python extension at an unchanged version can serve the cached wheel; require
  `uv cache clean` or `--reinstall` plus a behavior probe before any published number, and launch
  with `--no-sync`.
- A PR that regenerates one benchmark table re-checks every derived number (sibling results files,
  README headline, PyPI and repo descriptions); list those homes in the brief, and never run
  reviewer builds concurrently with a benchmark whose numbers will be published.
- Before filing a CI job for a floor interpreter or runtime version, probe the floor directly
  against the real dependency graph (`uv sync --python <floor>`, collect the suite): a declared
  floor is usually violated by transitive test dependencies and by newer syntax outside deferred
  annotations, and the issue's illustrative failure understates the work by an order of magnitude.
- A post-publish smoke install uses a fresh uv cache (`--no-cache` or a new UV_CACHE_DIR): a cache
  that served an earlier version keeps a stale simple-index page and reports the new version
  unsatisfiable even though PyPI lists its wheels.
- A performance slice's per-pass profile comes from a committed, reproducible harness (an example
  binary or a documented mode of one) named in the repo's perf README, never from a scratch
  instrumentation a reviewer or implementer built once; the first performance issue in a series
  builds the harness, and every later PR posts its before/after table from that command.
- When a slice mirrors an external tool's diff or distance semantics, brief the implementer to
  verify the tool's cost or length function separately from its enumeration: a tool can walk a
  composite one way for diffing and measure it another (count keys, not values), and reusing the
  enumeration's shape for the measure corrupts distance-based pairing without any parity test
  noticing until the fuzz batch does.
- Before starting reviews on a benchmark PR, check which main the measured wheel was built from:
  a branch cut before a performance merge reports the old engine's numbers under the new
  version's name. Rebase and re-measure first; a review of stale numbers is wasted. The same
  holds inside a PR: a table relabeled to a new version or head without a re-run after a code
  change is a finding, and a fix round that changes the measured path re-runs every table the
  README cites, not only the shapes the fix targeted.
- When a fix adds a threshold-triggered compaction or cleanup, drive the input that leaves the
  live count near zero after each pass, so the trigger fires on every new event, and time it at
  three sizes against the pre-fix build: a ratio-based trigger amortizes only when the scan
  excludes what it has already retired.
- A depth-driven cost claim is measured through the entry point that builds the value in-process
  (a binding, an internal API), not through a CLI whose text parser has its own nesting cap; the
  cap silently bounds the measurement below the depths the claim covers.
- When an interleaved A/B profile shows a gap only in passes the change does not touch, rerun
  with the pair order reversed before reporting it: being second in each pair while load rises
  reads as a regression.
- A byte-identity or output-comparison harness asserts that every output it hashes exists
  before comparing; two missing outputs hash equal and report a match.
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
  delivery error; one sample can predate the change under a window-based naming scheme.
