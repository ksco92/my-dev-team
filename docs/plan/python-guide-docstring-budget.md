---
difficulty: high
priority: p1
status: done
---

## Context
`context/python-coding-guide.md` says "Use Sphinx-style docstrings for all functions and methods"
and "Document all parameters, even obvious ones" in the same section that points at the
agent-baseline budget, which forbids a docstring longer than its body. A full audit of one Rust+Python
repo built under this guide found 69 functions whose docstring is longer than its body and 81 test
docstrings that restate the test name, all produced by following the guide; the code-health gate then
flags them under B7. The guide also has no rule for collapsing copy-pasted tests (one suite carried 15
near-identical fuzz batches and eight copies of one test across four files), no rule that a Python repo
runs a linter in its merge gate (that repo's gate was Rust-only; a ruff pass found 22 hits), and the
bindings guide's `__doc__` rule covers `#[pyclass]` only, not `.pyi` stubs, `#[pyfunction]` or
`create_exception!`.

## Requirements
- [ ] "Function and Method Docstrings" and "Docstring Rules" (and the "Test Docstrings" subsections
      under Unit Testing Standards) no longer mandate a docstring or `:param:` lines on every function.
      New rule set: `:param:`/`:return:`/`:raises:` lines on public functions only, in the existing
      Sphinx form; a `_private` helper or any function of three or fewer statements takes a one-line
      docstring or none; a test function's docstring carries only what its name cannot, and is omitted
      when it would paraphrase the name; a docstring never exceeds the body it documents. The
      sentences "Use Sphinx-style docstrings for all functions and methods" and "Document all
      parameters, even obvious ones" are gone (grep both).
- [ ] "Linter Configuration" and "Enforcement": a repository with tracked `.py` files runs a linter
      and a format check in its merge gate (`make check` or the CI equivalent); a guide rule that no
      configured tool enforces is reported by the gates as a finding against the gate, not only against
      the code. `ruff check` plus `ruff format --check` is named as an accepted single-tool equivalent
      of the Black/isort/Flake8 trio the section lists today.
- [ ] A new "Test Suite Structure" subsection under Unit Testing Standards with these rules, each one
      or two imperative sentences: three or more test functions, in one module or across the suite,
      whose bodies are identical after replacing literal constants become one
      `pytest.mark.parametrize` test, and a test that loops over a literal list of independent cases
      with an assert inside the loop is parametrized the same way; a test module over about 500 lines
      covering more than one feature is split (a `# noqa: E402` import below a test is the tell); a
      deterministic read-only artifact built identically by three or more tests in a module is a
      module-scoped fixture; a `_underscored` name imported by another module is renamed public, and
      `from conftest import` is replaced by a fixture or a support module; a duplicate-test-name guard
      spans the whole suite; three or more keyword arguments forwarded unchanged through two or more
      functions become one frozen dataclass; a module constant read once is inlined unless its name
      documents an external contract; a comment or docstring explaining why code is copied rather
      than imported is itself the finding.
- [ ] `context/python-bindings-coding-guide.md` section 4 "Stubs": every docstring that ships to a
      `pip install`ed reader (a `.pyi` stub, `#[pyfunction]`, `#[pymethods]`, `#[pyclass]`,
      `create_exception!`) is written for a reader with no checkout: complete sentences, no `crate::`
      paths, no rustdoc `[`...`]` link syntax, a file pointer names the repository, a bound (row cap,
      thread ceiling) stated inline; the stub's docstrings and the native `__doc__` are one home,
      either asserted equal by a test or the stub carries signatures plus a one-line summary.
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` version 0.7.4 to 0.8.0 (new rules are a feature
      under the major-zero policy), set in the final rebase.
- [ ] Prose register per `CLAUDE.md`: the rule, not the incident; no dates, repo or PR names in the
      guide text. The PR body carries the evidence per rule (file:line examples from the audit
      reports named in the brief), the way the repository's previous lesson PRs do.

## Acceptance Criteria
- [ ] `grep -n "all functions and methods\|even obvious ones" plugins/dev-team/context/python-coding-guide.md` returns nothing.
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')` exits 0;
      no new bullets under any `## Learned patterns` (the rules land as numbered-section prose, which
      lesson-lint does not count against the budget).
- [ ] `claude plugin validate plugins/dev-team --strict` and
      `claude plugin validate .claude-plugin/marketplace.json --strict` pass; `bash plugins/dev-team/tests/lesson-lint.test.sh` passes.
- [ ] Every requirement above is present as a rule a reviewer can apply from the text alone, with a
      threshold where one is stated (three bodies, 500 lines, three builds, three kwargs).
- [ ] No other guide, skill or agent file changes in this PR.

## Implementation Plan
Read `CLAUDE.md` and the two guides in full first; the "Docstring Rules" subsection already contains
budget-aware bullets that contradict the two mandates above, so the edit is a reconciliation, not an
append. Keep the existing examples that show public-function Sphinx docstrings; replace the test
docstring examples with one that shows a test with no docstring and one whose docstring states a
boundary the name cannot. Weigh where the "comment explaining a copy" rule reads best (Comments
section versus Test Suite Structure) and say which in the PR body. The evidence for each rule is in
the audit reports the brief names; cite file:line in the PR body only.

## Dependencies
- Blocked by: none · Blocks: code-health-structure-rules (next plugin slice)

## Out of Scope
The code-health skill, agent-baseline, rust-coding-guide, oss-reviewer catalog and readme-writer
changes from the same audit (separate slices). Any change to the onix repository.
