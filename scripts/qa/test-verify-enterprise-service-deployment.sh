#!/usr/bin/env bash
# @covers AC-001, AC-002, AC-003, AC-004, AC-005, AC-006, AC-007, AC-008
# @spec: enterprise-microservices_spec.md
#
# Self-test for verify-enterprise-service-deployment.sh.
#
# Fixtures:
#   1. env-override SKIP_RUNTIME_CHECKS=1 exits 2 with indeterminate message
#   2. flag --skip-runtime-checks exits 2 with indeterminate message
#   3. --help exits 0 and prints usage
#   4. unknown flag exits 1 with error message
#   5. invalid boolean env var (ALLOW_PARTIAL_READY=2) exits 1 with validation error
#   6. ALLOW_PARKED_SERVICES=1 with all-zero fake-kubectl profile exits 0
#   7. fake-kubectl all-healthy profile: AC-001..AC-006 all pass, exits 0
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY="${REPO_ROOT}/scripts/qa/verify-enterprise-service-deployment.sh"

TMPDIR="$(mktemp -d -t test-verify-esd.XXXXXX)"
trap 'rm -rf "${TMPDIR}"' EXIT

pass() { echo "[PASS] $1"; }
fail() { echo "[FAIL] $1" >&2; exit 1; }

capture_exit() {
  # Usage: capture_exit <outfile> cmd [args...]
  # Runs cmd, captures combined stdout+stderr to outfile, returns exit code.
  local outfile="$1"; shift
  local rc=0
  "$@" >"$outfile" 2>&1 || rc=$?
  echo "$rc"
}

# ---------------------------------------------------------------------------
# Fixture 1: SKIP_RUNTIME_CHECKS=1 env override → exit 2 with indeterminate
# ---------------------------------------------------------------------------
OUT="${TMPDIR}/f1.out"
RC="$(SKIP_RUNTIME_CHECKS=1 bash "$VERIFY" >"$OUT" 2>&1; echo $?) " || true
# Use process substitution to capture exit reliably
RC=0; SKIP_RUNTIME_CHECKS=1 bash "$VERIFY" >"$OUT" 2>&1 || RC=$?
if [[ "$RC" -eq 2 ]]; then
  pass "fixture-1: SKIP_RUNTIME_CHECKS=1 exits 2"
else
  fail "fixture-1: SKIP_RUNTIME_CHECKS=1 should exit 2, got $RC"
fi
grep -qa "runtime checks suppressed" "$OUT" \
  || fail "fixture-1: expected 'runtime checks suppressed' in output"
pass "fixture-1: skip-runtime message present"

# ---------------------------------------------------------------------------
# Fixture 2: --skip-runtime-checks flag → exit 2 with INDETERMINATE summary
# ---------------------------------------------------------------------------
OUT="${TMPDIR}/f2.out"
RC=0; bash "$VERIFY" --skip-runtime-checks >"$OUT" 2>&1 || RC=$?
if [[ "$RC" -eq 2 ]]; then
  pass "fixture-2: --skip-runtime-checks exits 2"
else
  fail "fixture-2: --skip-runtime-checks should exit 2, got $RC"
fi
grep -qa "INDETERMINATE" "$OUT" \
  || fail "fixture-2: INDETERMINATE summary line missing"
pass "fixture-2: INDETERMINATE summary present"

# ---------------------------------------------------------------------------
# Fixture 3: --help exits 0 and prints usage
# ---------------------------------------------------------------------------
OUT="${TMPDIR}/f3.out"
RC=0; bash "$VERIFY" --help >"$OUT" 2>&1 || RC=$?
if [[ "$RC" -eq 0 ]]; then
  pass "fixture-3: --help exits 0"
else
  fail "fixture-3: --help should exit 0, got $RC"
fi
grep -qa "Usage:" "$OUT" \
  || fail "fixture-3: Usage string missing from --help output"
pass "fixture-3: --help prints usage"

