#!/usr/bin/env bash
# merge-gate.sh — PreToolUse(Bash) hook. Blocks a merge unless the gate ledger proves every
# review gate passed at the PR's current head and CI is green.
#
# Guards:
#   gh pr merge <n|url> ...                        ledger PASS + `gh pr checks` all green
#   gh api ... repos/<o>/<r>/pulls/<n>/merge       the same check, PR and repo parsed from the path
#   gh api graphql ... mergePullRequest            always denied; merge through `gh pr merge`
#   git merge <branch> on main                     no-remote repo's local "PR" — ledger PASS (no CI)
#   git -C <dir> merge <branch>                    gated as a merge run in <dir>; denied when <dir>
#                                                  is no repo, -C repeats, or an option is unparsed
#   git pull on main                               only from a remote's main or master; else denied
#   git merge/pull after cd, pushd, worktree add,  always denied; the hook reads the branch before
#     a switch to main, -, @{-N}, a rebase onto    the command runs, so it cannot gate these
#     main, a --git-dir/--work-tree/GIT_DIR/
#     env -C redirect, or in a subshell
#   git -C <dir> pull                              always denied
#   git push in any of those forms or with -C      allowed only with a remote and literal refspecs
#                                                  with a source and a destination other than main,
#                                                  master, or HEAD/@, no delete, --all, or --mirror
#   two merge/pull/push segments, a merge of two   always denied
#     branches, a merge without -C from a cwd that is no repo
#   git push ... <src>:main                        denied unless <src> is main itself
#   git push --mirror, :main, a force or delete    always denied; long options match by prefix
#     of main, a forced --all, a bare force on main,
#     a pattern (*), matching (:), or two-colon
#     refspec
#
# Exit 2 blocks the tool call and every error path fails closed. The match is textual, so a command
# that merely quotes a guarded phrase is refused; write such text with a file tool instead. Shell
# redirections (fd numbers, &N, &>, >&, >!, {fd}) are dropped with their targets before matching and
# again when a subcommand's arguments are read.
# Not gated: git reached through shell constructs the matcher does not expand (quoting, escapes,
# line continuations, variables, `eval`, `bash -c`, backticks, aliases, config, split strings,
# `xargs`/`find -exec`), git or gh named other than as the bare lowercase word (a path to the
# binary, a wrapper under another name, a case variant that a case-insensitive filesystem still
# runs), and updates of main or master with no merge or push. The tpm's Check ledger and CI status
# step is the backstop.
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
# A redirection operator; its target, if any, is the next word.
REDIR='(\{[A-Za-z_][A-Za-z0-9_]*\}|[0-9]*)((<<<|<<|>>!?|>!|<>|>\||<|>)(&[0-9]+|&-)?|>&)|&>>?'
TOK="${REDIR}|${WORD}|[;&|()<>]"
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
stripped="" target=0
while IFS= read -r tok; do
  if (( target )); then target=0; continue; fi
  if [[ "$tok" =~ ^(${REDIR})$ ]]; then [[ "$tok" == *'&'[0-9-] ]] || target=1; continue; fi
  stripped+="$tok "
done < <(grep -oE "$TOK" <<<"$flat")
flat="$stripped"
has() { grep -Eq "$1" <<<"$flat"; }

has "${W}gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)" && is_gh_merge=1 || is_gh_merge=0
has "${W}gh[[:space:]]+api([[:space:]]|$)" && is_gh_api=1 || is_gh_api=0
has "${GIT}merge${END}" && is_git_merge=1 || is_git_merge=0
has "${GIT}push${END}" && is_git_push=1 || is_git_push=0
has "${GIT}pull${END}" && is_git_pull=1 || is_git_pull=0
has "${W}git[[:space:]][^;&|]*(-C|--git-dir|--work-tree)[^;&|]*[[:space:]](merge|pull|push)${END}" && is_redirected=1 || is_redirected=0
(( is_gh_merge || is_gh_api || is_git_merge || is_git_push || is_git_pull || is_redirected )) || exit 0

[[ -f "$BYPASS" ]] && { echo "merge-gate: bypass file present, allowing" >&2; exit 0; }

