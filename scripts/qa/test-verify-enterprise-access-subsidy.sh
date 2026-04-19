#!/usr/bin/env bash
# Self-test for verify-enterprise-access-subsidy.sh
# Covers: cluster-unreachable skip, healthy fake-cluster pass, missing-manifest fail
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-enterprise-access-subsidy.sh"

TMPDIR_BASE="$(mktemp -d -t test-verify-enterprise-access-subsidy.XXXXXX)"
cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

fail() { echo "[FAIL] $1" >&2; exit 1; }
pass() { echo "[PASS] $1"; }

# Strip ANSI colour codes for portable grep
strip_ansi() { sed 's/\x1b\[[0-9;]*m//g' "$1"; }

# ---------------------------------------------------------------------------
# Fixture 1: kubectl present but cluster unreachable (cluster-info exits 1).
# Script must exit 0 with a SKIP message — not a hard failure.
# ---------------------------------------------------------------------------
FAKEBIN1="${TMPDIR_BASE}/bin_no_cluster"
mkdir -p "$FAKEBIN1"
cat >"${FAKEBIN1}/kubectl" <<'EOF'
#!/usr/bin/env bash
# Simulate kubectl present but cluster unreachable
exit 1
EOF
chmod +x "${FAKEBIN1}/kubectl"

if PATH="${FAKEBIN1}:$PATH" bash "$VERIFY_SCRIPT" >/tmp/teas_no_cluster.out 2>&1; then
  :
else
  echo "--- output ---"; cat /tmp/teas_no_cluster.out
  fail "unreachable-cluster path must exit 0 (skip)"
fi
grep -q "SKIP" /tmp/teas_no_cluster.out || fail "unreachable-cluster path must print SKIP message"
pass "kubectl cluster-info fails → exits 0 with SKIP"

# ---------------------------------------------------------------------------
# Fixture 2: healthy fake cluster — access + subsidy pods running, manifests
# present, access worker ready, no subsidy worker. Verifier must exit 0 with
# FAIL: 0.
# ---------------------------------------------------------------------------
FAKEBIN2="${TMPDIR_BASE}/bin_live"
mkdir -p "$FAKEBIN2"

FAKE_REPO="${TMPDIR_BASE}/fake_repo"
mkdir -p "${FAKE_REPO}/deploy/k8s/base/apps/enterprise"
mkdir -p "${FAKE_REPO}/scripts/qa"

cat >"${FAKE_REPO}/deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-access
spec:
  template:
    spec:
      containers:
        - name: enterprise-access
          env:
            - name: ENTERPRISE_CATALOG_URL
              value: "http://enterprise-catalog:8000"
            - name: ENTERPRISE_SUBSIDY_URL
              value: "http://enterprise-subsidy:8000"
YAML

cat >"${FAKE_REPO}/deploy/k8s/base/apps/enterprise/enterprise-subsidy-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-subsidy
spec:
  template:
    spec:
      containers:
        - name: enterprise-subsidy
          env:
            - name: DB_NAME
              value: "enterprise_subsidy"
YAML

