#!/usr/bin/env bash
# agy-hook.sh — Antigravity lifecycle-hook protocol adapter for dev-team hooks.
#
# Reuses the existing Claude Code hook scripts (merge-gate.sh, attribution-guard.sh,
# session-context.sh) with zero duplicated guard logic by translating Antigravity's
# camelCase JSON stdin/stdout contract to and from the Claude Code hook contract.
#
# Usage:
#   agy-hook.sh merge-gate
#   agy-hook.sh attribution-guard
#   agy-hook.sh session-context <policy|process>
set -uo pipefail

ROOT="${PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export CLAUDE_PLUGIN_ROOT="$ROOT"

TMP_OUT=""
TMP_ERR=""
trap 'rm -f "$TMP_OUT" "$TMP_ERR"' EXIT

target="${1:-}"
shift || true

emit_deny() {
  printf '%s' "$1" | jq -Rs '{decision: "deny", reason: .}' \
    || printf '{"decision":"deny","reason":"agy-hook: blocked by security hook."}\n'
  exit 0
}

run_pre_tool_use() {
  local script="$ROOT/hooks/${1}.sh"
  if ! command -v jq >/dev/null 2>&1; then
    printf '{"decision":"deny","reason":"agy-hook: jq is required to run %s."}\n' "$1"
    exit 0
  fi
  [[ -x "$script" ]] || emit_deny "agy-hook: hook script not executable: $script"

  local input translated rc=0 out err reason
  input="$(cat)"
  if [[ -z "$input" ]] || ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$input"; then
    emit_deny "agy-hook: invalid or empty JSON payload on PreToolUse."
  fi
  if ! jq -e '(.toolCall.args.CommandLine == null) or ((.toolCall.args.CommandLine | type) == "string")' >/dev/null 2>&1 <<<"$input"; then
    emit_deny "agy-hook: unexpected non-string CommandLine on PreToolUse."
  fi
  if jq -e '(.toolCall.args.CommandLine // "") == ""' >/dev/null 2>&1 <<<"$input"; then
    printf '{"decision":"allow"}\n'
    exit 0
  fi

  if ! translated="$(jq -c '{tool_input: {command: .toolCall.args.CommandLine}, cwd: ((.cwd | strings) // (.workspacePaths | arrays | .[0] | strings) // "")}' <<<"$input" 2>/dev/null)" || [[ -z "$translated" ]]; then
    emit_deny "agy-hook: failed to translate PreToolUse payload."
  fi

  TMP_OUT="$(mktemp)" || emit_deny "agy-hook: failed to create temporary output file."
  TMP_ERR="$(mktemp)" || emit_deny "agy-hook: failed to create temporary error file."

  "$script" <<<"$translated" >"$TMP_OUT" 2>"$TMP_ERR" || rc=$?
  out="$(cat "$TMP_OUT")"
  err="$(cat "$TMP_ERR")"

  if (( rc == 0 )); then
    printf '{"decision":"allow"}\n'
    exit 0
  fi

  reason="$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$out" 2>/dev/null || true)"
  [[ -n "$reason" ]] || reason="$err"
  [[ -n "$reason" ]] || reason="$out"
  [[ -n "$reason" ]] || reason="blocked by ${1}"
  emit_deny "$reason"
}

run_session_start() {
  local block="${1:-}"
  local script="$ROOT/hooks/session-context.sh"
  if ! command -v jq >/dev/null 2>&1 || [[ ! -x "$script" ]]; then
    printf '{}\n'
    exit 0
  fi

  local input translated text
  input="$(cat)"
  translated="$(jq -c '{cwd: ((.cwd | strings) // (.workspacePaths | arrays | .[0] | strings) // "")}' <<<"$input" 2>/dev/null || printf '{}')"
  text="$("$script" "$block" <<<"$translated" 2>/dev/null || true)"

  if [[ "$block" == "policy" && -n "$text" ]]; then
    text="Plugin root (\`\${CLAUDE_PLUGIN_ROOT}\`): \`$ROOT\`

$text"
  fi

  if [[ -z "$text" ]]; then
    printf '{}\n'
    exit 0
  fi

  printf '%s' "$text" | jq -Rs '{injectSteps: [{systemMessage: {systemMessage: .}}]}'
  exit 0
}

case "$target" in
  merge-gate|attribution-guard)
    run_pre_tool_use "$target"
    ;;
  session-context)
    run_session_start "${1:-}"
    ;;
  *)
    echo "agy-hook: unknown target '$target' (expected merge-gate|attribution-guard|session-context)" >&2
    exit 2
    ;;
esac
