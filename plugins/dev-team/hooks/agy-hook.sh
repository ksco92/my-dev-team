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
  local reason="$1"
  if command -v jq >/dev/null 2>&1; then
    jq -n --arg r "$reason" '{decision: "deny", reason: $r}'
  else
    printf '{"decision":"deny","reason":"agy-hook: jq is required to evaluate security hooks."}\n'
  fi
  exit 0
}

run_pre_tool_use() {
  local script="$ROOT/hooks/${1}.sh"
  command -v jq >/dev/null 2>&1 || emit_deny "agy-hook: jq is required to run ${1}."
  [[ -x "$script" ]] || emit_deny "agy-hook: hook script not executable: $script"

  local input cmd cwd translated rc=0 out err reason
  input="$(cat)"
  if [[ -z "$input" ]] || ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$input"; then
    emit_deny "agy-hook: invalid or empty JSON payload on PreToolUse."
  fi
  if ! jq -e '(.toolCall.args.CommandLine == null) or ((.toolCall.args.CommandLine | type) == "string")' >/dev/null 2>&1 <<<"$input"; then
    emit_deny "agy-hook: unexpected non-string CommandLine on PreToolUse."
  fi

  cmd="$(jq -r '.toolCall.args.CommandLine // empty' <<<"$input")"
  cwd="$(jq -r '.cwd // (.workspacePaths[0] // empty)' <<<"$input" 2>/dev/null || true)"
  if [[ -z "$cmd" ]]; then
    printf '{"decision":"allow"}\n'
    exit 0
  fi

  translated="$(jq -n --arg c "$cmd" --arg d "$cwd" '{tool_input: {command: $c}, cwd: $d}')"
  TMP_OUT="$(mktemp)"
  TMP_ERR="$(mktemp)"

  "$script" <<<"$translated" >"$TMP_OUT" 2>"$TMP_ERR" || rc=$?
  out="$(cat "$TMP_OUT")"
  err="$(cat "$TMP_ERR")"
  rm -f "$TMP_OUT" "$TMP_ERR"
  TMP_OUT=""
  TMP_ERR=""

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

  local input cwd translated text
  input="$(cat)"
  cwd="$(jq -r '.cwd // (.workspacePaths[0] // empty)' <<<"$input" 2>/dev/null || true)"
  translated="$(jq -n --arg d "$cwd" '{cwd: $d}')"
  text="$("$script" "$block" <<<"$translated" 2>/dev/null || true)"

  if [[ "$block" == "policy" && -n "$text" ]]; then
    text="Plugin root (\`\${CLAUDE_PLUGIN_ROOT}\`): \`$ROOT\`

$text"
  fi

  if [[ -z "$text" ]]; then
    printf '{}\n'
    exit 0
  fi

  jq -n --arg m "$text" '{injectSteps: [{systemMessage: {systemMessage: $m}}]}'
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