# Whether `git <sub>` is redirected by an option in the alternation $2 or combined with a branch or
# directory change.
combined() {
  local mp="$1${END}"
  has "${W}git[[:space:]][^;&|]*($2)[^;&|]*[[:space:]]${mp}" \
    || has "${W}(cd|pushd)([[:space:]]|$).*${GIT}${mp}" \
    || has "${GIT}worktree[[:space:]]+add([[:space:]]|$).*${GIT}${mp}" \
    || has "(^|[;&|([:space:]\"'])GIT_(DIR|WORK_TREE)=" \
    || has "${W}env[[:space:]]([^;&|]*[[:space:]])?(-[A-Za-z]*C|--chdir)" \
    || has "\\([[:space:]]*${GIT_BODY}${mp}" \
    || has "${GIT}(checkout|switch)([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+[\"']?(${MAIN}|-|@\\{-[0-9]+\\})[\"']?${END}" \
    || has "${GIT}rebase([[:space:]]+[^;&|[:space:]]+)+[[:space:]]+[\"']?${MAIN}[\"']?${END}"
}
redirected_push=0
redir='--git-dir|--work-tree'
(( is_git_push || is_redirected )) && combined push "-C|$redir" && redirected_push=1
if (( is_git_merge || is_git_pull || is_redirected )) &&
  { combined merge "$redir" || combined pull "-C|$redir"; }; then
  deny "merge-gate: run the merge or pull as its own command, from the repository's working directory (or, for a merge, with git -C <repository>), on the branch already checked out there; one in the same command as a cd, pushd, worktree add, checkout, switch, or rebase, or redirected with --git-dir, --work-tree, GIT_DIR, GIT_WORK_TREE, env -C, or (for a pull) -C, or run in a subshell or command substitution, is not accepted."
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
  local target=0
  while IFS= read -r tok; do
    if (( target )); then target=0; continue; fi
    [[ "$tok" == [\;\&\|\(\)] ]] && break
    # A redirection inside a $(...) word survives the whole-command strip.
    if [[ "$tok" =~ ^(${REDIR})$ ]]; then [[ "$tok" == *'&'[0-9-] ]] || target=1; continue; fi
    tok="${tok//\"/}"; tok="${tok//\'/}"; printf '%s\n' "${tok//\\/}"
  done < <(grep -oE "$TOK" <<<"$rest")
}
while IFS= read -r m; do
  [[ "$m" =~ ^${GIT}merge${END} && "${BASH_REMATCH[0]}" == *[[:space:]]-C* ]] \
    || deny "merge-gate: the git options before this -C merge cannot be parsed, so its target cannot be read; write it as git -C <dir> merge <branch>, joining any option to its value with =."
