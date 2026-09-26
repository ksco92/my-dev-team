#!/usr/bin/env bash
# shellcheck disable=SC2016 # fixture bullets quote Markdown code spans
# Tests for bin/lesson-lint. Run: bash plugins/dev-team/tests/lesson-lint.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LINT="$PLUGIN/bin/lesson-lint"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

pass=0
fail=0
check() {
  if [[ "$2" == "$3" ]]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    printf 'FAIL: %s\n  expected: %s\n  actual:   %s\n' "$1" "$3" "$2"
  fi
}

# One bullet per call, placed in a skill file's Learned patterns section.
lint_bullet() {
  printf '# Skill\n\n## Learned patterns\n\n- %s\n' "$1" >"$TMP/SKILL.md"
  (cd "$TMP" && "$LINT" SKILL.md 2>&1)
}
expect_rule() {
  local out rc
  out="$(lint_bullet "$2")"; rc=$?
  check "$1: exit 1" "$rc" "1"
  check "$1: reports $3" "$out" "SKILL.md:5: $3: $(cut -c1-60 <<<"$2")"
}
expect_clean() {
  local out rc
  out="$(lint_bullet "$2")"; rc=$?
  check "$1: exit 0" "$rc" "0"
  check "$1: no output" "$out" ""
}

expect_clean "a one-sentence rule" "Run the check before merging."
expect_clean "two sentences" "Run the check. Then merge."
expect_clean "periods inside backticks are not sentences" 'Use `a. b. c.` here. Then stop.'
expect_clean "a period not followed by a space" "Pin the version to v1.2.3 exactly."
expect_clean "allowed claude paths" 'Read `~/.claude/DEV_PROCESS.md`, `~/.claude/gate-ledger/x`, `~/.claude/settings.json`, and `~/.claude/projects/p`.'
expect_clean "an alias is not a versioned id" "Run the gate on opus, never sonnet."
expect_clean "a PR body is not an incident tail" "Describe shortcuts in a PR body."
expect_clean "a gate name after in PR is not an incident tail" "Run the check in pr-reviewer."
expect_clean "a starting backtick" '`gh pr checks` is the CI status.'
expect_rule "three sentences" "One. Two. Three." sentences
expect_rule "an ISO date" "Rebase first, seen on 2026-09-02." date
expect_rule "a month and year" "Rebase first since March 2026." date
expect_rule "a month, day, and year" "Rebase first since Sep 2, 2026." date
expect_rule "a hash reference" "Rebase first, see #12." ticket
expect_rule "a PR number" "Rebase first as PR 12 did." ticket
expect_rule "an issue number" "Rebase first per issue 12." ticket
expect_rule "a versioned claude id" "Run claude-opus-4 for gates." model-id
expect_rule "a versioned opus id" "Run Opus-4 for gates." model-id
expect_rule "a versioned sonnet id" "Run sonnet-4 for gates." model-id
expect_rule "a claude path outside the list" 'Read `~/.claude/context/x.md` first.' claude-path
expect_rule "a claude path after an allowed one" 'Read `~/.claude/settings.json` and `~/.claude/hooks/x.sh`.' claude-path
expect_rule "added after" "Rebase first, added after a failed merge." incident
expect_rule "after observing" "Rebase first after observing a failure." incident
expect_rule "observed in" "Rebase first, as observed in the CI run." incident
expect_rule "in PR" "Rebase first, as in PR twelve." incident
expect_rule "learned from" "Rebase first, learned from a failure." incident
expect_rule "a lower-case start" "rebase first." lowercase

# Two rules on one bullet print two lines.
out="$(lint_bullet "rebase first per issue 12.")"
check "one line per failed rule" "$out" "$(printf 'SKILL.md:5: ticket: rebase first per issue 12.\nSKILL.md:5: lowercase: rebase first per issue 12.')"

# The report truncates the bullet to its first 60 characters.
long="Rebase first per issue 12 and then keep writing well past the sixty character cut."
check "the report truncates at 60 characters" "$(lint_bullet "$long")" "SKILL.md:5: ticket: ${long:0:60}"

# Duplicates, continuation lines, scope, and fences.
cat >"$TMP/scope.md" <<'MD'
# Guide

- Outside the section: one. two. three. four.

## Learned patterns

- Keep the  rule
  short.
- Keep the rule short.
- A rule wrapped. Over two
  lines. Is three sentences.

```
- Inside a fence. One. Two. Three.
```

## Next

