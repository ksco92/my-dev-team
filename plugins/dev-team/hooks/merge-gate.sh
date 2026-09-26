#!/usr/bin/env bash
# merge-gate.sh — PreToolUse(Bash) hook. Blocks a merge unless the gate ledger proves every
# review gate passed at the PR's current head and CI is green.
#
# Guards:
#   gh pr merge <n|url> ...                        ledger PASS + `gh pr checks` all green
#   gh api ... repos/<o>/<r>/pulls/<n>/merge       the same check, PR and repo parsed from the path
#   gh api graphql ... mergePullRequest            always denied; merge through `gh pr merge`
#   git merge <branch> on main                     no-remote repo's local "PR" — ledger PASS (no CI)
#   git pull <path|remote> <branch> on main       the same ledger check; a remote's trunk passes
#   git merge after cd/pushd/worktree add, with a  always denied; the hook reads the branch before
#     checkout/switch to main, -, or @{-N}, or     the command runs, so it cannot gate these
#     through -C, --git-dir, --work-tree,
#     GIT_DIR=, GIT_WORK_TREE=, env -C, or in
#     a subshell or $(...) substitution
#   two merges, or a merge of two branches         always denied
#   git merge from a cwd that is no repository     always denied
#   git push ... <src>:main                        denied unless <src> is main itself
#   git push --force / +ref / --delete ... main    always denied
#
# Exit 2 blocks the tool call (any other exit lets it through), so every unexpected error path
# here fails CLOSED: a hook that cannot prove the gate is green refuses the merge. The match is
# textual, so a command that merely quotes one of the guarded phrases is also refused; write such
# text with a file tool instead.
# Not gated: `bash -c`/`sh -c`, an absolute git path, a backtick substitution, an escaped or quoted
# `git`, a branch in a shell variable, a `symbolic-ref` switch, or a main update without a merge (`reset
# --hard`, `branch -f`, `update-ref`, a fetch into main, `checkout -B main <ref>`); hence the tpm's own
# Check ledger and CI status step before every Merge.
#
# Owner-only bypass: create $GATE_LEDGER_ROOT/.bypass, default ~/.claude/gate-ledger/.bypass
# (delete it afterwards). The model has no reason to touch that file; if it does, that is itself
# a policy breach to review.
set -uo pipefail

LEDGER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gate-ledger"
GATE_LEDGER_ROOT="${GATE_LEDGER_ROOT:-$HOME/.claude/gate-ledger}"
BYPASS="$GATE_LEDGER_ROOT/.bypass"
W='(^|[;&|([:space:]])'
MAIN='(refs/heads/)?(main|master)'
# `git`, its global options (a value may be quoted), and the space before the subcommand.
VAL='("[^"]*"|'"'"'[^'"'"']*'"'"'|[^;&|()[:space:]]+)'
GIT_BODY="git([[:space:]]+(-[cC][[:space:]]*${VAL}|--(git-dir|work-tree|namespace|exec-path|config-env)([[:space:]]+|=)${VAL}|-[-A-Za-z]+))*[[:space:]]+"
GIT="${W}${GIT_BODY}"
# One shell word (quotes kept) or one separator.
TOK='("[^"]*"|'"'"'[^'"'"']*'"'"'|[^][:space:]"'"'"';&|()]+)+|[;&|()]'

input="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[[ -n "$command" ]] || exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 2
}
flat="${command//$'\n'/ }"
has() { grep -Eq "$1" <<<"$flat"; }

has "${W}gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)" && is_gh_merge=1 || is_gh_merge=0
has "${W}gh[[:space:]]+api([[:space:]]|$)" && is_gh_api=1 || is_gh_api=0
has "${GIT}merge([[:space:]]|$)" && is_git_merge=1 || is_git_merge=0
has "${GIT}push([[:space:]]|$)" && is_git_push=1 || is_git_push=0
has "${GIT}pull([[:space:]]|$)" && is_git_pull=1 || is_git_pull=0
has "${W}git[[:space:]][^;&|]*(-C|--git-dir|--work-tree)[^;&|]*[[:space:]]merge([[:space:]]|$)" && is_redirected_merge=1 || is_redirected_merge=0
(( is_gh_merge || is_gh_api || is_git_merge || is_git_push || is_git_pull || is_redirected_merge )) || exit 0

