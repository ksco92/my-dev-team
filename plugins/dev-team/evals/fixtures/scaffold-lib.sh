#!/usr/bin/env bash
# Shared by the gate-eval scaffold scripts. build_pr_fixture lays a ledgerlite fixture into the run
# workspace: base/ holds the pre-change tree, and the root holds that tree overlaid with a case tree
# (by default ledgerlite-feature, one planted defect per review gate) that carries its ISSUE.md.
set -euo pipefail

build_pr_fixture() {
  local fixtures_dir="$1" tree="${2:-ledgerlite-feature}"
  cp -R "$fixtures_dir/ledgerlite-base" ./base
  cp -R "$fixtures_dir/ledgerlite-base/." ./
  cp -R "$fixtures_dir/$tree/." ./
}
