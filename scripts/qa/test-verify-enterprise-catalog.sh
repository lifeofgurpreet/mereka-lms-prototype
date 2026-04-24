#!/usr/bin/env bash
# test-verify-enterprise-catalog.sh — self-contained test suite for
# scripts/qa/verify-enterprise-catalog.sh
#
# Strategy: the verifier has an early-exit guard (exit 0) when kubectl is
# unavailable or the cluster is unreachable.  Static file checks only run
# after that guard.  Three fixtures cover the main semantic contracts:
#
#   1. no-kubectl (skip-path)
#      kubectl absent from PATH → guard triggers, exits 0 with SKIP message.
#      Validates graceful degradation in offline CI.
#
#   2. missing-catalog-deploy (seeded defect)
#      Fake kubectl (cluster-info succeeds, no pods), tmpdir without
#      enterprise-catalog-deployment.yaml → AC-019 static check FAIL, exit 1.
#
#   3. missing-worker-deploy (seeded defect)
#      Fake kubectl (cluster-info succeeds, no pods), tmpdir without
#      enterprise-catalog-worker-deployment.yaml → AC-020 static check FAIL, exit 1.
#
# NOTE: Live-cluster checks (AC-019 HTTP probes, AC-020 deployment readiness,
# AC-021 contains_content_items latency) require a running pod and are not
# exercisable offline.  The fake kubectl returns empty pod lists so those
# branches register FAIL, which is expected — fixtures 2 and 3 assert exit 1
# precisely because at least one FAIL fires.
#
# Usage:
#   bash scripts/qa/test-verify-enterprise-catalog.sh
#
# Bead: Batch 3 — test-verify-enterprise-catalog.sh self-test axis
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFIER_SRC="$REPO_ROOT/scripts/qa/verify-enterprise-catalog.sh"
WORK="$(mktemp -d -t test-verify-enterprise-catalog.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

PASS_COUNT=0
FAIL_COUNT=0

_pass() {
  PASS_COUNT=$(( PASS_COUNT + 1 ))
  echo "[test-verify-enterprise-catalog] PASS $*"
}

_fail() {
  FAIL_COUNT=$(( FAIL_COUNT + 1 ))
  echo "[test-verify-enterprise-catalog] FAIL $*" >&2
}

# ── helpers ───────────────────────────────────────────────────────────────────

run_expect_pass() {
  local label="$1" verifier="$2" extra_path="$3"
  local outfile="$WORK/${label//[^a-zA-Z0-9_]/_}.out"
  set +e
  PATH="${extra_path:+$extra_path:}$PATH" bash "$verifier" >"$outfile" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -ne 0 ]]; then
    _fail "${label}: expected exit 0, got $rc — tail: $(tail -5 "$outfile")"
    return
  fi
  _pass "${label}: exit 0"
}

run_expect_fail() {
  local label="$1" verifier="$2" extra_path="$3"
  local outfile="$WORK/${label//[^a-zA-Z0-9_]/_}.out"
  set +e
  PATH="${extra_path:+$extra_path:}$PATH" bash "$verifier" >"$outfile" 2>&1
  local rc=$?
  set -e
  if [[ "$rc" -eq 0 ]]; then
    _fail "${label}: expected non-zero exit, got 0 — tail: $(tail -5 "$outfile")"
    return
  fi
  _pass "${label}: exit non-zero ($rc)"
}

