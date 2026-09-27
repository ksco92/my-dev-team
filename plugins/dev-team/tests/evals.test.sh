#!/usr/bin/env bash
# Tests for plugins/dev-team/evals/: every case.yaml parses, and every scaffold script is
# executable and shellcheck-clean. Run: bash plugins/dev-team/tests/evals.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EVALS="$PLUGIN/evals"

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

have_pyyaml=0
python3 -c 'import yaml' >/dev/null 2>&1 && have_pyyaml=1

while IFS= read -r -d '' case_yaml; do
  rel="${case_yaml#"$PLUGIN"/}"
  if (( have_pyyaml )); then
    out="$(python3 -c '
import sys, yaml
with open(sys.argv[1]) as f:
    doc = yaml.safe_load(f)
assert isinstance(doc, dict), "not a mapping"
assert "schema_version" in doc, "missing schema_version"
assert "name" in doc, "missing name"
' "$case_yaml" 2>&1)"
    check "$rel parses with schema_version and name" "$out" ""
  else
    check "$rel declares schema_version" "$(grep -c '^schema_version:' "$case_yaml")" "1"
    check "$rel declares name" "$(grep -c '^name:' "$case_yaml")" "1"
  fi
done < <(find "$EVALS" -name case.yaml -print0)

while IFS= read -r -d '' scaffold; do
  rel="${scaffold#"$PLUGIN"/}"
  check "$rel is executable" "$( [[ -x "$scaffold" ]] && echo yes || echo no )" "yes"
  check "$rel is shellcheck-clean" "$(shellcheck "$scaffold" >&2; echo $?)" "0"
done < <(find "$EVALS" -name '*.sh' -print0)

echo "$pass passed, $fail failed"
(( fail == 0 ))
