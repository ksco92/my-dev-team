# Rust Coding Guide

Standards and rules for Rust projects. Established on the `onix` project (Rust rewrite
of Python DeepDiff); binding for any repo where Rust is written unless the repo's own
CLAUDE.md overrides.

---

## 1. Toolchain & Project Bootstrap

- **rustup + stable, pinned.** Every repo carries a `rust-toolchain.toml` pinning an
  exact stable version plus components, so gates are reproducible:
  ```toml
  [toolchain]
  channel = "1.98.0"
  components = ["clippy", "rustfmt", "llvm-tools-preview"]
  ```
  Bump the pin deliberately, in its own commit, with the full gate green.
- **Workspace from day one**, even for small projects: `crates/<name>-core` (library,
  no I/O) separated from `crates/<name>-cli` (thin binary). Bindings/extension crates
  land as siblings later without touching the core.
- **Release profile:** `lto = true`, `codegen-units = 1` in the workspace root.
- **Unpublished crates set `publish = false`** until a license is chosen; license
  choice, semver tooling, and MSRV policy are publish-time decisions (§5).
- Tool availability (macOS): `cargo-llvm-cov` and `cargo-deny` install via brew;
  `cargo-machete` and `cargo-mutants` only via `cargo install <tool> --locked`.
- Agent briefs must include `export PATH="$HOME/.cargo/bin:$PATH"` — fresh shells in
  agent sessions do not reliably have cargo on PATH.

## 2. Quality Gates (the `make check` canon)

One `make check` target is the local merge gate until CI exists, and becomes the CI
required check verbatim when the repo goes remote. All parts blocking:

| Gate | Command | Bar |
| --- | --- | --- |
| format | `cargo fmt --all --check` | no diffs |
| lint | `cargo clippy --all-targets --all-features -- -D warnings` | zero warnings |
| tests | `cargo test --workspace` | all pass (includes doctests) |
| coverage | `cargo llvm-cov --workspace --fail-under-lines 95` | ≥95% lines |
| docs | `RUSTDOCFLAGS="-D warnings" cargo doc --no-deps --workspace` | clean |
| supply chain | `cargo deny check` | advisories/licenses/bans/sources all clean |
| dep hygiene | `cargo machete` | no unused dependencies |

- **Lint config lives in workspace `Cargo.toml`**, never per-file:
  ```toml
  [workspace.lints.clippy]
  pedantic = { level = "warn", priority = -1 }
  [workspace.lints.rust]
  unsafe_code = "forbid"
  ```
  and each crate opts in with `[lints] workspace = true`. Pedantic at warn + `-D
  warnings` on the clippy invocation = pedantic effectively denied, overridable only
  by a **localized `#[allow(...)]` carrying a justification comment** (e.g.
  `float_cmp` where exact IEEE equality is the spec).
- **Coverage exclusions must be documented and temporary.** A logic-free bin shim may
  be excluded via `--ignore-filename-regex` with a comment stating when the exclusion
  is removed (the milestone where the shim gains behavior + integration tests).
- **Mutation testing (`cargo mutants`) is the coverage-quality check** — line coverage
  proves execution, mutants prove the tests would notice breakage. Too slow for every
  check; run it per milestone as its own `make mutants` target and triage every
  missed mutant (fix or explicitly justify).
- **Verify a new gate can actually fail before trusting it green** — e.g. add an
  untested function and watch `--fail-under-lines` exit non-zero, then revert.
  A gate that has never been red proves nothing.

## 3. Code Conventions

- **No `unsafe`** — enforced by the workspace `forbid`. If a future crate genuinely
  needs it, that crate isolates it and runs Miri in its gate; do not weaken the
  workspace default.
- **Panic-free reachable paths**: no `unwrap`/`expect`/`unreachable!` reachable from
  public APIs. An `expect` on an invariant proves it in its message string, not in a
  comment above it. A rustdoc `# Panics` section exists only for a panic a caller can
  trigger, never to say "never".