done < <(grep -oE "${W}git[[:space:]][^;&|]*-C[^;&|]*[[:space:]]merge${END}" <<<"$flat")
repo_dir="$cwd"
if (( is_git_merge )); then
  dirs=() next=0
  while IFS= read -r tok; do
    if (( next )); then dirs+=("$tok"); next=0
    elif [[ "$tok" == -C* ]]; then [[ "$tok" == -C ]] && next=1 || dirs+=("$tok"); fi
  done < <(grep -oE "${GIT}merge${END}" <<<"$flat" | head -1 | grep -oE "$TOK")
  if (( ${#dirs[@]} )); then
    (( ${#dirs[@]} == 1 )) || deny "merge-gate: pass one -C per merge; a merge with several is not accepted."
    raw="${dirs[0]}" dir="${dirs[0]//[\"\']/}" dir="${dir//\\/}"
    [[ "$dir" == /* ]] || dir="$cwd/$dir"
    if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
      deny "merge-gate: the merge's -C directory '$raw' is not a literal path to a git repository, so the merge target cannot be read; name an existing repository."
    fi
    repo_dir="$dir"
  fi
fi
current="$(git -C "$repo_dir" rev-parse --abbrev-ref HEAD 2>/dev/null)" || current=""
on_trunk=0; [[ "$current" == "main" || "$current" == "master" ]] && on_trunk=1
upstream_is_remote_trunk() {
  git -C "$repo_dir" rev-parse --symbolic-full-name '@{upstream}' 2>/dev/null | grep -Eqx 'refs/remotes/[^/]+/(main|master)'
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
    || deny "merge-gate: the directory '$repo_dir' is not a git repository, so the merge target cannot be read; run the merge from the repository's working directory or with git -C <repository>."
  if (( on_trunk )); then
    branch="${merge_ops[0]:-}"
    if [[ "$branch" == - ]]; then
      branch="$(git -C "$repo_dir" rev-parse --abbrev-ref '@{-1}' 2>/dev/null)" || deny "merge-gate: no previous branch for 'git merge -'."
    fi
    if [[ -z "$branch" ]]; then
      upstream_is_remote_trunk || deny "merge-gate: could not determine the branch being merged into $current."
    else
      repo="$(git -C "$repo_dir" rev-parse --show-toplevel 2>/dev/null)"
      head="$(git -C "$repo_dir" rev-parse "$branch" 2>/dev/null)" || deny "merge-gate: unknown branch '$branch'."
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
  elif (( ${#pull_ops[@]} != 2 )) || ! git -C "$repo_dir" remote | grep -qxF -- "${pull_ops[0]}" \
    || ! grep -Eqx "$MAIN" <<<"${pull_ops[1]}"; then
    pull_ok=0
  fi
  (( pull_ok )) || deny "merge-gate: on $current, pull only a remote's main or master (git pull with a remote main or master upstream, or git pull <remote> $current); fetch, then merge the local branch with git merge <branch> so the ledger is checked."
fi

if (( is_git_push )); then
  force=0 delete=0 all=0 skip=0 push_ops=()
  while IFS= read -r w; do
    if (( skip )); then skip=0; continue; fi
    # Long options match from the shortest prefix git accepts; in a short cluster, `o` takes the rest.
    case "$w" in
      --no-*) ;;
      --m*) deny "merge-gate: git push --mirror rewrites main; push branches and merge through the gated path." ;;
      --al* | --b*) all=1 ;;
      --de* | --pru*) force=1 delete=1 ;;
      --forc*) force=1 ;;
      --*=*) ;;
      --rep* | --recu* | --rece* | --e* | --pu*) skip=1 ;;
      --*) ;;
      -*)
        flags="${w#-}"; [[ "$w" == *o ]] && [[ "${flags%%o*}o" == "$flags" ]] && skip=1; flags="${flags%%o*}"
        [[ "$flags" == *[fd]* ]] && force=1; [[ "$flags" == *d* ]] && delete=1 ;;
      +*) force=1; push_ops+=("$w") ;;
      *) push_ops+=("$w") ;;
    esac
  done < <(words push)
  for tok in "${push_ops[@]:1:${#push_ops[@]}}"; do
    [[ "$tok" == *'*'* || "$tok" == : || "$tok" == +: ]] \
      && deny "merge-gate: only literal refspecs (<branch> or <src>:<dst>) are accepted; '$tok' is a pattern or matching refspec."
    [[ "$tok" != *:*:* ]] || deny "merge-gate: a refspec takes one colon at most; '$tok' is refused."
  done
  if (( redirected_push )); then
    # Another directory's current branch is unknown, so only literal branches other than main or master may be pushed.
    ok=$(( !delete && !all && ${#push_ops[@]} > 1 ))
    for tok in "${push_ops[@]:1:${#push_ops[@]}}"; do
      tok="${tok#+}"; dst="${tok##*:}"
      [[ -n "${tok%:*}" && "$dst" != HEAD && "$dst" != @ ]] \
        && ! grep -Eqx "$PUSH_MAIN" <<<"$dst" || ok=0
    done
    (( ok )) || deny "merge-gate: a push run through cd, pushd, -C, --git-dir, GIT_DIR, env -C, or beside a checkout must name its remote and literal refspecs with a non-empty source and a destination that is neither main, master, nor HEAD/@, without delete, --all, or --mirror; run any other push from the repository as its own command."
  fi
  (( force && all )) && deny "merge-gate: a forced push --all includes main; name the branch to push."
  (( force && on_trunk && ${#push_ops[@]} <= 1 )) \
    && deny "merge-gate: a force push without a refspec from $current pushes main; name the branch to push."
  for tok in "${push_ops[@]:1:${#push_ops[@]}}"; do
    tok="${tok#+}"
    [[ "$tok" == HEAD || "$tok" == @ ]] && tok="$current"
    if grep -Eqx "$PUSH_MAIN" <<<"$tok"; then
      (( force )) && deny "merge-gate: force or delete push to $tok is refused; main is only ever advanced by a gated merge."
    elif [[ "$tok" == *:* ]] && grep -Eqx "$PUSH_MAIN" <<<"${tok##*:}"; then
      src="${tok%:*}"
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
