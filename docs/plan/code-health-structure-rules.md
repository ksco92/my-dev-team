---
difficulty: high
priority: p1
status: done
---

## Context
A full-scope audit of a 36,000-line Rust+Python repository tagged every finding with the code-health
rule that would have caught it. Five miss classes came back. Part B's rules are read as applying to
production doc comments, so test comments, markdown, results documents, renderer string literals,
Makefiles, CI files and manifests carried most of the volume (about 90 mutation-kill narrations, about
70 "confirmed against version X" sentences, a 248-line config file with 198 comment lines). Diff mode
never re-greps a touched file outside its hunks, so evidence two lines away survived the PR that
targeted it. Cross-file truth (enumerations against match arms, "the one place" claims, pointers to
artifacts that no longer exist) is never checked. And the skill has no structural rules at all:
clippy's cognitive-complexity lint topped out at 13 across the repo while 21 functions exceeded 60
lines, two sat at exactly the 100-line ceiling, nine parameter bags overlapped in one crate, one file
held 9,246 lines and 17 concerns, and five structs said in their own docs that they exist to get under
a lint. The B12 comment ratio also counted doctest bodies, which made one file's target unreachable
without deleting the doctests an issue protected.

## Requirements
- [ ] Part B scope. B8 ("Tests are the evidence") states that it covers every tracked prose file: test
      comments and section banners, markdown, results documents, string literals a renderer writes
      into a tracked document, Makefiles, CI workflows and manifests; a pinned version is stated once
      in a file and never restated per claim. B9 adds "Never fails" or "does not fail" `# Errors`
      sections (the fix is the signature), a doc that restates an attribute on the same item, and an
      `# Errors` section on a function that returns no `Result`. B10's word list adds "genuinely",
      "precisely", "perfectly", "dramatically", "drop-in", "exact same", "overwhelming", and
      reviewer-addressed defenses ("not a gap", "faithfully reproduced", "rare in practice",
      "accepted, documented limitation"). B7 gains one exemption: a doc that a repository rule names
      as the single home of a posture or rationale is exempt from the length cap, and every
      restatement of it elsewhere becomes a one-line pointer.
- [ ] B1 ("Structure-first docstrings") is narrowed to a docstring that describes more than one step; a
      one-line contract needs no numbered list (the Python guide now says the same; the two must agree).
- [ ] B12 ratio. Doctest fence bodies are excluded from the comment ratio and the report states the
      prose-only ratio for a file with doctests. The ratio also counts prose inside string literals
      that a generator writes into a tracked document, and the rule covers shell scripts, Makefiles,
      CI workflows and manifests: two lines of purpose per target or key, mechanism in CONTRIBUTING.
- [ ] New Part B rules, numbered after the last existing one: every file name, `crate::` or
      `Type::Variant` path, test name, "the doctest/table/test below", "Step N" or lettered "(a)"
      label, and "see X's doc for <reason>" pointer in prose resolves to the named artifact, and the
      target of a "for why" pointer carries the reason (full mode checks every pointer; diff mode
      checks those in touched files); a uniqueness claim ("the one place", "the only difference") is
      grep-verified against sibling and twin functions and headings; after a module split, every
      section banner is checked against the items that follow it; an equivalent-mutant argument never
      sits at the code site (one line of invariant at most, the argument in the mutation record); no
      ordinal position words for sibling tests or batches ("a third batch", "the previous test"); no
      rustdoc intra-doc link syntax in markdown, Python or shipped `__doc__` text.
- [ ] Diff-mode procedure in "Review scope": run the B8, B9 and B10 patterns over each touched file in
      full, not only the hunks, and list pre-existing hits as a non-blocking ledger in the report so
      a trim PR cannot leave out-of-hunk evidence in a file it touched.