[[ -f "$BYPASS" ]] && { echo "merge-gate: bypass file present, allowing" >&2; exit 0; }

if (( is_redirected_merge )) || { (( is_git_merge )) && {
  has "${W}(cd|pushd)([[:space:]]|$).*${GIT}merge([[:space:]]|$)" \
    || has "${GIT}worktree[[:space:]]+add([[:space:]]|$).*${GIT}merge([[:space:]]|$)" \
    || has "${W}(export[[:space:]]+)?GIT_(DIR|WORK_TREE)=" \
    || has "${W}env[[:space:]]([^;&|]*[[:space:]])?(-C|--chdir)" \
    || has "\([[:space:]]*${GIT_BODY}merge([[:space:]]|$)" \
    || has "${GIT}(checkout|switch)([[:space:]]+[^;&|[:space:]]+)*[[:space:]]+[\"']?(${MAIN}|-|@\{-[0-9]+\})[\"']?([;&|)[:space:]]|$)"; }; }; then
  deny "merge-gate: run the merge as its own command, from a session whose working directory is the repository, on the already checked-out trunk; a merge in the same command as a cd, pushd, worktree add, checkout, or switch, or one redirected with -C, --git-dir, --work-tree, GIT_DIR, GIT_WORK_TREE, or env -C, or run in a subshell or command substitution, is not accepted."
fi

# Non-option operands of the last `git <sub>` segment, quotes stripped; $2 lists options that take a value.
operands() {
  local tok skip=0
  while IFS= read -r tok; do
    [[ "$tok" == [\;\&\|\(\)] ]] && break
    if (( skip )); then skip=0; continue; fi
    if [[ "$tok" == -* ]]; then [[ " $2 " == *" $tok "* ]] && skip=1; continue; fi
    tok="${tok//\"/}"; printf '%s\n' "${tok//\'/}"
  done < <(sed -E "s/.*${GIT}$1//" <<<"$flat" | grep -oE "$TOK")
}

# Ledger proof for merging a local branch into the checked-out trunk.
gate_branch() {
  local branch="$1" repo head ledger_out
  repo="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
  head="$(git -C "$cwd" rev-parse "$branch" 2>/dev/null)" || deny "merge-gate: unknown branch '$branch'."
  ledger_out="$("$LEDGER" check "$repo" "$branch" "$head" 2>&1)" \
    || deny "merge-gate: review gates not proven for $branch at ${head:0:12}: $ledger_out. A local branch→main merge is a PR for gate purposes — run all gates and record them."
}