# ---------------------------------------------------------------------------
# Fixture 4: unknown flag → exit 1 with error message
# ---------------------------------------------------------------------------
OUT="${TMPDIR}/f4.out"
RC=0; bash "$VERIFY" --badoption >"$OUT" 2>&1 || RC=$?
if [[ "$RC" -eq 1 ]]; then
  pass "fixture-4: unknown flag exits 1"
else
  fail "fixture-4: unknown flag should exit 1, got $RC"
fi
grep -qa "Unknown option" "$OUT" \
  || fail "fixture-4: 'Unknown option' message missing"
pass "fixture-4: unknown-flag error message present"

# ---------------------------------------------------------------------------
# Fixture 5: invalid boolean env var (ALLOW_PARTIAL_READY=2) → exit 1
# ---------------------------------------------------------------------------
OUT="${TMPDIR}/f5.out"
RC=0; ALLOW_PARTIAL_READY=2 bash "$VERIFY" >"$OUT" 2>&1 || RC=$?
if [[ "$RC" -eq 1 ]]; then
  pass "fixture-5: ALLOW_PARTIAL_READY=2 exits 1"
else
  fail "fixture-5: ALLOW_PARTIAL_READY=2 should exit 1, got $RC"
fi
grep -qa "Invalid ALLOW_PARTIAL_READY" "$OUT" \
  || fail "fixture-5: validation error message missing"
pass "fixture-5: bool-validation error message present"

# ---------------------------------------------------------------------------
# Fake-kubectl builder — used by fixtures 6 and 7
# ---------------------------------------------------------------------------
FAKEBIN="${TMPDIR}/bin"
mkdir -p "$FAKEBIN"

build_fake_kubectl() {
  local mode="$1"   # "healthy" | "parked"
  cat >"${FAKEBIN}/kubectl" <<FAKEKUBECTL
#!/usr/bin/env bash
set -euo pipefail

# cluster-info probe (require_kubectl)
if [[ "\${1:-}" == "cluster-info" ]]; then
  echo "Kubernetes control plane is running at https://fake-cluster:6443"
  exit 0
fi

# version --client
if [[ "\${1:-}" == "version" ]]; then
  echo "Client Version: v1.27.0"
  exit 0
fi

# config view --raw (kubeconfig copy when --context passed)
if [[ "\${1:-}" == "config" && "\${2:-}" == "view" ]]; then
  echo "apiVersion: v1
kind: Config
clusters: []
users: []
contexts: []
current-context: ''"
  exit 0
fi

# config use-context
if [[ "\${1:-}" == "config" && "\${2:-}" == "use-context" ]]; then
  exit 0
fi

# get deployment <name> -n <ns> -o jsonpath='...'
if [[ "\${1:-}" == "get" && "\${2:-}" == "deployment" ]]; then
  # Find the jsonpath value anywhere in args
  combined="\$*"
  if [[ "\$combined" == *readyReplicas* ]]; then
    case "$mode" in
      healthy)  printf '1' ;;
      parked)   printf '0' ;;
    esac
    exit 0
  fi
  if [[ "\$combined" == *"spec.replicas"* ]]; then
    case "$mode" in
      healthy)  printf '1' ;;
      parked)   printf '0' ;;
    esac
    exit 0
  fi
  if [[ "\$combined" == *instance* || "\$combined" == *part-of* ]]; then
    # Return correct label values for AC-001 label checks
    case "$mode" in
      healthy)  printf 'mereka-lms' ;;
      parked)   printf 'mereka-lms' ;;
    esac
    exit 0
  fi
  # Default: healthy=1, parked=0
  case "$mode" in
    healthy)  printf '1' ;;
    parked)   printf '0' ;;
  esac
  exit 0
fi