- [ ] New "Part D — Structure (followability)" between Part C and "Review scope", with these rules,
      each one or two imperative sentences with its threshold:
      D1 a production function over 60 clippy lines names its split point in the PR or is a flat
      dispatch table (one arm per line); a function within 10 lines of the repo's hard ceiling is a
      finding; block nesting deeper than 4 is a finding.
      D2 a struct, helper or split whose own doc says it exists to satisfy a lint threshold is a
      finding (the lint found a missing context struct or a duplicated shape; the extraction hid it).
      D3 two or more parameters passed unchanged through five or more functions become one context
      struct; at most one per-run context per module; a field present in three or more context
      structs moves to it.
      D4 a tuple type, alias or return with three or more fields, or any `bool` field, is a named
      struct.
      D5 count the distinct argument combinations at every production call site: a parameter fixed
      at one value is removed, parameters that always co-vary collapse into one enum or `Option`, a
      `bool` that selects behaviour at two or more sites becomes an enum or two functions, a
      parameter every caller fills from a field of another argument is removed.
      D6 a production module over 1,200 code lines or holding three or more independent concerns
      splits by concern; a source file over 3,000 total lines moves its in-module tests to a
      per-concern test directory; an item reached on the default path does not live in a module named
      for an opt-in feature, and a type named for a feature holds only that feature's state.
      D7 two or more match arms that are special cases of a sibling arm collapse into it; a guard
      repeated identically in three or more arms is hoisted; a variant set listed in three or more
      patterns with an `unreachable!` split becomes a nested enum.
      D8 a struct's fields or a category list enumerated by hand in three or more methods gets one
      accessor or table; a string key format written at two or more sites that must agree is
      produced by one function.
      D9 one output contract has one production renderer; a second serializer over 20 lines with at
      most one production caller is deleted or its caller routed through the first; a consumer that
      re-parses a library's output by string keys asks the library for the structure.
      D10 a serial and a parallel path that must be byte-identical share every per-item step and
      differ only in the driver; more than 10 duplicated lines between them is a finding; one
      worker-pool driver per crate, a second needs a measured reason in the PR.
      D11 a `cfg(test)` counter, flag, thread-local or field inside production code answers a question
      no other seam answers; tunables a test varies are run-context parameters, not thread-locals
      read inside production functions.
      D12 trust-boundary validation of one value happens at one layer; a second identical bound check
      in a wrapper or inner layer is removed by constructing the validated type earlier.
      D13 a fallback documented as unreachable names every error its callee can return and shows each
      unreachable, and its effect on the consumer is checked; a function documented as a mirror of
      another has a differential property test; an optimisation flag threaded through more than two
      signatures cites the walk it skips and is deleted when a later change makes that walk
      unconditional.
      D14 for ladder rung 5, a crate already resolved in the lockfile for a sibling crate is a reuse
      candidate and the PR states why an in-tree copy differs.
      Part D is language-agnostic in wording; stack-specific mechanics (which clippy lint, which
      visibility keyword) stay in the stack guides, which a sibling slice updates.
- [ ] Severity section: a Part D finding is MEDIUM by default, HIGH when it is a second renderer,
      a second worker pool, a lint-dodge structure, or a function at the ceiling.
- [ ] Output format: add a "Structure table (Part D)" row (longest functions touched, nesting, parameter
      bags) to the report skeleton, used in full mode and when a diff adds a function over the D1 line.
- [ ] Learned patterns: the list is at 25 (its own budget) and gains no bullet. Fold these into
      existing bullets by refinement: the rename-grep bullet also covers a file-to-directory module
      split and a crate that starts accepting a value class it refused (grep "unlike <crate>" across
      design pages and sibling crates); the two-homes (A2) bullet also covers an 8-word shingle overlap
      between two items' docs in one crate and a design-page move whose source copy is not deleted in
      the same PR; the "re-spelled constant" idea extends to a dated or versioned index ("as of
      0.5.0") older than the manifest version.
- [ ] `agents/code-health-reviewer.md`: one sentence that full mode runs Part D's structure table and
      diff mode runs the out-of-hunk ledger; nothing else changes there.
- [ ] `plugins/dev-team/.claude-plugin/plugin.json` version: one patch step above `main`'s at the
      final rebase (0.8.1 if the Python-guide slice has merged at 0.8.0, else 0.8.0 and the sibling
      takes 0.8.1; the orchestrator names the number in the rebase brief).
- [ ] Register per `CLAUDE.md`: the rule, not the incident; no dates, repo or PR names in the skill
      text; the PR body carries the evidence per rule under "Each rule and the evidence it came from",
      quoting file:line examples from the audit reports named in the brief.

## Acceptance Criteria
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')` exits 0; the
      Learned patterns bullet count in the skill is unchanged at 25.
- [ ] `bash plugins/dev-team/tests/lesson-lint.test.sh` passes; `claude plugin validate plugins/dev-team --strict`
      and `claude plugin validate .claude-plugin/marketplace.json --strict` pass (or are stated as left to CI).
- [ ] `bash plugins/dev-team/tests/evals.test.sh` passes, and the `code-health-redundant-helpers` eval
      case's expectations still hold against the edited skill text (read `plugins/dev-team/evals/`).
- [ ] Every rule above is present with its threshold; every B-rule number cited elsewhere in the plugin
      (`grep -rn 'B[0-9]\+' plugins/dev-team`) still points at the rule it meant.
- [ ] The skill stays procedure-plus-rules: no examples longer than one line, no incident narrative.

## Implementation Plan
Read the skill in full, then `context/agent-baseline.md` ("Code economy" and the budget), the
`reviewer-baseline.md`, and the rust and python guides' sections 3 and 4 so Part D does not restate a
stack rule (point at the guide instead). Write Part D as a numbered list in the skill's existing
register. Renumber nothing that exists; new B rules take the next numbers. Weigh whether D5's call-site
audit belongs under Part A rung 1 as a sharpening instead of Part D, and say which you chose in the
PR body. Run the local checks, set the plan file to `status: done`, rebase, bump, open the PR.

## Dependencies
- Blocked by: none · Related: python-guide-docstring-budget (same batch; merge order decides the
  version numbers) · Blocks: rust-guide-structure-section (the stack mechanics for Part D)

## Out of Scope
The agent-baseline budget bullets, the rust and python guides, the oss-reviewer catalog and the
readme-writer skill (separate slices). Any change to the onix repository.
