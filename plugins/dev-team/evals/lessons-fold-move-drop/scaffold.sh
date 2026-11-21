#!/usr/bin/env bash
# Lays a plugin-shaped repository under plugin-repo/ (one commit on main) holding three bullets: a
# Python rule in an orchestrator reference that a guide section treats without stating it, a guide
# bullet that a sentence of the same guide states, and a rule a test run by the tree's CI enforces.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
p=plugin-repo/plugins/dev-team
mkdir -p plugin-repo/.github/workflows "$p/bin" "$p/skills/tpm" "$p/agents" "$p/context/tpm" "$p/tests"

cp "$here/../../bin/lesson-lint" "$p/bin/lesson-lint"

cat >plugin-repo/.github/workflows/ci.yml <<'EOF'
name: CI
on: [pull_request, push]
jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: bash plugins/dev-team/tests/skill-frontmatter.test.sh
EOF

cat >"$p/skills/tpm/SKILL.md" <<'EOF'
---
name: tpm
description: Orchestrator. Splits a request into slices, briefs implementers, and runs the review gates.
---

# Orchestrator

## Phase 4 — Delegation

Before the first brief of a run, read `${CLAUDE_PLUGIN_ROOT}/context/tpm/briefing.md`.

## Phase 5 — Gates

Before the first gate of a run, read `${CLAUDE_PLUGIN_ROOT}/context/tpm/review-probes.md`.
EOF

cat >"$p/agents/implementer.md" <<'EOF'
---
name: implementer
description: Implements one slice end to end, with its tests.
---

# Implementer

Read `${CLAUDE_PLUGIN_ROOT}/context/agent-baseline.md` now; it is your binding operating contract.
EOF

cat >"$p/context/agent-baseline.md" <<'EOF'
# Implementer Baseline

## Before writing code

1. Load the stack guide for every layer the task touches:
   `${CLAUDE_PLUGIN_ROOT}/context/<stack>-coding-guide.md`.
EOF

cat >"$p/context/python-coding-guide.md" <<'EOF'
# Python Coding Guide

## Error handling

### Exception messages

Start an exception message with a lowercase phrase that states the failed condition, with no
trailing period: `raise ValueError("limit must be positive")`.

### Exception clauses

Catch the narrowest exception type the block can raise, and never write a bare `except:`.

## Learned patterns

- Never write a bare `except:`; catch the narrowest exception type the block raises.
EOF

cat >"$p/context/tpm/briefing.md" <<'EOF'
# tpm briefing rules

Binding rules for every brief the orchestrator writes.

- When a brief covers Python code that raises, require each exception message to name the value it
  rejected with `!r`, as in `got {limit!r}`.
EOF

cat >"$p/context/tpm/review-probes.md" <<'EOF'
# tpm review-probe rules

Binding rules for the probes a gate brief prescribes.

- Have every gate on a skill change check that each `skills/*/SKILL.md` opens with frontmatter that
  carries a `description:` line.
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
