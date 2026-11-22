# tpm mutation-probe rules

Binding rules for the mutants a gate runs and the fixtures that must kill them. Read with
`review-probes.md` before the first gate of a run.

- A symmetric check written as two one-directional clauses (`A.startsWith(B) || B.startsWith(A)`)
  needs accept fixtures in both input orders; a one-sided mutant false-positives in one order only.
- A sanitizer that strips a delimiter with one substitution pass is proved by nesting the delimiter
  inside itself, not by a fixture that carries it once.
- Mutating a regex guard, change only the `RegExp` line, never the message that quotes it, and
  mutate each piece (each alternative, `^`, `$`, `+` to `*`, each path group, each character class
  deleted in turn, each position of a counted class alone, each literal as a class of itself and a
  neighbouring class, each flag), requiring a test to fail for each; a mutant caught because the
  message changed failed on text, not behaviour, and a fixture with one sample of every allowed
  character usually leaves out a class.
- When a fix replaces per-field reject tests with one fixture that is bad in every field at once,
  mutate each field out of the check in turn and require a test to fail for each.
- Mutate a widened range matcher to its single canonical member; fixtures use the canonical member,
  so the widened range survives unnoticed.
- Mutate a result cache behind a worker pool into a cold concurrent request; sequential fixtures
  never see one call per worker.
- A stub for a function whose return value the code under test must consume returns a value that
  cannot be the real one; a stub equal to the real value lets a hard-coded copy of it pass the
  suite.
- When code filters one period with `==` and then keeps the latest run by a maximum timestamp,
  mutate `==` to `>=` as well as `<=`; only a fixture with a later period that holds a later-created
  run, on each side of a join, fails the `>=` mutant.
- A test that sends generated neighbours of a valid value is checked two ways: no generated value
  matches the pattern under test, and every candidate the generator leaves out does; an exclusion
  applied at every position hides a widening where the excluded character is not valid.
- When a PR wraps an existing per-run sequence in a loop, mutate each step of the sequence to run on
  the first pass only and on the last pass only, and assert each step's effect per pass, not on the
  final state.
- When a compound condition adds an item to one bucket of several (per period, per tenant), require
  a fixture with two buckets where the item belongs to exactly one; a single bucket, or the item in
  every bucket, leaves the bucket-equality operand unpinned.
- When a PR deletes tests, the correctness gate runs targeted mutants on the code those tests
  exercised (each render branch, each validate call) and does not rely on a sweep that disables
  `throw` sites; a sweep cannot see a non-throwing path that lost its only test.
