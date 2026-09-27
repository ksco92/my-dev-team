#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "$here/../fixtures/scaffold-lib.sh"
build_pr_fixture "$here/../fixtures"
