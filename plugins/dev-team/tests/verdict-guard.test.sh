#!/usr/bin/env bash
# Tests for hooks/verdict-guard.sh, fed SubagentStop-shaped JSON on stdin.
# Run: bash plugins/dev-team/tests/verdict-guard.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

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

SHA=0123456789abcdef0123456789abcdef01234567
block() { printf 'GATE: pr-reviewer\nVERDICT: %s\nHEAD: %s\nFINDINGS: %s' "${1:-PASS}" "${2:-$SHA}" "${3:-0}"; }
LACKS="verdict-guard: your last message lacks the line(s)"

# run <agent_type> <stop_hook_active> <message>: prints "<exit> <stderr>".
run() {
  local err rc
  err="$(jq -n --arg a "$1" --argjson s "$2" --arg m "$3" \
    '{agent_type: $a, stop_hook_active: $s, last_assistant_message: $m}' \
    | bash "$PLUGIN/hooks/verdict-guard.sh" 2>&1 >/dev/null)"
  rc=$?
  printf '%s %s' "$rc" "$err"
}
code() { run "$1" "$2" "$3" | cut -d' ' -f1; }

check "complete block" "$(run pr-reviewer false "$(block)")" "0 "
check "FAIL verdict" "$(code pr-reviewer false "$(block FAIL "$SHA" 3)")" "0"
check "7-hex HEAD" "$(code pr-reviewer false "$(block PASS 0123456)")" "0"
check "6-hex HEAD" "$(code pr-reviewer false "$(block PASS 012345)")" "2"
check "40-hex HEAD" "$(code pr-reviewer false "$(block PASS "$SHA")")" "0"
check "41-hex HEAD" "$(code pr-reviewer false "$(block PASS "${SHA}a")")" "2"
check "non-hex HEAD" "$(code pr-reviewer false "$(block PASS 0123456g)")" "2"

check "cleanup sentence only" "$(run pr-reviewer false "The worktree is removed.")" \
  "2 $LACKS GATE: <name>, VERDICT: PASS|FAIL|BLOCKED, HEAD: <sha>, FINDINGS: <count>; send the full verdict block as your final message."
check "missing HEAD names only HEAD" "$(run code-health-reviewer false $'GATE: g\nVERDICT: FAIL\nFINDINGS: 2')" \
  "2 $LACKS HEAD: <sha>; send the full verdict block as your final message."
check "non-numeric FINDINGS names FINDINGS" "$(run pr-reviewer false "$(block PASS "$SHA" many)")" \
  "2 $LACKS FINDINGS: <count>; send the full verdict block as your final message."
check "VERDICT: PASSING" "$(code pr-reviewer false "$(block PASSING)")" "2"
check "VERDICT: WIP" "$(code pr-reviewer false "$(block WIP)")" "2"
check "GATE without a name" "$(code pr-reviewer false $'GATE:\nVERDICT: PASS\nHEAD: 0123456\nFINDINGS: 0')" "2"
check "GATE name with a space" "$(code pr-reviewer false $'GATE: pr reviewer\nVERDICT: PASS\nHEAD: 0123456\nFINDINGS: 0')" "2"
check "markdown-wrapped GATE" "$(code pr-reviewer false $'**GATE: g**\nVERDICT: PASS\nHEAD: 0123456\nFINDINGS: 0')" "2"
check "BLOCKED inline in prose" "$(code pr-reviewer false $'GATE: g\nsee VERDICT: BLOCKED')" "2"
check "trailing space after a line" "$(code pr-reviewer false $'GATE: g \nVERDICT: PASS \nHEAD: 0123456 \nFINDINGS: 0 ')" "0"
check "trailing CR after a line" "$(code pr-reviewer false $'GATE: g\r\nVERDICT: PASS\r\nHEAD: 0123456\r\nFINDINGS: 0\r')" "0"
check "text after a complete block" "$(code pr-reviewer false "$(block)"$'\nThe worktree is removed.')" "0"

check "BLOCKED needs only GATE and VERDICT" "$(code pr-reviewer false $'GATE: g\nVERDICT: BLOCKED\nReason: no CI')" "0"
check "BLOCKED without GATE" "$(code pr-reviewer false $'VERDICT: BLOCKED')" "2"

check "implementer is not held" "$(code implementer false "The worktree is removed.")" "0"
check "dev-team-prefixed gate is held" "$(code dev-team:pr-reviewer false "The worktree is removed.")" "2"
check "other plugin's gate is not held" "$(code otherplugin:pr-reviewer false "The worktree is removed.")" "0"
for agent in code-health-reviewer oss-readiness-reviewer security-reviewer readme-reviewer; do
  check "$agent is held" "$(code "$agent" false "done")" "2"
  check "dev-team:$agent is held" "$(code "dev-team:$agent" false "done")" "2"
done

check "stop_hook_active true" "$(code pr-reviewer true "The worktree is removed.")" "0"
check "empty message" "$(code pr-reviewer false "")" "0"
check "message absent" "$(echo '{"agent_type":"pr-reviewer"}' | bash "$PLUGIN/hooks/verdict-guard.sh" 2>&1; echo $?)" "0"
check "invalid JSON" "$(echo 'not json' | bash "$PLUGIN/hooks/verdict-guard.sh" 2>&1; echo $?)" "0"
check "trailing garbage after JSON" "$(echo '{"agent_type":"pr-reviewer","last_assistant_message":"x"} {' | bash "$PLUGIN/hooks/verdict-guard.sh" 2>&1; echo $?)" "0"

printf '%s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