last_out() {
  # Return path of most recently written output file
  ls -t "$WORK"/*.out 2>/dev/null | head -1
}

# ── fake kubectl builder ──────────────────────────────────────────────────────
# make_fake_kubectl <bindir>
# Returns success for cluster-info; empty string for pod queries; non-zero for
# get deployment (triggers the AC-020 "deployment not found" FAIL branch).
make_fake_kubectl() {
  local d="$1"
  mkdir -p "$d"
  cat >"$d/kubectl" <<'KUBECTL'
#!/usr/bin/env bash
# fake kubectl for test-verify-enterprise-catalog fixtures
args="$*"
if [[ "${1:-}" == "cluster-info" ]]; then
  echo "Kubernetes control plane is running at https://fake:6443"
  exit 0
fi
if [[ "${1:-}" == "get" && "${2:-}" == "pods" ]]; then
  # empty: no running pods
  printf ''
  exit 0
fi
if [[ "${1:-}" == "get" && "${2:-}" == "deployment" ]]; then
  exit 1
fi
# default silent success
exit 0
KUBECTL
  chmod +x "$d/kubectl"
}

# ── fixture tree builder ──────────────────────────────────────────────────────
# build_fixture_tree <root>
# Creates deploy/k8s paths with minimal valid YAMLs and copies the verifier
# into scripts/qa/ so BASH_SOURCE-derived REPO_ROOT resolves to <root>.
build_fixture_tree() {
  local d="$1"
  mkdir -p \
    "$d/scripts/qa" \
    "$d/deploy/k8s/base/apps/enterprise/workers"

  # AC-019 static check target
  cat >"$d/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-catalog
spec:
  template:
    spec:
      initContainers:
        - name: config-gen
          env:
            - name: DISCOVERY_SERVICE_URL
              value: "http://discovery:8000"
            - name: DJANGO_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: enterprise-secrets
                  key: ENTERPRISE_CATALOG_SECRET_KEY
YAML

  # AC-020 static check target
  cat >"$d/deploy/k8s/base/apps/enterprise/workers/enterprise-catalog-worker-deployment.yaml" <<'YAML'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: enterprise-catalog-worker
spec:
  template:
    spec:
      initContainers:
        - name: config-gen
          env:
            - name: DJANGO_SECRET_KEY
              valueFrom:
                secretKeyRef:
                  name: enterprise-secrets
                  key: ENTERPRISE_CATALOG_SECRET_KEY
      containers:
        - name: enterprise-catalog-worker
          command: ["/venv/bin/celery"]
          args: ["-A", "enterprise_catalog", "worker"]
YAML

  cp "$VERIFIER_SRC" "$d/scripts/qa/verify-enterprise-catalog.sh"
  chmod +x "$d/scripts/qa/verify-enterprise-catalog.sh"
}

# ═══════════════════════════════════════════════════════════════════════════════
# Fixture 1: no-kubectl (skip-path)
#
# Validates: when kubectl cluster-info fails (simulating offline CI with no
# valid kube context) the verifier exits 0 with a SKIP message, so it never
# blocks on cluster unavailability.
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- Fixture 1: no-kubectl (skip-path → exit 0 with SKIP message) ---"

FIX1_BIN="$WORK/fix1bin"
mkdir -p "$FIX1_BIN"
# Fake kubectl: cluster-info fails → triggers the early-exit guard
cat >"$FIX1_BIN/kubectl" <<'KUBECTL'
#!/usr/bin/env bash
if [[ "${1:-}" == "cluster-info" ]]; then
  echo "error: no cluster reachable" >&2
  exit 1
fi
exit 0
KUBECTL
chmod +x "$FIX1_BIN/kubectl"

FIX1_OUT="$WORK/fix1.out"
set +e
PATH="$FIX1_BIN:$PATH" bash "$VERIFIER_SRC" >"$FIX1_OUT" 2>&1
FIX1_EXIT=$?
set -e

if [[ $FIX1_EXIT -eq 0 ]]; then
  _pass "fixture 1: exits 0 when kubectl is absent"
else
  _fail "fixture 1: expected exit 0 (skip), got $FIX1_EXIT — output: $(cat "$FIX1_OUT")"
fi

if grep -q "SKIP" "$FIX1_OUT" 2>/dev/null; then
  _pass "fixture 1: SKIP message emitted to stdout"
else
  _fail "fixture 1: expected SKIP in output; got: $(cat "$FIX1_OUT")"
fi

if grep -q "kubectl not available or cluster unreachable" "$FIX1_OUT" 2>/dev/null; then
  _pass "fixture 1: explanatory note references kubectl context requirement"
else
  _fail "fixture 1: kubectl context note not found; got: $(cat "$FIX1_OUT")"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Fixture 2: missing catalog deployment manifest
#
# Validates: AC-019 static check FAILS and verifier exits 1 when
# enterprise-catalog-deployment.yaml is absent.
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- Fixture 2: missing catalog deployment manifest → AC-019 FAIL, exit 1 ---"

FIX2_ROOT="$WORK/fix2"
FIX2_BIN="$WORK/fix2bin"
make_fake_kubectl "$FIX2_BIN"
build_fixture_tree "$FIX2_ROOT"
rm -f "$FIX2_ROOT/deploy/k8s/base/apps/enterprise/enterprise-catalog-deployment.yaml"

FIX2_OUT="$WORK/fix2.out"
set +e
PATH="$FIX2_BIN:$PATH" bash "$FIX2_ROOT/scripts/qa/verify-enterprise-catalog.sh" >"$FIX2_OUT" 2>&1
FIX2_EXIT=$?
set -e

if [[ $FIX2_EXIT -ne 0 ]]; then
  _pass "fixture 2: exits non-zero when catalog deployment manifest is absent"
else
  _fail "fixture 2: expected non-zero exit, got 0"
fi

if grep -q "Catalog deployment missing DISCOVERY_SERVICE_URL" "$FIX2_OUT" 2>/dev/null; then
  _pass "fixture 2: AC-019 static FAIL message surfaced"
else
  _fail "fixture 2: AC-019 FAIL message not found; FAIL lines: $(grep '✗' "$FIX2_OUT" || echo '(none)')"
fi

# ═══════════════════════════════════════════════════════════════════════════════
# Fixture 3: missing worker deployment manifest
#
# Validates: AC-020 static checks FAIL and verifier exits 1 when
# enterprise-catalog-worker-deployment.yaml is absent.
# ═══════════════════════════════════════════════════════════════════════════════
echo ""
echo "--- Fixture 3: missing worker deployment manifest → AC-020 FAIL, exit 1 ---"

FIX3_ROOT="$WORK/fix3"
FIX3_BIN="$WORK/fix3bin"
make_fake_kubectl "$FIX3_BIN"
build_fixture_tree "$FIX3_ROOT"
rm -f "$FIX3_ROOT/deploy/k8s/base/apps/enterprise/workers/enterprise-catalog-worker-deployment.yaml"

FIX3_OUT="$WORK/fix3.out"
set +e
PATH="$FIX3_BIN:$PATH" bash "$FIX3_ROOT/scripts/qa/verify-enterprise-catalog.sh" >"$FIX3_OUT" 2>&1
FIX3_EXIT=$?
set -e

if [[ $FIX3_EXIT -ne 0 ]]; then
  _pass "fixture 3: exits non-zero when worker deployment manifest is absent"
else
  _fail "fixture 3: expected non-zero exit, got 0"
fi

if grep -q "Catalog worker deployment manifest not found" "$FIX3_OUT" 2>/dev/null; then
  _pass "fixture 3: AC-020 static FAIL message surfaced (manifest not found)"
else
  _fail "fixture 3: AC-020 FAIL message not found; FAIL lines: $(grep '✗' "$FIX3_OUT" || echo '(none)')"
fi

# ── summary ───────────────────────────────────────────────────────────────────
echo ""
echo "Summary: PASS=${PASS_COUNT} FAIL=${FAIL_COUNT}"
if [[ $FAIL_COUNT -gt 0 ]]; then
  echo "[test-verify-enterprise-catalog] FAILED" >&2
  exit 1
fi
echo "[test-verify-enterprise-catalog] ALL FIXTURES PASSED"