- **Doc comments follow the budget** in `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md` (Comment,
  docstring, and helper budget): a public item gets one to three lines of contract, a
  runnable example only where it teaches the API (doctests are tests), and a
  `pub(crate)`/private item usually gets none. A module doc is under ten lines. Test
  evidence, trial counts, and "confirmed against deepdiff x.y" never appear in a doc.
  `#![deny(missing_docs)]` once a crate's API stabilizes.
- **No single-use one-statement helpers**: a `fn` that wraps one expression for one call
  site (`x.expect(...)`, a renamed stdlib call) is inlined; a doc comment longer than the
  body is the tell.
- **Determinism by construction**: `BTreeMap`/`BTreeSet` over `HashMap` wherever
  output ordering is observable (serialization, reports, iteration feeding output).
- **Unit tests live in-module** (`#[cfg(test)] mod tests`), integration tests in
  `tests/`. Rust convention over Python habit — no separate unit-test tree.
- Idioms clippy will catch but write right the first time: `write!` into a `String`
  over `format!` + `push_str`; iterators over index loops; `#[must_use]` on pure fns.

## 4. Testing Conventions

- **Assert exact shapes, not counts.** For JSON-producing code, assert full
  `serde_json::json!` literals — a test that checks `is_empty()` or a length would
  miss swapped fields or wrong key names.
