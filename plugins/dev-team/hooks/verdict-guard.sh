#!/usr/bin/env bash
# verdict-guard.sh: SubagentStop hook. A review-gate subagent must end with the verdict block
# (GATE matching its canonical gate name, VERDICT, HEAD, FINDINGS lines; BLOCKED needs only GATE
# and VERDICT; PASS requires FINDINGS: 0 and FAIL requires FINDINGS >= 1); otherwise exit 2 asks
# it to resend. Every other case, including stop_hook_active and an unreadable input, exits 0.
set -uo pipefail

# The sentinel keeps trailing newlines and an empty message from collapsing into the previous field.
fields="$(jq -r '(.agent_type // "" | gsub("[\\n\\r]|\u0000"; " ")), (.stop_hook_active == true), ((.last_assistant_message // "") + "\n.")' 2>/dev/null)" || exit 0
type="${fields%%$'\n'*}"
rest="${fields#*$'\n'}"
active="${rest%%$'\n'*}"
text="${rest#*$'\n'}"
text="${text%$'\n.'}"
case "${type#dev-team:}" in
  pr-reviewer) expected_gate="pr-reviewer" ;;
  code-health-reviewer) expected_gate="code-health" ;;
  oss-readiness-reviewer) expected_gate="oss-reviewer" ;;
  security-reviewer) expected_gate="security-review" ;;
  readme-reviewer) expected_gate="readme-writer" ;;
  *) exit 0 ;;
esac
[[ "$active" == "true" || -z "$text" ]] && exit 0

has() { grep -Eq "$1" <<<"$text"; }
missing=()
if ! has '^GATE: [^[:space:]]+[[:space:]]*$'; then
  missing+=("GATE: $expected_gate")
elif ! has "^GATE: ${expected_gate}[[:space:]]*\$"; then
  missing+=("GATE: $expected_gate (exact gate name)")
fi

if ! has '^VERDICT: BLOCKED[[:space:]]*$'; then
  verdict_line="$(grep -E '^VERDICT: (PASS|FAIL)[[:space:]]*$' <<<"$text" | tail -1 || true)"
  if [[ -z "$verdict_line" ]]; then
    missing+=("VERDICT: PASS|FAIL|BLOCKED")
  fi
  has '^HEAD: [0-9a-fA-F]{7,40}[[:space:]]*$' || missing+=("HEAD: <sha>")
  findings_line="$(grep -E '^FINDINGS: [0-9]+[[:space:]]*$' <<<"$text" | tail -1 || true)"
  if [[ -z "$findings_line" ]]; then
    missing+=("FINDINGS: <count>")
  elif [[ -n "$verdict_line" ]]; then
    verdict_val="$(awk '{print $2}' <<<"$verdict_line" | tr -d '\r')"
    findings_val="$(awk '{print $2}' <<<"$findings_line" | tr -d '\r')"
    if [[ "$verdict_val" == "PASS" && "$findings_val" != "0" ]]; then
      missing+=("FINDINGS: 0 (PASS requires zero findings)")
    elif [[ "$verdict_val" == "FAIL" && "$findings_val" == "0" ]]; then
      missing+=("FINDINGS: <count >= 1> (FAIL requires at least one finding)")
    fi
  fi
fi
[[ ${#missing[@]} -eq 0 ]] && exit 0

list="$(printf '%s, ' "${missing[@]}")"
echo "verdict-guard: your last message lacks the line(s) ${list%, }; send the full verdict block as your final message." >&2
exit 2
