#!/usr/bin/env bash
# Tests for bin/gate-ledger: the ledger, its history file, and stats.
# Run: bash plugins/dev-team/tests/gate-ledger.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GL="$PLUGIN/bin/gate-ledger"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
export GATE_LEDGER_ROOT="$TMP/root"

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
tab() { local IFS=$'\t'; printf '%s\n' "$*"; }

hist="$GATE_LEDGER_ROOT/a__b/1.history.jsonl"
ledger="$GATE_LEDGER_ROOT/a__b/1.json"

"$GL" record a/b 1 code-health FAIL 2 h1 opus >/dev/null
"$GL" record a/b 1 pr-reviewer PASS 0 h1 sonnet >/dev/null
check "two records at one head give two history lines" "$(wc -l <"$hist" | tr -d ' ')" "2"
check "the ledger holds both gates" "$(jq -c '.gates | keys' "$ledger")" '["code-health","pr-reviewer"]'

"$GL" record a/b 1 code-health PASS 0 h2 opus >/dev/null
check "a record at a new head resets the ledger to one gate" "$(jq -c '.gates | keys' "$ledger")" '["code-health"]'
check "a record at a new head gives a third history line" "$(wc -l <"$hist" | tr -d ' ')" "3"
check "each history line has the eight keys" \
  "$(jq -c 'keys' "$hist" | sort -u)" '["at","findings","gate","head","id","model","repo","verdict"]'
check "a history line holds the call's values" \
  "$(head -1 "$hist" | jq -c 'del(.at)')" '{"repo":"a/b","id":"1","head":"h1","gate":"code-health","verdict":"FAIL","findings":2,"model":"opus"}'
check "the history line's time is the ledger entry's time" "$(tail -1 "$hist" | jq -r .at)" "$(jq -r '.gates["code-health"].at' "$ledger")"

"$GL" record a/b 2 pr-reviewer FAIL 1 h3 opus >/dev/null
"$GL" record a/bc 1 code-health PASS 0 h9 sonnet >/dev/null
"$GL" record a/bc 1 security-review PASS 1 h9 sonnet >/dev/null
"$GL" record a/bc 1 oss-reviewer BLOCKED 0 h9 sonnet >/dev/null
reset_out="$("$GL" reset a/b 1)"
check "reset prints the ledger path" "$reset_out" "reset $ledger"
check "reset removes the ledger" "$(test -e "$ledger" && echo present || echo gone)" "gone"
check "reset leaves the history" "$(wc -l <"$hist" | tr -d ' ')" "3"

mkdir -p "$GATE_LEDGER_ROOT/a__b/9.history.jsonl"
check "record exits 1 when the history cannot be appended" "$("$GL" record a/b 9 code-health PASS 0 h1 opus >/dev/null 2>&1; echo $?)" "1"
check "the ledger is written when the history cannot be appended" "$(jq -r .head "$GATE_LEDGER_ROOT/a__b/9.json")" "h1"
rmdir "$GATE_LEDGER_ROOT/a__b/9.history.jsonl"

gate_header="$(tab gate records not_clean findings)"
change_header="$(tab repo id heads records findings)"
check "stats prints both tables" "$("$GL" stats)" "$gate_header
$(tab code-health 3 1 2)
$(tab oss-reviewer 1 1 0)
$(tab pr-reviewer 2 1 1)
$(tab security-review 1 1 1)

$change_header
$(tab a/b 1 2 3 2)
$(tab a/b 2 1 1 1)
$(tab a/bc 1 1 3 1)"
check "stats <repo-key> leaves the other repository out" "$("$GL" stats a/b)" "$gate_header
$(tab code-health 2 1 2)
$(tab pr-reviewer 2 1 1)

$change_header
$(tab a/b 1 2 3 2)
$(tab a/b 2 1 1 1)"
check "stats on an empty root" "$(GATE_LEDGER_ROOT="$TMP/empty" "$GL" stats; echo "rc=$?")" "no history
rc=0"

echo '{not json' >>"$GATE_LEDGER_ROOT/a__bc/1.history.jsonl"
check "stats names an unparsable history file and exits 1" \
  "$("$GL" stats 2>&1 >/dev/null | grep -c "gate-ledger: cannot parse $GATE_LEDGER_ROOT/a__bc/1.history.jsonl"; "$GL" stats >/dev/null 2>&1; echo "rc=$?")" "1
rc=1"
check "record still works with an unparsable history file" "$("$GL" record a/bc 1 pr-reviewer PASS 0 h9 opus >/dev/null; echo "rc=$?")" "rc=0"
check "check still reads the ledger with an unparsable history file" "$("$GL" check a/bc 1 h9 | head -1)" "gate oss-reviewer: BLOCKED (findings=0)"

check "an unknown command exits 2" "$("$GL" nope >/dev/null 2>&1; echo $?)" "2"
check "stats with two arguments exits 2" "$("$GL" stats a/b a/bc >/dev/null 2>&1; echo $?)" "2"

padded="$TMP/gate-ledger"
{ printf '# padding\n%.0s' 1 2 3 4 5 6 7 8 9 10; sed 's/^#   gate-ledger stats .*/&\n#   gate-ledger inserted-after-stats/' "$GL"; } >"$padded"
check "usage prints the stats, inserted and history lines of a longer header" \
  "$(bash "$padded" 2>&1 | grep -cE 'gate-ledger stats  |inserted-after-stats|history.jsonl')" "3"

# Configurable gate roster via DEV_PROCESS.md frontmatter and GATE_LEDGER_GATES.
cfg_repo="$TMP/cfg-repo"
mkdir -p "$cfg_repo"
cat >"$cfg_repo/DEV_PROCESS.md" <<'MD'
---
tracker: none
host: none
workspace: branch-in-place
merge_method: merge
gates: pr-reviewer, code-health, security-review
---
MD
"$GL" record cfg/repo 7 pr-reviewer PASS 0 h7 sonnet >/dev/null
"$GL" record cfg/repo 7 code-health PASS 0 h7 sonnet >/dev/null
"$GL" record cfg/repo 7 security-review PASS 0 h7 opus >/dev/null
check "custom gates in DEV_PROCESS.md passes with configured subset" \
  "$("$GL" check cfg/repo 7 h7 --repo-dir "$cfg_repo" >/dev/null 2>&1; echo $?)" "0"
check "default 5-gate check fails when oss-reviewer and readme-writer missing" \
  "$("$GL" check cfg/repo 7 h7 --repo-dir "$TMP" >/dev/null 2>&1; echo $?)" "1"
check "GATE_LEDGER_GATES overrides required gates" \
  "$(GATE_LEDGER_GATES="pr-reviewer,code-health" "$GL" check cfg/repo 7 h7 >/dev/null 2>&1; echo $?)" "0"

# Concurrent record calls do not clobber each other.
(
  "$GL" record conc/repo 1 pr-reviewer PASS 0 hc1 sonnet >/dev/null &
  "$GL" record conc/repo 1 code-health PASS 0 hc1 sonnet >/dev/null &
  "$GL" record conc/repo 1 oss-reviewer PASS 0 hc1 sonnet >/dev/null &
  "$GL" record conc/repo 1 security-review PASS 0 hc1 opus >/dev/null &
  "$GL" record conc/repo 1 readme-writer PASS 0 hc1 sonnet >/dev/null &
  wait
)
check "concurrent records preserve all 5 gates" \
  "$("$GL" check conc/repo 1 hc1 --repo-dir "$TMP" >/dev/null 2>&1; echo $?)" "0"

echo "$pass passed, $fail failed"
(( fail == 0 ))
