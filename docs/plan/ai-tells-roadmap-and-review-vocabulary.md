---
difficulty: medium
priority: p1
status: done
---

## Context
A full-scope audit of a public Rust+Python repository found about 38 pipeline-vocabulary leaks and
about 78 history-narration sites that the oss-reviewer catalog's existing entries did not match: the
regexes are narrower than the common variants ("used to return", "that slice's", "Round-2", "MVP",
"this fix", "per the\nbrief" across a line break, a private rule file named by its basename), and five
tell families have no entry (roadmap-phase words, untracked-plan authority, agent and review
vocabulary beyond role nouns, a results document grading the change against its own target, a config
file that is mostly the tool's template comments).

## Requirements
- [ ] `skills/oss-reviewer/references/ai-tells.md`: five new entries numbered from the highest existing
      `### 4.N` plus one (grep for it; the file has duplicate and out-of-order numbers, so take the
      maximum), each in the catalog's own entry shape (name and severity, pattern as regex or
      structure, Exclude line, Severity line with one-sentence why, Added-by line):
      roadmap-phase vocabulary in shipped prose ("MVP", "POC", "in this version", "for now",
      "later versions add", "implemented so far", "would be added the same way", "temporary bridge",
      "interim", "stopgap"); untracked-plan or private-rule authority cited in tracked prose ("this
      harness's own rule", "per the brief" including across a line break, "marked nice-to-have, not
      required", "originally envisioned", a private rule file named by basename, a coding-guide
      named by file name); agent and review vocabulary in tracked prose ("foreground session", "fix
      round", "Round-2", "found during review", "review follow-up", "this fix's reviewed scope",
      "merged head", "the <x> finding" naming a behaviour); a results document grading the change
      against its own target ("the target of this change is met", "within the Nx-of-<tool> target");
      a config file over 50% comment lines whose comments match the tool's `init` output (cross-ref
      beyond-source §5.11 and state the threshold there too).
- [ ] Sharpen the existing entries' patterns, each as an added regex line or an added sentence in the
      entry, never a rewrite: §4.1 (`this fix('s)?`, `issue #\d+'s .{0,20}requirement`, "acceptance
      example", "this issue is about", "per the brief" across line breaks); §4.26 (the same doc
      sentence on three or more helpers in one file, a two-file template pair restating a third, four
      sibling item docs differing by one word); §4.36 ("implemented so far", "would be added the same
      way", "a candidate follow-up", "natural follow-up"); §4.86 (any future-tense condition in a
      comment: "until CI exists", "will need once #N", checked against the tree and tracker); §4.87
      (revert-and-rerun proofs: "confirmed by temporarily", "by temporarily forcing", "reverting ...
      reproduces", "tried while developing", "smallest size found", "confirmed by applying ... by
      hand"); §4.109 (short milestone tags `\b[mM]\d+\b` in comments or cited filenames; no digit
      requirement for "temporary"/"interim"); §4.110 and §4.141 (full-scope mode diffs a renderer's
      literals against the document it generates and opens every "see <file>'s docstring for
      <artifact>" pointer, intra-file included); §4.112 ("found during review", "review follow-up",
      `\bround[- ]?\d+\b`, "the <x> finding"); §4.114 (applies to code: a "see X's doc for why"
      pointer between items is opened and the target must carry the reason; README pointers name a
      public item or a heading, never "the hashing functions in <file>"); §4.115 (full-scope mode
      diffs every closed type enumeration in a doc against the match arms it documents, and "both" or
      "the two" against the enum's variant count); §4.118 (`\b(next|this|that|the|each|a)\s+slice'?s?\b`
      outside code spans); §4.119 (also grep the bare basename of every untracked agent-rule file
      against the tracked tree); §4.122 (a bare numeral before quirks, exceptions, divergences,
      differences or consequences; numerals summarising another file's list; "Step N" and "section N"
      pointers recounted in the target); §4.126 (`\bthe (one|only) place\b`); §4.131 (the wider history
      regex: "used to", "previously", "the old <path|algorithm|form|port|ceiling>", "pre-fix", "before
      the fix", `pre-#?\d+`, "Regression test for", "has always", "predates", "now also", "is now
      covered", "stored exactly as before", "this replaces", "keeps working unchanged", "switched to",
      "(grew|shrank|went) from N to M", "earlier version", "at the time this crate landed"; and test
      names containing `_now_` or `_old_`); §4.132 ("doubles as the ... regression", "the fix
      targeted", "the bug this", "the reported repro", "headline defect", "once already").
- [ ] Every regex is tested once with `grep -E` against a scratch file holding one positive and one
      negative line per pattern (write the scratch file in your worktree's untracked space, do not
      commit it); paste the command and result in the PR body.
- [ ] `skills/oss-reviewer/SKILL.md` is procedure-only and does not change.
- [ ] Register per `CLAUDE.md` for the entry prose; Added-by lines carry the date in the catalog's own
      format. The PR body carries evidence per entry (file:line examples from the audit report named
      in the brief).
- [ ] Version: one patch step above `main`'s at the final rebase; the orchestrator names it.

## Acceptance Criteria
- [ ] `plugins/dev-team/bin/lesson-lint --added origin/main $(git ls-files 'plugins/dev-team/*.md')` exits 0
      (the catalog is not a Learned-patterns file; confirm the tool ignores it or passes).
- [ ] Both `claude plugin validate` commands pass or are stated as left to CI;
      `bash plugins/dev-team/tests/evals.test.sh` passes and the `oss-reviewer-ai-tells` eval case's
      expectations still hold (read `plugins/dev-team/evals/`).
- [ ] No existing entry's number changes; the five new numbers are unique and consecutive after the
      current maximum.
- [ ] Every new or sharpened regex has a tested positive and negative line in the PR body.

## Implementation Plan
Read the catalog's last 40 entries for the current register and the numbering state, then
`beyond-source.md` §5.11. Add the five entries at the end; sharpen in place. Keep each entry under
about 25 lines. Set the plan file to `status: done`, run the checks, rebase, bump, open the PR.

## Dependencies
- Blocked by: none · Related: the other plugin slices of this batch (merge order decides version numbers)

## Out of Scope
The code-health skill, the guides, the readme-writer skill; the audited repository.
