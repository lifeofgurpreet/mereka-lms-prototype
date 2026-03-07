#!/usr/bin/env bash
# Seeded-defect self-test for verify-secrets-isolation.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-secrets-isolation.sh"

tmpdir="$(mktemp -d -t verify-secrets-isolation.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/deploy/k8s/base/secrets" \
  "$tmpdir/deploy/k8s/overlays/rke2-nonprod/patches" \
  "$tmpdir/deploy/k8s/overlays/production"

write_pass_fixtures() {
  cat >"$tmpdir/deploy/k8s/base/secrets/external-secrets.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
  target:
    name: openedx-secrets
EOF

  cat >"$tmpdir/deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: infisical-secret-store-dev
EOF

  cat >"$tmpdir/deploy/k8s/overlays/production/external-secrets.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-isolation.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-secrets-isolation.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-secrets-isolation.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "base gcp store + rke2 infisical store passes isolation checks"

cat >"$tmpdir/deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec:
  secretStoreRef:
    kind: ClusterSecretStore
    name: gcp-secret-manager
EOF
run_expect_fail "rke2 patch using production gcp store is rejected"

echo "OK"
