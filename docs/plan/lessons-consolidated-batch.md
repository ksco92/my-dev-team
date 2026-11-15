---
difficulty: high
priority: p1
status: done
---

## Context

Nine lesson changes are open against this repository, several edit the same files and each bumps the
version, so they cannot merge one after another without a rebase each; more lessons wait in the
maintainer's backlog of lessons kept outside the repository, and one open issue holds a lesson
candidate. The owner asked for one change that carries all of them, routed by one rule and filtered
by one test, through every gate.

## Requirements

- [ ] Every lesson bullet of the open pull requests 46, 50, 56, 57, 58, 59, 60, 61 and 62, of the
      maintainer's backlog of lessons kept outside the repository, and of issue 49 is accounted for
      in the change body's table: its source, where it landed (file and section), or why it was
      dropped or folded into an existing bullet.
- [ ] Routing, on the owner's word: a lesson about writing or reviewing Python (PySpark, pytest,
      packaging, typing included) lands in `plugins/dev-team/context/python-coding-guide.md`; one
      about AWS CDK or infrastructure as code in `cdk-coding-guide.md`; one about React, frontend
      TypeScript or its test tooling in `react-coding-guide.md`. A stack lesson never lands in a
      `context/tpm/` file or an agent file.
- [ ] Everything else is kept only when it passes both tests: it would be true in a different
      repository (no dependence on one project's layout, names, services or history), and it is good
      enough to change what a future brief, gate or implementer does (specific trigger, specific
      action). A lesson that fails either is dropped, with the reason in the table. A kept one lands
      in the `context/tpm/<topic>.md` file, agent file or skill phase text that owns its trigger.
- [ ] Each landed bullet states the rule, not the incident: one imperative sentence, two at most, no
      date, no repository, project, pull request or person name, no account, region or path. A
      lesson already stated on `main` refines that bullet instead of adding a near-duplicate; two
      candidates that say the same thing land once.
- [ ] `lesson-lint` budgets hold for every file the change touches. A file over budget is split by
      trigger, not trimmed (issue 48 names candidate splits); every loader that names a split file
      (the tpm skill's phase text, the table in `context/policy.md`, agent files) names the new
      file, and no fragment of a split bullet is left with a purpose clause that is no longer true.
- [ ] One version bump of `plugins/dev-team/.claude-plugin/plugin.json` (patch).
- [ ] This plan file is committed with `status: done`.

## Acceptance Criteria

- [ ] The table in the change body has one row per source bullet, and its counts add up: landed plus
      folded plus dropped equals the number of source bullets, per source.
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')`
      passes, and so does every other local check `CLAUDE.md` lists that does not call
      `claude plugin eval`; an eval case is run only when the change touches a file that case
      exercises, and the body says which were run or why none.
- [ ] No bullet names a project, repository, pull request, person, account or date: a grep for the
      names the sources use returns nothing in the changed files.
- [ ] No file under `plugins/dev-team/hooks/`, `plugins/dev-team/bin/`, `plugins/dev-team/tests/` or
      `.github/` changes.
- [ ] The plugin's one-line description is unchanged in every place the process file lists.

## Implementation Plan

Read every source first and build the table before editing a file. Decide routing and the two tests
per bullet, then dedupe against `main` and across sources, then place, then check budgets and split
where needed, then run the checks. The nine source pull requests are not merged, rebased or closed
by this change; the orchestrator closes them after it merges.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Changing a hook, a script, a test or CI. Rewriting bullets already on `main` that no source touches,
beyond what a split or a refinement needs. Closing the source pull requests or issues.
