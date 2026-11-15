---
difficulty: high
priority: p0
status: done
---

## Context

The repository is public. It has no LICENSE, its manifest says `UNLICENSED`, two guides open by
naming the owner, and several guides and skill references name the owner's other projects where a
reader needs the use case instead. The owner decided: the license is Apache 2.0; the owner's name
comes out of the guides; project names come out and each passage is reworded around the use case it
illustrates.

## Requirements

- [ ] A root `LICENSE` holding the unmodified Apache License 2.0 text, and a root `NOTICE` of two
      lines: the project name, then `Copyright <year> <owner's full name>`.
      `gh repo view ksco92/my-dev-team --json licenseInfo -q .licenseInfo.key` reports `apache-2.0`
      once merged.
- [ ] `license` is `Apache-2.0` in `plugins/dev-team/.claude-plugin/plugin.json` and wherever else a
      manifest carries a license field (the marketplace manifest when its schema has one;
      `claude plugin validate --strict` decides what is allowed).
- [ ] The root README ends with a `License` section naming Apache 2.0 and linking `LICENSE`; the
      plugin README points there; nothing else in either README changes meaning, and the plugin's
      one-line description is unchanged everywhere `DEV_PROCESS.md` lists it.
- [ ] The eval fixtures that carry their own LICENSE files keep them, untouched.
- [ ] No guide, skill, agent, reference or policy file names the owner (the opening lines of the
      Python and React guides, example ARNs or user names in references). A guide's opening line
      says what the guide is for.
- [ ] No guide, skill, agent, reference or policy file names one of the owner's other projects. Each
      passage that did is reworded around the use case, keeping the rule, the technical fact and the
      example that make it useful: a rule that only made sense for one project is restated generally
      or removed, and the change body lists every removal with its reason.
- [ ] `plugin.json`'s `author` field and the marketplace manifest's `owner` field are left as they
      are (a package names its author in its manifest); the change body says so.
- [ ] One version bump of `plugin.json` (minor: the license change is a change of terms for a
      consumer).
- [ ] This plan file is committed with `status: done`.

## Acceptance Criteria

- [ ] A grep of the tracked files for the owner's first name and for each of the owner's other
      project names returns only `plugin.json`'s `author` field and the marketplace manifest's
      `owner` field, `NOTICE`, files under `docs/plan/` that are tickets of past changes, and eval
      fixtures; the change body shows the command and its output.
- [ ] Per reworded passage, the rule or fact it carried is still stated: the change body has a table
      of every edited passage (file, what it named, what it says now in a few words, and "rule kept"
      or the reason it was removed).
- [ ] `lesson-lint`, prettier, `shellcheck`, both `claude plugin validate --strict` commands and the
      five test scripts pass; no file under `hooks/`, `bin/`, `tests/` or `.github/` changes unless
      a test names a file this change renames (none is expected).
- [ ] The loaders still resolve: no file is renamed or moved.

## Implementation Plan

Inventory first (every hit, grouped by file), then the license files and manifests, then the
rewording file by file, largest last (`skills/oss-reviewer/references/ai-tells.md` holds most of the
hits: its entries are patterns with evidence drawn from projects; keep each pattern and its code
shape, drop where it was seen).

## Dependencies

- Blocked by: none · Blocks: none

## Out of Scope

Plan files of past changes under `docs/plan/`. The eval fixtures' own license files. Splitting
over-budget lesson sections (issue 48). Any change to hooks, scripts, tests or CI.
