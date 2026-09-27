#!/usr/bin/env bash
# merge-gate.sh — PreToolUse(Bash) hook. Blocks a merge unless the gate ledger proves every
# review gate passed at the PR's current head and CI is green.
#
# Guards:
#   gh pr merge <n|url> ...                        ledger PASS + `gh pr checks` all green
#   gh api ... repos/<o>/<r>/pulls/<n>/merge       the same check, PR and repo parsed from the path
#   gh api graphql ... mergePullRequest            always denied; merge through `gh pr merge`
#   git merge <branch> on main                     no-remote repo's local "PR" — ledger PASS (no CI)
#   git pull on main                               only from a remote trunk; anything else denied
#   git merge/pull/push after cd, pushd, worktree  always denied; the hook reads the branch before
#     add, a switch to main, -, @{-N}, a rebase    the command runs, so it cannot gate these
#     onto main, a -C/--git-dir/--work-tree/
#     GIT_DIR/env -C redirect, or in a subshell
#   two merge/pull/push segments, a merge of two   always denied
#     branches, a merge from a cwd that is no repo
#   git push ... <src>:main                        denied unless <src> is main itself
#   git push --mirror, :main, a force or delete    always denied; long options match by prefix
#     of main, a forced --all, a bare force on main,
#     a pattern (*) or matching (:) refspec
#
# Exit 2 blocks the tool call and every error path fails closed. The match is textual, so a command
# that merely quotes a guarded phrase is refused; write such text with a file tool instead.
# Not gated: git reached through shell constructs the matcher does not expand (quoting, escapes,
# variables, `eval`, `bash -c`, backticks, aliases, config, split strings, `xargs`/`find -exec`), and
# trunk updates with no merge or push. The tpm's Check ledger and CI status step is the backstop.
#
# Owner-only bypass: create $GATE_LEDGER_ROOT/.bypass, default ~/.claude/gate-ledger/.bypass
# (delete it afterwards). The model has no reason to touch that file; if it does, that is itself
# a policy breach to review.
set -uo pipefail

LEDGER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gate-ledger"
GATE_LEDGER_ROOT="${GATE_LEDGER_ROOT:-$HOME/.claude/gate-ledger}"
BYPASS="$GATE_LEDGER_ROOT/.bypass"
W='(^|[;&|([:space:]])'
END='([[:space:];&|)<>]|$)'
MAIN='(refs/heads/)?(main|master)'
PUSH_MAIN='((refs/)?heads/)?(main|master)'
QUOTED='"[^"]*"|'"'"'[^'"'"']*'"'"''
# One shell word: quoted strings, $(...) substitutions, escaped and plain characters.
WORD="(${QUOTED}|\\\$\\([^)]*\\)|\\\\.|[^][:space:]\"';&|()<>\\\\])+"
TOK="${WORD}|[;&|()<>]"
GIT_BODY="git([[:space:]]+(-[cC][[:space:]]*${WORD}|--(git-dir|work-tree|namespace|exec-path|config-env)[[:space:]]+${WORD}|--[a-z-]+=${WORD}|-[-A-Za-z]+))*[[:space:]]+"
GIT="${W}${GIT_BODY}"
STRATEGY_OPTS="-s --strategy -X --strategy-option"

input="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[[ -n "$command" ]] || exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 2
}
flat="${command//$'\n'/; }"
has() { grep -Eq "$1" <<<"$flat"; }

has "${W}gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)" && is_gh_merge=1 || is_gh_merge=0
has "${W}gh[[:space:]]+api([[:space:]]|$)" && is_gh_api=1 || is_gh_api=0
has "${GIT}merge${END}" && is_git_merge=1 || is_git_merge=0
has "${GIT}push${END}" && is_git_push=1 || is_git_push=0
has "${GIT}pull${END}" && is_git_pull=1 || is_git_pull=0
has "${W}git[[:space:]][^;&|]*(-C|--git-dir|--work-tree)[^;&|]*[[:space:]](merge|pull|push)${END}" && is_redirected=1 || is_redirected=0
(( is_gh_merge || is_gh_api || is_git_merge || is_git_push || is_git_pull || is_redirected )) || exit 0

