#!/usr/bin/env bash
# Seeded-defect self-test for verify-k8s-repo-boundaries.sh.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-k8s-repo-boundaries.sh"

tmpdir="$(mktemp -d -t verify-k8s-repo-boundaries.XXXXXX)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/docs/operations" \
  "$tmpdir/infrastructure/k8s/cronjobs" \
  "$tmpdir/infrastructure/k8s/velero" \
  "$tmpdir/.github/workflows" \
  "$tmpdir/scripts/infra" \
  "$tmpdir/scripts/qa"

cat >"$tmpdir/docs/policies/operations/REPO_BOUNDARIES.md" <<'EOF'
# Repo boundaries
EOF

cat >"$tmpdir/infrastructure/k8s/cronjobs/auth-verify-prod.yaml" <<'EOF'
apiVersion: batch/v1
kind: CronJob
EOF

cat >"$tmpdir/infrastructure/k8s/cronjobs/cert-verify-prod.yaml" <<'EOF'
apiVersion: batch/v1
kind: CronJob
EOF

cat >"$tmpdir/infrastructure/k8s/cronjobs/kustomization.yaml" <<'EOF'
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
EOF

cat >"$tmpdir/infrastructure/k8s/velero/restore-test-script.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
echo restore
EOF
chmod +x "$tmpdir/infrastructure/k8s/velero/restore-test-script.sh"

cat >"$tmpdir/infrastructure/k8s/mongodb.yaml" <<'EOF'
# DEPRECATED: In-cluster MongoDB legacy marker only.
# apiVersion: apps/v1
# kind: Deployment
# metadata:
# spec:
EOF

run_expect_pass() {
  local label="$1"
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-k8s-repo-boundaries.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  set +e
  REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" >/tmp/verify-k8s-repo-boundaries.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected failure but command succeeded" >&2
    cat /tmp/verify-k8s-repo-boundaries.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

run_expect_pass "allowlisted infrastructure/k8s support files pass"

cat >"$tmpdir/infrastructure/k8s/rogue-manifest.yaml" <<'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: rogue-shadow-infra
EOF
run_expect_fail "non-allowlisted infrastructure/k8s manifests are rejected"

echo "OK"
