#!/usr/bin/env bash
# Seeded-defect self-test for verify-dev-prod-secret-separation.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-dev-prod-secret-separation.sh"

tmpdir="$(mktemp -d -t verify-dev-prod-secret-separation.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s/overlays/local/patches" "$tmpdir/scripts/shared"

cat >"$tmpdir/scripts/shared/ci-skip-guards.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
require_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}
EOF
chmod +x "$tmpdir/scripts/shared/ci-skip-guards.sh"

write_valid_fixtures() {
  cat >"$tmpdir/deploy/k8s/overlays/local/patches/openedx-secrets-dev.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  data:
    - remoteRef: { key: MEREKA_LMS_STRIPE_SECRET_KEY_DEV }
    - remoteRef: { key: MEREKA_LMS_STRIPE_PUBLISHABLE_KEY_DEV }
    - remoteRef: { key: MEREKA_LMS_STRIPE_WEBHOOK_SECRET_DEV }
EOF

  cat >"$tmpdir/deploy/k8s/overlays/local/patches/database-secrets-dev.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  data:
    - remoteRef: { key: MEREKA_LMS_MYSQL_ROOT_PASSWORD_DEV }
    - remoteRef: { key: MEREKA_LMS_MYSQL_PASSWORD_DEV }
    - remoteRef: { key: MEREKA_LMS_MYSQL_DISCOVERY_PASSWORD_DEV }
    - remoteRef: { key: MEREKA_LMS_MYSQL_ECOMMERCE_PASSWORD_DEV }
    - remoteRef: { key: MEREKA_LMS_MYSQL_NOTES_PASSWORD_DEV }
    - remoteRef: { key: MEREKA_LMS_MYSQL_XQUEUE_PASSWORD_DEV }
    - remoteRef: { key: MEREKA_LMS_MYSQL_CREDENTIALS_PASSWORD_DEV }
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-dev-prod-secret-separation.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-dev-prod-secret-separation.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-dev-prod-secret-separation.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_valid_fixtures
run_expect_pass "dev overlays using *_DEV keys pass separation guard"

cat >"$tmpdir/deploy/k8s/overlays/local/patches/openedx-secrets-dev.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
spec:
  data:
    - remoteRef: { key: MEREKA_LMS_STRIPE_SECRET_KEY }
EOF
run_expect_fail "missing *_DEV stripe keys are rejected"

echo "OK"
