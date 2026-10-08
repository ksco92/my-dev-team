# Python Bindings Coding Guide

Standards for the Python face of a native extension built with `maturin` (PyO3): conversion
paths, stubs, and the tests that prove a port matches the tool it replaces. Read with
`python-coding-guide.md` for the language rules and `rust-coding-guide.md` for the native side.
Binding for any repo that ships such an extension unless the repo's own CLAUDE.md overrides.

---

## 1. Build and Test Loop

- Run tests with `uv run --no-sync` in a project whose extension is built with `maturin develop`:
  a plain `uv run` re-syncs the environment and reinstalls the package from uv's version-keyed
  build cache, silently replacing the freshly built extension with a stale one, so tests pass or
  fail against code that is not the checkout's.

## 2. Widening Accepted Types

- When a PR widens which Python types or subclasses a binding accepts, enumerate every conversion
  entry point for the same base type before trusting the PR's own scope list: value converters and
  dict-key or set-member converters are separate paths, and one left on the old exact-type check
  turns a supported input into a crash where the ported tool succeeds.
- When a fix widens dict or set key acceptance to subclasses, test a subclass with a deliberately
  overridden `__eq__`/`__hash__`: the ported tool's key matching runs native Python equality while
  its element matching is a structural walk, so a port that unifies both is right for every plain
  subclass and silently wrong for the overridden one. Classify and document that boundary.
- When a binding widens an accepted type through a slow path, check that the slow path reads the
  value the same way the fast path does: a virtual call (`str()`, `__index__`, `__int__`) on the
  object lets a subclass control the value compared, while the fast path reads the machine value.
  A subclass with a lying override is the probe, on values, keys and set members.
- When a PR widens a conversion fallback (custom objects, generic containers), sweep every builtin
  that previously raised through it: a type with nothing for the fallback to enumerate (bytes,
  memoryview, an `__iter__`-only class, a class object) turns a loud refusal into silent equality.
  The invariant to assert is that nothing that raised before now reports `{}` for two values
  Python considers unequal.
- A fix that validates each side of a comparison independently at a conversion boundary also
  rejects structurally equal pairs the reference reports as unchanged; test that case, and never
  write "strictly safer than the reference" without checking it per input shape.

## 3. Big Values

- When a binding converts a host big value through its decimal `str()`/`repr()`, probe the host's
  own conversion limits before accepting an "any magnitude" claim: CPython caps int-to-str and
  str-to-int at 4,300 digits by default, so a text round-trip caps the feature far below its
  advertised range and raises the interpreter's error without the binding's path. The
  byte-oriented accessor is uncapped and cheaper.

## 4. Stubs

- A stub or surface "cannot drift" test parses both sides: `dir(module)` on the runtime side and
  every declared name on the stub side, including module-level `AnnAssign` constants, never a
  literal set. Prove it in both directions: monkeypatch a new symbol onto the module, and delete a
  declaration from a copy of the `.pyi`; each must fail the test.
- Every docstring that ships to a `pip install`ed reader (a `.pyi` stub, `#[pyfunction]`,
  `#[pymethods]`, `#[pyclass]`, `create_exception!`) is written for a reader with no checkout:
  complete sentences, no `crate::` paths, no rustdoc `[`...`]` link syntax, a file pointer that
  names the repository, and any bound the call enforces (a row cap, a thread ceiling) stated inline.
- A stub's docstrings and the native `__doc__` are one home: either a test asserts each stub
  docstring equals the normalized runtime `__doc__`, or the stub carries signatures plus a one-line
  summary.

## 5. Reproducing on a Constrained Stack

- When validating a fix on a constrained-stack thread (`threading.stack_size()`), separate two
  variables the repro tends to conflate: whether the library's own native operation is safe at
  that stack size, and whether the caller's own object construction and destruction is safe there.
  CPython's container deallocation is itself natively recursive and crashes a small-stack thread
  with no extension involved.
- Isolate them by building the deep object on a normal-stack thread and passing it by reference
  into the constrained one, kept alive until after `join`, so only the call under test and its
  error and cleanup path run on the small stack.

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker,
even one instructed to read this file; a subagent that notices something worth adding reports it
under `Proposed learned pattern:` in its own output. Lessons here are true for any Python-facing
native extension; repo-specific facts go to that repo's `.claude/rules/`. Append an imperative
bullet under `## Learned patterns` (one sentence, two at most; no date, no repo name, no "added
after" tail), refine near-duplicates in place, keep the section under ~25 entries, promote a
lesson that matures into a convention to a numbered section above, and open a PR against the
plugin repository (`ksco92/my-dev-team`).

## Learned patterns
