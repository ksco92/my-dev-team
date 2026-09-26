#!/usr/bin/env bash
# attribution-guard.sh — PreToolUse(Bash) hook. Refuses commits, merges, tags, PR/issue bodies
# and comments that carry an AI-attribution string (owner policy: none, in any repo, from any
# session or subagent). The `attribution` setting already stops the harness from adding them;
# this catches a model or brief that types one in anyway — inline in the command, or in a file
# the command hands to git/gh (`-F`, `--file`, `--body-file`, `--input`, `-F key=@path`).
# Exit 2 = blocked.
set -uo pipefail

ATTR='co-authored-by:[^\n]*(claude|anthropic)|claude-session:|generated with \[?claude code|🤖 generated'

input="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[[ -n "$command" ]] || exit 0

grep -Eq '(^|[;&|[:space:]])(git[[:space:]]+(commit|merge|tag)|gh[[:space:]]+(pr[[:space:]]+(create|edit|comment|merge|review)|issue[[:space:]]+(create|comment|edit)|api))([[:space:]]|$)' <<<"$command" || exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 2
}
MSG="attribution-guard: AI-attribution trailer/footer in a commit or PR body is banned in every repo (owner policy). Remove the Co-Authored-By / Claude-Session / Generated-with lines and retry."

grep -Eiq "$ATTR" <<<"$command" && deny "$MSG"

# Files the command reads its message or body from.
while read -r flag val; do
  [[ -n "$val" ]] || continue
  case "$val" in
    *=@*) val="${val#*=@}" ;;                                          # gh api -F body=@file
    *=*)  [[ "$flag" == "-F" || "$flag" == "--field" ]] && continue ;; # gh api -F key=value: a literal
  esac
  val="${val%\"}"; val="${val#\"}"; val="${val%\'}"; val="${val#\'}"
  [[ "$val" == "-" ]] && continue
  [[ "$val" == /* ]] || val="$cwd/$val"
  [[ -f "$val" ]] || continue
  grep -Eiq "$ATTR" "$val" && deny "$MSG (found in $val)"
done < <(grep -oE -- '(^|[[:space:]])(-F|--field|--file|--body-file|--input)[[:space:]=]+[^[:space:]]+' <<<"$command" | sed -E 's/^[[:space:]]*//; s/[[:space:]=]+/ /')
exit 0