- **Differential testing against an incumbent is the spec** when porting/matching an
  existing tool: generate golden files from the real incumbent (pinned version) and
  require byte-identical canonical output. Docs lie; observed behavior doesn't.
  Verify semantic claims empirically (e.g. run real Python `repr()` against the
  Rust port's output) rather than from memory.
- **Name tests for what they actually cover.** A test named `large_u64...` whose
  value fits in i64 is a review finding; rename or fix the value.
- Property tests (proptest) for algebraic invariants (`diff(x,x)` is empty; every
  reported path resolves in its input) once the core API stabilizes.
- **A property that claims to permute permutes.** It uses `prop_shuffle`, or asserts
  that at least one generated case is a non-identity permutation (a full-length
  `sample::subsequence` is always the identity). An order-independence test first
  asserts that its two inputs iterate in different orders.
- **An expected value is never the production expression.** A test whose expectation is
  computed by the code under test, or `env!` compared with `env!`, is deleted.
- **One proptest config constructor and one seed policy per repo**, in a shared
  test-support module that every `proptest!` block uses.
- **One suite per case.** The same case run through the in-process and the binary layer
  with the same fixture and expected output lives in one suite; the other layer keeps only
  what it alone can assert (exit code, stdio).
- **Examples share code through one module.** Two examples anywhere in the workspace that
  share more than 20 identical lines move them into one `#[path]`-included module.

## 5. Publish-Time Gates (parked until a crate ships)

- Choose license → set `license` in workspace, drop `publish = false`, set
  `licenses.private.ignore = false` back in deny.toml.
- `cargo semver-checks` as a release gate (enforces the semver policy in CLAUDE.md).
- MSRV: declare `rust-version`, check with `cargo-msrv`.
- Criterion benchmarks with committed baselines → regression gate in CI.

## 6. Known Pitfalls

- `cargo deny init`'s template is a minefield of near-duplicate keys: `[licenses]
  private` vs `[licenses.private]`, and a commented `ignore` adjacent to a live one —
  edit surgically and re-run `cargo deny check` after every change; the parser
  rejects duplicate keys with a confusing error.
- The stock deny.toml `allow` list is EMPTY — the licenses gate passes vacuously
  until the first external dependency arrives, then fails. Populate `"MIT"`,
  `"Apache-2.0"` when the first dep lands, not before (machete keeps deps honest).
- `cargo llvm-cov` counts bins in the workspace denominator — an untestable
  `fn main` will silently eat the margin; exclude explicitly (documented) or test it.
- clippy pedantic promotes `float_cmp` and `format_push_string`; see §2/§3 for the
  sanctioned resolutions.

## 7. Structure

The code-health skill's Part D states the structure rules for every stack; this section
is their Rust mechanism, plus the Rust-only rules.

- **Length and nesting (Part D rule 1).** `clippy.toml` sets
  `excessive-nesting-threshold = 4`, which enables the lint (the default 0 leaves it off)
  and counts `mod`, `impl` and function-body blocks; the length lint keeps its 100-line
  ceiling and Part D's 60-line soft line is judged in review. The only production allow is
  a dispatch table (Part D rule 1), and tests are exempt through
  `#![cfg_attr(test, allow(clippy::too_many_lines))]` at the library root and an allow at
  each `tests/` crate root.
- **Parameter bags (Part D rule 3)** become one `#[derive(Clone, Copy)]` struct of
  references, passed by value.
- **Named fields (Part D rule 4)** cover tuple structs, `type` aliases over tuples and
  tuple returns; `type_complexity` does not flag `(usize, usize, bool)`.
- **Composition.** Two structs that share four or more fields with the same validation
  compose, one containing the other. A method that does not read `self` is an associated
  fn.
- **No `expect` whose message restates an invariant the type could carry.** An `is_x()`
  plus `as_x().expect()` pair becomes an enum or an `Option`-returning accessor, and an
  `Option::take().expect()` inside a closure called once becomes an `FnOnce` closure.
- **One `children()` iterator.** Explicit-stack walks over one recursive type that repeat
  its child enumeration are a Part D rule 8 enumeration: the type exposes
  `children()`, and each walk calls `stack.extend(node.children())`.
- **`From` over repeated `map_err`.** Five or more `map_err` closures that map one foreign
  error type to one variant become a `From` impl (a by-value mapping fn when the orphan
  rule forbids `From`), and the variant's message fits every site.
- **One mutex-poison policy per crate**; `unwrap_or_default()` on a lock result, which
  silently drops the poisoned data, is a finding.
- **Visibility.** A `pub` item in a workspace library crate with zero uses outside the
  crate is `pub(crate)` unless it is documented API, and a `pub(crate)` item with zero uses
  outside its module is private. Enable rustc `unreachable_pub` and leave clippy
  `redundant_pub_crate` off, since the two contradict inside a private module.
- **`#[allow]` reasons.** A reason states why the code is right, and one reason serves two
  adjacent items; the baseline's comment budget covers the rest.

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in
any repo of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an
imperative bullet under the `## Learned patterns` sub-heading for its trigger (one sentence, two
at most; no date, no repo name, no "added after" tail), refine near-duplicates in place, keep each
sub-list under ~25 entries, and open a PR against the plugin repository (`ksco92/my-dev-team`).

## Learned patterns

### Stack safety and depth

- A depth guard bounds total native stack only if a second recursion at the same frame (cloning a
  deep value into the output) checks the remaining budget, not a flat constant; derived
  `Clone`/`Drop`/`Serialize` on a recursive type are separate uncatchable overflow sinks.
- Test a stack-safety fix at non-default bounds, with a control that still crashes, and with a case
  exactly at the reduced budget that is accepted and processed; a rejected case only proves the
  check fires.
- Never build a path by cloning the parent slice per recursion level (O(depth²)); thread one
  `&mut Vec` down, push before recursing, pop after.
- When push/recurse/pop repeats at three or more sites, extract a `scoped(buf, seg, f)` helper so
  the pop is structural; a leak regression test needs two or three siblings, not a loop.
- In an explicit-stack rewrite, derive per-frame counters from a buffer already threaded through
  (`path.len()`) instead of storing them per frame.
- A depth-budget counter on native recursion is a logic guard, not stack safety: make the walk
  iterative, or run it on a thread sized from a measured per-frame bound at the maximum budget. A
  doc that states the per-frame figure cites the committed example that measures it, and a second
  doc that restates it re-runs that example rather than copying the number.
- A change that grows a recursive frame (threading a `Result` or a closure through it) or shrinks a
  thread's stack reservation bisects the native crash depth before and after on the deepest shape,
  including every path that recurses natively before its depth bound applies (an FFI import of a
  nested schema).
- An iterative `Drop` on a recursive type is one door of several: check `PartialEq`, `Debug`,
  `Clone`, `Serialize`, and `Hash` on the same type against the same overflow.
- Before calling a derived `Clone`/`Drop` on an external enum non-recursive because its nested
  fields sit behind `Arc`, check every variant: one `Box`-based variant (Arrow's
  `DataType::Dictionary(Box<DataType>, Box<DataType>)`) makes the recursion claim true for the
  whole type.

### Hashing, equality and memo keys

- Before removing or changing a transform, enumerate every property downstream code relies on it
  for, and key structural invariants (dedup, identity) on the structural value, never a rendered
  string.
- A hash table keyed by attacker-controlled content on a default path uses `RandomState` or an
  ordered map; FxHash only under a documented size cap, and drop the `Hash` derive on the key type
  so the fast table cannot come back silently.
- An interned id standing in for a compared value needs equal value ⟹ equal id too, which any
  normalization on the value breaks; emulating an incumbent's per-node cache means two ids per node.
- A memoization key carries every quantity the memoized function reads; an order-insensitive key
  over a multiplicity-sensitive function is a collision no forward-only suite sees.
- A `Hash` impl over user-controlled depth uses an explicit work stack, and `Hash`/`Eq`
  consistency is proven by a property test whose twin differs where `Eq` is coarser than structure
  (signed zero, shifted offset, integral floats), with the hash mutated to confirm the test has power.
- Before adding a numeric normalization, grep the crate for the literal idiom (`+ 0.0`, `to_bits`,
  `total_cmp`); equality, ordering, and hashing share one `pub(crate)` helper.
- Two consecutive `RandomState::new()` keys are correlated; a 128-bit hash uses one keyed SipHash
  (`siphasher::Hasher128`) with `getrandom` keys.
- `f + 0.0` quiets a signaling NaN; a float fold reused for ordering or hashing special-cases
  `is_nan()` first.

### Arrow, buffers and spill files

- A scratch file for untrusted data is `tempfile::tempfile()` re-read via `try_clone` and `seek`,
  never `File::create` on a predictable name under `temp_dir()`.
- `arrow_cast`'s `ArrayFormatter` under default `FormatOptions` writes `ERROR:` and `<invalid>` into
  output instead of failing; render untrusted values with `ValueFormatter::try_to_string`, durations
  from the raw integer and unit, and enforce render invariants with typed errors, never
  `debug_assert!`.
- When a PR adds a spill, cache or shard partitioned by key, measure its on-disk or tmpfs peak at
  two or more partition counts, never once at the default: a zero-copy `take` or slice on a
  view- or buffer-sharing array type retains the source's full buffers, so each shard carries
  the whole dataset and the cost is shards times data, a multiplier absent from the PR's own
  scaling story.
- When a fix compacts a spill or cache by casting away one buffer-sharing representation,
  enumerate every other representation with the same retention (view arrays keep their variadic
  buffers, dictionary arrays keep the whole dictionary) before accepting a "now independent of
  the shard count" claim; measure one shape per retaining type at two shard counts, and drive
  each of the fix's dispatch arms with an end-to-end case, since an unreached arm can carry a
  wrong target and ship green.
- When a fix's dispatch arm is recursive, the test that pins it uses a value whose inner type
  differs from its outer normalization (a `Dictionary` of a view type, not of `Utf8`); the
  non-recursive mutant yields the same target on the plain fixture and the suite stays green.
  Prove it by flattening the recursion one level and watching the test go red.
- A cast that compacts a view array into an offset-based array inherits the target's offset
  width: i32 offsets cap one array at about 2 GiB and arrow panics past it, so a compaction on
  a default path targets the Large variant, and the probe is a few values of hundreds of MiB
  in one batch under an alarm and an RSS cap.

### Docs and rustdoc

- When trimming a doc comment with intra-doc links, reuse the exact link forms that compiled;
  `-D warnings` turns a broken link into a gate failure.
- `cargo doc --no-deps` skips intra-doc links on private items; the gate also runs
  `RUSTDOCFLAGS="-D warnings" cargo doc --document-private-items -p <crate>`, under which a
  public item's doc naming a private item in bracketed link syntax fails as
  `private_intra_doc_links`; name private items from public docs in plain backticks.
- A `pub` item's rustdoc states its one constraint inline (the DoS bound an error exists for, the
  complexity a flag opts into); a repo-relative path to a design page renders as plain text in
  `cargo doc` and on docs.rs, so it supplements the sentence and never replaces it. `pub(crate)`
  items may point alone.
