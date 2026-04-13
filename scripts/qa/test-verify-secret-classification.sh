#!/usr/bin/env bash
# Seeded-defect self-test for verify-secret-classification.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-secret-classification.sh"

tmpdir="$(mktemp -d -t verify-secret-classification.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s/base/secrets"

run_verify() {
  env -u CI_CHANGED_FILES \
      -u VERIFY_SECRET_CLASSIFICATION_SCOPE \
      -u VERIFY_SECRET_CLASSIFICATION_CHANGED_FILES \
      REPO_ROOT_OVERRIDE="$tmpdir" \
      bash "$VERIFY"
}

run_expect_pass() {
  local label="$1"
  run_verify >/tmp/verify-secret-classification.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  run_verify >/tmp/verify-secret-classification.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-secret-classification.out >&2 || true
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

cat >"$tmpdir/deploy/k8s/base/secrets/SECRET_CLASSIFICATION.yaml" <<'EOF'
secrets:
  - key: MEREKA_LMS_STRIPE_WEBHOOK_SECRET
    class: env_unique
EOF
run_expect_pass "classification covers all discovered ExternalSecret keys"

cat >"$tmpdir/deploy/k8s/base/secrets/SECRET_CLASSIFICATION.yaml" <<'EOF'
secrets:
  - key: MEREKA_LMS_UNUSED_SECRET
    class: env_unique
EOF
run_expect_fail "unknown/missing classification coverage is rejected"

echo "OK"
