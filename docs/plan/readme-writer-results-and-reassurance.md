---
difficulty: medium
priority: p2
status: done
---

## Context
A full-scope audit of a public repository found README and results-document defects the readme-writer
review gate has no rule for: Known-limitations bullets reassuring the reader about frequency ("rare in
practice", "far beyond any real schema"), a section vouching for its own fidelity ("every figure here
is copied verbatim"), a pointer linking to the section it sits in, a 303-word Performance paragraph
narrating per-release deltas, a 729-line results document laid out as a per-issue changelog with an
Environment table naming an older version than its later sections, a 145-line prose catalogue of test
cases, a hand-kept index paragraph repeating the document's own headings (and miscounting them), two
headings in one file sharing text, and rustdoc link syntax in markdown.

## Requirements
- [ ] `skills/readme-writer/SKILL.md` section 3 (Correctness, anti-drift) or section 2 (Structure),
      whichever fits each rule, gains these rules in one or two imperative sentences each: a
      Known-limitations bullet carries no reassurance about frequency or likelihood; a section never
      vouches for its own fidelity or process; a pointer never links to the section it sits in, and a
      same-document word ("above", "below") is false across a file boundary; the Performance section
      carries the current release's numbers only, with per-release deltas left to a changelog; a
      results document (RESULTS, MUTANTS and the like) holds one current table per measured shape plus
      a method pointer, drops before/after columns and per-release sections once a newer run
      supersedes them, and its Environment table names the version of every table it holds; a document
      does not enumerate test or fixture cases in prose (a prefix-to-purpose table plus a pointer at
      the generator); a hand-kept index that repeats the document's own headings is replaced by the
      headings; no two headings in one file share text; no rustdoc intra-doc link syntax in markdown.
- [ ] Section 7 (REVIEW mode): the gate applies the results-document rules to every tracked `*.md`
      the diff touches that holds a measurement table, not only README.md, and re-counts any numeral
      that summarises a list in another file.
- [ ] The skill's `## Learned patterns` list (2 bullets today) gains at most two bullets; the rest land
      as section prose.
- [ ] Register per `CLAUDE.md`; the PR body carries evidence per rule under "Each rule and the evidence
      it came from" with file:line examples from the audit reports named in the brief.
- [ ] Version: one patch step above `main`'s at the final rebase; the orchestrator names it.

## Acceptance Criteria
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')` exits 0.
- [ ] Both `claude plugin validate` commands pass or are stated as left to CI;
      `bash plugins/dev-team/tests/evals.test.sh` passes and the `readme-writer-doc-drift` eval case's
      expectations still hold (read `plugins/dev-team/evals/`).
- [ ] Every rule above appears once with its threshold where one is stated; the skill's section
      numbering is unchanged.

## Implementation Plan
Read the skill in full; its section 3 already carries anti-drift rules, so most additions are
refinements of existing bullets. Decide per rule whether it is correctness (section 3) or structure
(section 2) and say so in the PR body. Set the plan file to `status: done`, run the checks, rebase,
bump, open the PR.

## Dependencies
- Blocked by: none · Related: the other plugin slices of this batch (merge order decides version numbers)

## Out of Scope
The code-health skill, the guides and the oss-reviewer catalog; the audited repository.
