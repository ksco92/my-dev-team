---
difficulty: medium
priority: p2
status: done
---

## Context

One orchestrated run that built, published and adopted a Python package wrapping third-party lint
and test tools behind one command left fifteen lesson candidates. The ones that would hold in
another repository and would change what a future brief, gate or implementer does land in one
change.

## Requirements

- [ ] Each kept lesson lands as one bullet, or one clause of an existing bullet or paragraph, in the
      file its trigger belongs to: Python lessons in `context/python-coding-guide.md`, README rules
      in the `readme-writer` skill, ticket procedure in the phase text of `skills/tpm/SKILL.md`, the
      rest in the matching `context/tpm/<topic>.md`.
- [ ] Each lesson states the rule, not the incident: one sentence, two at most, with no date and no
      repository, project, package, pull request or person name.
- [ ] Every factual claim about a tool that a lesson makes is checked against the tool's source, its
      documentation or a one-line reproduction before it lands, and the evidence is recorded below;
      a claim that cannot be checked is dropped.
- [ ] The change body names every candidate that was dropped or folded, with the line it duplicates
      or the reason.
- [ ] No file this change adds to goes over its bullet budget, and `skills/tpm/SKILL.md` stays under
      350 lines.
- [ ] The plugin version is 0.11.2.

## Acceptance Criteria

- [ ] All requirements verifiable from code/tests
- [ ] Lint passes · coverage on new code ≥ project standard (default 95%)
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')`
      exits 0 and warns about no file this change adds to
- [ ] The prettier Markdown check passes and both manifests validate

## Implementation Plan

Grep each target file and its neighbours for the same lesson first and refine an existing bullet
where one covers it; append the rest at bullet level; reformat with prettier; run `lesson-lint`;
bump the patch version.

Evidence, run with `uv run --with <pkg>` on Python 3.14, pytest 9.2.0, mypy 2.4.1, coverage 7.17.3
and pytest-cov 7.1.0:

- `python -m black --check .` beside a planted `black.py` ran it; under `-P` it did not.
  `subprocess._args_from_interpreter_flags()` returns `['-P']` and a `spawn` worker has `safe_path`,
  but a child run as `sys.executable -m worker` imported a planted `worker.py`; with
  `PYTHONSAFEPATH=1` it did not. Python docs: both added in 3.11.
- `pytest -- -pname` loaded a planted `name.py` as a plugin (`consider_preparse` has no `--` check);
  `-- ./-pname` did not. `mypy -- @list` checked the files `list` names; `mypy -- ./@list` did not.
- flake8 with an explicit `--config` and flake8-rst-docstrings read `./docutils.conf`; its
  `warning_stream` truncated a file outside the directory.
- `json.dumps(c)` in a TOML string, read back with `tomllib`, fails for every astral character by
  default and only for U+007F with `ensure_ascii=False`. coverage read `$HOME_MARK` in a config
  value as the variable's value.
- PyPI docs: a pending publisher does "not ... reserve a project's name until it is actually used".
  `warehouse/oidc/models/github.py` compares `job_workflow_ref` with the token's own `ref` or `sha`;
  the publisher stores no ref. GitHub docs: an environment's deployment rule matches `GITHUB_REF`
  against selected branch and tag patterns; GitHub rulesets docs: "Restrict creations", "Restrict
  updates" ("only users with bypass permissions can push to branches or tags whose name matches the
  pattern") and "Restrict deletions" ("only users with bypass permissions can delete branches or
  tags whose name matches the pattern") are separate rules, each given to "only users with bypass
  permissions"; the page's pull-request rule reads "all changes to the target branch", and it names
  no pull-request requirement for tags.
- `readme_renderer` keeps `[x](LICENSE)` as `href="LICENSE"`; on a project page that is
  `/project/<name>/LICENSE`, a release the JSON API answers 404 for.
- At 94.74%, `coverage report --fail-under=95` exits 0 and exits 2 with `--precision=2`;
  `_fail_under_precision` uses the floor's own decimals when it is fractional. A scope of
  statement-less files reports `TOTAL 0 0 100%` and `num_statements` 0.
- mypy `--strict` rejects `dict[str, str]` for `dict[str, str | int]` and accepts `{**x}` and
  `dict(x)`.
- `os.walk` lists a dangling symlink, a symlink loop, a FIFO and a link to `/dev/zero`; `os.stat`
  raises on the first two and reading the FIFO blocked past a two-second alarm.
- mypy with `disallow_untyped_defs`: `allow_untyped_defs = True`, `no_disallow_untyped_defs = True`,
  a `[mypy-a]` section and a first-line `# mypy: allow-untyped-defs, allow-any-explicit` each turn
  the errors off; a `pyproject.toml` `[tool.mypy]` table is read when no `mypy.ini` exists.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

A split of `context/tpm/review-probes.md`, which stays at its budget of 30: no candidate of this
batch needs it, and the loop-mutation probe an earlier lessons change held for that split still
waits. Dropped candidates: the squash-merge message, which two `context/tpm/briefing.md` bullets
already cover; a grep for example-file contents, which the test run already catches; and the
two-mechanism rule for a surviving mutant, for which no single-sentence wording gave one consistent
instruction across the equal-coverage and partial-coverage cases, while the existing `briefing.md`
bullet on deleting guarded code already routes the deletion to its own gate round.
