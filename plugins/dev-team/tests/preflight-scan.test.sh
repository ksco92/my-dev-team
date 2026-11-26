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

# Regression: backticked TODO/CH004/DOC002 in README, test-file comments, unicode paths,
# repo-root links, symlink isolation, --base injection, and eval fixture tells.
fp_repo="$TMP/fp"
mkdir -p "$fp_repo/src" "$fp_repo/tests" "$fp_repo/docs"
git_clean "$fp_repo" init -q -b main
cat >"$fp_repo/LICENSE" <<'LIC'
MIT License

Copyright (c) 2026 Example
LIC
cat >"$fp_repo/.prettierrc.json" <<'JSON'
{}
JSON
git_clean "$fp_repo" add -A
git_clean "$fp_repo" commit -q -m "base"
git_clean "$fp_repo" checkout -q -b feat

cat >"$fp_repo/README.md" <<'MD'
# sample

Rejects source `TODO`/`FIXME`/`XXX`/`HACK` crumbs and ``[`crate::Foo`]`` or `[x](missing.md)` examples.
See [license](/LICENSE).
MD
cat >"$fp_repo/tests/test_sample.py" <<'PY'
"""Fixture test."""


def test_absence_fixture() -> None:
    # Panics: never
    # Certainly! I've added this for testing.
    # This is deliberately here.
    # ponytail: remove later
    sample = "# Panics: never\n"
    assert sample
PY
cat >"$fp_repo/src/clean_str.py" <<'PY'
"""Fixture source holding a string literal."""

EXAMPLE = "# Panics: never\n"
PY
git_clean "$fp_repo" add -A
git_clean "$fp_repo" commit -q -m "feat"

fp_out="$("$SCAN" --scope=diff --base main --repo "$fp_repo" 2>&1)"
fp_rc=$?
check "clean regression branch exits 0 in diff mode" "$fp_rc" "0"
check "backticked TODO in README does not trip AI008" "$(grep -c '\[AI008\]' <<<"$fp_out")" "0"
check "backticked rustdoc link does not trip CH004" "$(grep -c '\[CH004\]' <<<"$fp_out")" "0"
check "test-file absence comment and source string do not trip CH002" "$(grep -c '\[CH002\]' <<<"$fp_out")" "0"
check "prettierrc with markdown files does not trip AI009 in full mode" \
  "$("$SCAN" --scope=full --repo "$fp_repo" 2>&1 | grep -c '\[AI009\]')" "0"

# Security: --base option injection rejected without writing output file
inject_target="$TMP/injected_out"
"$SCAN" --scope=diff --base="--output=$inject_target" --repo "$fp_repo" >/dev/null 2>&1
check "--base starting with '-' exits 2" "$?" "2"
check "--base injection creates no file" "$(find "$TMP" -maxdepth 1 -name 'injected_out*' | wc -l | tr -d ' ')" "0"

# Security: escaping Markdown link triggers DOC002
cat >"$fp_repo/docs/bad_link.md" <<'MD'
[escape](../../../../etc/hosts)
MD
git_clean "$fp_repo" add docs/bad_link.md
git_clean "$fp_repo" commit -q -m "bad link"
check "escaping relative link triggers DOC002" \
  "$("$SCAN" --scope=diff --base main --repo "$fp_repo" 2>&1 | grep -c '\[DOC002\]')" "1"

# Security: symlink pointing outside repo is skipped without leaking contents
printf '# TODO: SECRET_OUTSIDE_DATA\n' >"$TMP/outside_secret.py"
ln -s "$TMP/outside_secret.py" "$fp_repo/src/leak.py"
git_clean "$fp_repo" add src/leak.py
git_clean "$fp_repo" commit -q -m "symlink"
leak_out="$("$SCAN" --scope=diff --base main --repo "$fp_repo" 2>&1)"
check "outside symlink does not leak external file contents" "$(grep -c 'SECRET_OUTSIDE_DATA' <<<"$leak_out")" "0"

# Unicode filename is scanned despite core.quotePath
printf '"""Unicode."""\n# TODO: hidden in unicode\n' >"$fp_repo/src/café.py"
git_clean "$fp_repo" add "src/café.py"
git_clean "$fp_repo" commit -q -m "unicode"
check "unicode filename is scanned for AI002" \
  "$("$SCAN" --scope=diff --base main --repo "$fp_repo" 2>&1 | grep -c '\[AI002\]')" "1"

# Eval tells: status-emoji print and task-referential docstring
cat >"$fp_repo/src/eval_tells.py" <<'PY'
"""Eval tells fixture."""


def run() -> None:
    """Added for issue #12 per reviewer request."""
    print("✅ done")
PY
git_clean "$fp_repo" add src/eval_tells.py
git_clean "$fp_repo" commit -q -m "eval tells"
eval_out="$("$SCAN" --scope=diff --base main --repo "$fp_repo" 2>&1)"
check "detects task-referential issue/reviewer phrasing (AI001)" "$(grep -c '\[AI001\]' <<<"$eval_out")" "1"
check "detects status-emoji print log (AI003)" "$(grep -c '\[AI003\]' <<<"$eval_out")" "1"

# Positive AI009: eslint.config.js and .prettierrc.json in a Rust-only repo do not self-exempt
rs_repo="$TMP/rs-only"
mkdir -p "$rs_repo/src"
git_clean "$rs_repo" init -q -b main
cat >"$rs_repo/LICENSE" <<'LIC'
MIT License

Copyright (c) 2026 Example
LIC
printf 'fn main() {}\n' >"$rs_repo/src/main.rs"
printf 'export default [];\n' >"$rs_repo/eslint.config.js"
printf '{}\n' >"$rs_repo/.prettierrc.json"
git_clean "$rs_repo" add -A
git_clean "$rs_repo" commit -q -m "rust only"
rs_out="$("$SCAN" --scope=full --repo "$rs_repo" 2>&1)"
check "flags eslint.config.js and .prettierrc.json in Rust-only repo (AI009)" "$(grep -c '\[AI009\]' <<<"$rs_out")" "2"

# Invalid repo exits 2
"$SCAN" --repo "$TMP/missing" >/dev/null 2>&1
check "missing repo exits 2" "$?" "2"

echo "$pass passed, $fail failed"
(( fail == 0 ))
