#!/usr/bin/env bash
# session-context.sh <policy|process> — SessionStart hook. Prints the harness policy or the
# resolved DEV_PROCESS.md; a SessionStart hook's stdout is added to the session context. Exits 0
# on every path so a broken hook never blocks a session.
set -uo pipefail

# Claude Code moves a hook's stdout past this many characters to a file and keeps only a preview,
# so each block runs as its own hook and a larger one is replaced by a pointer.
LIMIT=10000
root="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# Text printed by a hook is not substituted by Claude Code, so expand the plugin root here.
block() { local text; text="$(cat)"; printf '%s\n\n%s' "$1" "${text//\$\{CLAUDE_PLUGIN_ROOT\}/$root}"; }

case "${1:-}" in
  policy)
    header="# Harness policy (dev-team plugin)"
    source="$root/context/policy.md"
    if [[ -f "$source" ]]; then out="$(block "$header" <"$source")"; else out="$header: not found at $source."; fi ;;
  process)
    repo="${CLAUDE_PROJECT_DIR:-}"
    [[ -n "$repo" ]] || repo="$(jq -r '.cwd // empty' 2>/dev/null)"
    if path="$("$root/bin/dev-process" path ${repo:+--repo "$repo"} 2>&1)" \
      && process="$("$root/bin/dev-process" show ${repo:+--repo "$repo"} 2>&1)"; then
      header="# Development process (resolved from $path)"
      source="\`$root/bin/dev-process show [<section>]${repo:+ --repo $repo}\`"
      out="$(block "$header" <<<"$process")"
    else
      out="# Development process: resolution failed (${process:-$path}); ask the user which process applies."
    fi ;;
  *)
    out="dev-team session-context.sh: unknown block '${1:-}'." ;;
esac

if (( ${#out} > LIMIT )); then
  out="$header

Not inlined: ${#out} characters exceeds the $LIMIT-character limit on hook output. Read it with $source."
fi
printf '%s\n' "$out"
exit 0
