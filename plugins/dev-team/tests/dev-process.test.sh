#!/usr/bin/env bash
# Tests for bin/dev-process, hooks/session-context.sh, and the process files' conformance to the
# contract's operation tables. Run: bash plugins/dev-team/tests/dev-process.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_ROOT="$(cd "$PLUGIN/../.." && pwd)"
DP="$PLUGIN/bin/dev-process"
DEFAULT="$PLUGIN/context/dev-process.default.md"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

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

empty_home="$TMP/empty-home"
machine_home="$TMP/machine-home"
repo="$TMP/repo"
bare="$TMP/bare"
mkdir -p "$empty_home" "$machine_home/.claude" "$repo/sub" "$bare"
printf -- '---\ntracker: github\n---\n' >"$machine_home/.claude/DEV_PROCESS.md"
cat >"$repo/DEV_PROCESS.md" <<'MD'
---
tracker: asana
host:  github
---

## Tracker: Asana

```markdown
## Context
```

## Code host: GitHub

host body
MD
git -C "$repo" init -q

# Resolution tiers.
check "repo tier via --repo" "$(HOME="$empty_home" "$DP" path --repo "$repo")" "$repo/DEV_PROCESS.md"
check "repo tier via CLAUDE_PROJECT_DIR" "$(HOME="$empty_home" CLAUDE_PROJECT_DIR="$repo" "$DP" path)" "$repo/DEV_PROCESS.md"
check "repo tier via git toplevel of the cwd" \
  "$(cd "$repo/sub" && HOME="$empty_home" CLAUDE_PROJECT_DIR='' "$DP" path)" "$(cd "$repo" && pwd -P)/DEV_PROCESS.md"
check "--repo wins over CLAUDE_PROJECT_DIR" \
  "$(HOME="$machine_home" CLAUDE_PROJECT_DIR="$repo" "$DP" path --repo "$bare")" "$machine_home/.claude/DEV_PROCESS.md"
check "machine tier" "$(HOME="$machine_home" "$DP" path --repo "$bare")" "$machine_home/.claude/DEV_PROCESS.md"
check "plugin default tier" "$(HOME="$empty_home" "$DP" path --repo "$bare")" "$DEFAULT"

# Sections.
fence='```'
check "show one section, fenced headings kept inside it" \
  "$(HOME="$empty_home" "$DP" show tracker --repo "$repo")" \
  "$(printf '## Tracker: Asana\n\n%smarkdown\n## Context\n%s\n' "$fence" "$fence")"
check "show matches the first word case-insensitively" \
  "$(HOME="$empty_home" "$DP" show CODE --repo "$repo")" "$(printf '## Code host: GitHub\n\nhost body')"
check "show without a section prints the file" \
  "$(HOME="$empty_home" "$DP" show --repo "$repo")" "$(cat "$repo/DEV_PROCESS.md")"
check "show the repository section of the default" \
  "$(HOME="$empty_home" "$DP" show repository --repo "$bare" | head -1)" "## Repository-specific constraints"

# Frontmatter.
check "get a key" "$(HOME="$empty_home" "$DP" get tracker --repo "$repo")" "asana"
check "get trims the value" "$(HOME="$empty_home" "$DP" get host --repo "$repo")" "github"
check "get from the default" "$(HOME="$empty_home" "$DP" get workspace --repo "$bare")" "branch-in-place"

# Errors: exit 1 and one line on stderr.
err="$(HOME="$empty_home" "$DP" show bogus --repo "$repo" 2>&1 >/dev/null)"
check "unknown section exits 1" "$?" "1"
check "unknown section message" "$err" "dev-process: no section 'bogus' in $repo/DEV_PROCESS.md"
err="$(HOME="$empty_home" "$DP" get bogus --repo "$repo" 2>&1 >/dev/null)"
check "unknown key exits 1" "$?" "1"
check "unknown key message" "$err" "dev-process: no frontmatter key 'bogus' in $repo/DEV_PROCESS.md"

