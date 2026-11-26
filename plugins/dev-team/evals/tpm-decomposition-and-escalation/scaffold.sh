#!/usr/bin/env bash
# Creates a minimal app-repo/ with CLAUDE.md so the tpm skill can inspect project context.
set -euo pipefail
mkdir -p app-repo/src app-repo/web

cat >app-repo/CLAUDE.md <<'EOF'
# app-repo

Small Python API (`src/`) and React UI (`web/`) for managing outgoing webhooks.
EOF

cat >app-repo/README.md <<'EOF'
# app-repo

Webhook service with delivery tracking.
EOF
