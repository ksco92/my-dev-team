# tpm review-probe rules

Binding rules for what a gate probes in a PR's code and claims: mutants, hostile inputs,
validation paths, and statements checked against the source. Read with `gates.md` before the
first gate of a run.

- A PR body that calls a state unreachable ("nothing soft-deletes X today") is checked against the
  admin surface as well as the application paths: a `ModelAdmin` that overrides add but not delete
  permission still reaches the state, and the gate reproduces it before accepting the claim.
- Reviewing a rules or policy file that describes code, compare every mechanism word ("literal
  table name", "aborts", "placeholder") against the line it describes at the head; text drafted
  from an earlier proposal keeps the wording of an implementation a later PR replaced.
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
  count overflows `timedelta` into a traceback); and when a PR edits a line already over the
  column convention, the PR owns the line's new length.
- When a PR justifies an input rule by a collision it prevents, probe the trivial form across
  entries: two equal values, and one nested in another.
- Check a uniqueness guard on a name that becomes a physical resource name against the service's
  own folding rule, not `===`.
- A symmetric check written as two one-directional clauses (`A.startsWith(B) || B.startsWith(A)`)
  needs accept fixtures in both input orders; a one-sided mutant false-positives in one order only.
- When a props value flows through several layers, grep the validation call across them to see a
  validator exported from the props file at every layer.
- When a guide names a setting as required for a security mode, read the service's own page for
  that mode and require every setting it lists, each attached to the resource that carries it; a
  setting that lives in account state is stated as a deployment precondition with a live check.
- When a PR enforces a safety rule on model or user text with a list of banned words, drive the
  check with invisible characters, look-alike letters from another alphabet, and the claim's other
  phrasings (affixless, category label, substitution) before trusting its tests.
- A sanitizer that strips a delimiter with one substitution pass is proved by nesting the delimiter
  inside itself, not by a fixture that carries it once.
- When a PR validates input against a character-class pattern, delete each class from the regex one at a
  time and require a test to fail for each; a fixture with one sample of every allowed character usually
  leaves out a class.
