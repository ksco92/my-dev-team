# Python Coding Standards Guide

Standards and rules for Python projects, binding for any repo where Python is written unless the
repo's own `CLAUDE.md` overrides. Deterministic rules are enforced in code by
[`max-lint`](https://github.com/ksco92/rattata); this guide keeps only the contract summary and the
judgment calls a linter cannot check.

---

## Automated Enforcement (`max-lint`)

A repository with tracked `.py` files runs a non-mutating linter and format check in its merge gate
(`max-lint lint --check` and `max-lint test`, or `ruff check` + `ruff format --check` + `pydoclint`

- `mypy` + `pytest --cov`). A rule in this guide that an available linter could enforce but the
  repository's config omits is a finding against the merge gate.

`max-lint` (`ksco92/rattata`) enforces the following deterministically:

- **Formatting & imports:** `black` (130 chars), `isort` (`profile = "black"`),
  `add-trailing-comma`, `flake8-commas`, `flake8-multiline-containers`.
- **Typing:** strict `mypy` (`disallow_untyped_defs`, `no_implicit_optional`,
  `disallow_any_explicit`, `disallow_any_generics`, `disallow_any_unimported`,
  `warn_redundant_casts`, `warn_return_any`), `flake8-annotations` (`ANN401`), and `MXL001` (bans
  legacy `typing.Dict`/`List`/`Tuple`/`Set`/`Optional`/`Union`/`Callable`/`Iterator` etc.; use
  builtin generics, `|`, and `collections.abc`). Use `Self` from `typing_extensions` for instance
  methods; model third-party clients with narrow `Protocol` types.
- **Docstrings:** `flake8-docstrings`, `flake8-rst-docstrings` (`raw`/`include` disabled via bundled
  `docutils.conf`), `pydoclint` (`style = sphinx`, `arg-type-hints-in-docstring = false`,
  `check-return-types = false`, `check-yield-types = false`,
  `skip-checking-short-docstrings = false`, `skip-checking-private-functions = false`,
  `allow-init-docstring = true`, `check-class-attributes = false`), and `MXL002` (module docstring
  <= 10 physical lines).
- **Code health & tests (`MXL003`–`MXL012`):** single-exception `except` clauses (`MXL003`), no
  silent broad `except: pass` (`MXL004`), prose comment/docstring ratio <= 40% (`MXL005`), no bare
  `NotImplementedError()` (`MXL006`), block nesting <= 4 (`MXL007`), no documented absences
  (`MXL008`), no `TODO`/`FIXME`/`XXX`/`HACK` crumbs in production source (`MXL009`), pytest-only
  module-level test functions allowing `unittest.mock` (`MXL010`), `with patch(...)` instead of
  `@patch` decorators (`MXL011`), and no sibling `test_*` imports (`MXL012`).
- **Coverage:** 95% branch coverage (`pytest-cov` with `precision = 2`).

---

## General Coding Standards

### Docstring Content and Style

Every function and method in production modules (both public and `_private`, including `__init__`)
carries Sphinx `:param:`, `:return:` / `:yields:`, and `:raises:` lines enforced by `pydoclint`.
Test functions under `tests/` follow the test docstring rule below.

- **Imperative summary line**, sized to the budget in
  `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md` (Comment, docstring, and helper budget): state
  the contract plus at most one constraint the signature cannot show.
- **Parameter descriptions** end with a period and state what the name and type hint cannot (units,
  bounds, what `None` means), never restating default values the signature shows.
- **`:raises:` lines** document only exceptions raised by a literal `raise` statement in the
  function's own body, never exceptions propagated from callees.
- **Structure first:** multi-step docstrings use a numbered list of steps with rationale kept to one
  trailing clause per step.
- **No single-use one-statement helpers:** inline a private `_helper()` with one call site and one
  statement.

### Blank Lines Around Multi-line Statements

Readability convention for scanning functions top to bottom (outside `black`'s scope):

1. **`return` always gets a blank line above it**, regardless of what precedes it.
2. **A `for`/`if`/`while`/`with` block gets a blank line above it** (when not first in its block)
   **and below it** (when followed by another statement in the same block).
3. **Any other multi-line statement** (call, literal) **gets a blank line on any side bordering a
   different statement.**

Exemptions: never add a blank line immediately after a block header (`for x in y:`); `try`/`except`
blocks and consecutive short `if condition: return` guard-clause ladders stay dense without blank
lines between clauses.

### Comments

- **Do not restate** reasoning already captured in the docstring, exception message, or code. Drop
  inline comments that only preserve a past implementation trade-off once the code reads clearly;
  that rationale belongs in the PR description.
- **A comment explaining why code is copied instead of imported** is itself the finding: fix the
  import path and delete both the copy and the explanation.
- **Constant comments** stay to two lines or fewer and annotate the constant directly; never alias a
  shared constant (`LOCAL = SHARED`) just to hang a comment on it.

#### Section Separators (ETL Job Modules)

In ETL projects with one module per job (e.g. `src/<package>/databases/`), keep labeled banner
separators (`####...` + `# <Section>`) uniformly before the constants block and before each
top-level public function or logical method group, regardless of file size; never remove existing
banners. Small utility files (1–3 functions with no logical groups) need no banners; files with many
small private helpers group them under one `# Helpers` banner; test files use single-line
`# <category> tests` comments.

### Error Handling & Defensive Code

- **Exception messages** are specific, include relevant context, and end with a period.
- **Exception clauses (`MXL003`):** always use stacked single-exception clauses so each branch has
  its own test; Python 3.14 (PEP 758) `except A, B:` is rejected and `black` rewrites tuple forms
  into it on `py314` targets.
- **Defensive code:** a guard, retry, or fallback requires an observed, recurring failure class;
  remove speculative guards instead of documenting them.

### Naming, Organization & Lockfiles

- `snake_case` for modules, functions, variables; `PascalCase` for classes; `UPPER_SNAKE_CASE` for
  constants; leading `_` for private helpers; order class methods `__init__`, public, private.
- Initialize all instance attributes in `__init__`. Use standard `logging` (`info`, `warning`,
  `error`, `debug`) and early returns for error conditions.
- After bumping the version in `pyproject.toml`, run `uv lock` and commit `uv.lock` in the same
  commit; verify by grepping the committed file, not the working tree.

---

## Unit Testing Standards

- **Framework:** `pytest` only (`MXL010` bans `unittest` test cases and `class Test*`, while
  allowing `unittest.mock` for patching). Mirror source paths as `test_<module>.py`, annotate every
  test function `-> None`, and keep tests independent.
- **Test docstrings:** carry only what the test name cannot (e.g. a boundary condition); omit when
  it would paraphrase the name. Never document fixtures as `:param:` lines.
- **Mocking:** import from `unittest.mock` (`MagicMock`, `patch`, `ANY`) and always use
  `with patch(...)` context managers (tuple syntax for multiple patches), never `@patch` decorators
  (`MXL011`). For boto3, prefer a top-level mock function patching
  `botocore.client.BaseClient._make_api_call` that raises `ValueError` on unexpected operations.
- **Test suite structure:**
  - Three or more test functions with identical bodies after replacing literals, or a test looping
    over a literal list of cases with `assert`, become one `pytest.mark.parametrize` test.
  - Split a test module over ~500 lines covering multiple features into one module per feature.
  - A deterministic read-only artifact built identically by 3+ tests becomes a `scope="module"`
    fixture (using `tmp_path_factory` for files).
  - Rename any `_underscored` helper imported by another module to public; replace
    `from conftest import` with a fixture or a non-`test_` support module (`MXL012` bans sibling
    `test_*` imports).
  - Check duplicate test names across the whole suite, not per module.
  - Three or more keyword arguments forwarded unchanged through 2+ functions become one frozen
    dataclass parameter.
  - Inline a module constant read once unless its name documents an external contract (vendor limit,
    protocol value).

---

## Self-mutation rule

Maintained by the orchestrating session only, never by a delegated subagent or headless worker, even
one instructed to read this file; a subagent that notices something worth adding reports it under
`Proposed learned pattern:` in its own output. Lessons here are stack-specific and true in any repo
of this stack; repo-specific facts go to that repo's `.claude/rules/`. Append an imperative bullet
under `## Learned patterns` (one sentence, two at most; no date, no repo name, no "added after"
tail), refine near-duplicates in place, keep the section under ~25 entries, and open a PR against
the plugin repository (`ksco92/my-dev-team`). A lesson that only fires in a Django or DRF project
goes to `django-coding-guide.md`; one about the Python face of a native extension goes to
`python-bindings-coding-guide.md`; a lesson that matures into a standing convention becomes a
section above and leaves this list.

## Learned patterns

- Prefer a shared boolean primitive (`is_df_empty`) with the raise inlined at the call site over a
  per-job `_guard_x` wrapper; emptiness probes use `take(1)`, never `count()`.
- Hardware-resource numbers derive from the current machine at import (`os.cpu_count()`,
  `os.sysconf`) with the ratio as the named constant; server-side limits stay literals.
- Guard non-finite JSON numerics before a `Decimal` conversion: `json.loads` accepts bare
  `NaN`/`Infinity`.
- A differential test whose oracle is the interpreter (`repr()`, `unicodedata`, `json`) pins the
  interpreter (`.python-version`, `uv python install` in the workflow) and reads the CI log for the
  one `uv sync` picked.
- When rewriting a Python file by line ranges taken from `ast` line numbers, build the line array
  with `readlines()` or `split("\n")`, never `str.splitlines()`: it also splits on U+2028/U+2029,
  which a string literal can carry, and the array desyncs from the compiler's `\n`-only numbering.
- Measure a file's comment ratio with `tokenize` COMMENT tokens plus docstrings found by AST
  position (the first string statement of a module, class or function), less their `:param:`,
  `:return:` and `:raises:` lines; a scan for `#` lines or triple quotes counts an embedded script
  or fixture string as prose.
- Check that a parsed JSON value is a `dict` before testing a key with `in`
  (`"K" in json.loads(x)`): on a number or `None` it raises `TypeError`, and on a list or a string
  it tests element or substring membership.
- A PySpark field stays non-nullable through `F.lit` of a non-None value, `F.localtimestamp()` and
  arithmetic over non-nullable columns, and turns nullable through `F.to_date(F.lit(text))`, an
  aggregate, a cast of a nullable input or the optional side of an outer join; `where(isNotNull())`
  leaves the schema nullable and `DataFrame.to(schema)` rejects the change, so make a field
  non-nullable with `F.coalesce(expr, F.lit(fallback))` or `spark.createDataFrame(df.rdd, schema)`.
- A mutation run that rewrites a module repeatedly sets `PYTHONDONTWRITEBYTECODE=1` and clears
  `__pycache__` first; bytecode staleness is checked by whole-second mtime and size, so a
  same-length mutant written within the second of the last one runs the previous mutant's `.pyc`.
- When code catches a framework's converted exception type around calls into a foreign runtime
  (PySpark's `CapturedException`, a gRPC status wrapper), trigger one real refusal and check its
  Python class before trusting the handler or its tests; a converter passes an exception it does not
  recognise through raw, and a test fake that subclasses the caught type cannot show that.
- `patch("<module>.time.sleep")` sets `sleep` on the one shared `time` module, so another thread
  that sleeps during the test consumes the mock's side effects; patch the module's own name
  (`patch("<module>.time")`) and set `sleep` on that mock.
- Before recommending a pip option as a security control, test it against every form a caller can
  supply (wheel, source distribution, requirements file, direct path or URL), each with the other
  conditions removed; `--dry-run` still runs a source distribution's build backend, and
  `--only-binary` does not apply to a requirement given as a path.
- A guard that reads `sys.modules` to reject a name already imported runs once before a loop that
  imports the module, never inside it; the first pass imports the module and the guard fails on the
  second.
- A tool run as `python -m <tool>` imports same-named modules from its working directory first; set
  `PYTHONSAFEPATH=1` (Python 3.11+) in its environment rather than `-P`, which a worker the tool
  starts as a fresh `sys.executable` command does not receive.
- Spell every path handed to a tool's command line so it cannot begin with `-` or `@` (prefix `./`);
  `--` stops neither pytest's `-p` scan nor mypy's `@file` expansion.
- Publish a new name's first PyPI release before announcing it, since a pending trusted publisher
  does not reserve the name, and check its provenance names the repository and workflow. Name in the
  publisher a GitHub environment that admits only the ref the publish workflow runs on, a ref only a
  reviewed merge or a holder of bypass permission can move (the trunk under a rule requiring a
  reviewed pull request, or `v*` tags under a ruleset restricting their creation, updates and
  deletion, created only on trunk commits), since PyPI otherwise accepts the workflow from any ref.
- Set coverage `precision = 2` beside a whole-number floor, which is compared at the report
  precision (whole percent by default), so 94.7% passes 95. A scope of statement-less files reports
  100%, so also require a non-zero `num_statements` in the JSON report.
- When a third-party parameter is an invariant container of a wider element type
  (`dict[str, A | B]`), pass a copy built at the call site (`{**x}` or `dict(x)`) instead of
  widening a shared function's return type or restating the library's alias.
- When a fix runs `os.stat`, `Path.resolve` or a reader over paths from a directory walk, drive a
  dangling symlink, a symlink loop, a FIFO and a symlink to `/dev/zero` through it under a hard
  timeout.
- `str.isdecimal()` and `isdigit()` accept non-ASCII digits and `int()` raises its own ValueError
  past 4300 digits, so neither validates caller-controlled text; check with `re.fullmatch` on a
  regex compiled with `re.ASCII` and a bounded length, since a pattern ending in `$` matches before
  a trailing newline.
- Pinning a child Python linter's config does not pin libraries its plugins embed (such as
  `docutils.conf` under flake8 docstring plugins); isolate them explicitly (e.g. `DOCUTILSCONFIG`)
  and prove in a scratch copy that a planted config file leaves a sentinel untouched.
