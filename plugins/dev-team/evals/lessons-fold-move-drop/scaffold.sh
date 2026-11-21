#!/usr/bin/env bash
# Lays a plugin-shaped repository under plugin-repo/ (one commit on main) whose orchestrator
# references hold three bullets: a Python rule a guide section treats without stating it, a rule
# the tpm skill's Phase 5 already states, and a rule tests/skill-frontmatter.test.sh enforces.
set -euo pipefail
p=plugin-repo/plugins/dev-team
mkdir -p "$p/skills/tpm" "$p/agents" "$p/context/tpm" "$p/tests"

cat >"$p/skills/tpm/SKILL.md" <<'EOF'
---
name: tpm
description: Orchestrator. Splits a request into slices, briefs implementers, runs the review gates, and merges.
---

# Orchestrator

## Phase 4 — Delegation

Before the first brief of a run, read `${CLAUDE_PLUGIN_ROOT}/context/tpm/briefing.md`; it is binding
on every brief.

## Phase 5 — Gates and merge

Read `${CLAUDE_PLUGIN_ROOT}/context/tpm/gates.md` and
`${CLAUDE_PLUGIN_ROOT}/context/tpm/review-probes.md` before the first gate of a run.

Before every merge, whatever its form, run the Check ledger operation and require it to pass. Then
merge with the process file's Merge operation.
EOF

cat >"$p/agents/implementer.md" <<'EOF'
---
name: implementer
description: Implements one slice end to end, with its tests.
---

# Implementer

Read `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md` now; it is your binding operating contract.

## Learned patterns

- Run the formatter on every file you touched before committing.
EOF

cat >"$p/agents/pr-reviewer.md" <<'EOF'
---
name: pr-reviewer
description: Correctness gate for a pull request.
---

# PR Reviewer

Read the stack guide in `${CLAUDE_PLUGIN_ROOT}/context/` for each stack the PR touches; its sections
and its `## Learned patterns` are review criteria.
EOF

cat >"$p/context/agent-baseline.md" <<'EOF'
# Implementer Baseline

## Before writing code

1. Read the ticket; its acceptance criteria are your contract.
2. Load the stack guide for every layer the task touches:
   `${CLAUDE_PLUGIN_ROOT}/context/<stack>-coding-guide.md`.

## Learned patterns

- After every rebase onto main, diff your version fields against `origin/main`; identical values
  merge with no conflict marker.
EOF

cat >"$p/context/policy.md" <<'EOF'
# Harness policy

| Task involves | Read first |
| --- | --- |
| Python | `python-coding-guide.md` |

## Where lessons go (binding)

A lesson's home is decided by one test: _would it be true in a different repo?_ A lesson true in one
repo goes to that repo's `.claude/rules/<topic>.md`. State the rule, not the incident: one
imperative sentence, two at most, no date, no repo or PR name.
EOF

cat >"$p/context/python-coding-guide.md" <<'EOF'
# Python Coding Guide

## Error handling

### Exception messages

Start an exception message with a lowercase phrase that states the failed condition, with no
trailing period: `raise ValueError("limit must be positive")`.

### Exception clauses

Catch the narrowest exception type the block can raise; never a bare `except:`.

## Learned patterns

- Prefer `pathlib.Path` over `os.path` in new code.
EOF

cat >"$p/context/tpm/briefing.md" <<'EOF'
# tpm briefing rules

Binding rules for every brief the orchestrator writes.

- Name in every `low` brief the existing test file to copy, by its path.
- When a brief covers Python code that raises, require each exception message to name the value it
  rejected with `!r`, as in `got {limit!r}`.
- Give every brief the branch name from the process file's Branch name operation.
EOF

cat >"$p/context/tpm/gates.md" <<'EOF'
# tpm gate rules

Binding rules for running the review gates and merging.

- Read each gate's evidence, not only its verdict header; one grep of the head decides a disputed
  claim.
- Before every merge, run the Check ledger operation and require it to pass.
EOF

cat >"$p/context/tpm/review-probes.md" <<'EOF'
# tpm review-probe rules

Binding rules for the probes a gate brief prescribes.

- Have every gate on a skill change check that each `skills/*/SKILL.md` opens with frontmatter that
  carries a `description:` line.
- When a PR changes a shell script, brief the gate to run `shellcheck` on it at the head.
EOF

cat >"$p/tests/skill-frontmatter.test.sh" <<'EOF'
#!/usr/bin/env bash
# Every skills/*/SKILL.md opens with frontmatter that carries a description line.
set -uo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
status=0
for f in "$root"/skills/*/SKILL.md; do
  if [[ "$(head -n 1 "$f")" != "---" ]] || ! sed -n '2,/^---$/p' "$f" | grep -q '^description: .'; then
    echo "FAIL: ${f#"$root"/} has no description in its frontmatter"
    status=1
  fi
done
(( status == 0 )) && echo "PASS"
exit "$status"
EOF
chmod +x "$p/tests/skill-frontmatter.test.sh"

git -C plugin-repo init -q -b main
git -C plugin-repo -c user.name=fixture -c user.email=fixture@example.com add -A
git -C plugin-repo -c user.name=fixture -c user.email=fixture@example.com commit -qm "Import the plugin"
