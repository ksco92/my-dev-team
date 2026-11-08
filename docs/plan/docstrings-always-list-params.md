---
difficulty: low
priority: p1
status: done
---

## Context
The owner decided that every public Python function documents each parameter, its return value and
each exception it raises in Sphinx form, enforced by pydoclint with short docstrings checked. The
Python guide said the opposite: those lines only on functions of more than three statements, a
`:param:` omitted when it paraphrases the name, no docstring longer than its body, and the
missing-parameter codes kept disabled.

## Requirements
- [ ] `context/python-coding-guide.md` "Function and Method Docstrings": the three bullets state that every public function or method carries `:param:` for each parameter, `:return:` unless None and `:raises:` for each raised exception, however short the body; a private helper or test function keeps the one-line form; the examples show every parameter documented and a short public function with the full form.
- [ ] "Docstring Rules": a `:param:` line is never omitted; it says what the name and type hint cannot when there is such a thing.
- [ ] "Linter Configuration": the missing-parameter, missing-return and missing-raises codes are enabled through pydoclint with the options named, the test folder exempt; the Flake8 enforced-rules list names pydoclint.
- [ ] `context/agent-baseline.md` budget bullet admits the parameter, return and raises lines the stack guide requires.
- [ ] Version 0.9.11.

## Acceptance Criteria
- [ ] No sentence in `plugins/dev-team` still limits Sphinx lines to functions of more than three statements, allows omitting a `:param:`, or says the missing-parameter codes stay disabled.
- [ ] `claude plugin validate` passes for both manifests; `lesson-lint --added origin/main` exits 0.

## Implementation Plan
Edit the two guides in place, bump the version, open the PR.

## Dependencies
- Blocked by: none · Blocks: none

## Out of Scope
The Rust and other stack guides; the evals' implementer grader, whose prose-under-code check is per file and unchanged.
