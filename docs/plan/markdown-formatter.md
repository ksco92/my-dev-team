---
difficulty: medium
priority: p1
status: done
---

## Context

Review gates repeatedly file findings about ragged rewraps and lines over the surrounding width in
guide and skill prose. A formatter that owns line wrapping removes that finding class.

## Requirements

- [x] `.prettierrc.json` at the repository root sets `proseWrap` to `always` and `printWidth` to
      100; `.prettierignore` lists `node_modules` and `plugins/dev-team/evals/results`.
- [x] Every tracked `.md` file under `plugins/dev-team/`, `docs/` and the repository root is
      formatted once with prettier 3.6.2, the exact version used everywhere.
- [x] The CI `validate` job gains a "Check Markdown formatting" step after the shellcheck step,
      running `prettier@3.6.2 --check` over every tracked `.md` file.
- [x] `CLAUDE.md` "Local checks" lists the `--check` command and says `--write` reformats.
- [x] The code-health skill's prose rules state that line wrapping in a file a formatter owns is
      never a finding.
- [x] `lesson-lint --added <base>` treats a bullet as added only when its whitespace-collapsed text
      is absent from the merge base's copy of the same file, so a pure reflow is never linted; the
      test script covers a reflowed bullet, a one-word change and a new bullet.
- [x] The plugin version is one patch step above `main`'s at the final rebase.

## Acceptance Criteria

- [x] `npx --yes prettier@3.6.2 --check` passes over every tracked `.md` file.
- [x] `claude plugin validate` passes for both manifests; the three Bash test scripts pass.
- [x] `lesson-lint --added origin/main` over the plugin's Markdown exits 0 without excluding files
      or weakening the lint.

## Implementation Plan

Add the config, run the formatter once, add the CI step and the two documentation lines, bump the
version in the final rebase.

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Markdown in other repositories; the code-health gate's other rules.