- A doc comment on a `#[pyclass]` or `#[pymethods]` item ships verbatim as the Python
  `__doc__`, so it is written for a `pip install`ed reader with no checkout: complete sentences,
  no `crate::` paths, no rustdoc `[`...`]` link syntax, and a file pointer names the repository
  it lives in; verify on the built wheel with `help()`, not in `cargo doc`.

### Tests, lints, CI and mutation

- `let _ = (a, b);` silencing unused params hides a placeholder signature and a hidden doctest line
  `# let _ = X;` hides an unused import; remove the params or underscore each with the milestone
  that re-adds it, and delete the doctest line with the import.
- Verify a rebuilt native extension by behavior, never by mtime; `uv cache clean` before trusting a
  reinstall at an unchanged version.
- Reproduce a lone `cargo-mutants` TIMEOUT standalone before reading it as a hang; a perf fix that
  swaps an iterative primitive for a recursive comparator re-runs the stack probe with inputs that
  cannot short-circuit.
- Accept a strengthened property test only after running it at 20 to 100 times the committed case
  count across several seeds and measuring the flake rate; guard a perturbation that feeds
  canonicalization order by depth rather than `prop_assume!`. A case-count claim names the form
  the test runs under, since the `proptest!` macro applies `PROPTEST_CASES` over its config while a
  direct `TestRunner::new` with an explicitly set `cases` ignores it, and its proof is the observed
  run count or runtime, not the config value.
