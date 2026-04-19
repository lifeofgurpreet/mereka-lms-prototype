#!/usr/bin/env bash
# Seeded-defect self-test for verify-enterprise-observability.sh.
# Patterns: tempdir fixture-tree + fake-kubectl-in-PATH + env-override (REPO_ROOT_OVERRIDE).
#
# Fixtures:
#   1. Valid SM + PR manifests + fake kubectl → static checks PASS
#   2. SM missing enterprise-access target → static check FAIL
#   3. PR manifest absent → static check FAIL
#   4. No-cluster path (fake kubectl cluster-info fails) → graceful skip (exit 0)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="$ROOT_DIR/scripts/qa/verify-enterprise-observability.sh"

TMPDIR_BASE="$(mktemp -d -t test-verify-enterprise-observability.XXXXXX)"
trap 'rm -rf "$TMPDIR_BASE"' EXIT

FAKEBIN="$TMPDIR_BASE/fakebin"
mkdir -p "$FAKEBIN"

# ---------------------------------------------------------------------------
# Fake kubectl — accepts cluster-info, returns empty strings for live queries
# so that no cluster check ever produces a FAIL (only static-manifest checks
# can fail in this test harness).
# ---------------------------------------------------------------------------
cat >"$FAKEBIN/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
# cluster-info: succeed so require_kubectl passes and _CLUSTER_AVAILABLE stays 1
if [[ "${1:-}" == "cluster-info" ]]; then
  echo "Kubernetes control plane is running"
  exit 0
fi
# All other commands return empty output — no live cluster checks will PASS or FAIL
echo ""
exit 0
EOF
chmod +x "$FAKEBIN/kubectl"

# Variant: kubectl that fails cluster-info (no cluster reachable).
FAKEBIN_NOCLUSTER="$TMPDIR_BASE/fakebin-nocluster"
mkdir -p "$FAKEBIN_NOCLUSTER"
cat >"$FAKEBIN_NOCLUSTER/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "cluster-info" ]]; then
  exit 1
fi
echo ""
exit 0
EOF
chmod +x "$FAKEBIN_NOCLUSTER/kubectl"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
run_expect_pass() {
  local label="$1"
  local tmpdir="$2"
  shift 2
  local extra_path="${1:-$FAKEBIN}"
  PATH="$extra_path:$PATH" REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" \
    >/tmp/verify-enterprise-observability.out 2>&1
  echo "PASS ${label}"
}

run_expect_fail() {
  local label="$1"
  local tmpdir="$2"
  shift 2
  local extra_path="${1:-$FAKEBIN}"
  set +e
  PATH="$extra_path:$PATH" REPO_ROOT_OVERRIDE="$tmpdir" bash "$VERIFY" \
    >/tmp/verify-enterprise-observability.out 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    echo "FAIL ${label}: expected non-zero exit but got 0" >&2
    cat /tmp/verify-enterprise-observability.out >&2 || true
    exit 1
  fi
  echo "PASS ${label}"
}

# ---------------------------------------------------------------------------
# Fixture builder helpers
# ---------------------------------------------------------------------------
write_shared_stubs() {
  local tmpdir="$1"
  mkdir -p "$tmpdir/scripts/shared" "$tmpdir/deploy/k8s/base/monitoring"
  # Stub out ci-skip-guards so REPO_ROOT propagates correctly when sourced.
  cp "$ROOT_DIR/scripts/shared/ci-skip-guards.sh" "$tmpdir/scripts/shared/ci-skip-guards.sh"
}

write_valid_sm() {
  local dir="$1"
  cat >"$dir/servicemonitor-enterprise.yaml" <<'SM'
---
kind: ServiceMonitor
metadata:
  name: enterprise-catalog-metrics
spec:
  endpoints:
    - path: /metrics
      interval: 30s
  selector:
    matchLabels:
      app.kubernetes.io/name: enterprise-catalog
---
kind: ServiceMonitor
metadata:
  name: enterprise-access-metrics
spec:
  endpoints:
    - path: /metrics
      interval: 30s
  selector:
    matchLabels:
      app.kubernetes.io/name: enterprise-access
---
kind: ServiceMonitor
metadata:
  name: enterprise-subsidy-metrics
spec:
  endpoints:
    - path: /metrics
      interval: 30s
  selector:
    matchLabels:
      app.kubernetes.io/name: enterprise-subsidy
SM
}

write_valid_pr() {
  local dir="$1"
  cat >"$dir/prometheusrule-enterprise.yaml" <<'PR'
---
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
spec:
  groups:
    - rules:
        - alert: EnterpriseCatalogDown
        - alert: EnterpriseAccessDown
        - alert: EnterpriseSubsidyDown
        - alert: LicenseManagerDown
PR
}

# ---------------------------------------------------------------------------
# Fixture 1: valid SM + valid PR → static checks PASS with fake cluster kubectl
# ---------------------------------------------------------------------------
D1="$TMPDIR_BASE/fixture1"
write_shared_stubs "$D1"
write_valid_sm "$D1/deploy/k8s/base/monitoring"
write_valid_pr "$D1/deploy/k8s/base/monitoring"

run_expect_pass "valid SM + PR manifests pass all static checks" "$D1"

# ---------------------------------------------------------------------------
# Fixture 2 (seeded defect): SM missing enterprise-access target → FAIL
# ---------------------------------------------------------------------------
D2="$TMPDIR_BASE/fixture2"
write_shared_stubs "$D2"
mkdir -p "$D2/deploy/k8s/base/monitoring"
# SM has catalog + subsidy but NOT enterprise-access
cat >"$D2/deploy/k8s/base/monitoring/servicemonitor-enterprise.yaml" <<'SM'
---
kind: ServiceMonitor
metadata:
  name: enterprise-catalog-metrics
spec:
  endpoints:
    - path: /metrics
      interval: 30s
  selector:
    matchLabels:
      app.kubernetes.io/name: enterprise-catalog
---
kind: ServiceMonitor
metadata:
  name: enterprise-subsidy-metrics
spec:
  endpoints:
    - path: /metrics
      interval: 30s
  selector:
    matchLabels:
      app.kubernetes.io/name: enterprise-subsidy
SM
write_valid_pr "$D2/deploy/k8s/base/monitoring"

run_expect_fail "SM missing enterprise-access target is rejected" "$D2"

# ---------------------------------------------------------------------------
# Fixture 3 (seeded defect): PrometheusRule manifest absent → FAIL
# ---------------------------------------------------------------------------
D3="$TMPDIR_BASE/fixture3"
write_shared_stubs "$D3"
mkdir -p "$D3/deploy/k8s/base/monitoring"
write_valid_sm "$D3/deploy/k8s/base/monitoring"
# PrometheusRule file intentionally omitted

run_expect_fail "absent PrometheusRule manifest is rejected" "$D3"

# ---------------------------------------------------------------------------
# Fixture 4: no-cluster path (kubectl cluster-info fails) → graceful skip (exit 0)
# The script calls `require_kubectl || exit 0` so the whole script exits 0
# when no cluster is reachable — that is the correct skip behaviour.
# ---------------------------------------------------------------------------
D4="$TMPDIR_BASE/fixture4"
write_shared_stubs "$D4"
write_valid_sm "$D4/deploy/k8s/base/monitoring"
write_valid_pr "$D4/deploy/k8s/base/monitoring"

run_expect_pass "no-cluster path exits 0 (graceful skip)" "$D4" "$FAKEBIN_NOCLUSTER"

echo "OK"
