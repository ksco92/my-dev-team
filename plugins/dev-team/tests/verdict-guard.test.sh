#!/usr/bin/env bash
# Tests for hooks/verdict-guard.sh, fed SubagentStop-shaped JSON on stdin.
# Run: bash plugins/dev-team/tests/verdict-guard.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
[[ -n "$TMP" && "$TMP" == /* ]] || { echo "TMP is empty or relative" >&2; exit 1; }

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

BLOCK=$'GATE: pr-reviewer\nVERDICT: PASS\nHEAD: 0123456789abcdef0123456789abcdef01234567\nFINDINGS: 0'
CLEANUP="The worktree is removed."

# transcript <file> <text>...: one assistant line per text, a tool_use line between them.
transcript() {
  local file="$1" text
  shift
  : >"$file"
  for text in "$@"; do
    jq -nc --arg t "$text" '{type: "assistant", message: {role: "assistant", content: [{type: "text", text: $t}]}}' >>"$file"
    jq -nc '{type: "assistant", message: {role: "assistant", content: [{type: "tool_use", id: "t1", name: "Bash", input: {}}]}}' >>"$file"
  done
}

# run <agent_type> <stop_hook_active> <transcript path>: prints "<exit> <stderr>".
run() {
  local err rc
  err="$(jq -n --arg a "$1" --argjson s "$2" --arg p "$3" \
    '{agent_type: $a, stop_hook_active: $s, agent_transcript_path: $p}' \
    | bash "$PLUGIN/hooks/verdict-guard.sh" 2>&1 >/dev/null)"
  rc=$?
  printf '%s %s' "$rc" "$err"
}

transcript "$TMP/complete.jsonl" "$BLOCK"
check "complete block" "$(run pr-reviewer false "$TMP/complete.jsonl")" "0 "

transcript "$TMP/cleanup.jsonl" "$BLOCK" "$CLEANUP"
check "cleanup sentence after a complete block" "$(run pr-reviewer false "$TMP/cleanup.jsonl")" \
  "2 verdict-guard: your last message lacks the line(s) GATE: <name>, VERDICT: PASS|FAIL|BLOCKED, HEAD: <sha>, FINDINGS: <count>; send the full verdict block as your final message."

transcript "$TMP/nohead.jsonl" $'GATE: pr-reviewer\nVERDICT: FAIL\nFINDINGS: 2'
check "block without HEAD names only HEAD" "$(run code-health-reviewer false "$TMP/nohead.jsonl")" \
  "2 verdict-guard: your last message lacks the line(s) HEAD: <sha>; send the full verdict block as your final message."

transcript "$TMP/shorthead.jsonl" $'GATE: pr-reviewer\nVERDICT: PASS\nHEAD: abc123\nFINDINGS: 0'
check "6-hex HEAD is refused" "$(run pr-reviewer false "$TMP/shorthead.jsonl" | cut -c1-1)" "2"

transcript "$TMP/blocked.jsonl" $'GATE: pr-reviewer\nVERDICT: BLOCKED\nReason: no CI\nWhat you need: a re-trigger'
check "BLOCKED needs only GATE and VERDICT" "$(run pr-reviewer false "$TMP/blocked.jsonl")" "0 "

transcript "$TMP/implementer.jsonl" "$CLEANUP"
check "non-gate subagent" "$(run implementer false "$TMP/implementer.jsonl")" "0 "
check "plugin-namespaced gate type" "$(run dev-team:security-reviewer false "$TMP/cleanup.jsonl" | cut -c1-1)" "2"

check "stop_hook_active true" "$(run pr-reviewer true "$TMP/cleanup.jsonl")" "0 "
check "unreadable transcript" "$(run pr-reviewer false "$TMP/missing.jsonl")" "0 "

printf '{"type":"assistant"\nnot json' >"$TMP/garbage.jsonl"
check "malformed transcript" "$(run pr-reviewer false "$TMP/garbage.jsonl")" "0 "

# last_assistant_message wins over the transcript.
out="$(jq -n --arg m "$CLEANUP" --arg p "$TMP/complete.jsonl" \
  '{agent_type: "pr-reviewer", stop_hook_active: false, last_assistant_message: $m, agent_transcript_path: $p}' \
  | bash "$PLUGIN/hooks/verdict-guard.sh" 2>&1 >/dev/null)"
check "last_assistant_message is read first" "$?" "2"
check "last_assistant_message stderr" "${out:0:14}" "verdict-guard:"

printf '%s passed, %s failed\n' "$pass" "$fail"
[[ "$fail" -eq 0 ]]
