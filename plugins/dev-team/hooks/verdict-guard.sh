#!/usr/bin/env bash
# verdict-guard.sh — SubagentStop hook. A review-gate subagent (pr-reviewer, code-health-reviewer,
# oss-readiness-reviewer, security-reviewer, readme-reviewer, bare or `dev-team:`-prefixed) may not
# finish unless its last_assistant_message has, each on its own line, GATE: <name>,
# VERDICT: PASS|FAIL|BLOCKED, HEAD: <7 to 40 hex> and FINDINGS: <digits>; BLOCKED needs only GATE
# and VERDICT. Exit 2 = the subagent keeps running with stderr as its next instruction; every other
# case, including stop_hook_active, a missing or empty message and unparseable input, exits 0.
set -euo pipefail

fields="$(jq -r '(.agent_type // ""), (.stop_hook_active // false), ((.last_assistant_message // "") + "\n.")' 2>/dev/null)" || exit 0
type="${fields%%$'\n'*}"
rest="${fields#*$'\n'}"
active="${rest%%$'\n'*}"
text="${rest#*$'\n'}"
text="${text%$'\n.'}"
case "$type" in
  pr-reviewer | code-health-reviewer | oss-readiness-reviewer | security-reviewer | readme-reviewer) ;;
  dev-team:pr-reviewer | dev-team:code-health-reviewer | dev-team:oss-readiness-reviewer) ;;
  dev-team:security-reviewer | dev-team:readme-reviewer) ;;
  *) exit 0 ;;
esac
[[ "$active" == "true" || -z "$text" ]] && exit 0

has() { grep -Eq "$1" <<<"$text"; }
missing=()
has '^GATE: [^[:space:]]+[[:space:]]*$' || missing+=("GATE: <name>")
if ! has '^VERDICT: BLOCKED[[:space:]]*$'; then
  has '^VERDICT: (PASS|FAIL)[[:space:]]*$' || missing+=("VERDICT: PASS|FAIL|BLOCKED")
  has '^HEAD: [0-9a-fA-F]{7,40}[[:space:]]*$' || missing+=("HEAD: <sha>")
  has '^FINDINGS: [0-9]+[[:space:]]*$' || missing+=("FINDINGS: <count>")
fi
[[ ${#missing[@]} -eq 0 ]] && exit 0

list="$(printf '%s, ' "${missing[@]}")"
echo "verdict-guard: your last message lacks the line(s) ${list%, }; send the full verdict block as your final message." >&2
exit 2
