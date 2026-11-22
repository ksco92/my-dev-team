# tpm review-probe rules

Binding rules for what a gate probes in a PR's code and claims: mutants, hostile inputs, validation
paths, and statements checked against the source. Read with `gates.md` and `mutation-probes.md`
before the first gate of a run.

- A PR body that calls a state unreachable ("nothing soft-deletes X today") is checked against the
  admin surface as well as the application paths: a `ModelAdmin` that overrides add but not delete
  permission still reaches the state, and the gate reproduces it before accepting the claim.
- Reviewing a redactor or parser fix, re-run every earlier regression input with the parser's
  delimiters placed inside the secret and with the payload at every position the parser splits (a
  later field, a value, the query string); after a normalising step is added in front of a check
  that matched several representations, run the mutant that deletes each existing representation;
  and execute each parametrised security case through the library call the check reads before
  trusting its count.
- Reviewing a limit or counter: swap the atomic statement for a read-then-write in the probe and
  require the threaded test to fail on every run; drive zero, negative and oversized well-typed
  values end to end (the insert side of a conflict-guarded limit never sees the limit; a huge day
  count overflows `timedelta` into a traceback); and when a PR edits a line already over the column
  convention, the PR owns the line's new length.
- When a PR justifies an input rule by a collision it prevents, probe the trivial form across
  entries: two equal values, and one nested in another.
- Check a uniqueness guard on a name that becomes a physical resource name against the service's own
  folding rule, not `===`.
- When a props value flows through several layers, grep the validation call across them to see a
  validator exported from the props file at every layer.
- When a guide names a setting as required for a security mode, read the service's own page for that
  mode and require every setting it lists, each attached to the resource that carries it; a setting
  that lives in account state is stated as a deployment precondition with a live check.
- When a PR enforces a safety rule on model or user text with a list of banned words, drive the
  check with invisible characters, look-alike letters from another alphabet, and the claim's other
  phrasings (affixless, category label, substitution) before trusting its tests.
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
- When a fix builds a hostname from a region or a similar id, compare the id pattern with the
  partitions it admits (a `cn-*` region's hosts end in `.com.cn`) and check whether a sibling URL in
  the same flow already hardcodes the suffix, which decides whether the gap is new or an existing
  limit.
- When a PR fixes one switch of a family of related ones (metrics flags, logging options), list the
  synthesized defaults and check every feature the title and the upgrade note name against each
  sibling a caller can still change.
- Probe a parse-based validator through the real entry point with only the downstream class patched,
  never through a copy of its expression; that proves the order of the checks and that a rejected
  value never reaches the downstream.
- When a PR removes validation or copying code, settle "nothing changed for valid input" by running
  both commits over an input matrix and comparing whole rendered outputs, and add the dimension that
  forces each alternate code path (for grants, a cross-account grantee that moves statements onto
  the resource policy).
- For a dependency pin, compare the manifest inside the downloaded tarball with the registry
  metadata and with the source manifest at the attested commit, compare the lockfile's
  `hasInstallScript` with whether the tarball carries an install script or a `binding.gyp` in its
  root, hash the tarball against the lockfile's integrity, and check that the provenance
  attestation's subject digest equals the tarball's hash before reading its commit; registry
  metadata alone can omit an install script the tarball carries.