# get deployments -l (label selector, component=enterprise)
if [[ "\${1:-}" == "get" && "\${2:-}" == "deployments" ]]; then
  case "$mode" in
    healthy)
      printf 'enterprise-catalog\nenterprise-catalog-worker\nenterprise-access\nenterprise-access-worker\nenterprise-subsidy\nenterprise-admin-portal\nenterprise-learner-portal\n'
      ;;
    parked)
      printf 'enterprise-catalog\nenterprise-catalog-worker\nenterprise-access\nenterprise-access-worker\nenterprise-subsidy\nenterprise-admin-portal\nenterprise-learner-portal\n'
      ;;
  esac
  exit 0
fi

# get endpoints
if [[ "\${1:-}" == "get" && "\${2:-}" == "endpoints" ]]; then
  case "$mode" in
    healthy)  printf '192.168.1.1' ;;
    parked)   printf '' ;;
  esac
  exit 0
fi

# get pods
if [[ "\${1:-}" == "get" && "\${2:-}" == "pods" ]]; then
  case "$mode" in
    healthy)  printf 'enterprise-catalog-abc123' ;;
    parked)   printf '' ;;
  esac
  exit 0
fi

# exec (health endpoints via pod_http)
if [[ "\${1:-}" == "exec" ]]; then
  echo "200"
  exit 0
fi

# rollout status
if [[ "\${1:-}" == "rollout" && "\${2:-}" == "status" ]]; then
  exit 0
fi

# get events (scheduler diagnostics)
if [[ "\${1:-}" == "get" && "\${2:-}" == "events" ]]; then
  exit 0
fi

# get nodes
if [[ "\${1:-}" == "get" && "\${2:-}" == "nodes" ]]; then
  exit 0
fi

exit 0
FAKEKUBECTL
  chmod +x "${FAKEBIN}/kubectl"
}

# ---------------------------------------------------------------------------
# Fixture 6: ALLOW_PARKED_SERVICES=1 with all-parked (0-replica) kubectl → exit 0
# ---------------------------------------------------------------------------
build_fake_kubectl "parked"
OUT="${TMPDIR}/f6.out"
RC=0
PATH="${FAKEBIN}:${PATH}" ALLOW_PARKED_SERVICES=1 NAMESPACE=mereka-lms \
  bash "$VERIFY" >"$OUT" 2>&1 || RC=$?
if [[ "$RC" -eq 0 ]]; then
  pass "fixture-6: ALLOW_PARKED_SERVICES=1 all-zero replicas exits 0"
else
  fail "fixture-6: ALLOW_PARKED_SERVICES=1 all-zero should exit 0, got $RC ($(cat "$OUT" | tail -5))"
fi
grep -qa "explicitly parked at replicas=0" "$OUT" \
  || fail "fixture-6: parked-state message missing"
pass "fixture-6: parked-state message present"

# ---------------------------------------------------------------------------
# Fixture 7: fake-kubectl healthy profile → AC-001..AC-006 pass, exits 0
# ---------------------------------------------------------------------------
build_fake_kubectl "healthy"
OUT="${TMPDIR}/f7.out"
RC=0
PATH="${FAKEBIN}:${PATH}" NAMESPACE=mereka-lms WAIT_FOR_STEADY_SECONDS=0 \
  bash "$VERIFY" >"$OUT" 2>&1 || RC=$?
if [[ "$RC" -eq 0 ]]; then
  pass "fixture-7: healthy fake-kubectl profile exits 0"
else
  fail "fixture-7: healthy profile should exit 0, got $RC (output follows)
$(cat "$OUT")"
fi
grep -qa "AC-001:" "$OUT" \
  || fail "fixture-7: AC-001 checks missing from output"
grep -qa "AC-003:" "$OUT" \
  || fail "fixture-7: AC-003 health check missing from output"
pass "fixture-7: AC-001 and AC-003 check lines present in output"
if grep -qa "^.*✗.*" "$OUT"; then
  fail "fixture-7: unexpected FAIL (✗) lines found in healthy output"
fi
pass "fixture-7: no FAIL lines in healthy output"

echo "TEST_VERIFY_ENTERPRISE_SERVICE_DEPLOYMENT_OK"