- After the section. One. Two. Three.
MD
out="$(cd "$TMP" && "$LINT" scope.md 2>&1)"
check "scope: exit 1" "$?" "1"
check "scope: duplicates after whitespace normalization, a wrapped bullet, nothing outside" "$out" \
  "$(printf 'scope.md:7: duplicate: Keep the rule short.\nscope.md:9: duplicate: Keep the rule short.\nscope.md:10: sentences: A rule wrapped. Over two lines. Is three sentences.')"

# A context/tpm file is linted in full, without a Learned patterns heading.
mkdir -p "$TMP/context/tpm"
printf '# tpm rules\n\nIntro. Prose. Here. Too.\n\n- rule one.\n' >"$TMP/context/tpm/x.md"
check "tpm file: every top-level bullet" "$(cd "$TMP" && "$LINT" context/tpm/x.md 2>&1)" "context/tpm/x.md:5: lowercase: rule one."

# Budgets: a warning on stderr, never a failure.
budget_file() {
  mkdir -p "$(dirname "$TMP/$1")"
  { printf '# F\n\n## Learned patterns\n\n'; for ((i = 1; i <= $2; i++)); do printf -- '- Rule %d.\n' "$i"; done; } >"$TMP/$1"
}
budget_case() {
  local out rc
  budget_file "$2" "$3"
  out="$(cd "$TMP" && "$LINT" "$2" 2>&1 >/dev/null)"; rc=$?
  check "$1: exit 0" "$rc" "0"
  check "$1: stderr" "$out" "$4"
}
budget_case "agent at 20" agents/a.md 20 ""
budget_case "agent over 20" agents/a.md 21 "agents/a.md: warning: budget: 21 bullets, budget 20"
budget_case "skill over 20" skills/s/SKILL.md 21 "skills/s/SKILL.md: warning: budget: 21 bullets, budget 20"
budget_case "stack guide at 25" context/rust-coding-guide.md 25 ""
budget_case "stack guide over 25" context/rust-coding-guide.md 26 "context/rust-coding-guide.md: warning: budget: 26 bullets, budget 25"
budget_case "baseline over 25" context/agent-baseline.md 26 "context/agent-baseline.md: warning: budget: 26 bullets, budget 25"
rm -f "$TMP/context/tpm/x.md"
budget_case "tpm at 30" context/tpm/x.md 30 ""
budget_case "tpm over 30" context/tpm/x.md 31 "context/tpm/x.md: warning: budget: 31 bullets, budget 30"

# --added lints only bullets with an added line, against the merge base.
repo="$TMP/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
printf '# A\n\n## Learned patterns\n\n- old rule. One. Two.\n- Kept rule.\n' >"$repo/a.md"
git -C "$repo" add a.md && git -C "$repo" -c user.name=t -c user.email=t@t commit -qm base
git -C "$repo" checkout -qb feature
printf '# A\n\n## Learned patterns\n\n- old rule. One. Two.\n- Kept rule,\n  now wrapped see #7.\n- New rule.\n- new rule.\n' >"$repo/a.md"
out="$(cd "$repo" && "$LINT" --added main a.md 2>&1)"
check "--added: exit 1" "$?" "1"
check "--added: an edited continuation line and a new bullet, not the old bullet" "$out" \
  "$(printf 'a.md:6: ticket: Kept rule, now wrapped see #7.\na.md:9: lowercase: new rule.')"
git -C "$repo" -c user.name=t -c user.email=t@t commit -qam feature
git -C "$repo" checkout -q main
printf '# A\n\n## Learned patterns\n\n- Old rule.\n- Kept rule.\n' >"$repo/a.md"
git -C "$repo" -c user.name=t -c user.email=t@t commit -qam main-moves
git -C "$repo" checkout -q feature
check "--added: a bullet main has since edited is not an addition" "$(cd "$repo" && "$LINT" --added main a.md 2>&1 | wc -l | tr -d ' ')" "2"
git -C "$repo" checkout -q main
out="$(cd "$repo" && "$LINT" --added main a.md 2>&1)"
check "--added: no additions, exit 0" "$?" "0"
check "--added: no additions, no output" "$out" ""
check "--added: works from another directory" "$("$LINT" --added main "$repo/a.md" 2>&1)" ""

# Usage errors exit 2.
for argv in "" "--added" "--added main" "--bogus x.md" "$TMP/missing.md"; do
  read -ra words <<<"$argv"
  "$LINT" "${words[@]+"${words[@]}"}" >/dev/null 2>&1
  check "'lesson-lint $argv' exits 2" "$?" "2"
done
(cd "$repo" && "$LINT" --added nosuchref a.md >/dev/null 2>&1)
check "an unknown base ref exits 2" "$?" "2"

echo "$pass passed, $fail failed"
(( fail == 0 ))
