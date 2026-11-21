#!/usr/bin/env bash
# Shared by the gate-eval scaffold scripts. build_pr_fixture lays a ledgerlite fixture into the run
# workspace: base/ holds the pre-change tree, the root a proposed tree (by default ledgerlite-feature,
# one planted defect per review gate), and ISSUE.md the linked issue.
set -euo pipefail

build_pr_fixture() {
  local fixtures_dir="$1" tree="${2:-ledgerlite-feature}" issue="${3:-ISSUE.md}"
  cp -R "$fixtures_dir/ledgerlite-base" ./base
  cp -R "$fixtures_dir/$tree/." ./
  cp "$fixtures_dir/$issue" ./ISSUE.md
}
