#!/usr/bin/env bash
# Lays a --base-only ledgerlite checkout under repo/ (one commit on main, no planted branch), the
# linked issue at ISSUE.md, and the deterministic grader at grade-implementer.sh.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
fixtures="$here/../fixtures"

mkdir -p repo
cp -R "$fixtures/ledgerlite-base/." repo/
cp "$fixtures/ISSUE.md" ./ISSUE.md
cp "$fixtures/grade-implementer.sh" ./grade-implementer.sh
chmod +x ./grade-implementer.sh

git -C repo init -q -b main
git -C repo -c user.name=fixture -c user.email=fixture@example.com add -A
git -C repo -c user.name=fixture -c user.email=fixture@example.com \
  commit -qm "ledgerlite: initial import (sum a CSV ledger)"
