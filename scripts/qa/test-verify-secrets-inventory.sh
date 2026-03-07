#!/usr/bin/env bash
# Seeded-defect self-test for verify-secrets-inventory.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-secrets-inventory.sh"

tmpdir="$(mktemp -d -t verify-secrets-inventory.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s/base/secrets"

write_valid_fixtures() {
  cat >"$tmpdir/deploy/k8s/base/secrets/external-secrets.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec:
  data:
    - secretKey: OPENEDX_SECRET_KEY
    - secretKey: CMS_SECRET_KEY
    - secretKey: MONGODB_USERNAME
    - secretKey: MONGODB_PASSWORD
    - secretKey: FORUM_MONGODB_HOST
    - secretKey: JWT_SECRET_KEY_LMS
    - secretKey: JWT_SECRET_KEY_CMS
    - secretKey: JWT_SECRET_KEY_DISCOVERY
    - secretKey: JWT_SECRET_KEY_NOTES
    - secretKey: JWT_SECRET_KEY_XQUEUE
    - secretKey: JWT_PRIVATE_SIGNING_JWK
    - secretKey: OIDC_CLIENT_SECRET
    - secretKey: STRIPE_SECRET_KEY
    - secretKey: STRIPE_PUBLISHABLE_KEY
    - secretKey: STRIPE_WEBHOOK_SECRET
EOF

  cat >"$tmpdir/deploy/k8s/base/secrets/openedx-secrets.yaml" <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: database-secrets
stringData:
  MYSQL_ROOT_PASSWORD: changeme
  OPENEDX_MYSQL_PASSWORD: changeme
  MYSQL_DISCOVERY_PASSWORD: changeme
  MYSQL_NOTES_PASSWORD: changeme
  MYSQL_XQUEUE_PASSWORD: changeme
  MYSQL_CREDENTIALS_PASSWORD: changeme
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-inventory.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-inventory.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-secrets-inventory.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_valid_fixtures
run_expect_pass "required openedx/database secret inventory passes"

# Remove one required openedx secret key to trigger failure.
cat >"$tmpdir/deploy/k8s/base/secrets/external-secrets.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec:
  data:
    - secretKey: OPENEDX_SECRET_KEY
EOF
run_expect_fail "missing required openedx secret inventory entries are rejected"

echo "OK"
