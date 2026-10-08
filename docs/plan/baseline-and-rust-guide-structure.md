---
difficulty: high
priority: p1
status: done
---

## Context
A full-scope audit of a Rust+Python repository showed the comment budget in `agent-baseline.md` being
read as covering production doc comments only: about 90 test comments narrated which mutant they kill,
about 70 sentences restated the pinned reference version, item docs justified themselves by the lint
they satisfy, benchmark figures and instrumentation rationale sat in doc comments, and one design-page
pointer was repeated in nine item docs of one file. The Rust guide has no structural conventions
(function length, parameter plumbing, visibility, `From` impls, test truth), its Learned patterns list
is at 40 bullets against a budget of 25, and two of its needed rules are stack-specific mechanics for
the code-health skill's new Part D.

## Requirements
- [ ] `context/agent-baseline.md`, "Comment, docstring, and helper budget": refine the "Tests are the
      evidence" bullet to cover test comments and section banners (a test comment states the boundary
      its fixture sits on and never names a mutant it kills or cannot kill, a mutation run, the
      internal branch it reaches, or a sibling test; shared rationale goes once on the section banner).
      Add, as refinements of existing bullets where one fits and as new bullets only where none does:
      no reviewer-addressed defenses ("not a gap", "faithfully reproduced", "rare in practice"; state
      the limit once and point at the compatibility doc); a doc never justifies an item by the lint or
      tooling it satisfies; benchmark timings, size figures and instrumentation-design rationale are
      PR-body content like trial counts; one design-page pointer per file, in the module doc, and a doc
      never declares itself "the single home" or lists who points at it; a README performance section
      and a tracked results document report the current release (per-release before/after deltas
      leave the tracked doc); never explain where a test lives or why it is not elsewhere. The
      baseline's Learned patterns list is at 24 of 25: at most one new bullet there, the rest as
      refinements of the budget section's prose.
- [ ] `context/rust-coding-guide.md`: a new numbered section "7. Structure" after "6. Known Pitfalls"
      carrying the stack mechanics for the code-health skill's Part D: `too-many-lines-threshold = 60`
      for non-test code and `excessive_nesting` at 4 in `clippy.toml`, with a flat dispatch table (one
      arm per line) the stated exemption; two or more parameters threaded unchanged through five or
      more functions become one `Copy` struct of references; a tuple with three or more fields or any
      `bool` field is a named struct; two structs sharing four or more fields with the same validation
      compose, and a method that does not read `self` is an associated fn; no `expect` whose message
      restates an invariant the type could carry (an `is_x()` plus `as_x().expect()` pair becomes an
      enum or an `Option`-returning accessor; a `take().expect()` in a once-called closure becomes
      `FnOnce`); when three or more explicit-stack walks over one recursive type repeat its child
      enumeration, the type exposes one `children()` iterator; five or more `map_err` closures mapping
      one foreign error to one variant become a `From` impl, and one mutex-poison policy per crate
      (`unwrap_or_default()` on a lock result is a finding); a `pub` item in a workspace library crate
      with zero uses outside the crate is `pub(crate)` unless it is documented API, a `pub(crate)` item
      with zero uses outside its module is private, and `unreachable_pub` plus `redundant_pub_crate`
      are enabled to check it; an `#[allow]` reason states why the code is right, never a coverage or
      tooling motive, and one reason serves two adjacent items.
- [ ] `context/rust-coding-guide.md`, "4. Testing Conventions": a property that claims to permute uses
      `prop_shuffle` or asserts at least one generated case is a non-identity permutation; an
      order-independence test first asserts its inputs iterate differently; an expected value that is
      the production expression (or `env!` against `env!`) is deleted; one proptest config constructor
      and seed policy per repo; the same case through in-process and binary layers with identical
      fixture and expected output lives in one suite; two examples anywhere in the workspace sharing
      more than 20 identical lines share one `#[path]`-included module; a hidden doctest line that
      only silences an unused import goes with the import.
- [ ] Reconcile the existing Learned-patterns bullet that answers a `too_many_lines` hit with a helper
      extraction against the code-health skill's Part D rule that an extraction whose doc says it exists
      for a lint is a finding: the fix for a length hit is restructuring the caller (a context struct, a
      table, a split by concern), never an `#[allow]` and never an extraction named for the lint; refine
      the bullet in place.
- [ ] `context/rust-coding-guide.md`, "## Learned patterns": split the 40 bullets by trigger into
      sub-headings under the one `## Learned patterns` heading (stack safety and depth; hashing and
      memo keys; Arrow and buffers; docs and rustdoc; CI, coverage and mutation; benchmarks and
      measurement), each sub-list under 25, every bullet kept verbatim or refined in place, none
      dropped; verify `bin/lesson-lint` still finds and counts them (read its section-detection logic
      first and adjust the split shape to what it parses, or state in the PR body that lesson-lint
      counts the whole list and the split is for readers).
- [ ] Register per `CLAUDE.md`: rule not incident, no dates or repo or PR names in guide text. The PR
      body carries evidence per rule under "Each rule and the evidence it came from" with file:line
      examples from the audit reports named in the brief.
- [ ] Version: one patch step above `main`'s at the final rebase; the orchestrator names it.

## Acceptance Criteria
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')` exits 0
      with no budget warning on the rust guide (or the PR body explains the warning if the tool counts
      the whole list regardless of sub-headings).
- [ ] `bash plugins/dev-team/tests/lesson-lint.test.sh` passes; both `claude plugin validate` commands
      pass or are stated as left to CI.
- [ ] `grep -c '^- ' ` over the rust guide's Learned patterns region equals 40 before and after
      (no bullet lost); each sub-list is under 25.
- [ ] Every rule above appears once, with its threshold, in the section named for it; nothing in
      section 7 restates a rule that Part D of the code-health skill states in stack-agnostic form
      beyond the clippy or Rust mechanism (point at Part D by name).

## Implementation Plan
Read the baseline and the rust guide in full, then the code-health skill (its Part D may already have
landed on `main`; if it has, cite its rule numbers; if not, write section 7 so it reads alone). Read
`bin/lesson-lint` before splitting the list. Keep each new rule to one or two sentences. Set the plan
file to `status: done`, run the local checks, rebase, bump, open the PR.

## Dependencies
- Blocked by: none · Related: code-health-structure-rules (Part D; merge order decides version numbers)

## Out of Scope
The python guides, the code-health skill, the oss-reviewer catalog and the readme-writer skill. Any
change to the audited repository.