cat >"${FAKEBIN2}/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-}" in
  cluster-info)
    echo "Kubernetes control plane is running"; exit 0 ;;
  get)
    case "${2:-}" in
      pods)
        full="$*"
        if [[ "$full" == *enterprise-access* && "$full" != *worker* ]]; then
          printf 'enterprise-access-abc123'
        elif [[ "$full" == *enterprise-subsidy* ]]; then
          printf 'enterprise-subsidy-def456'
        fi
        exit 0 ;;
      deployment)
        if [[ "$*" == *enterprise-access-worker* ]]; then
          printf '1'; exit 0
        fi
        # subsidy-worker does not exist
        exit 1 ;;
    esac ;;
  exec)
    # Health check → 200; all other probes → 401
    if [[ "$*" == */health/* ]]; then
      printf '200'
    else
      printf '401'
    fi
    exit 0 ;;
esac
exit 1
EOF
chmod +x "${FAKEBIN2}/kubectl"

cp "$VERIFY_SCRIPT" "${FAKE_REPO}/scripts/qa/verify-enterprise-access-subsidy.sh"
chmod +x "${FAKE_REPO}/scripts/qa/verify-enterprise-access-subsidy.sh"

if PATH="${FAKEBIN2}:$PATH" bash \
    "${FAKE_REPO}/scripts/qa/verify-enterprise-access-subsidy.sh" \
    >/tmp/teas_live.out 2>&1; then
  :
else
  echo "--- output ---"; cat /tmp/teas_live.out
  fail "live-cluster fixture must exit 0"
fi
FAIL_COUNT="$(strip_ansi /tmp/teas_live.out | grep -oP 'FAIL:\s*\K[0-9]+' | tail -1 || echo '')"
[[ "${FAIL_COUNT:-}" == "0" ]] || {
  echo "--- output ---"; cat /tmp/teas_live.out
  fail "live-cluster fixture must report FAIL: 0, got '${FAIL_COUNT:-<none>}'"
}
pass "live-cluster fixture → exits 0, FAIL: 0"

# Spot-check specific AC checks in output
strip_ansi /tmp/teas_live.out | grep -q "Access policies endpoint exists\|Access policies endpoint reachable" || \
  fail "AC-022 access policies check not found in output"
pass "AC-022 access policies endpoint check present"

strip_ansi /tmp/teas_live.out | grep -q "Subsidies endpoint\|Transactions endpoint" || \
  fail "AC-023 subsidy endpoint checks not found in output"
pass "AC-023 subsidy endpoint checks present"

strip_ansi /tmp/teas_live.out | grep -q "No subsidy worker" || \
  fail "AC-025 no-subsidy-worker idempotency check not found in output"
pass "AC-025 no-subsidy-worker idempotency check present"

# ---------------------------------------------------------------------------
# Fixture 3: access manifest MISSING ENTERPRISE_CATALOG_URL + ENTERPRISE_SUBSIDY_URL.
# Verifier must report at least one FAIL for AC-022.
# ---------------------------------------------------------------------------
FAKE_REPO2="${TMPDIR_BASE}/fake_repo2"
mkdir -p "${FAKE_REPO2}/deploy/k8s/base/apps/enterprise"
mkdir -p "${FAKE_REPO2}/scripts/qa"

# Manifest deliberately missing the cross-service URL env vars
cat >"${FAKE_REPO2}/deploy/k8s/base/apps/enterprise/enterprise-access-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-access
spec:
  template:
    spec:
      containers:
        - name: enterprise-access
          env: []
YAML

FAKEBIN3="${TMPDIR_BASE}/bin_no_pod"
mkdir -p "$FAKEBIN3"
cat >"${FAKEBIN3}/kubectl" <<'EOF'
#!/usr/bin/env bash
# cluster reachable but no pods running; no worker deployments
case "${1:-}" in
  cluster-info) echo "Kubernetes control plane is running"; exit 0 ;;
  get)
    case "${2:-}" in
      pods) printf ''; exit 0 ;;
      deployment) exit 1 ;;
    esac ;;
esac
exit 1
EOF
chmod +x "${FAKEBIN3}/kubectl"

cp "$VERIFY_SCRIPT" "${FAKE_REPO2}/scripts/qa/verify-enterprise-access-subsidy.sh"
chmod +x "${FAKE_REPO2}/scripts/qa/verify-enterprise-access-subsidy.sh"

PATH="${FAKEBIN3}:$PATH" bash \
    "${FAKE_REPO2}/scripts/qa/verify-enterprise-access-subsidy.sh" \
    >/tmp/teas_missing_urls.out 2>&1 || true

FAIL_COUNT2="$(strip_ansi /tmp/teas_missing_urls.out | grep -oP 'FAIL:\s*\K[0-9]+' | tail -1 || echo '0')"
[[ "${FAIL_COUNT2:-0}" -gt 0 ]] || {
  echo "--- output ---"; cat /tmp/teas_missing_urls.out
  fail "missing cross-service URL manifest must cause at least one FAIL"
}
strip_ansi /tmp/teas_missing_urls.out | grep -qi "ENTERPRISE_CATALOG_URL\|ENTERPRISE_SUBSIDY_URL\|missing" || \
  fail "missing-URL failure must mention ENTERPRISE_CATALOG_URL or ENTERPRISE_SUBSIDY_URL"
pass "missing cross-service URL manifest → AC-022 FAIL detected"

echo "TEST_VERIFY_ENTERPRISE_ACCESS_SUBSIDY_OK"
