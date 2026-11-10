# tpm doc-edit rules

Binding rules for briefs, fix rounds and gate probes whose subject is prose that describes code: a
README, a rules or policy file, a doc comment, a skill file. Read with `briefing.md` before a brief
that prescribes, trims or moves such text, and with `review-probes.md` before the first gate on a PR
that changes it.

- When prescribing a doc reword, give the exact old and new text so the round closes on a diff
  proof; the new text states the rule only, never "pinned by <test>" or "confirmed against
  <version>"; any observed state it asserts (a package list, a count) is reproduced at the head
  first, not typed from the previous head; and a fragment replacement is written out as the whole
  resulting line, so a phrase the sentence already carries is not spliced in twice. The new line is
  no longer than the one it replaces and carries no fact another paragraph of the file holds: grep
  the file for each fact it states and put the detail in the paragraph that owns it.
- An explanatory clause added in a fix round to make a sample output fit is where an invented
  mechanism slips in; the brief prescribes the rule sentence from the code, a ticket-dictated
  rules-file sentence included, and the reviewer checks the database state at that step, not only
  the final output.
- When a code-economy finding trims a rules paragraph to a pointer, list the facts the pointed-to
  file does not hold and brief them kept; a rules file names every change that needs review, even a
  field that a description elsewhere already mentions.
- Brief every doc and rules-file edit to state what the code does without a cause clause (`because`,
  `which makes`, `as for any`) unless the cause was checked against the source; an unverified
  explanation is the next round's finding.
- Every doc-trim brief requires an empty diff once comment and doc lines are stripped, a moved
  list's new home that does not point back at the old one, and a re-read of the lead-in of every
  list it shortens; a brief that adds rule sentences to a README states each rule once, in the
  section that owns the type, with pointer bullets elsewhere.
- Brief every gate on a doc restructure or move to diff the set of sentences between base and head,
  not the layout: each dropped sentence has a new home or is a deletion the ticket asked for, and a
  figure another file cites is found at its new home.
- Reviewing a rules or policy file that describes code, compare every mechanism word ("literal table
  name", "aborts", "placeholder") against the line it describes at the head; text drafted from an
  earlier proposal keeps the wording of an implementation a later PR replaced.
- A README or doc bullet that restates an upstream dependency's guarantee is checked against the
  upstream's precondition and known-limitations sections; the downstream copy tends to drop the
  precondition.
- When a PR adds properties to a resource whose builder's doc comment lists the resulting state,
  compare that list with the property block at the head; README edits land, the API doc beside the
  code drifts.
- Before a fix brief prescribes a doc line, send the exact candidate to every gate that reads prose,
  the ones that passed included, and brief it only when each agrees; a line checked with the failing
  gates alone is another gate's finding in the next round.
- When a PR ties the form of a value to a setting of the entity that owns it, grep every doc, doc
  comment and skill line that states the form, not only the hunks, and require each to hold for
  every path that produces the value (scheduled, derived, manual); every section a rewritten
  sentence cites still carries the claim.
