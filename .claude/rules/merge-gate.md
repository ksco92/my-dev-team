Prose describing the merge gate states exactly what `hooks/merge-gate.sh` checks per form, including its exceptions for a PR with no reported checks and for skipped checks.
The ledger and the bypass file are writable by the model and are accepted risks, so the gate guards against mistakes, not against a hostile model.
A "not gated" statement about the merge gate names a class of forms, never a closed list.
Every gated subcommand is refused when it appears more than once in a command, and a subcommand added as a ledger-gated peer of merge joins the same trigger set.
The review gates' scope on hook changes is the forms an agent plausibly writes by mistake; a form outside that scope is recorded in the accepted-limits statement, not filed as a finding.
Prose about what the hook refuses or gates names `main` or `master`, the names the hook matches, never "the trunk".
A merge the hook detects as redirected with -C whose git prefix it cannot parse is denied, never left ungated.
