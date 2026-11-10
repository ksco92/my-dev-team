# tpm review-probe rules

Binding rules for what a gate probes in a PR's code and claims: mutants, hostile inputs, validation
paths, and statements checked against the source. Read with `gates.md` before the first gate of a
run.

- A PR body that calls a state unreachable ("nothing soft-deletes X today") is checked against the
  admin surface as well as the application paths: a `ModelAdmin` that overrides add but not delete
  permission still reaches the state, and the gate reproduces it before accepting the claim.
- Reviewing a redactor or parser fix, re-run every earlier regression input with the parser's
  delimiters placed inside the secret and with the payload at every position the parser splits (a
  later field, a value, the query string); after a normalising step is added in front of a check
  that matched several representations, run the mutant that deletes each existing representation;
  and execute each parametrised security case through the library call the check reads before
  trusting its count.
- Verify an "the ORM cannot do X" justification for raw SQL against the pinned framework's source
  (`inspect.getsource` on the relevant method) before accepting it; one call turns a claim into a
  citation, and the base manager or a conditional update often already does it.
- Reviewing a limit or counter: swap the atomic statement for a read-then-write in the probe and
  require the threaded test to fail on every run; drive zero, negative and oversized well-typed
  values end to end (the insert side of a conflict-guarded limit never sees the limit; a huge day
  count overflows `timedelta` into a traceback); and when a PR edits a line already over the column
  convention, the PR owns the line's new length.
- When a PR justifies an input rule by a collision it prevents, probe the trivial form across
  entries: two equal values, and one nested in another; probe a dedupe or log-once set keyed by a
  display name with an object named after its container (a database named like the catalog), since
  two kinds of object sharing one key silence each other for the run.
- Check a uniqueness guard on a name that becomes a physical resource name against the service's own
  folding rule, not `===`.
- A symmetric check written as two one-directional clauses (`A.startsWith(B) || B.startsWith(A)`)
  needs accept fixtures in both input orders; a one-sided mutant false-positives in one order only.
- When a props value flows through several layers, grep the validation call across them to see a
  validator exported from the props file at every layer.
- When a guide names a setting as required for a security mode, read the service's own page for that
  mode and require every setting it lists, each attached to the resource that carries it; a setting
  that lives in account state is stated as a deployment precondition with a live check.
- When a PR enforces a safety rule on model or user text with a list of banned words, drive the
  check with invisible characters, look-alike letters from another alphabet, and the claim's other
  phrasings (affixless, category label, substitution) before trusting its tests.
- A sanitizer that strips a delimiter with one substitution pass is proved by nesting the delimiter
  inside itself, not by a fixture that carries it once.
- When a PR validates input against a character-class pattern, delete each class from the regex one
  at a time and require a test to fail for each; a fixture with one sample of every allowed
  character usually leaves out a class.
- Mutating a regex guard, change only the `RegExp` line, never the message that quotes it, and
  mutate each piece (each alternative, `^`, `$`, `+` to `*`, each path group); a mutant caught
  because the message changed failed on text, not behaviour.
- When a fix replaces per-field reject tests with one fixture that is bad in every field at once,
  mutate each field out of the check in turn and require a test to fail for each.
- When a change reroutes a hook's input source (the cwd to a parsed option), grep every denial
  message and every always-refuses sentence for the old source's name; they keep describing it after
  the input moved.
- When a matcher turns newlines into separators before matching, probe every gated form with a
  backslash line continuation between the command's options and its subcommand; the shell joins the
  lines and the matcher sees two commands, and a form the contract lists as not gated is recorded,
  not filed.
- A PR body that summarizes a run's log ("only startup noise", "no errors") is checked by filtering
  the log for its ERROR-level lines and comparing them with a sibling run's.
- A numeric claim about a library's limit (a size cap, a split threshold) is checked by grepping the
  constant's name across the library's installed source, never against a recalled vendor number: the
  value may sit in a sibling file and differ from the documented limit.
- A claim that a change now always reaches a deployed resource is checked against the resource's
  pre-fix history; an old state identical to a new one collides.
- A name joined from two consumer names with a separator legal in both (`dq_${db}_${table}`) is
  probed with two pairs that split at different points (`a_b`+`c` and `a`+`b_c`), since uniqueness
  per pair is not uniqueness across the set.
- When a value is interpolated inside quotes of a target grammar, read that grammar's escape rules,
  not only its quote character; rejecting `"` alone lets a trailing `\` swallow the closing quote
  (DQDL `QUOTED_STRING`, `ESC: '\\"' | '\\\\'`).
- A lesson or PR body that classifies a CLI flag by its mechanism is checked by running the command
  with the flag alone and with its companions, never from the `--help` line; a default filter can
  cancel one flag's effect so the artifact comes only from the combination.
- Mutate a widened range matcher to its single canonical member; fixtures use the canonical member,
  so the widened range survives unnoticed.
- Mutate a result cache behind a worker pool into a cold concurrent request; sequential fixtures
  never see one call per worker.
- When a fix builds a hostname from a region or a similar id, compare the id pattern with the
  partitions it admits (a `cn-*` region's hosts end in `.com.cn`) and check whether a sibling URL in
  the same flow already hardcodes the suffix, which decides whether the gap is new or an existing
  limit.
- A stub for a function whose return value the code under test must consume returns a value that
  cannot be the real one; a stub equal to the real value lets a hard-coded copy of it pass the
  suite.
- When code catches a framework's converted exception type around calls into a foreign runtime
  (PySpark's `CapturedException`, a gRPC status wrapper), trigger one real refusal live and check
  its Python class before trusting the handler or its tests; converters pass unrecognised foreign
  exceptions through raw, and a test fake that subclasses the caught type is blind to that by
  construction.
- When a job filters one period with `==` and then keeps the latest run by a maximum timestamp,
  mutate `==` to `>=` as well as `<=`; only a fixture with a later period that holds a later-created
  run, on each side of a join, fails the `>=` mutant.
- A timeout or capacity claim for a larger fan-out is sized from the deployed function's own report
  records (a Lambda's `platform.report` durations under the JSON log format, cold and warm), never
  from a call-count estimate. The gate pulls the same log window and recomputes the extremes and
  each figure derived from them, since a range read from a subset is quoted as the whole window.
