#!/usr/bin/env bash
# Seeded-defect self-test for verify-secrets-naming-convention.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-secrets-naming-convention.sh"

tmpdir="$(mktemp -d -t verify-secrets-naming.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s/base/secrets"

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-naming.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-naming.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-secrets-naming.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$tmpdir/deploy/k8s/base/secrets/externalsecret.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: good-secret
spec:
  data:
    - secretKey: STRIPE_WEBHOOK_SECRET
      remoteRef:
        key: MEREKA_LMS_STRIPE_WEBHOOK_SECRET
EOF
run_expect_pass "valid ExternalSecret remoteRef.key prefix passes"

cat >"$tmpdir/deploy/k8s/base/secrets/externalsecret.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: bad-secret
spec:
  data:
    - secretKey: STRIPE_WEBHOOK_SECRET
      remoteRef:
        key: STRIPE_WEBHOOK_SECRET
EOF
run_expect_fail "remoteRef.key without MEREKA_LMS_ prefix is rejected"

cat >"$tmpdir/deploy/k8s/base/secrets/externalsecret.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: bad-local
spec:
  data:
    - secretKey: MEREKA_LMS_STRIPE_WEBHOOK_SECRET
      remoteRef:
        key: MEREKA_LMS_STRIPE_WEBHOOK_SECRET
EOF
run_expect_fail "local secretKey with MEREKA_LMS_ prefix is rejected"

echo "OK"