# Hook: each block under the context limit, the plugin root expanded, exit 0 when resolution fails.
HOOK="$PLUGIN/hooks/session-context.sh"
long_root="$TMP/a-plugin-cache-path-as-long-as-an-installed-one/ksco92/dev-team/0.0.0"
mkdir -p "$(dirname "$long_root")" && ln -s "$PLUGIN" "$long_root"
out="$(CLAUDE_PLUGIN_ROOT="$long_root" "$HOOK" policy </dev/null)"
check "policy block header" "$(head -1 <<<"$out")" "# Harness policy (dev-team plugin)"
check "policy block is inlined under a long plugin root" "$(grep -c '^Not inlined' <<<"$out")" "0"
check "policy block expands the plugin root" "$(grep -c 'CLAUDE_PLUGIN_ROOT' <<<"$out")" "0"
out="$(HOME="$empty_home" CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$repo" "$HOOK" process </dev/null)"
check "process block names the resolved file" "$(head -1 <<<"$out")" "# Development process (resolved from $repo/DEV_PROCESS.md)"
check "process block falls back to the stdin cwd" \
  "$(HOME="$empty_home" CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR='' "$HOOK" process <<<"{\"cwd\":\"$repo\"}" | head -1)" \
  "# Development process (resolved from $repo/DEV_PROCESS.md)"
check "default process block is inlined and expanded" \
  "$(HOME="$empty_home" CLAUDE_PLUGIN_ROOT="$long_root" CLAUDE_PROJECT_DIR="$bare" "$HOOK" process </dev/null | grep -c -e '^Not inlined' -e 'CLAUDE_PLUGIN_ROOT')" "0"
big="$TMP/big"
mkdir -p "$big" && { printf -- '---\ntracker: none\n---\n'; head -c 12000 /dev/zero | tr '\0' x; } >"$big/DEV_PROCESS.md"
out="$(CLAUDE_PLUGIN_ROOT="$PLUGIN" CLAUDE_PROJECT_DIR="$big" "$HOOK" process </dev/null)"
check "oversized process file is replaced by a pointer" "$(grep -c '^Not inlined: .* Read it with `.*/bin/dev-process show' <<<"$out")" "1"
check "the pointer fits the limit" "$(( ${#out} <= 10000 ))" "1"
broken="$TMP/broken"
mkdir -p "$broken/bin"
printf '#!/bin/sh\necho boom >&2\nexit 1\n' >"$broken/bin/dev-process"
chmod +x "$broken/bin/dev-process"
out="$(CLAUDE_PLUGIN_ROOT="$broken" CLAUDE_PROJECT_DIR="$repo" "$HOOK" process </dev/null)"
check "hook exits 0 when resolution fails" "$?" "0"
check "hook reports a resolution failure in one line" "$out" "# Development process: resolution failed (boom); ask the user which process applies."
out="$(CLAUDE_PLUGIN_ROOT="$broken" "$HOOK" policy </dev/null)"
check "hook exits 0 when the policy is missing" "$?" "0"
check "hook reports a missing policy in one line" "$out" "# Harness policy (dev-team plugin): not found at $broken/context/policy.md."

# Every process file fits the hook limit and carries every Tracker, Code host, and Workspace
# operation of the contract.
operations() { awk -v want="$1" '/^## /{on = ($2 == want)} on && /^\| [^-]/ && !/^\| Operation /' "$PLUGIN/context/dev-process-contract.md" | cut -d'|' -f2 | sed 's/^ *//; s/ *$//'; }
for file in "$DEFAULT" "$PLUGIN/templates/DEV_PROCESS.md" "$REPO_ROOT/DEV_PROCESS.md" "$REPO_ROOT"/docs/examples/DEV_PROCESS.*.md; do
  mkdir -p "$TMP/conf" && cp "$file" "$TMP/conf/DEV_PROCESS.md"
  check "${file#"$REPO_ROOT"/} is inlined by the hook" \
    "$(CLAUDE_PLUGIN_ROOT="$long_root" CLAUDE_PROJECT_DIR="$TMP/conf" "$HOOK" process </dev/null | grep -c '^Not inlined')" "0"
  for word in Tracker Code Workspace; do
    body="$("$DP" show "$word" --repo "$TMP/conf")"
    while IFS= read -r op; do
      check "${file#"$REPO_ROOT"/} has '$op' under $word" "$(grep -cF "| $op |" <<<"$body")" "1"
    done < <(operations "$word")
  done
done

echo "$pass passed, $fail failed"
(( fail == 0 ))
