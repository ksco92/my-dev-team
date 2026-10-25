# tpm measurement rules

Evidence rules for slices whose deliverable is a number or a parity claim: benchmarks and published
numbers, performance or complexity fixes, profiles, ports and parity targets, new bindings or FFI
layers, and output-comparison harnesses. Read before writing the issue for such a slice and again
before its gates.

- When a benchmark or results deliverable is gated, check its headline metric against the spec's
  own stats rules (medians, N runs, same inputs) and that numbers trace to committed raw data.
- On a "faithful port" slice, require seeded differential fuzzing against the real reference and
  a read of the reference's call graph one level up; a divergence "believed inherent" is not
  accepted — minimize, instrument, diff term by term. Two implementations of one upstream quirk in
  the same codebase are the first place to look.
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
- Rebuilding a Python extension at an unchanged version can serve the cached wheel; require
  `uv cache clean` or `--reinstall` plus a behavior probe before any published number, and launch
  with `--no-sync`.
- A PR that regenerates one benchmark table re-checks every derived number (sibling results files,
  README headline, PyPI and repo descriptions); list those homes in the brief, and never run
  reviewer builds concurrently with a benchmark whose numbers will be published.
- A performance slice's per-pass profile comes from a committed, reproducible harness (an example
  binary or a documented mode of one) named in the repo's perf README, never from a scratch
  instrumentation a reviewer or implementer built once; the first performance issue in a series
  builds the harness, and every later PR posts its before/after table from that command.
- When a slice mirrors an external tool's diff or distance semantics, brief the implementer to
  verify the tool's cost or length function separately from its enumeration: a tool can walk a
  composite one way for diffing and measure it another (count keys, not values), and reusing the
  enumeration's shape for the measure corrupts distance-based pairing without any parity test
  noticing until the fuzz batch does.
- Before starting reviews on a benchmark PR, check which main the measured wheel was built from, and
  rebase and re-measure when the branch was cut before a performance merge. Inside a PR, a table
  relabeled to a new version or head without a re-run after a code change is a finding, and a fix
  round that changes the measured path re-runs every table the README cites, not only the shapes the
  fix targeted.
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
