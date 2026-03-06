#!/usr/bin/env bash
# Lightweight self-test for verify-repo-structure.sh.
#
# This is NOT exhaustive; it validates the harness works without mutating the real repo.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-repo-structure.sh"

tmpdir="$(mktemp -d -t repo-structure-test.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir"/{deploy,k8s,scripts,infrastructure,docs,specs,services,assets,var,tutor_env}
mkdir -p "$tmpdir/deploy/k8s/overlays/local" "$tmpdir/deploy/k8s/overlays/production" "$tmpdir/deploy/k8s/base/secrets"
mkdir -p "$tmpdir/scripts"/{shared,infra,migrations,branding,analytics,qa}
mkdir -p "$tmpdir/docs"/{adr,onboarding,operations,migrations,architecture,archive}
mkdir -p "$tmpdir/infrastructure"/{tutor,cloudflare,terraform,monitoring}

cat >"$tmpdir/.gitignore" <<'EOF'
var/
tutor_env/
.coverage.*
.hypothesis/
*.pid
*.sock
*.sqlite3
*.db
*.sqlite3-wal
*.db-wal
EOF

cat >"$tmpdir/scripts/shared/config.sh" <<'EOF'
#!/usr/bin/env bash
export GCP_PROJECT="bbi-k8"
export GCP_REGION="asia-southeast1"
export LMS_DOMAIN="example.invalid"
EOF

cat >"$tmpdir/README.md" <<'EOF'
# Test repo
EOF
cat >"$tmpdir/CLAUDE.md" <<'EOF'
# AI instructions
EOF
cat >"$tmpdir/AGENTS.md" <<'EOF'
# Agent instructions
EOF
cat >"$tmpdir/CONTRIBUTING.md" <<'EOF'
# Contributing
EOF
cat >"$tmpdir/MIGRATION_CHECKLIST.md" <<'EOF'
# Migrations
EOF
cat >"$tmpdir/CHANGES.md" <<'EOF'
# Changelog
EOF
cat >"$tmpdir/GEMINI.md" <<'EOF'
# Gemini
EOF

echo "Running verify against isolated tree: $tmpdir"
REPO_ROOT_OVERRIDE="$tmpdir" ALLOW_EXTRA_ROOT_MD=1 bash "$VERIFY"

echo "OK"
