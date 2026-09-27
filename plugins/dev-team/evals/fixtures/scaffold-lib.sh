#!/usr/bin/env bash
# Shared by the gate-eval scaffold scripts. build_pr_fixture lays the ledgerlite fixture (a tiny
# Python CLI with one planted defect per review gate) into the run workspace: the pre-change tree
# under base/, the proposed tree at the workspace root, and the linked issue at ISSUE.md.
set -euo pipefail

build_pr_fixture() {
  local fixtures_dir="$1"
  cp -R "$fixtures_dir/ledgerlite-base" ./base
  cp -R "$fixtures_dir/ledgerlite-feature/." ./
  cp "$fixtures_dir/ISSUE.md" ./ISSUE.md
}
