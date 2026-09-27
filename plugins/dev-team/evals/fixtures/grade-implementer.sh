#!/usr/bin/env bash
# grade-implementer.sh — deterministic grader for the implementer eval (evals.json id 6).
#
# Usage: grade-implementer.sh <worktree holding the implementation>
#
# One PASS/FAIL line per check; exit 1 when any check fails. The checks are the issue's acceptance
# criteria (behavior through the CLI, a suite that pins the inclusive end bound) plus PLANTS.md
# inverted: the implementation must contain none of the defect classes the gate evals plant.
set -uo pipefail
WT="${1:?usage: grade-implementer.sh <worktree>}"
cd "$WT" || exit 2
fail=0
check() { local rc=$1; shift; if (( rc == 0 )); then echo "PASS  $*"; else echo "FAIL  $*"; fail=1; fi; }
assert_eq() { if [[ "$1" == "$2" ]]; then check 0 "$3"; else check 1 "$3"; fi; }

PY=(python3)
if ! python3 -c 'import pytest' 2>/dev/null; then
  command -v uv >/dev/null || { echo "need pytest importable by python3, or uv"; exit 2; }
  PY=(uv run --no-project --with pytest==9.1.1 python)
fi
export PYTHONPATH=.

out="$("${PY[@]}" -m pytest -q 2>&1)"; rc=$?; check $rc "pytest passes ($(tail -1 <<<"$out"))"

csv="$(mktemp ../tmp.XXXXXX)"; printf 'date,amount\n2026-01-05,10.50\n2026-01-06,4.50\n2026-01-09,1.00\n' > "$csv"
probe() { "${PY[@]}" -c 'import sys; from ledgerlite.cli import main; sys.exit(main(sys.argv[1:]))' "$@" 2>&1 | tail -1; }
assert_eq "$(probe "$csv")" "total: 16.00" "no flags: total unchanged (16.00)"
assert_eq "$(probe "$csv" --start 2026-01-06 --end 2026-01-06)" "total: 4.50" "--end is inclusive: an entry dated exactly --end is counted"
assert_eq "$(probe "$csv" --end 2026-01-06)" "total: 15.00" "open start bound"
assert_eq "$(probe "$csv" --start 2026-01-09)" "total: 1.00" "open end bound"
assert_eq "$(probe "$csv" --start 2026-01-06 --end 2026-01-05)" "total: 0.00" "empty range totals 0.00"
rm -f "$csv"

# The suite must pin the end boundary: flip the end comparison to exclusive and expect red.
m="$(mktemp -d ../tmpdir.XXXXXX)"; cp -R . "$m"
if "${PY[@]}" - "$m/ledgerlite" <<'PYEOF'
import pathlib, re, sys
root = pathlib.Path(sys.argv[1]); changed = False
for f in root.glob("*.py"):
    s = f.read_text(); t = s
    for pat, rep in ((r"<=\s*end\b", "< end"), (r"\bend\s*>=", "end >"), (r">\s*end\b", ">= end"), (r"\bend\s*<(?!=)", "end <=")):
        t2 = re.sub(pat, rep, t)
        if t2 != t:
            t = t2; break
    if t != s:
        f.write_text(t); changed = True
sys.exit(0 if changed else 1)
PYEOF
then
  (cd "$m" && "${PY[@]}" -m pytest -q >/dev/null 2>&1); mutant_rc=$?
  if [[ $mutant_rc -ne 0 ]]; then check 0 "suite goes red on an exclusive-end mutant (boundary test exists)"
  else check 1 "suite goes red on an exclusive-end mutant (boundary test exists)"; fi
else
  check 1 "could not build the exclusive-end mutant (no end comparison found in ledgerlite/*.py); inspect the boundary test by hand"
fi
rm -rf "$m"

"${PY[@]}" - <<'PYEOF' || fail=1
import ast, io, pathlib, re, sys, tokenize
lib = pathlib.Path("ledgerlite"); results = []
def rec(ok, msg): results.append((bool(ok), msg))
src = {f: f.read_text() for f in sorted(lib.glob("*.py"))}
allsrc = "\n".join(src.values())
rec(not re.search(r"shell\s*=\s*True|\bsubprocess\b|os\.system", allsrc), "no subprocess or shell in the library")
rec(not re.search(r"_live_[0-9a-f]{12,}|API_TOKEN|SECRET|PASSWORD", allsrc), "no hardcoded secret")
rec(not re.search(r"\b(TODO|FIXME|XXX)\b", allsrc), "no TODO crumbs")
rec(not re.search(r"\bprint\(", src[lib / "ledger.py"]), "no print in library code")
rec(not re.search(r"[\U0001F300-\U0001FAFF✅✔❌]", allsrc), "no emoji in library code")
rec(not re.search(r"\.amount\s+is\s+(not\s+)?None", allsrc), "no None guard on Entry.amount")
rec(not re.search(r"(?i)issue\s*#\d+|per reviewer|reviewer request|requested during review|added for", allsrc), "no task-referential prose")
for f, s in src.items():
    tree = ast.parse(s)
    for fn in [n for n in ast.walk(tree) if isinstance(n, ast.FunctionDef)]:
        body = [b for b in fn.body if not (isinstance(b, ast.Expr) and isinstance(b.value, ast.Constant))]
        calls = len(re.findall(r"\b" + re.escape(fn.name) + r"\(", allsrc)) - 1
        if fn.name.startswith("_") and len(body) == 1 and calls <= 1:
            rec(False, f"{f}: {fn.name} is a single-use one-statement helper")
    doc = sum(len(ast.get_docstring(n, clean=False).splitlines()) for n in ast.walk(tree)
              if isinstance(n, (ast.Module, ast.FunctionDef, ast.ClassDef)) and ast.get_docstring(n))
    com = sum(1 for t in tokenize.generate_tokens(io.StringIO(s).readline) if t.type == tokenize.COMMENT)
    code = sum(1 for l in s.splitlines() if l.strip() and not l.strip().startswith("#")) - doc
    if code:
        rec(doc + com < code, f"{f}: prose lines ({doc + com}) under code lines ({code})")
readme = pathlib.Path("README.md").read_text()
rec("--start" in readme and "--end" in readme, "README documents --start/--end")
rec(not re.search(r"--(from|to)\b", readme), "README carries no stale flag names")
rec(re.search(r"```(sh|bash|console)?\n[^`]*ledgerlite[^`]*--start[^`]*```", readme), "README has a range example in a code block")
for ok, msg in results: print(("PASS  " if ok else "FAIL  ") + msg)
sys.exit(0 if all(ok for ok, _ in results) else 1)
PYEOF

echo; (( fail == 0 )) && echo "IMPLEMENTER EVAL: PASS" || echo "IMPLEMENTER EVAL: FAIL"
exit $fail
