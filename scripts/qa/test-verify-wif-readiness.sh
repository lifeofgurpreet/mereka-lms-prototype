#!/usr/bin/env bash
# Seeded-defect self-test for verify-wif-readiness.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-wif-readiness.sh"

tmpdir="$(mktemp -d -t verify-wif-readiness.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/.github/workflows" "$tmpdir/deploy/k8s/base/secrets" "$tmpdir/docs/operations"

write_pass_fixtures() {
  cat >"$tmpdir/.github/workflows/build.yml" <<'EOF'
name: build
jobs:
  build:
    permissions:
      id-token: write
      contents: read
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123/locations/global/workloadIdentityPools/pool/providers/provider
EOF

  cat >"$tmpdir/deploy/k8s/base/secrets/external-secrets.yaml" <<'EOF'
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: openedx-secrets
spec:
  target:
    name: openedx-secrets
EOF

  cat >"$tmpdir/docs/operations/WORKLOAD_IDENTITY_FEDERATION.md" <<'EOF'
# Workload Identity Federation
EOF
}

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-wif-readiness.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-wif-readiness.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-wif-readiness.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

write_pass_fixtures
run_expect_pass "WIF workflow with id-token write passes readiness checks"

cat >"$tmpdir/.github/workflows/build.yml" <<'EOF'
name: build
jobs:
  build:
    permissions:
      contents: read
    steps:
      - uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: projects/123/locations/global/workloadIdentityPools/pool/providers/provider
EOF
run_expect_fail "WIF workflow missing id-token: write is rejected"

echo "OK"
