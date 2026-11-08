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
- [x] `context/python-coding-guide.md` "Function and Method Docstrings": the two bullets state that every public function or method carries `:param:` for each parameter, `:return:` unless None and `:raises:` for each raised exception, however short the body; a private helper or test function keeps the one-line form; the examples show every parameter documented and a short public function with the full form.
- [x] "Docstring Rules": every parameter has a `:param:` line that says what the name and type hint cannot, or a short noun phrase when it has none.
- [x] "Linter Configuration": the missing-parameter, missing-return and missing-raises codes are enabled through pydoclint with the options named, the test folder exempt; the Flake8 enforced-rules list names pydoclint.
- [x] `context/agent-baseline.md` budget bullet admits the parameter, return and raises lines the stack guide requires.
- [x] `skills/code-health/SKILL.md`, `agents/pr-reviewer.md`, the oss-reviewer skill and its tell catalog, and the baseline's helper bullet exempt the required lines from their length and restatement caps.
- [x] Every public-function example in the guide shows the full form, or the example says its docstrings are abbreviated.
- [x] `__init__` counts as public, and the class examples document its parameters.
- [x] Version 0.9.11.

## Acceptance Criteria
- [x] No sentence in `plugins/dev-team` still limits Sphinx lines to functions of more than three statements, allows omitting a `:param:`, or says the missing-parameter codes stay disabled.
- [x] `claude plugin validate` passes for both manifests; `lesson-lint --added origin/main` exits 0.

## Implementation Plan
Edit the two guides in place, bump the version, open the PR.

## Dependencies
- Blocked by: none · Blocks: none

## Out of Scope
The Rust and other stack guides; the evals' implementer grader, whose prose-under-code check is per file and unchanged.
