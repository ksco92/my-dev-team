#!/usr/bin/env bash
# Tests for hooks/merge-gate.sh and hooks/attribution-guard.sh, fed hook-shaped JSON on stdin with
# a stub gh on PATH. Run: bash plugins/dev-team/tests/merge-gate.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GATE_LEDGER_ROOT="$TMP/ledger"
LEDGER="$PLUGIN/bin/gate-ledger"
on_main="$TMP/on-main"
on_feature="$TMP/on-feature"
fresh="$TMP/fresh"
# An empty fixture path would point `git -C ""` at the caller's repository.
for fixture in PLUGIN TMP on_main on_feature fresh; do
  [[ -n "${!fixture}" && "${!fixture}" == /* ]] || { echo "fixture path $fixture is empty or relative" >&2; exit 1; }
done
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
git -C "$on_main" fetch -q origin
printf 'Merge feature/x\n' >"$TMP/msg"
upstream() { git -C "$on_main" branch -q -u "$1" main; }

combined="merge-gate: run the merge or pull as its own command, from a session whose working directory is the repository, on the already checked-out trunk; one in the same command as a cd, pushd, worktree add, checkout, switch, or rebase, or redirected with -C, --git-dir, --work-tree, GIT_DIR, GIT_WORK_TREE, or env -C, or run in a subshell or command substitution, is not accepted."
denied_combined() { check "$1 is denied" "$(gate "$1" "$2")" "2 $combined"; }
denied_combined 'git checkout main && git merge feature/x' "$on_feature"
denied_combined 'git switch main; git merge feature/x' "$on_feature"
denied_combined 'git checkout -B master && git merge feature/x' "$on_feature"
denied_combined 'git checkout "main" && git merge feature/x' "$on_feature"
denied_combined "git checkout 'main' && git merge feature/x" "$on_feature"
denied_combined 'git switch - && git merge feature/x' "$on_feature"
denied_combined 'git checkout @{-1} && git merge feature/x' "$on_feature"
denied_combined 'git switch @{-1}; git merge feature/x' "$on_feature"
denied_combined 'git switch "@{-1}"; git merge feature/x' "$on_feature"
denied_combined 'git rebase feature/x main && git merge feature/x' "$on_feature"
denied_combined "cd $on_main && git merge feature/x" "$TMP"
denied_combined "cd $on_main && git merge feature/x" "$on_feature"
denied_combined "(cd $on_main; git merge feature/x)" "$TMP"
denied_combined "pushd $on_main && git merge feature/x" "$TMP"
denied_combined "git worktree add $TMP/wt main && cd $TMP/wt && git merge feature/x" "$on_feature"
denied_combined "git worktree add $TMP/wt main && git merge feature/x" "$on_feature"
denied_combined "cd $on_main
git merge feature/x" "$TMP"
denied_combined "git worktree add $TMP/wt main
git merge feature/x" "$on_feature"
denied_combined "git -C $on_main merge feature/x" "$TMP"
denied_combined "git -C \"$on_main\" merge --no-ff feature/x" "$TMP"
denied_combined "git -c k=v -C $on_main merge feature/x" "$TMP"
denied_combined "git --git-dir=$on_main/.git --work-tree=$on_main merge feature/x" "$TMP"
denied_combined "GIT_DIR=$on_main/.git git merge feature/x" "$on_feature"
denied_combined "GIT_WORK_TREE=$on_main git merge feature/x" "$on_feature"
denied_combined "export GIT_DIR=$on_main/.git; git merge feature/x" "$on_feature"
denied_combined "env 'GIT_DIR=$on_main/.git' git merge feature/x" "$on_feature"
denied_combined "export \"GIT_DIR=$on_main/.git\"; git merge feature/x" "$on_feature"
denied_combined "env -C $on_main git merge feature/x" "$on_feature"
denied_combined "env -iC $on_main git merge feature/x" "$on_feature"
denied_combined "cd $on_main && git pull . feature/x" "$TMP"
denied_combined "git -C $on_main pull . feature/x" "$TMP"
check "a checkout of main alone is allowed" "$(gate 'git checkout main' "$on_feature")" "0 "
check "a checkout of main-like branch with a merge is not the combined shape" \
  "$(gate 'git checkout main-next && git merge feature/x' "$on_feature")" "0 "
check "git -C <dir> merge-base is allowed" "$(gate "git -C $on_main merge-base main feature/x" "$TMP")" "0 "

check "merge from a cwd that is not a repository is denied" "$(gate 'git merge feature/x' "$TMP")" \
  "2 merge-gate: the working directory '$TMP' is not a git repository, so the merge target cannot be read; run the merge from a session whose working directory is the repository."
check "merge on a feature branch is allowed" "$(gate 'git merge main' "$on_feature")" "0 "
# shellcheck disable=SC2016 # the $(...) inside a -c value is part of the command under test
option_forms=('git -c k=v' 'git --no-pager' 'git -c "user.name=a b"' "git -c user.name='a b'" 'git -c k=v\ w' 'git -c k=$(echo v)' 'git --attr-source=HEAD')
for prefix in git "${option_forms[@]}"; do
  out="$(gate "$prefix merge feature/x" "$on_main")"
  check "'$prefix merge feature/x' on main without a ledger is denied" "${out%% *}" "2"
  check "'$prefix merge feature/x' denial names the unproven gates" "$(grep -c 'review gates not proven for feature/x' <<<"$out")" "1"
done
out="$(gate 'git merge -' "$on_main")"
check "'git merge -' on main without a ledger is denied" "${out%% *}" "2"
check "'git merge -' is gated on the previous branch" "$(grep -c 'review gates not proven for feature/x' <<<"$out")" "1"
repo_key="$(git -C "$on_main" rev-parse --show-toplevel)"
branch_head="$(git -C "$on_main" rev-parse feature/x)"
for g in pr-reviewer code-health oss-reviewer security-review readme-writer; do
  "$LEDGER" record "$repo_key" feature/x "$g" PASS 0 "$branch_head" sonnet >/dev/null
done
for prefix in git "${option_forms[@]}"; do
  check "'$prefix merge feature/x' on main with five PASS at the head is allowed" "$(gate "$prefix merge feature/x" "$on_main")" "0 "
done
for cmd in 'git merge -' "git merge --no-ff feature/x -F $TMP/msg" 'git merge -m "Merge feature/x" feature/x' 'git merge -X theirs feature/x' \
  "git merge --no-ff feature/x -F \"\$(git rev-parse --git-common-dir)/changes/feature/x.md\""; do
  check "'$cmd' on main with five PASS at the head is allowed" "$(gate "$cmd" "$on_main")" "0 "
done

check "a merge of two branches is denied" "$(gate 'git merge feature/x other' "$on_main")" \
  "2 merge-gate: merge one branch per command, as git merge [options] <branch>; a merge of several branches is not accepted."
segments="2 merge-gate: run one git merge, pull, or push per command; a command with several of them is not accepted."
for cmd in 'git merge other; git merge feature/x' 'git merge other;git merge feature/x' 'git merge;git merge feature/x' 'git pull . x; git pull' \
  'git pull origin x && git pull origin main' 'git pull . x | git pull' 'git push origin evil:main; git push origin x' 'git push origin "evil:main" && git push' \
  'git pull origin main && git merge feature/x' 'git pull . x
git pull'; do
  check "'$cmd' has several gated segments and is denied" "$(gate "$cmd" "$on_main")" "$segments"
done
for cmd in 'git merge evil; git merge-base --fork-point feature/x' 'git merge evil; git merge-base --help'; do
  check "'$cmd' is denied on the merge's own operand" "$(gate "$cmd" "$on_main")" "2 merge-gate: unknown branch 'evil'."
done
check "a merge beside merge-base, merge-tree, merge-file, and push-x is one segment" \
  "$(gate 'git merge-base main feature/x; git merge-tree main feature/x; git merge-file a b c; git push-x; git merge feature/x' "$on_main")" "0 "
for cmd in 'git merge -m feature/x other' 'git merge -s ours other'; do
  out="$(gate "$cmd" "$on_main")"
  check "'$cmd' is denied" "${out%% *}" "2"
  check "'$cmd' gates the real operand" "$(grep -c 'review gates not proven for other' <<<"$out")" "1"
done
check "a merge in a subshell is denied even with five PASS" "$(gate '(git merge feature/x)' "$on_main")" "2 $combined"
# shellcheck disable=SC2016 # the substitution is the command under test
check "a merge in a command substitution is denied even with five PASS" \
  "$(gate 'out=$(git merge feature/x)' "$on_main")" "2 $combined"

no_branch="2 merge-gate: could not determine the branch being merged into main."
upstream other
check "a bare merge; with a local upstream is denied" "$(gate 'git merge; true' "$on_main")" "$no_branch"
check "a bare merge&& with a local upstream is denied" "$(gate 'git merge&&true' "$on_main")" "$no_branch"
upstream origin/main
check "a bare merge with a remote-trunk upstream is allowed" "$(gate 'git merge&&true' "$on_main")" "0 "

pull_denied="2 merge-gate: on main, pull only its remote trunk (git pull with a remote-trunk upstream, or git pull <remote> main); fetch, then merge the local branch with git merge <branch> so the ledger is checked."
for cmd in 'git pull' 'git pull --ff-only' 'git pull --rebase' 'git pull --no-rebase' 'git pull -X theirs'; do
  check "bare '$cmd' with a remote-trunk upstream is allowed" "$(gate "$cmd" "$on_main")" "0 "
done
for cmd in 'git pull origin main' 'git pull origin refs/heads/main' 'git pull --ff-only origin main' 'git pull -X theirs origin main'; do
  check "explicit remote trunk '$cmd' is allowed" "$(gate "$cmd" "$on_main")" "0 "
done
for cmd in 'git pull origin feature/x' 'git pull . feature/x' "git pull $on_feature" 'git pull https://example.com/r.git main' 'git pull --squash'; do
  check "'$cmd' on main is denied" "$(gate "$cmd" "$on_main")" "$pull_denied"
done
upstream other
check "a bare pull with a local upstream is denied" "$(gate 'git pull' "$on_main")" "$pull_denied"
check "a pull on a feature branch is allowed" "$(gate 'git pull . main' "$on_feature")" "0 "

onto="2 merge-gate: pushing 'feature/x' onto main bypasses the PR and its gates; open a PR and merge it with 'gh pr merge' (or 'git merge' on main in a no-remote repo)."
bare_force="2 merge-gate: a force push without a refspec from main pushes main; name the branch to push."
redirected_push="merge-gate: a push run through cd, pushd, -C, --git-dir, GIT_DIR, env -C, or beside a checkout must name its remote and literal refspecs with a non-empty source and a destination that is neither the trunk nor HEAD/@, without delete, --all, or --mirror; run any other push from the repository as its own command."
denied_redirected_push() { check "$1 is denied" "$(gate "$1" "$2")" "2 $redirected_push"; }
denied_redirected_push "git -C $on_main push . feature/x:main" "$TMP"
denied_redirected_push "git --git-dir=$on_main/.git push . feature/x:main" "$TMP"
denied_redirected_push "git -C $on_feature push origin HEAD:main" "$on_main"
denied_redirected_push "cd $on_feature && git push origin HEAD:main" "$on_main"
denied_redirected_push "GIT_DIR=$on_feature/.git git push origin HEAD:main" "$on_main"
denied_redirected_push "git -C $on_main push -f" "$on_feature"
denied_redirected_push "cd $on_feature && git push" "$on_main"
denied_redirected_push "git -C $on_feature push origin main" "$on_main"
denied_redirected_push "git -C $on_feature push origin HEAD" "$on_main"
denied_redirected_push "git -C $on_feature push origin :feature/x" "$on_main"
denied_redirected_push "git -C $on_feature push --delete origin feature/x" "$on_main"
denied_redirected_push "git -C $on_feature push -d origin feature/x" "$on_main"
denied_redirected_push "git -C $on_feature push --all origin" "$on_main"
check "cd <wt> && git push origin 'refs/heads/*' is refused as non-literal" \
  "$(gate "cd $on_feature && git push origin 'refs/heads/*'" "$on_main" | grep -cF "merge-gate: only literal refspecs (<branch> or <src>:<dst>) are accepted;")" "1"
for cmd in "cd $on_feature && git push -u origin feature/x" "git -C $on_feature push -u origin feature/x" \
  "git -C $on_feature push --force-with-lease origin feature/x" "git -C $on_feature push origin feature/x:feature/x"; do
  check "'$cmd' pushes a literal non-trunk branch and is allowed" "$(gate "$cmd" "$on_main")" "0 "
done
check "a push redirected through > is still parsed" "$(gate 'git push origin feature:main>/dev/null' "$on_feature")" \
  "2 merge-gate: pushing 'feature' onto main bypasses the PR and its gates; open a PR and merge it with 'gh pr merge' (or 'git merge' on main in a no-remote repo)."
for cmd in 'git push
git push -f' 'git push
git push' 'git push
git pull'; do
  check "newline-joined '$cmd' has several gated segments and is denied" "$(gate "$cmd" "$on_main")" "$segments"
done
literal="merge-gate: only literal refspecs (<branch> or <src>:<dst>) are accepted;"
for ref in "'refs/heads/x*:refs/heads/m*'" '-f origin :' "'+refs/heads/*:refs/heads/*'" "--prune origin 'refs/heads/*:refs/heads/*'" "-f origin 'refs/heads/*'"; do
  case "$ref" in -*) cmd="git push $ref" ;; *) cmd="git push origin $ref" ;; esac
  check "'$cmd' is refused as a non-literal refspec" "$(gate "$cmd" "$on_feature" | grep -cF "$literal")" "1"
done
check "a literal branch pair is allowed" "$(gate 'git push origin feature/x:feature/x' "$on_feature")" "0 "
for cmd in 'git push --force-w origin main' 'git push --dele origin main'; do
  check "'$cmd' on main is a force or delete of main" "$(gate "$cmd" "$on_main")" \
    "2 merge-gate: force or delete push to main is refused; main is only ever advanced by a gated merge."
done
check "'git push --mirr origin' is a mirror push" "$(gate 'git push --mirr origin' "$on_main")" \
  "2 merge-gate: git push --mirror rewrites main; push branches and merge through the gated path."
for cmd in 'git push --branches -f origin' 'git push --bran -f origin' 'git push --al -f origin'; do
  check "'$cmd' is a forced --all" "$(gate "$cmd" "$on_feature")" "2 merge-gate: a forced push --all includes main; name the branch to push."
done
for cmd in 'git push --recurse-submodules no origin -f' 'git push -o ci.skip -f origin'; do
  check "'$cmd' on main skips the option value and is a bare force" "$(gate "$cmd" "$on_main")" "$bare_force"
done
for prefix in "${option_forms[@]}"; do
  check "'$prefix push' onto main is denied" "$(gate "$prefix push origin feature/x:main" "$on_feature")" "$onto"
done
for ref in "'feature/x:main'" '"feature/x:main"' 'feature/x:ma\in'; do
  check "a quoted or escaped refspec $ref is denied" "$(gate "git push origin $ref" "$on_feature")" "$onto"
done
check "an empty source onto main is denied" "$(gate 'git push origin :main' "$on_feature")" \
  "2 merge-gate: pushing an empty source onto main deletes it; main is only ever advanced by a gated merge."
check "an empty source onto refs/heads/main is denied" "$(gate 'git push origin :refs/heads/main' "$on_feature")" \
  "2 merge-gate: pushing an empty source onto refs/heads/main deletes it; main is only ever advanced by a gated merge."
check "a bare force push on main is denied" "$(gate 'git push -f' "$on_main")" "$bare_force"
check "a force push to a remote on main is denied" "$(gate 'git push --force origin' "$on_main")" "$bare_force"
check "a mirror push is denied" "$(gate 'git push --mirror' "$on_feature")" \
  "2 merge-gate: git push --mirror rewrites main; push branches and merge through the gated path."
check "a force push of a feature branch is allowed" "$(gate 'git push -f origin feature/x' "$on_feature")" "0 "
check "a bare force push on a feature branch is allowed" "$(gate 'git push -f' "$on_feature")" "0 "
mkdir -p "$fresh" && git -C "$fresh" init -q -b main && git_t "$fresh" commit -q --allow-empty -m base
check "'git merge -' with no previous branch is denied" "$(gate 'git merge -' "$fresh")" \
  "2 merge-gate: no previous branch for 'git merge -'."
check "a push of main onto main is allowed" "$(gate 'git push origin main' "$on_main")" "0 "
check "a push of a feature branch is allowed" "$(gate 'git push origin feature/x' "$on_feature")" "0 "
for cmd in 'git push -uf origin' 'git push -fu origin' 'git push +HEAD'; do
  check "'$cmd' on main is a bare force and is denied" "$(gate "$cmd" "$on_main")" "$bare_force"
done
for cmd in 'git push -f origin HEAD' 'git push origin +HEAD' 'git push -f origin @'; do
  check "'$cmd' on main resolves to main and is denied" "$(gate "$cmd" "$on_main")" \
    "2 merge-gate: force or delete push to main is refused; main is only ever advanced by a gated merge."
done
check "a forced --all is denied from a feature branch" "$(gate 'git push --all -f origin' "$on_feature")" \
  "2 merge-gate: a forced push --all includes main; name the branch to push."
check "a push onto heads/main is denied" "$(gate 'git push origin evil:heads/main' "$on_feature")" \
  "2 merge-gate: pushing 'evil' onto heads/main bypasses the PR and its gates; open a PR and merge it with 'gh pr merge' (or 'git merge' on main in a no-remote repo)."

for cmd in 'git push origin >/dev/null feature:main' 'git push origin 2>&1 feature:main' 'git push origin &>/dev/null feature:main'; do
  check "'$cmd' parses the refspec after the redirection" "$(gate "$cmd" "$on_feature")" \
    "2 merge-gate: pushing 'feature' onto main bypasses the PR and its gates; open a PR and merge it with 'gh pr merge' (or 'git merge' on main in a no-remote repo)."
done
check "an empty source after a redirection is denied" "$(gate 'git push origin </dev/null :main' "$on_feature")" \
  "2 merge-gate: pushing an empty source onto main deletes it; main is only ever advanced by a gated merge."
check "a force of main after a redirection is denied" "$(gate 'git push -f origin </dev/null main' "$on_feature")" \
  "2 merge-gate: force or delete push to main is refused; main is only ever advanced by a gated merge."
check "a pattern refspec after a redirection is denied" \
  "$(gate "git push origin >/dev/null '+refs/heads/*:refs/heads/*'" "$on_feature" | grep -cF "$literal")" "1"
denied_redirected_push "git -C $on_main push -f origin feature >/dev/null HEAD:main" "$TMP"
check "a merge operand after a redirection is gated" "$(gate 'git merge >/dev/null evil' "$on_main")" "2 merge-gate: unknown branch 'evil'."
upstream origin/main
check "a pull source after a redirection is gated" "$(gate 'git pull >/dev/null origin feature' "$on_main")" "$pull_denied"
check "a push with a trailing redirection is allowed" "$(gate 'git push origin feature/x >/dev/null' "$on_feature")" "0 "
colons="2 merge-gate: a refspec takes one colon at most;"
for cmd in "git push origin 'HEAD^{/feat:}:refs/heads/main'" 'git push origin HEAD^{/feat:}:main' \
  "git -C $on_feature push -f origin 'HEAD^{/rogue:}:refs/heads/main'" "git -C $on_feature push origin feature:x:main"; do
  check "'$cmd' has two colons and is denied" "$(gate "$cmd" "$on_main" | grep -cF "$colons")" "1"
done

for cmd in 'git push -f origin 2>&1' 'git push --force origin 2>/dev/null' 'git push -f origin 1>/tmp/x' 'git push -f origin &>/tmp/x' \
  'git push -ohello -f origin' 'git push --repo x -f origin' 'git push --receive-pack x -f origin' 'git push --exec x -f origin' \
  'git push --push-option x -f origin' 'git push --e git-receive-pack -f origin'; do
  check "'$cmd' on main is a bare force" "$(gate "$cmd" "$on_main")" "$bare_force"
done
denied_redirected_push "git -C $on_main push -f origin 2>&1" "$on_feature"
denied_redirected_push "git -C $on_main push -f origin @" "$on_feature"
denied_redirected_push "git -C $on_feature push origin +:feature/x" "$on_main"
denied_redirected_push "git -C $on_feature push --de origin feature/x" "$on_main"
check "'git push --de origin main' on main is a delete of main" "$(gate 'git push --de origin main' "$on_main")" \
  "2 merge-gate: force or delete push to main is refused; main is only ever advanced by a gated merge."
check "'git push --m origin' is a mirror push" "$(gate 'git push --m origin' "$on_main")" \
  "2 merge-gate: git push --mirror rewrites main; push branches and merge through the gated path."
check "'git push --b -f origin' is a forced --all" "$(gate 'git push --b -f origin' "$on_feature")" \
  "2 merge-gate: a forced push --all includes main; name the branch to push."
check "'git push origin +:' is refused as non-literal" "$(gate 'git push origin +:' "$on_feature" | grep -cF "$literal")" "1"
check "a push option before a branch is allowed" "$(gate 'git push -o ci.skip origin feature/x' "$on_feature")" "0 "
check "'git pull origin main 2>&1' is allowed" "$(gate 'git pull origin main 2>&1' "$on_main")" "0 "
out="$(gate 'git merge other 2>&1' "$on_main")"
check "'git merge other 2>&1' is gated on its one branch" "$(grep -c 'review gates not proven for other' <<<"$out")" "1"
check "'git merge feature/x 2>&1' with five PASS is allowed" "$(gate 'git merge feature/x 2>&1' "$on_main")" "0 "

check "a redirection before the push subcommand is parsed" "$(gate 'git 2>&1 push origin feature/x:main' "$on_feature")" "$onto"
check "a redirection glued to git is parsed" "$(gate 'git>x push origin feature/x:main' "$on_feature")" "$onto"
check "a redirection after a global option is parsed" "$(gate 'git -c a=b >x push origin feature/x:main' "$on_feature")" "$onto"
check "a redirection before a forced push of main is parsed" "$(gate 'git 2>&1 push -f origin main' "$on_feature")" \
  "2 merge-gate: force or delete push to main is refused; main is only ever advanced by a gated merge."
check "a redirection before a mirror push is parsed" "$(gate 'git 2>&1 push --mirror origin' "$on_feature")" \
  "2 merge-gate: git push --mirror rewrites main; push branches and merge through the gated path."
denied_redirected_push 'git -C /tmp 2>&1 push origin feature:main' "$on_feature"
check "a redirection before the merge subcommand is parsed" "$(gate 'git 2>&1 merge feature' "$on_main")" "2 merge-gate: unknown branch 'feature'."
check "a redirection before the pull subcommand is parsed" "$(gate 'git >x pull origin feature' "$on_main")" "$pull_denied"
check "a push with a redirection before the subcommand is allowed" "$(gate 'git 2>&1 push origin feature/x' "$on_feature")" "0 "
for cmd in 'git push --prune --all origin' 'git push --prune --branches origin'; do
  check "'$cmd' is a forced --all" "$(gate "$cmd" "$on_feature")" "2 merge-gate: a forced push --all includes main; name the branch to push."
done
for cmd in 'git push -f origin >&/dev/null' 'git push -f origin >! /tmp/x' 'git push -f origin {fd}>/dev/null'; do
  check "'$cmd' on main consumes the redirection target and is a bare force" "$(gate "$cmd" "$on_main")" "$bare_force"
done
check "'git pull origin main >&/dev/null' is allowed" "$(gate 'git pull origin main >&/dev/null' "$on_main")" "0 "
check "'git push -of origin' on main reads the rest of the -o cluster as its value and is allowed" "$(gate 'git push -of origin' "$on_main")" "0 "
check "a redirected '-od' push reads d as the -o value and is allowed" "$(gate "git -C $on_feature push -od origin feature/x" "$on_main")" "0 "
check "'git push --pru --all origin' is a forced --all" "$(gate 'git push --pru --all origin' "$on_feature")" \
  "2 merge-gate: a forced push --all includes main; name the branch to push."
# shellcheck disable=SC2016 # the substitutions are the commands under test
for cmd in 'out=$(git push -f origin 2>&1)' 'out=$(git push -f 2>/dev/null)' 'echo $(git push --force origin >/dev/null)' 'echo "$(git push -f origin 2>&1)"'; do
  check "'$cmd' on main has no refspec inside a substitution and is denied" "$(gate "$cmd" "$on_main")" "2 $redirected_push"
done
denied_redirected_push "out=\$(git -C $on_main push -f origin 2>&1)" "$on_feature"
# shellcheck disable=SC2016 # the substitution is the command under test
check "a captured push of a feature branch is allowed" "$(gate 'out=$(git push origin feature/x 2>&1)' "$on_feature")" "0 "

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
