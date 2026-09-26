#!/usr/bin/env bash
# merge-gate.sh — PreToolUse(Bash) hook. Blocks a merge unless the gate ledger proves every
# review gate passed at the PR's current head and CI is green.
#
# Guards:
#   gh pr merge <n|url> ...                        ledger PASS + `gh pr checks` all green
#   gh api ... repos/<o>/<r>/pulls/<n>/merge       the same check, PR and repo parsed from the path
#   gh api graphql ... mergePullRequest            always denied; merge through `gh pr merge`
#   git merge <branch> on main                     no-remote repo's local "PR" — ledger PASS (no CI)
#   git push ... <src>:main                        denied unless <src> is main itself
#   git push --force / +ref / --delete ... main    always denied
#
# Exit 2 blocks the tool call (any other exit lets it through), so every unexpected error path
# here fails CLOSED: a hook that cannot prove the gate is green refuses the merge. The match is
# textual, so a command that merely quotes one of the guarded phrases is also refused; write such
# text with a file tool instead.
#
# Owner-only bypass: create $GATE_LEDGER_ROOT/.bypass, default ~/.claude/gate-ledger/.bypass
# (delete it afterwards). The model has no reason to touch that file; if it does, that is itself
# a policy breach to review.
set -uo pipefail

LEDGER="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/bin/gate-ledger"
GATE_LEDGER_ROOT="${GATE_LEDGER_ROOT:-$HOME/.claude/gate-ledger}"
BYPASS="$GATE_LEDGER_ROOT/.bypass"
W='(^|[;&|[:space:]])'
MAIN='(refs/heads/)?(main|master)'

input="$(cat)"
command="$(jq -r '.tool_input.command // empty' <<<"$input")"
cwd="$(jq -r '.cwd // empty' <<<"$input")"
[[ -n "$command" ]] || exit 0

deny() {
  jq -n --arg r "$1" '{hookSpecificOutput: {hookEventName: "PreToolUse", permissionDecision: "deny", permissionDecisionReason: $r}}'
  exit 2
}
has() { grep -Eq "$1" <<<"$command"; }

has "${W}gh[[:space:]]+pr[[:space:]]+merge([[:space:]]|$)" && is_gh_merge=1 || is_gh_merge=0
has "${W}gh[[:space:]]+api([[:space:]]|$)" && is_gh_api=1 || is_gh_api=0
has "${W}git[[:space:]]+merge([[:space:]]|$)" && is_git_merge=1 || is_git_merge=0
has "${W}git[[:space:]]+push([[:space:]]|$)" && is_git_push=1 || is_git_push=0
(( is_gh_merge || is_gh_api || is_git_merge || is_git_push )) || exit 0

[[ -f "$BYPASS" ]] && { echo "merge-gate: bypass file present, allowing" >&2; exit 0; }

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
  [[ -n "$pr" && -n "$repo" ]] || deny "merge-gate: could not determine PR number/repo from '$command' — pass an explicit PR number (and --repo when outside the checkout)."
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
  push_args="$(sed -E 's/.*git[[:space:]]+push//; s/[;&|].*//' <<<"$command")"
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
  current="$(git -C "$cwd" rev-parse --abbrev-ref HEAD 2>/dev/null)" || exit 0
  if [[ "$current" == "main" || "$current" == "master" ]]; then
    branch="$(sed -E 's/.*git[[:space:]]+merge//' <<<"$command" | tr ' ' '\n' | grep -vE '^(-|$)' | head -1)"
    [[ -n "$branch" ]] || deny "merge-gate: could not determine the branch being merged into $current."
    repo="$(git -C "$cwd" rev-parse --show-toplevel 2>/dev/null)"
    head="$(git -C "$cwd" rev-parse "$branch" 2>/dev/null)" || deny "merge-gate: unknown branch '$branch'."
    ledger_out="$("$LEDGER" check "$repo" "$branch" "$head" 2>&1)" \
      || deny "merge-gate: review gates not proven for $branch at ${head:0:12}: $ledger_out. A local branch→main merge is a PR for gate purposes — run all gates and record them."
  fi
fi
exit 0
