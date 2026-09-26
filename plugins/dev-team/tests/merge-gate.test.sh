#!/usr/bin/env bash
# Tests for hooks/merge-gate.sh and hooks/attribution-guard.sh, fed hook-shaped JSON on stdin with
# a stub gh on PATH. Run: bash plugins/dev-team/tests/merge-gate.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GATE_LEDGER_ROOT="$TMP/ledger"
LEDGER="$PLUGIN/bin/gate-ledger"
STUB_HEAD=0123456789abcdef0123456789abcdef01234567

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

mkdir -p "$TMP/bin"
cat >"$TMP/bin/gh" <<SH
#!/usr/bin/env bash
case "\$1 \$2" in
  "repo view") echo "none of the git remotes point to a known GitHub host" >&2; exit 1 ;;
  "pr view") echo $STUB_HEAD ;;
  "pr checks") echo '[{"name":"validate","bucket":"pass"}]' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$TMP/bin/gh"

# Prints "<exit> <permissionDecisionReason>".
run() {
  local hook="$1" cmd="$2" cwd="$3" out rc
  out="$(jq -n --arg c "$cmd" --arg d "$cwd" '{tool_input: {command: $c}, cwd: $d}' \
    | PATH="$TMP/bin:$PATH" bash "$PLUGIN/hooks/$hook" 2>/dev/null)"
  rc=$?
  printf '%s %s' "$rc" "$(jq -r '.hookSpecificOutput.permissionDecisionReason // empty' <<<"$out" 2>/dev/null)"
}
gate() { run merge-gate.sh "$@"; }

git_t() { git -C "$1" -c user.name=t -c user.email=t@t "${@:2}"; }
on_main="$TMP/on-main"
on_feature="$TMP/on-feature"
for repo in "$on_main" "$on_feature"; do
  mkdir -p "$repo"
  git -C "$repo" init -q -b main
  git_t "$repo" commit -q --allow-empty -m base
  git -C "$repo" checkout -qb feature/x
  git_t "$repo" commit -q --allow-empty -m change
done
git -C "$on_main" checkout -q main

combined="merge-gate: run the checkout of main and the git merge as separate commands, from inside the repository; a merge in the same command as a checkout or switch to main, and a git -C <dir> merge, are not accepted."
check "checkout main && merge is denied" "$(gate 'git checkout main && git merge feature/x' "$on_feature")" "2 $combined"
check "switch main; merge is denied" "$(gate 'git switch main; git merge feature/x' "$on_feature")" "2 $combined"
check "git -C <dir> merge is denied" "$(gate "git -C $on_main merge feature/x" "$TMP")" "2 $combined"
check "git -C with a quoted path is denied" "$(gate "git -C \"$on_main\" merge --no-ff feature/x" "$TMP")" "2 $combined"
check "checkout -B master && merge is denied" "$(gate 'git checkout -B master && git merge feature/x' "$on_feature")" "2 $combined"
check "a checkout of main alone is allowed" "$(gate 'git checkout main' "$on_feature")" "0 "
check "a checkout of main-like branch with a merge is not the combined shape" \
  "$(gate 'git checkout main-next && git merge feature/x' "$on_feature")" "0 "
check "git -C <dir> merge-base is allowed" "$(gate "git -C $on_main merge-base main feature/x" "$TMP")" "0 "

check "merge on a feature branch is allowed" "$(gate 'git merge main' "$on_feature")" "0 "
out="$(gate 'git merge feature/x' "$on_main")"
check "merge on main without a ledger is denied" "${out%% *}" "2"
check "the denial names the unproven gates" "$(grep -c 'review gates not proven for feature/x' <<<"$out")" "1"
repo_key="$(git -C "$on_main" rev-parse --show-toplevel)"
branch_head="$(git -C "$on_main" rev-parse feature/x)"
for g in pr-reviewer code-health oss-reviewer security-review readme-writer; do
  "$LEDGER" record "$repo_key" feature/x "$g" PASS 0 "$branch_head" sonnet >/dev/null
done
check "merge on main with five PASS at the head is allowed" "$(gate 'git merge feature/x' "$on_main")" "0 "

check "gh pr merge outside a GitHub repo is denied at the repo lookup" "$(gate 'gh pr merge 1' "$TMP")" \
  "2 merge-gate: could not resolve the repository from the cwd '$TMP' with gh repo view; pass --repo <owner/name>."
out="$(gate 'gh pr merge 1 --repo o/r' "$TMP")"
check "gh pr merge --repo without a ledger is denied" "${out%% *}" "2"
for g in pr-reviewer code-health oss-reviewer security-review readme-writer; do
  "$LEDGER" record o/r 1 "$g" PASS 0 "$STUB_HEAD" sonnet >/dev/null
done
check "gh pr merge --repo with five PASS and green checks is allowed" "$(gate 'gh pr merge 1 --repo o/r' "$TMP")" "0 "

# The trailer is assembled at run time so this file never carries it.
name=Claude
trailer="Co-Authored-By: $name <noreply@example.com>"
out="$(run attribution-guard.sh "git commit -m \"Fix it

$trailer\"" "$on_main")"
check "a commit carrying an attribution trailer is refused" "${out%% *}" "2"
check "the refusal names the trailer" "$(grep -c '^2 attribution-guard: AI-attribution trailer' <<<"$out")" "1"
check "a commit without one is allowed" "$(run attribution-guard.sh 'git commit -m "Fix it"' "$on_main")" "0 "

echo "$pass passed, $fail failed"
(( fail == 0 ))
