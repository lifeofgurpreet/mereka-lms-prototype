#!/usr/bin/env bash
# Seeded-defect self-test for verify-secret-inventory.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-secret-inventory.sh"

tmpdir="$(mktemp -d -t verify-secret-inventory.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s/base/secrets"

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secret-inventory.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secret-inventory.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-secret-inventory.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$tmpdir/deploy/k8s/base/secrets/external-secrets.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: demo
spec:
  data:
    - secretKey: STRIPE_WEBHOOK_SECRET
      remoteRef:
        key: MEREKA_LMS_STRIPE_WEBHOOK_SECRET
EOF
run_expect_pass "valid MEREKA_LMS_* key extraction passes (GCP checks may skip)"

cat >"$tmpdir/deploy/k8s/base/secrets/external-secrets.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: invalid
spec:
  data:
    - secretKey: STRIPE_WEBHOOK_SECRET
      remoteRef:
        key: STRIPE_WEBHOOK_SECRET
EOF
run_expect_fail "missing MEREKA_LMS_* remoteRef keys is rejected"

echo "OK"
