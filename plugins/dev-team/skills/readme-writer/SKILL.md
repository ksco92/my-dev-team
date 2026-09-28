---
name: readme-writer
description: Writes AND reviews project READMEs for correctness (anti-drift), structure, and discoverability (human SEO + AI/LLM consumption). Review mode is the 5th standing review gate on every PR; write mode creates or updates a README. Evidence-based — every rule below traces to verified research (2026-09) or the owner's house style.
---

# README Writer / Reviewer

Two modes. **WRITE** creates or updates a README. **REVIEW** is a standing review
gate (the 5th, alongside pr-reviewer / code-health / oss-reviewer /
security-review): findings-only, never modifies the repo, every finding blocks
per the owner's nits-block policy.

Everything here is grounded in adversarially-verified research (GitHub official
docs, the Standard README spec, GitHub's Open Source Survey, CSCW/EMSE empirical
studies, LLM-docs preprints) plus the owner's house style (arceus, eevee). Where
evidence is weak, this file says so instead of pretending.

## 1. Content baseline (what a README must answer)

GitHub's official five, plus license — an automated gate can check each is
answerable from the README alone:

1. **What** the project does (title + short description).
2. **Why** it is useful — the value proposition. Empirically the most common
   structural gap, and unclear goals cause outright rejection by prospective
   users/contributors (CSCW 2019: the README is "the project's welcome mat";
   every interviewed contributor evaluated it).
3. **How** to get started (install + a working first use).
4. **Where** to get help (docs links, issues).
5. **Who** maintains it + how to contribute.
6. **License** — visibly. 64% of users rate a license very important for using,
   67% for contributing; it was rated the single most important documentation.
   A missing LICENSE file is a BLOCKER for any public repo.