[[ -f "$BYPASS" ]] && { echo "merge-gate: bypass file present, allowing" >&2; exit 0; }

MP="(merge|pull|push)${END}"
if (( is_redirected )) || { (( is_git_merge || is_git_pull || is_git_push )) && {
  has "${W}(cd|pushd)([[:space:]]|$).*${GIT}${MP}" \
    || has "${GIT}worktree[[:space:]]+add([[:space:]]|$).*${GIT}${MP}" \
    || has "(^|[;&|([:space:]\"'])GIT_(DIR|WORK_TREE)=" \
    || has "${W}env[[:space:]]([^;&|]*[[:space:]])?(-[A-Za-z]*C|--chdir)" \
    || has "\\([[:space:]]*${GIT_BODY}${MP}" \
    || has "${GIT}(checkout|switch)([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+[\"']?(${MAIN}|-|@\\{-[0-9]+\\})[\"']?${END}" \
    || has "${GIT}rebase([[:space:]]+[^;&|[:space:]]+)+[[:space:]]+[\"']?${MAIN}[\"']?${END}"; }; }; then
  deny "merge-gate: run the merge, pull, or push as its own command, from a session whose working directory is the repository, on the already checked-out trunk; one in the same command as a cd, pushd, worktree add, checkout, switch, or rebase, or redirected with -C, --git-dir, --work-tree, GIT_DIR, GIT_WORK_TREE, or env -C, or run in a subshell or command substitution, is not accepted."
fi

spaced="$(sed -E 's/[;&|()<>]/& /g' <<<"$flat")"
if (( $(grep -oE "${GIT}(merge|pull|push)${END}" <<<"$spaced" | wc -l) > 1 )); then
  deny "merge-gate: run one git merge, pull, or push per command; a command with several of them is not accepted."
fi

