#!/usr/bin/env bash
# Tests for hooks/agy-hook.sh and bin/install-agy (Antigravity adapter).
# Run: bash plugins/dev-team/tests/agy-adapter.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ADAPTER="$PLUGIN/hooks/agy-hook.sh"
INSTALLER="$PLUGIN/bin/install-agy"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

export HOME="$TMP/home"
mkdir -p "$HOME"
export GATE_LEDGER_ROOT="$TMP/ledger"
unset GATE_LEDGER_GATES

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

# --- agy-hook.sh PreToolUse tests ---
repo="$TMP/repo"
mkdir -p "$repo"
git -C "$repo" init -q -b main
git -C "$repo" -c user.name=t -c user.email=t@t commit -q --allow-empty -m "init"

out="$(jq -n --arg d "$repo" '{toolCall:{name:"run_command",args:{CommandLine:"git status"}},cwd:$d}' | "$ADAPTER" merge-gate)"
check "merge-gate allows safe git status" "$(jq -r .decision <<<"$out")" "allow"

out="$(jq -n --arg d "$repo" '{toolCall:{name:"run_command",args:{CommandLine:"git push --force origin main"}},cwd:$d}' | "$ADAPTER" merge-gate)"
check "merge-gate denies force push to main" "$(jq -r .decision <<<"$out")" "deny"
check "merge-gate deny includes reason" "$(jq -r '.reason | length > 0' <<<"$out")" "true"

# Assemble attribution trailers at runtime so this test file never carries literal ones.
trailer="Co-Authored-By: Cla""ude <noreply@example.com>"
out="$(jq -n --arg c "git commit -m \"Msg\n\n$trailer\"" --arg d "$repo" '{toolCall:{name:"run_command",args:{CommandLine:$c}},cwd:$d}' | "$ADAPTER" attribution-guard)"
check "attribution-guard denies commit carrying Claude trailer" "$(jq -r .decision <<<"$out")" "deny"

agy_trailer="Co-Authored-By: Anti""gravity <noreply@example.com>"
out="$(jq -n --arg c "git commit -m \"Msg\n\n$agy_trailer\"" --arg d "$repo" '{toolCall:{name:"run_command",args:{CommandLine:$c}},cwd:$d}' | "$ADAPTER" attribution-guard)"
check "attribution-guard denies commit carrying Antigravity trailer" "$(jq -r .decision <<<"$out")" "deny"

out="$(jq -n --arg d "$repo" '{toolCall:{name:"run_command",args:{CommandLine:"git commit -m \"Plain msg\""}},cwd:$d}' | "$ADAPTER" attribution-guard)"
check "attribution-guard allows clean commit" "$(jq -r .decision <<<"$out")" "allow"

out="$(jq -n --arg d "$repo" '{toolCall:{name:"read_file",args:{Path:"README.md"}},cwd:$d}' | "$ADAPTER" merge-gate)"
check "missing CommandLine returns allow" "$(jq -r .decision <<<"$out")" "allow"

out="$("$ADAPTER" merge-gate <<<"not-valid-json")"
check "malformed JSON on PreToolUse fails closed" "$(jq -r .decision <<<"$out")" "deny"

out="$("$ADAPTER" merge-gate </dev/null)"
check "empty stdin on PreToolUse fails closed" "$(jq -r .decision <<<"$out")" "deny"

"$ADAPTER" bogus >/dev/null 2>&1
check "unknown adapter target exits 2" "$?" "2"

# Fail-closed when jq is absent on PreToolUse.
no_jq_out="$(PATH="/usr/bin:/bin" bash -c '
  hash -r
  if command -v jq >/dev/null 2>&1; then
    echo "{\"decision\":\"deny\",\"reason\":\"jq-in-sysbin\"}"
  else
    "$1" merge-gate <<<"{\"toolCall\":{\"args\":{\"CommandLine\":\"git push -f origin main\"}}}"
  fi
' _ "$ADAPTER")"
check "PreToolUse fails closed without jq" "$(jq -r .decision <<<"$no_jq_out")" "deny"

# --- agy-hook.sh SessionStart tests ---
pol_out="$(jq -n --arg d "$repo" '{cwd:$d}' | "$ADAPTER" session-context policy)"
check "session-context policy emits injectSteps systemMessage" \
  "$(jq -r '.injectSteps[0].systemMessage.systemMessage | contains("Plugin root") and contains("Personal coding guides")' <<<"$pol_out")" "true"
check "session-context policy expands CLAUDE_PLUGIN_ROOT in body" \
  "$(jq -r --arg r "$PLUGIN" '.injectSteps[0].systemMessage.systemMessage | contains($r + "/context/")' <<<"$pol_out")" "true"