Also required: a **dated status paragraph** (project maturity, what's shipped,
what's not) — status/"is this alive?" is the second most-missed content class,
and README comprehensiveness measurably predicts new-contributor attraction
(9,977-repo npm regression).

## 2. Structure (the lintable ordering)

Derived from the Standard README spec (mechanically checkable: presence, order,
string equality), adapted to house style:

```
1. # Title                      == the package/crate name, exactly
2. Badge row                    (see §4 policy)
3. **Bold value proposition**   1-3 sentences, own paragraph: what + why + the
                                differentiator. A stranger decides here.
4. Short description alignment  the repo description (Repo description
                                operation) and the package manager description
                                field MUST match the README's one-line summary
                                (triple-match check — lintable)
5. Status (dated)               "Status (Month YYYY): ..." — maturity, channels
                                published, what's deliberately not done
6. Install                      every real channel (registry, binary, source),
                                each with a copy-pasteable code block
7. Quickstart / Usage           smallest COMPLETE working example: exact
                                install→import→call→output. Code blocks required.
8. Deeper sections              architecture map, benchmarks, docs pointers,
                                compatibility notes — project-specific
9. Contributing                 or a pointer to CONTRIBUTING.md
10. License                     LAST section, always
```

ToC required at ≥100 lines. Benchmarks, when present: only numbers from a
committed, regenerable report (link it), with environment + date + methodology
pointer — never hand-carried numbers (see §3).

**Audience rule.** Sections 1–7 are written for a *user of the published
artifact*: someone deciding in thirty seconds whether to install it, then
installing it. Contributor material — toolchain setup, the gate/CI table,
coverage-tool quirks, mutation-testing results, code reading paths through doc
comments, regeneration procedures — goes to `CONTRIBUTING.md` (or
`DEVELOPMENT.md` / the doc comments themselves) with ONE link from the
Contributing section. It never appears before Usage. A "Setup from scratch"
section that installs a toolchain is contributor material, not Install.

**Limitations** get their own section ("Known limitations" / "Compatibility")
placed after Usage: one line per limitation, the detail behind a link. The
value proposition and the status paragraph carry at most one caveat clause
between them; a README whose second sentence is a boundary case has the order
backwards.

**Length budget.** Target ≤250 lines. Exempt from the budget: user-facing
API reference (the arceus pattern: every export documented with an example)
and any table that shows the project's competitiveness — benchmarks,
comparisons against alternatives, feature matrices, measured data. Those
tables stay in the README in full; only their *methodology* moves to the
linked report. Everything else over budget links out rather than expanding.

**Multi-surface projects** (a library plus a CLI plus bindings): Install
lists each surface as its own one-liner, largest audience first; an
unpublished channel gets one line ("not yet published; from source:
`<one command>`"), never a toolchain tutorial. Quickstart shows one complete
example per surface in the same order. When the README doubles as the
registry long description (`readme =` in `pyproject.toml`, `readme` in
`Cargo.toml`, `README.md` picked up by npm), the first screen must make sense
to a reader on that registry's page — a pip user must not meet rustup first.

## 3. Correctness — anti-drift (the highest-weight review dimension)

Doc drift is the dominant measured failure mode in open source (GitHub survey:
93% of users hit incomplete/outdated docs; 60% of contributors never fix docs).
Rules, all reviewable:

- **Every checkable claim must trace to current repo state.** Commands must
  exist with the flags shown (`grep` the Makefile/CLI), gate/CI tables must
  match the actual targets, file paths and links must resolve, version/feature
  claims must match the manifests. In review mode, DIFF the README's claims
  against the PR's changes: a PR that changes behavior the README describes,
  without updating the README, is a HIGH finding.
- **Executable examples beat prose.** Rust: put README code under test with
  `#[doc = include_str!("../README.md")]` on a `#[cfg(doctest)]` item (official
  rustdoc pattern) so `cargo test` runs the README. Python: pytest-codeblocks
  runs python/sh blocks in CI. When the ecosystem supports it and the example is
  stable, WIRE IT; when not wired, the review must manually run the quickstart.
- **Numbers only from generated artifacts.** Perf/coverage/count claims cite the
  committed generated report (RESULTS.md-style) and match it exactly. A number
  that matches nothing in the repo record is a HIGH finding (this repo family
  has caught the same stale-number drift repeatedly — 12.4-vs-12.799 class).
- **The triple-match**: README one-liner == repo description (Repo description
  operation) == package manager description field. String-comparable; check all three.

## 4. Badges — signal, not fruit salad

Peer-reviewed evidence (EMSE 2020 npm study; 2024 100k-repo GAM study):
badges backed by real automated analysis ("assessment signals") correlate with
genuinely better projects; cheap info badges are noise; **more than ~5 badges
correlates with FEWER downloads** for popular packages.

- Allowed core set: CI status, coverage, registry version (one per registry
  actually published to), downloads, license. House style may add types /
  last-commit — total target ≤7, hard-question anything beyond.
- Every badge must RESOLVE and be truthful: a red/unknown/404 badge, or a badge
  for an unpublished registry, is a finding. No aspirational badges.
- Eligibility is mechanical: CI badge whenever a workflow runs on `main`
  (a repo with a workflow and no CI badge is a finding); coverage badge only
  when a coverage service is actually wired (no upload step → no badge);
  registry badges only once the package is live there; license and
  last-commit always available. A README with zero badges while a workflow
  exists has skipped this section.
- Badge row sits directly under the title (house style), one line per badge in
  source for reviewable diffs.

## 5. Discoverability — humans first, machines honestly

**Classic (verified, do all of it):** H1 exactly = the name a user installs
(when the repo or engine name differs from the package name, the package name
is the H1 and the repo/engine name goes in the first sentence — arceus is the
precedent: repo `arceus`, H1 `cdk-glue-iceberg-table`); the value proposition
contains the terms a searcher would use (what-it-is + ecosystem, e.g. "Rust",
"DeepDiff-compatible", "JSON diff"); repo description
filled (Repo description operation; triple-match §3); GitHub host: repo topics
set (do it via gh api, it's free); social-preview image optional but cheap.

**AI/LLM consumption (real concern, honest evidence):** verified: LLMs
systematically fail on under-documented libraries (~30% success on niche libs
across 5+ models) and a human-oriented README is NOT automatically good LLM
context (in some model/library pairs it performed worse than nothing). NOT
verified: that ReadMe.LLM/llms.txt formats deliver dramatic gains — those
claims failed adversarial verification; llms.txt adoption is real but efficacy
is unproven and major-engine support is absent. Therefore:
- DO the cheap, no-regret moves: a fully self-contained quickstart (exact
  install command, exact import, exact call, expected output — an agent can
  replicate without inference); explicit API-surface statements ("the public
  API is X, Y, Z"); state facts in prose rather than implying them; never put
  load-bearing information only in images; stable heading anchors.
- MAY add llms.txt (root file: one-paragraph project summary + links to the
  canonical docs) — cost ~10 minutes, unproven benefit, harmless. Don't claim
  it does more than that.
- DON'T contort the human README for hypothetical machine gains — the verified
  finding is that completeness and explicitness help both audiences.

## 6. WRITE mode procedure

1. Read the repo first: manifests, Makefile/CI, CLI --help output, existing
   docs, published channels, the generated reports. The README is a projection
   of repo state — never write a claim you didn't verify.
2. Sort every candidate paragraph by audience (§2 audience rule) BEFORE
   drafting: user-facing stays, contributor-facing goes to `CONTRIBUTING.md`
   (create it in the same change if it does not exist). Then draft in the §2
   order, house voice: bold value-prop opening (see the owner's arceus/eevee
   READMEs — declarative, specific, no marketing fluff, inviting: lead with
   what the reader can do, not with what the tool cannot), dated status,
   install-every-channel, smallest-complete quickstart, limitations after
   Usage. Check the length budget last and link out, never compress prose
   into denser prose.
3. Wire executable examples (§3) where the ecosystem supports it.
4. Set/verify repo description + topics + package description (triple-match).
5. Self-review with the §7 checklist before handing off.

## 7. REVIEW mode procedure (the gate)

Findings-only report, file:line, severity (BLOCKER/HIGH/MEDIUM/LOW/NIT). Never
modify the repo. On a PR, scope = the README(s) + every PR change that touches
behavior any README describes. Full mode (pre-release/audit) = the whole README
against the whole repo.

Checklist (each item is a concrete check):
- [ ] Six baseline answers present (§1); value proposition within first screen
- [ ] Dated status paragraph exists and is ≤90 days stale (or event-current)
- [ ] Section order per §2; License last; ToC if ≥100 lines
- [ ] Install + Usage have copy-pasteable code blocks; quickstart is COMPLETE
      (run it, or confirm it's under doctest/codeblocks CI)
- [ ] Examples run in the README's own section order from a fresh state, never
      the order a section implies; a new refusal paragraph is checked against
      the untouched examples around it
- [ ] Anti-drift sweep (§3): commands/flags exist; gate/CI tables match the
      Makefile/workflows; links resolve; numbers match generated reports;
      PR-diff vs README-claims cross-check
- [ ] Triple-match: README one-liner == repo description == package description
- [ ] Badges: all resolve, all truthful, count ≤7, assessment-class
- [ ] LICENSE file exists and README names it (public repos: BLOCKER if not)
- [ ] Discoverability: H1 = package name; topics set; searcher terms present
- [ ] No load-bearing info only in images; quickstart self-contained enough
      for an LLM agent to replicate without inference
- [ ] Audience and length (§2): no contributor material (toolchain setup,
      gate tables, coverage/mutation internals, code reading paths) before
      Usage or outside a single Contributing link — MEDIUM; benchmark
      methodology inline instead of linked — MEDIUM; limitations in the
      opening paragraph or ahead of the quickstart — MEDIUM; over the line
      budget without the API-reference or competitiveness-table exemption —
      MEDIUM; on a multi-surface project, the first screen unusable for the
      registry that renders this README — HIGH

## 8. House style (owner's fingerprint — from arceus/eevee)

- Opening: **bold, specific, one-to-three-sentence value proposition** naming
  the exact artifact and its differentiator ("X is the Y that Z — no A, no B").
- "Status (Month YYYY):" paragraph with real channels and real caveats.
- Install lists every real channel with its one-liner.
- Links point INTO the repo (spec/, packages/, docs/) — the README is a hub,
  not a silo.
- Honest limitations: a one-line pointer inline where a user would hit one,
  the full list in a "Known limitations" section after Usage (arceus), never
  in the opening paragraph and never ahead of the quickstart.
- Length comes from user-facing reference (arceus: 649 lines, almost all API
  and FAQ), never from contributor internals; eevee says everything a user
  needs in 99 lines and links the rest.

## Self-mutation rule

This file is maintained by the **orchestrating session only** — never by a
delegated subagent or headless worker, even one instructed to read it. Durable
lessons from real README work: append a dated bullet under `## Learned
patterns`, refine near-duplicates in place, keep the research grounding honest
(if new evidence overturns §4/§5 claims, update the section, don't stack
contradicting bullets). Open a PR against the plugin repository (`ksco92/my-dev-team`).

## Learned patterns

<!-- dated learned-pattern bullets get appended here -->

<!-- Learned patterns (orchestrating session lands these; subagents propose only) -->
- When reviewing a punctuation/em-dash-reduction pass, specifically check every double-dash
  parenthetical whose enclosed text contains its own commas: converting that pair to commas is
  the one dash substitution that reliably produces list-like misparse ambiguity while staying
  technically grammatical. Prescribe parentheses or restructuring there, never a comma pair.
- 2026-09-02: The anti-drift and completeness rules pull toward a contributor manual unless the
  audience rule and the length budget pull back. A README whose first user-facing example sits
  below a doc-comment reading path, a toolchain install, and a 60-line limitations list has
  satisfied every correctness check and failed the reader; the gate now scores audience and
  length (§7) so that shape is a finding, not a pass.