if (( is_git_merge )); then
  merge_ops=()
  while IFS= read -r op; do merge_ops+=("$op"); done \
    < <(operands merge "-m --message -F --file -s --strategy -X --strategy-option --into-name")
  if (( $(grep -oE "${GIT}merge([[:space:]]|$)" <<<"$flat" | wc -l) > 1 || ${#merge_ops[@]} > 1 )); then
    deny "merge-gate: merge one branch per command, as git merge [options] <branch>; a command with several merges, or a merge of several branches, is not accepted."
  fi
fi

# Ledger + CI proof for one GitHub PR. Any failure to read state denies.
gate_pr() {
  local repo="$1" pr="$2" head ledger_out checks bad
  head="$(gh pr view "$pr" --repo "$repo" --json headRefOid --jq .headRefOid 2>/dev/null)" \
    || deny "merge-gate: gh pr view $pr failed for $repo."
  ledger_out="$("$LEDGER" check "$repo" "$pr" "$head" 2>&1)" \
    || deny "merge-gate: review gates not proven at head ${head:0:12}: $ledger_out. Run every gate on this head and record verdicts with gate-ledger before merging."
  # CI must be terminal-green: any pending/failing/cancelled bucket blocks.
  # Exception (owner-approved): a repo with NO checks configured — `gh pr checks` exits non-zero
  # with "no checks reported" there. CI-less repos are gated by the local lint/test runs the
  # ledger's gates already require, so that one case is an empty (green) check list.
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
  # PR id: first bare number or a trailing /pull/<n> in a URL; --repo overrides the cwd repo.
  merge_args="$(sed -E 's/.*gh[[:space:]]+pr[[:space:]]+merge//' <<<"$command")"
  # First whitespace-delimited number only: take one match BEFORE stripping whitespace, or a
  # compound command's later numbers (a `gh pr view 29`, an `issue view 21`) concatenate into one.
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

if (( is_git_push )); then
  # Only the push's own arguments: strip everything before `git push` and after the next separator.
  push_args="$(sed -E "s/.*${GIT}push//; s/[;&|].*//" <<<"$flat")"
  force=0
  grep -Eq -- '(^|[[:space:]])(-f|--force|--force-with-lease(=[^[:space:]]*)?|-d|--delete)([[:space:]]|$)' <<<"$push_args" && force=1
  for tok in $push_args; do
    [[ "$tok" == +* ]] && { force=1; tok="${tok#+}"; }
    if grep -Eq "^${MAIN}$" <<<"$tok"; then
      (( force )) && deny "merge-gate: force or delete push to $tok is refused; main is only ever advanced by a gated merge."
      continue
    fi
    if grep -Eq "^[^:]*:${MAIN}$" <<<"$tok"; then
      src="${tok%%:*}"
      (( force )) && deny "merge-gate: force push of '$src' onto ${tok#*:} is refused."
      if [[ "$src" == "HEAD" || -z "$src" ]]; then
        src="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)" || deny "merge-gate: cannot resolve HEAD in $cwd for '$tok'."
      fi
      [[ "$src" == "main" || "$src" == "master" ]] \
        || deny "merge-gate: pushing '$src' onto ${tok#*:} bypasses the PR and its gates; open a PR and merge it with 'gh pr merge' (or 'git merge' on main in a no-remote repo)."
    fi
  done
fi

if (( is_git_merge )); then
  # git merge — only guarded when merging INTO main/master (the no-remote "PR").
  current="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)" \
    || deny "merge-gate: the working directory '$cwd' is not a git repository, so the merge target cannot be read; run the merge from a session whose working directory is the repository."
  if [[ "$current" == "main" || "$current" == "master" ]]; then
    [[ -n "${merge_ops[0]:-}" ]] || deny "merge-gate: could not determine the branch being merged into $current."
    gate_branch "${merge_ops[0]}"
  fi
fi

if (( is_git_pull )); then
  # A pull into the trunk is a merge unless it takes the trunk from a configured remote.
  current="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)" || current=""
  if [[ "$current" == "main" || "$current" == "master" ]]; then
    pull_ops=()
    while IFS= read -r op; do pull_ops+=("$op"); done \
      < <(operands pull "-s --strategy -X --strategy-option -o --server-option --depth --deepen --shallow-since --shallow-exclude --negotiation-tip")
    if (( ${#pull_ops[@]} > 0 )); then
      (( ${#pull_ops[@]} <= 2 )) || deny "merge-gate: pull one branch per command; a pull of several branches into $current is not accepted."
      src="${pull_ops[1]:-}"; src="${src#+}"; src="${src%%:*}"
      if git -C "$cwd" remote | grep -qxF -- "${pull_ops[0]}"; then
        [[ -z "$src" || "$src" == "main" || "$src" == "master" ]] || gate_branch "$src"
      else
        [[ -n "$src" ]] || deny "merge-gate: could not determine the branch pulled from '${pull_ops[0]}' into $current."
        gate_branch "$src"
      fi
    fi
  fi
fi
exit 0