- Never cache `target/` in CI keyed only on `Cargo.lock`; use `Swatinem/rust-cache` or exclude the
  workspace crates and fingerprint sources.
- A Unicode data crate used for CPython parity asserts `UNICODE_VERSION` equals
  `unicodedata.unidata_version` on the test interpreter.
- A test for a formula combining three or more terms holds every term non-zero and mutually
  distinct and asserts the exact computed constant; a fixture with any term at zero cannot catch
  a sign or operator flip on that term.
- Clippy's `too_many_lines` counts physical lines including `#[cfg]`-gated ones, so feature-gated
  instrumentation added to a near-limit function trips it in the un-instrumented build; make the
  gating macro expand to the bare body when the feature is off, and see the code-health skill's
  Part D rule 2.
- Re-run `cargo llvm-cov --show-missing-lines` yourself on any per-line coverage claim in a PR
  body: inserting a match arm shifts line numbers, so the "new arm" cited as the sole gap is often
  an adjacent pre-existing arm.

### Performance and measurement

- `serde_json::Value`'s `Map` allocates a fixed 11-slot leaf (~640 B) for any small map; measure
  map memory by node count and prefer an exactly-sized sorted `Box<[(K, V)]>` when small maps
  dominate.
- Under `unsafe_code = "forbid"`, use a dev-dependency allocator (`stats_alloc`) instead of a
  `#[global_allocator]`; measure net retained bytes over a region sized to tens of MB.
- A hand-written incremental decoder that replaces `str::chars()` must never call
  `str::from_utf8` on the whole remaining slice per element: that is O(n²) even when the rare
  branch is never taken. Decode from a byte cursor using the lead byte's width, and measure any
  such replacement against the original at three sizes before trusting the diff.
- When adding a rarely used variant to an enum that serves as a hot hash-table key or scalar
  value, box the payload if it is larger than the existing arms: an unboxed large arm widens
  every entry and shows up as a measurable regression on the hot path, not only as memory.
- A per-pass profiler states which run each reported row comes from and computes closure (passes
  against total) on the instrumented run itself, after a discarded warm-up; a warm run's passes
  against a cold run's total misstate the residual, and per-row medians across processes need not
  add up, which the method sentence says.