proc_out="$(jq -n --arg d "$repo" '{workspacePaths:[$d]}' | "$ADAPTER" session-context process)"
check "session-context process emits injectSteps systemMessage" \
  "$(jq -r '.injectSteps[0].systemMessage.systemMessage | contains("Development process")' <<<"$proc_out")" "true"

# --- install-agy tests ---
target="$TMP/agy-plugins/dev-team"
"$INSTALLER" --source "$PLUGIN" --target "$target" >/dev/null
check "install-agy exits 0" "$?" "0"

for link in skills context bin templates hooks README.md; do
  check "symlink created for $link" "$(test -L "$target/$link" && echo yes || echo no)" "yes"
done

check "plugin.json has matching name" "$(jq -r .name "$target/plugin.json")" "dev-team"
check "plugin.json has matching version" "$(jq -r .version "$target/plugin.json")" "$(jq -r .version "$PLUGIN/.claude-plugin/plugin.json")"
check "plugin.json drops Claude-only schema key" "$(jq 'has("$schema")' "$target/plugin.json")" "false"
check "hooks.json wires PreToolUse on run_command" \
  "$(jq -r '.["dev-team-guards"].PreToolUse[0].matcher' "$target/hooks.json")" "run_command"
check "hooks.json wires SessionStart policy and process" \
  "$(jq '.["dev-team-guards"].SessionStart | length' "$target/hooks.json")" "2"

src_agent_count="$(find "$PLUGIN/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
dst_agent_count="$(find "$target/agents" -maxdepth 1 -name '*.md' | wc -l | tr -d ' ')"
check "generated agent stub count matches source agents" "$dst_agent_count" "$src_agent_count"
check "implementer stub maps write and bash tools" \
  "$(grep -c '^tools: \[read_file, write_file, edit_file, run_command, manage_task, search_web\]$' "$target/agents/implementer.md")" "1"
check "pr-reviewer stub stays read-only plus command and search tools" \
  "$(grep -c '^tools: \[read_file, run_command, manage_task, search_web\]$' "$target/agents/pr-reviewer.md")" "1"
check "agent stub sets subagent: true and omits Claude model" \
  "$(grep -c '^subagent: true$' "$target/agents/pr-reviewer.md"):$(grep -c '^model:' "$target/agents/pr-reviewer.md")" "1:0"
check "code-health-reviewer stub references preloaded skill" \
  "$(grep -c 'skills/code-health/SKILL.md' "$target/agents/code-health-reviewer.md")" "1"

# Re-run idempotency and stale-agent cleanup.
touch "$target/agents/stale-removed-agent.md"
"$INSTALLER" --source "$PLUGIN" --target "$target" >/dev/null
check "idempotent re-run exits 0" "$?" "0"
check "re-run removes stale generated agent stub" \
  "$(test -e "$target/agents/stale-removed-agent.md" && echo present || echo gone)" "gone"

# Hooks run cleanly from the installed plugin directory (matching Antigravity cwd = plugin root).
inst_out="$(cd "$target" && jq -n --arg d "$repo" '{toolCall:{name:"run_command",args:{CommandLine:"git push --force origin main"}},cwd:$d}' | PLUGIN_ROOT="$target" ./hooks/agy-hook.sh merge-gate)"
check "installed hooks.json command denies force push from plugin root" "$(jq -r .decision <<<"$inst_out")" "deny"

# Safety: install refuses symlink target, file target, and non-symlink collisions.
file_target="$TMP/file-target"
touch "$file_target"
"$INSTALLER" --source "$PLUGIN" --target "$file_target" >/dev/null 2>&1
check "install refuses regular-file target" "$?" "2"

symlink_target="$TMP/symlink-target"
ln -s "$TMP" "$symlink_target"
"$INSTALLER" --source "$PLUGIN" --target "$symlink_target" >/dev/null 2>&1
check "install refuses symlink target" "$?" "2"

collision_target="$TMP/collision-target"
mkdir -p "$collision_target/skills"
"$INSTALLER" --source "$PLUGIN" --target "$collision_target" >/dev/null 2>&1
check "install refuses overwriting non-symlink directory" "$?" "2"

# Safety: uninstall refuses unmanaged directory without marker, succeeds on installed target.
unmanaged="$TMP/unmanaged"
mkdir -p "$unmanaged"
"$INSTALLER" --uninstall --target "$unmanaged" >/dev/null 2>&1
check "uninstall refuses directory without marker" "$?" "2"
check "unmanaged directory left intact" "$(test -d "$unmanaged" && echo yes || echo no)" "yes"

"$INSTALLER" --uninstall --target "$target" >/dev/null
check "uninstall removes installed plugin" "$(test -e "$target" && echo present || echo gone)" "gone"
check "uninstall leaves source repo intact" "$(test -d "$PLUGIN/skills" && echo yes || echo no)" "yes"

echo "$pass passed, $fail failed"
(( fail == 0 ))
