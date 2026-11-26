#!/usr/bin/env bash
# Tests for bin/preflight-scan. Run: bash plugins/dev-team/tests/preflight-scan.test.sh
set -uo pipefail

PLUGIN="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCAN="$PLUGIN/bin/preflight-scan"
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

git_clean() {
  GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null \
    git -C "$1" -c user.name=Test -c user.email=test@example.com -c commit.gpgsign=false "${@:2}"
}

repo="$TMP/repo"
mkdir -p "$repo/src" "$repo/tests" "$repo/.github/workflows"
git_clean "$repo" init -q -b main
cat >"$repo/LICENSE" <<'LIC'
MIT License

Copyright (c) 2026 Example
LIC
cat >"$repo/.github/workflows/ci.yml" <<'WF'
on:
  push:
    branches: [main]
WF
cat >"$repo/README.md" <<'MD'
# Demo

![CI](https://github.com/org/demo/actions/workflows/ci.yml/badge.svg)

See [src/ok.py](src/ok.py).
MD
cat >"$repo/src/ok.py" <<'PY'
"""Clean module."""


def add(a: int, b: int) -> int:
    """Add two integers."""
    return a + b
PY
git_clean "$repo" add -A
git_clean "$repo" commit -q -m "init"

out="$("$SCAN" --scope=full --repo "$repo" 2>&1)"
check "clean repo exits 0 in full mode" "$?" "0"
check "clean repo prints nothing" "$out" ""

# Introduce deterministic violations on a feature branch.
git_clean "$repo" checkout -q -b feature/test
cat >"$repo/src/bad.py" <<'PY'
"""Bad module."""

# TODO: finish this later
# Certainly! I've added the helper per the brief in this PR.
# Panics: never
# This is deliberately here.
# ponytail: global lock without trigger
# See [`crate::foo`]
PATH = "/Users/alice/secret"
PY
cat >"$repo/tests/test_dup.py" <<'PY'
"""Dup tests."""


def test_one() -> None:
    assert True


def test_one() -> None:
    assert True
PY
cat >"$repo/README.md" <<'MD'
# Demo

Coming soon!

## Usage

See [missing.md](missing.md).

## Usage

Repeated heading.
MD
cat >"$repo/pyproject.toml" <<'TOML'
[project]
authors = [{ name = "Your Name" }]
TOML
git_clean "$repo" add -A
git_clean "$repo" commit -q -m "bad"

diff_out="$("$SCAN" --scope=diff --base main --repo "$repo" 2>&1)"
rc=$?
check "diff mode exits 1 on violations" "$rc" "1"
for rule in AI001 AI002 AI003 AI007 AI008 CH002 CH003 CH004 CH005 CH006 DOC001 DOC002 DOC004; do
  check "detects $rule" "$(grep -c "\[$rule\]" <<<"$diff_out" | grep -c '^[1-9]')" "1"
done

json_out="$("$SCAN" --scope=diff --base main --repo "$repo" --json)"
check "json output parses as non-empty array" "$(jq 'length > 0' <<<"$json_out")" "true"

# Comment ratio > 40% (CH001)
{
  echo '"""Noisy."""'
  for i in $(seq 1 12); do echo "# prose line $i"; done
  for i in $(seq 1 10); do echo "X_$i = $i"; done
} >"$repo/src/noisy.py"
git_clean "$repo" add src/noisy.py
ratio_out="$("$SCAN" --scope=diff --base main --repo "$repo" 2>&1)"
check "detects CH001 comment ratio > 40%" "$(grep -c '\[CH001\]' <<<"$ratio_out")" "1"

# Regression: backticked TODO in README and absence string in test fixtures do not false-positive
fp_repo="$TMP/fp"
mkdir -p "$fp_repo/tests"
git_clean "$fp_repo" init -q -b main
cat >"$fp_repo/README.md" <<'MD'
# sample

Rejects source `TODO`/`FIXME`/`XXX`/`HACK` crumbs.
MD
cat >"$fp_repo/tests/test_sample.py" <<'PY'
"""Fixture test."""


def test_absence_fixture() -> None:
    sample = "# Panics: never\n"
    assert sample
PY
git_clean "$fp_repo" add -A
git_clean "$fp_repo" commit -q -m "init"
fp_out="$("$SCAN" --scope=diff --base main --repo "$fp_repo" 2>&1)"
check "backticked TODO in README does not trip AI008" "$(grep -c '\[AI008\]' <<<"$fp_out")" "0"
check "absence string in test file does not trip CH002" "$(grep -c '\[CH002\]' <<<"$fp_out")" "0"

# Invalid repo exits 2
"$SCAN" --repo "$TMP/missing" >/dev/null 2>&1
check "missing repo exits 2" "$?" "2"

echo "$pass passed, $fail failed"
(( fail == 0 ))
