#!/usr/bin/env bash
# verdict-guard.sh — SubagentStop hook. A review-gate subagent (pr-reviewer, code-health-reviewer,
# oss-readiness-reviewer, security-reviewer, readme-reviewer) may not finish unless its final
# assistant text has, each on its own line, GATE: <name>, VERDICT: PASS|FAIL|BLOCKED, HEAD: <7 to
# 40 hex> and FINDINGS: <digits>; BLOCKED needs only GATE and VERDICT. The text is the hook
# input's last_assistant_message, else the last assistant text in agent_transcript_path.
# Exit 2 = the subagent keeps running with stderr as its next instruction; every other case,
# including an unreadable transcript and stop_hook_active, exits 0.
set -euo pipefail

input="$(cat)"
type="$(jq -r '.agent_type // empty' <<<"$input" 2>/dev/null || true)"
case "${type##*:}" in
  pr-reviewer | code-health-reviewer | oss-readiness-reviewer | security-reviewer | readme-reviewer) ;;
  *) exit 0 ;;
esac
[[ "$(jq -r '.stop_hook_active // false' <<<"$input")" == "true" ]] && exit 0

text="$(jq -r '.last_assistant_message // empty' <<<"$input")"
if [[ -z "$text" ]]; then
  path="$(jq -r '.agent_transcript_path // empty' <<<"$input")"
  [[ -n "$path" && -r "$path" ]] || exit 0
  text="$(jq -rs '[.[] | select(.type == "assistant")
    | [.message.content[]? | select(.type == "text") | .text] | select(length > 0) | join("\n")]
    | last // empty' "$path" 2>/dev/null)" || exit 0
fi
[[ -n "$text" ]] || exit 0

has() { grep -Eq "$1" <<<"$text"; }
missing=()
has '^GATE: [^[:space:]]+[[:space:]]*$' || missing+=("GATE: <name>")
if has '^VERDICT: BLOCKED[[:space:]]*$'; then
  :
else
  has '^VERDICT: (PASS|FAIL)[[:space:]]*$' || missing+=("VERDICT: PASS|FAIL|BLOCKED")
  has '^HEAD: [0-9a-fA-F]{7,40}[[:space:]]*$' || missing+=("HEAD: <sha>")
  has '^FINDINGS: [0-9]+[[:space:]]*$' || missing+=("FINDINGS: <count>")
fi
[[ ${#missing[@]} -eq 0 ]] && exit 0

list="$(printf '%s, ' "${missing[@]}")"
echo "verdict-guard: your last message lacks the line(s) ${list%, }; send the full verdict block as your final message." >&2
exit 2
