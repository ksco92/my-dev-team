---
difficulty: high
priority: p1
status: done
---

## Context

Every finding blocks, and the usual fix for a finding is to add something: a guard, a validation, a
test for an input, a sentence. A whole-repository audit that followed a gated run removed more
source than the run had added, and every line it removed had passed the five gates. The owner
decided that a finding whose fix is added code blocks only when the gate shows the case can happen.

## Requirements

- [x] The rule, stated once in `context/reviewer-baseline.md` and binding on all five gates: a
      finding that asks for added code (a guard, a validation, a fallback, a defensive copy, or a
      test for an input) blocks only with a reproducer, which is the input reaching the code through
      the project's public interface, shown as a failing test, a command with its output, or the
      calling line. A gate that cannot show one lists the item under an `UNREPRODUCED` heading after
      its findings; such an item is not counted in `FINDINGS` and does not change the verdict.
- [x] The same file states what the rule leaves alone, as a closed list: wrong behaviour the diff
      shows, a false statement in documentation or the change body, a failed acceptance criterion of
      the ticket (a test the ticket names included), a request to remove or shorten, and a style or
      register finding. Each still blocks with no reproducer.
- [x] For the security gate the reproducer is the path to the code from where an input an untrusted
      party controls enters the repository, cited line by line; a working exploit is not required,
      and a finding with such a path blocks as it does today.
- [x] Each gate's output format (the five agent files and the three gate skills) carries the
      `UNREPRODUCED` section in the same position and form, after the verdict block's findings; the
      verdict block itself keeps its lines.
- [x] `context/policy.md`, Merge authority and gating: "Every finding from every gate is fixed,
      never waived" is amended to exclude an unreproduced item, which is filed and not fixed.
      `policy.md` grows by at most 450 characters net.
- [x] `skills/tpm/SKILL.md`: 5.2 keeps unreproduced items out of the fix brief; 5.3 has the
      orchestrator file them before every merge, a round where every gate passed included, one
      follow-up per change, through the File a follow-up operation with a title that starts `Audit:`
      (the prefix the `audit` skill reads). The contract's File a follow-up row names this second
      caller. The file does not pass its limit of about 350 lines.
- [x] `context/tpm/gates.md`, the bullet for a run whose purpose is removal: a request the owner's
      threat model covers, or that an untrusted caller can reach, is decided by the baseline's
      reproducer rule as in any other run, so the two rules cannot give different answers for one
      finding; the rest of that bullet is unchanged.
- [x] `context/tpm/findings.md`: one bullet, that the orchestrator moves an unreproduced item into a
      fix brief only by producing the reproducer itself, and that a gate which lists a reproduced
      finding as unreproduced, or the reverse, re-issues its verdict.
- [x] `tests/verdict-guard.test.sh`: a gate result with zero findings, a `PASS` verdict and a
      populated `UNREPRODUCED` section passes the guard; a result whose `FINDINGS` count includes
      the unreproduced items is handled as a count mismatch is handled today.

## Acceptance Criteria

- [x] All requirements verifiable from the files and the test scripts
- [x] Every local check in `CLAUDE.md` passes
- [x] `git diff origin/main...HEAD -- plugins/dev-team/evals` is empty
- [x] `grep -rn "UNREPRODUCED" plugins/dev-team` names the baseline, the five agent files or their
      skills, the tpm skill, and the guard's test, and no file states the rule a second time in
      other words
- [x] `wc -c plugins/dev-team/context/policy.md` is at most 450 above its size on the base

## Implementation Plan

The decision to weigh is where each sentence lives so the rule is stated once: the baseline holds
the rule and its closed list, the agent files and skills hold only the output section and a pointer,
the policy holds the one-clause amendment, the tpm skill holds what the orchestrator does with the
items. `skills/code-health/SKILL.md` already prints a non-blocking "Out-of-hunk ledger"; take its
form for the new section and check the two do not overlap. Read `hooks/verdict-guard.sh` before
choosing the section's heading so the guard's block parsing is not disturbed; the hook itself should
need no edit. The version takes a minor bump in the final rebase.

## Dependencies

- Blocked by: audit-skill-and-cold-reader (it defines the `Audit:` prefix; develop in parallel,
  merge after it) · Blocks: none

## Out of Scope

Which gates run on a change; the ledger; any reduction of what the security gate reviews; a change
to `hooks/merge-gate.sh`. An eval case: a case with a tempting null check on an internal function
was built in two shapes, and the reviewer without the rule did not raise the check in any run, so
the case passed on both sides of the change and was removed.
