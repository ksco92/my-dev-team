#!/usr/bin/env bash
# verdict-guard.sh: SubagentStop hook. A review-gate subagent must end with the verdict block
# (GATE, VERDICT, HEAD, FINDINGS lines; BLOCKED needs only the first two); otherwise exit 2 asks it
# to resend. Every other case, including stop_hook_active and an unreadable input, exits 0.
set -uo pipefail

# The sentinel keeps trailing newlines and an empty message from collapsing into the previous field.
fields="$(jq -r '(.agent_type // "" | gsub("[\\n\\r]"; " ")), (.stop_hook_active // false), ((.last_assistant_message // "") + "\n.")' 2>/dev/null)" || exit 0
type="${fields%%$'\n'*}"
rest="${fields#*$'\n'}"
active="${rest%%$'\n'*}"
text="${rest#*$'\n'}"
text="${text%$'\n.'}"
case "${type#dev-team:}" in
  pr-reviewer | code-health-reviewer | oss-readiness-reviewer | security-reviewer | readme-reviewer) ;;
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
