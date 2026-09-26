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
git -C "$on_main" branch other
git -C "$on_main" remote add origin "$on_feature"
printf 'Merge feature/x\n' >"$TMP/msg"

combined="merge-gate: run the merge as its own command, from a session whose working directory is the repository, on the already checked-out trunk; a merge in the same command as a cd, pushd, worktree add, checkout, or switch, or one redirected with -C, --git-dir, --work-tree, GIT_DIR, GIT_WORK_TREE, or env -C, or run in a subshell or command substitution, is not accepted."
denied_combined() { check "$1 is denied" "$(gate "$1" "$2")" "2 $combined"; }
denied_combined 'git checkout main && git merge feature/x' "$on_feature"
denied_combined 'git switch main; git merge feature/x' "$on_feature"
denied_combined 'git checkout -B master && git merge feature/x' "$on_feature"
denied_combined 'git checkout "main" && git merge feature/x' "$on_feature"
denied_combined "git checkout 'main' && git merge feature/x" "$on_feature"
denied_combined 'git switch - && git merge feature/x' "$on_feature"
denied_combined "cd $on_main && git merge feature/x" "$TMP"
denied_combined "cd $on_main && git merge feature/x" "$on_feature"
denied_combined "(cd $on_main; git merge feature/x)" "$TMP"
denied_combined "pushd $on_main && git merge feature/x" "$TMP"
denied_combined "git worktree add $TMP/wt main && cd $TMP/wt && git merge feature/x" "$on_feature"
denied_combined "git worktree add $TMP/wt main && git merge feature/x" "$on_feature"
denied_combined "git -C $on_main merge feature/x" "$TMP"
denied_combined "git -C \"$on_main\" merge --no-ff feature/x" "$TMP"
denied_combined "git -c k=v -C $on_main merge feature/x" "$TMP"
denied_combined "git --git-dir=$on_main/.git --work-tree=$on_main merge feature/x" "$TMP"
denied_combined "GIT_DIR=$on_main/.git git merge feature/x" "$on_feature"
denied_combined "GIT_WORK_TREE=$on_main git merge feature/x" "$on_feature"
denied_combined "export GIT_DIR=$on_main/.git; git merge feature/x" "$on_feature"
denied_combined "env -C $on_main git merge feature/x" "$on_feature"
denied_combined 'git checkout @{-1} && git merge feature/x' "$on_feature"
denied_combined 'git switch @{-1}; git merge feature/x' "$on_feature"
denied_combined 'git switch "@{-1}"; git merge feature/x' "$on_feature"
denied_combined "cd $on_main
git merge feature/x" "$TMP"
denied_combined "git worktree add $TMP/wt main
git merge feature/x" "$on_feature"
check "a checkout of main alone is allowed" "$(gate 'git checkout main' "$on_feature")" "0 "
check "a checkout of main-like branch with a merge is not the combined shape" \
  "$(gate 'git checkout main-next && git merge feature/x' "$on_feature")" "0 "
check "git -C <dir> merge-base is allowed" "$(gate "git -C $on_main merge-base main feature/x" "$TMP")" "0 "

check "merge from a cwd that is not a repository is denied" "$(gate 'git merge feature/x' "$TMP")" \
  "2 merge-gate: the working directory '$TMP' is not a git repository, so the merge target cannot be read; run the merge from a session whose working directory is the repository."
check "merge on a feature branch is allowed" "$(gate 'git merge main' "$on_feature")" "0 "
for cmd in 'git merge feature/x' 'git -c k=v merge feature/x' 'git --no-pager merge feature/x' 'git -c "user.name=a b" merge feature/x' \
  'git pull . feature/x' 'git pull origin feature/x'; do
  out="$(gate "$cmd" "$on_main")"
  check "'$cmd' on main without a ledger is denied" "${out%% *}" "2"
  check "'$cmd' denial names the unproven gates" "$(grep -c 'review gates not proven for feature/x' <<<"$out")" "1"
done
repo_key="$(git -C "$on_main" rev-parse --show-toplevel)"
branch_head="$(git -C "$on_main" rev-parse feature/x)"
for g in pr-reviewer code-health oss-reviewer security-review readme-writer; do
  "$LEDGER" record "$repo_key" feature/x "$g" PASS 0 "$branch_head" sonnet >/dev/null
done
check "a pull of the trunk from a remote is allowed" "$(gate 'git pull origin main' "$on_main")" "0 "
check "a pull from the upstream is allowed" "$(gate 'git pull --ff-only' "$on_main")" "0 "
for cmd in 'git merge feature/x' 'git -c k=v merge feature/x' 'git --no-pager merge feature/x' 'git -c "user.name=a b" merge feature/x' \
  'git pull . feature/x' "git merge --no-ff feature/x -F $TMP/msg" 'git merge -m "Merge feature/x" feature/x' \
  "git merge --no-ff feature/x -F \"\$(git rev-parse --git-common-dir)/changes/feature/x.md\""; do
  check "'$cmd' on main with five PASS at the head is allowed" "$(gate "$cmd" "$on_main")" "0 "
done

several="merge-gate: merge one branch per command, as git merge [options] <branch>; a command with several merges, or a merge of several branches, is not accepted."
check "a merge of two branches is denied" "$(gate 'git merge feature/x other' "$on_main")" "2 $several"
check "two merges in one command are denied" "$(gate 'git merge other; git merge feature/x' "$on_main")" "2 $several"
out="$(gate 'git merge -m feature/x other' "$on_main")"
check "a -m value is not the merged branch" "${out%% *}" "2"
check "the -m case gates the real operand" "$(grep -c 'review gates not proven for other' <<<"$out")" "1"
check "a merge in a subshell is denied even with five PASS" "$(gate '(git merge feature/x)' "$on_main")" "2 $combined"
# shellcheck disable=SC2016 # the substitution is the command under test
check "a merge in a command substitution is denied even with five PASS" \
  "$(gate 'out=$(git merge feature/x)' "$on_main")" "2 $combined"
check "a pull of two branches is denied" "$(gate 'git pull . feature/x other' "$on_main")" \
  "2 merge-gate: pull one branch per command; a pull of several branches into main is not accepted."

onto="pushing 'feature/x' onto main bypasses the PR and its gates"
check "push through -C onto main is denied" "$(gate "git -C $on_main push . feature/x:main" "$TMP" | grep -c "$onto")" "1"
check "push with -c onto main is denied" "$(gate 'git -c a=b push origin feature/x:main' "$on_feature" | grep -c "$onto")" "1"
check "push through --git-dir onto main is denied" \
  "$(gate "git --git-dir=$on_main/.git push . feature/x:main" "$TMP" | grep -c "$onto")" "1"

check "gh pr merge outside a GitHub repo is denied at the repo lookup" "$(gate 'gh pr merge 1' "$TMP")" \
  "2 merge-gate: could not resolve the repository from the cwd '$TMP' with gh repo view; pass --repo <owner/name>."
check "gh pr merge without a PR number is denied at the PR number" "$(gate 'gh pr merge --repo o/r --squash' "$TMP")" \
  "2 merge-gate: could not determine the PR number from 'gh pr merge --repo o/r --squash'; pass an explicit PR number."
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