# Words of the `git <sub>` segment, quotes and escapes removed, up to the next separator.
words() {
  local tok n rest
  [[ "$flat" =~ ${GIT}$1${END}(.*) ]] || return 0
  n=${#BASH_REMATCH[@]}; rest="${BASH_REMATCH[n-2]}${BASH_REMATCH[n-1]}"
  while IFS= read -r tok; do
    [[ "$tok" == [\;\&\|\(\)\<\>] ]] && break
    tok="${tok//\"/}"; tok="${tok//\'/}"; printf '%s\n' "${tok//\\/}"
  done < <(grep -oE "$TOK" <<<"$rest")
}
current="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)" || current=""
on_trunk=0; [[ "$current" == "main" || "$current" == "master" ]] && on_trunk=1
upstream_is_remote_trunk() {
  git -C "$cwd" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null | grep -Eqx 'refs/remotes/[^/]+/(main|master)'
}

if (( is_git_merge )); then
  merge_ops=() skip=0
  while IFS= read -r w; do
    if (( skip )); then skip=0
    elif [[ "$w" == -?* ]]; then [[ " -m --message -F --file $STRATEGY_OPTS --into-name " == *" $w "* ]] && skip=1
    else merge_ops+=("$w"); fi
  done < <(words merge)
  (( ${#merge_ops[@]} <= 1 )) \
    || deny "merge-gate: merge one branch per command, as git merge [options] <branch>; a merge of several branches is not accepted."
  [[ -n "$current" ]] \
    || deny "merge-gate: the working directory '$cwd' is not a git repository, so the merge target cannot be read; run the merge from a session whose working directory is the repository."
  if (( on_trunk )); then
    branch="${merge_ops[0]:-}"
    if [[ "$branch" == - ]]; then
      branch="$(git -C "$cwd" rev-parse --abbrev-ref '@{-1}' 2>/dev/null)" || deny "merge-gate: no previous branch for 'git merge -'."
    fi
    if [[ -z "$branch" ]]; then
      upstream_is_remote_trunk || deny "merge-gate: could not determine the branch being merged into $current."
    else
      repo="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
      head="$(git -C "$cwd" rev-parse "$branch" 2>/dev/null)" || deny "merge-gate: unknown branch '$branch'."
      ledger_out="$("$LEDGER" check "$repo" "$branch" "$head" 2>&1)" \
        || deny "merge-gate: review gates not proven for $branch at ${head:0:12}: $ledger_out. A local branch→main merge is a PR for gate purposes — run all gates and record them."
    fi
  fi
fi

if (( is_git_pull && on_trunk )); then
  pull_ops=() skip=0 pull_ok=1
  while IFS= read -r w; do
    if (( skip )); then skip=0
    elif [[ " $STRATEGY_OPTS " == *" $w "* ]]; then skip=1
    elif [[ "$w" == -* ]]; then [[ " --ff-only --rebase --no-rebase " == *" $w "* ]] || pull_ok=0
    else pull_ops+=("$w"); fi
  done < <(words pull)
  if (( ${#pull_ops[@]} == 0 )); then
    upstream_is_remote_trunk || pull_ok=0
  elif (( ${#pull_ops[@]} != 2 )) || ! git -C "$cwd" remote | grep -qxF -- "${pull_ops[0]}" \
    || ! grep -Eqx "$MAIN" <<<"${pull_ops[1]}"; then
    pull_ok=0
  fi
  (( pull_ok )) || deny "merge-gate: on $current, pull only its remote trunk (git pull with a remote-trunk upstream, or git pull <remote> $current); fetch, then merge the local branch with git merge <branch> so the ledger is checked."
fi

if (( is_git_push )); then
  force=0 all=0 skip=0 push_ops=()
  while IFS= read -r w; do
    if (( skip )); then skip=0; continue; fi
    # Long options match by prefix, as git accepts them.
    case "$w" in
      --no-*) ;;
      --mi*) deny "merge-gate: git push --mirror rewrites main; push branches and merge through the gated path." ;;
      --al* | --br*) all=1 ;;
      --del* | --forc*) force=1 ;;
      --*=*) ;;
      --rep* | --recu* | --rece* | --ex* | --pu*) skip=1 ;;
      --*) ;;
      -*) [[ "$w" == *[fd]* ]] && force=1; [[ "$w" == *o ]] && skip=1 ;;
      +*) force=1; push_ops+=("$w") ;;
      *) push_ops+=("$w") ;;
    esac
  done < <(words push)
  (( force && all )) && deny "merge-gate: a forced push --all includes main; name the branch to push."
  (( force && on_trunk && ${#push_ops[@]} <= 1 )) \
    && deny "merge-gate: a force push without a refspec from $current pushes main; name the branch to push."
  for tok in "${push_ops[@]:1:${#push_ops[@]}}"; do
    [[ "$tok" == *'*'* || "$tok" == : || "$tok" == +: ]] \
      && deny "merge-gate: only literal refspecs (<branch> or <src>:<dst>) are accepted; '$tok' is a pattern or matching refspec."
    tok="${tok#+}"
    [[ "$tok" == HEAD || "$tok" == @ ]] && tok="$current"
    if grep -Eqx "$PUSH_MAIN" <<<"$tok"; then
      (( force )) && deny "merge-gate: force or delete push to $tok is refused; main is only ever advanced by a gated merge."
    elif grep -Eqx "[^:]*:${PUSH_MAIN}" <<<"$tok"; then
      src="${tok%%:*}"
      [[ -n "$src" ]] || deny "merge-gate: pushing an empty source onto ${tok#*:} deletes it; main is only ever advanced by a gated merge."
      (( force )) && deny "merge-gate: force push of '$src' onto ${tok#*:} is refused."
      if [[ "$src" == HEAD || "$src" == @ ]]; then
        src="$current"; [[ -n "$src" ]] || deny "merge-gate: cannot resolve HEAD in $cwd for '$tok'."
      fi
      [[ "$src" == "main" || "$src" == "master" ]] \
        || deny "merge-gate: pushing '$src' onto ${tok#*:} bypasses the PR and its gates; open a PR and merge it with 'gh pr merge' (or 'git merge' on main in a no-remote repo)."
    fi
  done
fi

gate_pr() {
  local repo="$1" pr="$2" head ledger_out checks bad
  head="$(gh pr view "$pr" --repo "$repo" --json headRefOid --jq .headRefOid 2>/dev/null)" \
    || deny "merge-gate: gh pr view $pr failed for $repo."
  ledger_out="$("$LEDGER" check "$repo" "$pr" "$head" 2>&1)" \
    || deny "merge-gate: review gates not proven at head ${head:0:12}: $ledger_out. Run every gate on this head and record verdicts with gate-ledger before merging."
  # Owner-approved: a repo with no CI configured ("no checks reported") counts as an empty, green list.
  if ! checks="$(gh pr checks "$pr" --repo "$repo" --json name,bucket 2>&1)"; then
    if grep -qi "no checks reported" <<<"$checks"; then
      checks="[]"
      echo "merge-gate: no CI checks configured on $repo — ledger gates are the full gate" >&2
    else
      deny "merge-gate: gh pr checks failed: $checks"
    fi
  fi
  bad="$(jq -r '[.[] | select(.bucket != "pass" and .bucket != "skipping")] | map("\(.name)=\(.bucket)") | join(", ")' <<<"$checks" 2>/dev/null)"
  [[ -z "$bad" ]] || deny "merge-gate: CI not green on ${head:0:12}: $bad. Wait for terminal pass (or fix) before merging."
}

if (( is_gh_merge )); then
  merge_args="$(sed -E 's/.*gh[[:space:]]+pr[[:space:]]+merge//' <<<"$command")"
  # The first standalone number only; a compound command's later numbers must not concatenate.
  pr="$(grep -oE '(^|[[:space:]])[0-9]+([[:space:]]|$)' <<<"$merge_args" | head -1 | tr -d '[:space:]')"
  [[ -z "$pr" ]] && pr="$(grep -oE '/pull/[0-9]+' <<<"$merge_args" | grep -oE '[0-9]+' | head -1)"
  repo="$(grep -oE -- '(--repo|-R)[[:space:]=]+[^[:space:]]+' <<<"$merge_args" | sed -E 's/^(--repo|-R)[[:space:]=]+//' | head -1)"
  if [[ -z "$repo" ]]; then
    repo="$(cd "$cwd" 2>/dev/null && gh repo view --json nameWithOwner --jq .nameWithOwner 2>/dev/null)" || repo=""
  fi
  [[ -n "$pr" ]] || deny "merge-gate: could not determine the PR number from '$command'; pass an explicit PR number."
  [[ -n "$repo" ]] || deny "merge-gate: could not resolve the repository from the cwd '$cwd' with gh repo view; pass --repo <owner/name>."
  gate_pr "$repo" "$pr"
fi

if (( is_gh_api )); then
  has 'mergePullRequest' && deny "merge-gate: GraphQL mergePullRequest is not a gated path; merge with 'gh pr merge <n>' so the ledger and CI are checked."
  path="$(grep -oE 'repos/[^/[:space:]]+/[^/[:space:]]+/pulls/[0-9]+/merge' <<<"$command" | head -1)"
  if [[ -n "$path" ]]; then
    repo="$(cut -d/ -f2,3 <<<"$path")"; pr="$(cut -d/ -f5 <<<"$path")"
    gate_pr "$repo" "$pr"
  fi
fi
exit 0
