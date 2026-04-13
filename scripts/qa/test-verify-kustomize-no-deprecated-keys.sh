#!/usr/bin/env bash
# Seeded-defect self-test for verify-kustomize-no-deprecated-keys.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-kustomize-no-deprecated-keys.sh"

tmpdir="$(mktemp -d -t verify-kustomize-keys.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p "$tmpdir/deploy/k8s/base"
KUSTOMIZATION="$tmpdir/deploy/k8s/base/kustomization.yaml"

run_expect_pass() {
  local label="$1"
  env -u VERIFY_KUSTOMIZE_NO_DEPRECATED_KEYS_SCOPE \
    -u VERIFY_KUSTOMIZE_NO_DEPRECATED_KEYS_CHANGED_FILES \
    -u CI_CHANGED_FILES \
    REPO_ROOT_OVERRIDE="$tmpdir" \
    bash "$VERIFY" >/tmp/verify-kustomize-keys.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  env -u VERIFY_KUSTOMIZE_NO_DEPRECATED_KEYS_SCOPE \
    -u VERIFY_KUSTOMIZE_NO_DEPRECATED_KEYS_CHANGED_FILES \
    -u CI_CHANGED_FILES \
    REPO_ROOT_OVERRIDE="$tmpdir" \
    bash "$VERIFY" >/tmp/verify-kustomize-keys.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-kustomize-keys.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

cat >"$KUSTOMIZATION" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patches:
  - target:
      kind: Deployment
      name: lms
    path: patch.yaml
EOF
run_expect_pass "modern kustomize keys pass"

cat >"$KUSTOMIZATION" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
  - deployment.yaml
patchesStrategicMerge:
  - patch.yaml
EOF
run_expect_fail "deprecated kustomize keys are rejected"

echo "OK"
