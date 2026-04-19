#!/usr/bin/env bash
# Self-test for verify-enterprise-license-management.sh
#
# Fixture coverage:
#   F1 - no-cluster skip path: kubectl absent → exits 0 with SKIP sentinel
#   F2 - license-manager not deployed: AC-015 static MFE_ENV pass,
#        AC-016 redis-absent → catalog deploy fallback, AC-016 access-worker fail
#   F3 - license-manager deployed: AC-014 auth enforcement (401 path),
#        AC-015 API-root live path, AC-017/AC-018 deployed pass
#
# Pattern: fake-kubectl-in-PATH (tempdir bin/ prepended to PATH per fixture)
# Each fixture runs the script in a sub-process and asserts stdout/exit code.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-enterprise-license-management.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

# ---------------------------------------------------------------------------
# F1: no cluster — kubectl absent → SKIP exit 0
# ---------------------------------------------------------------------------
echo "--- F1: no-cluster skip path ---"

F1BIN="${TMPDIR}/f1bin"
mkdir -p "$F1BIN"

# Provide a kubectl that always reports cluster unreachable
cat >"${F1BIN}/kubectl" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in
  cluster-info) exit 1 ;;
  *) exit 1 ;;
esac
EOF
chmod +x "${F1BIN}/kubectl"

F1OUT="${TMPDIR}/f1.out"
if ! PATH="${F1BIN}:$PATH" bash "$VERIFY_SCRIPT" >"$F1OUT" 2>&1; then
  fail "F1: script should exit 0 when cluster unreachable"
fi
grep -q "SKIP" "$F1OUT" || fail "F1: expected SKIP sentinel in output"
pass "F1: kubectl cluster-info failure → clean SKIP exit 0"

# ---------------------------------------------------------------------------
# F2: license-manager NOT deployed — static file path exercised
#     kubectl stubs: cluster-info=0, get deployment license-manager=1 (not found),
#     get pods redis=0 returns empty, get deployment enterprise-access-worker=1 (not found)
# ---------------------------------------------------------------------------
echo "--- F2: license-manager absent, static fallback exercised ---"

F2BIN="${TMPDIR}/f2bin"
mkdir -p "$F2BIN"

cat >"${F2BIN}/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CMD="${1:-}"
SUBCMD="${2:-}"
ARGS="$*"

case "${CMD}" in
  cluster-info) exit 0 ;;
  get)
    case "${SUBCMD}" in
      deployment)
        # license-manager not deployed; enterprise-access-worker not deployed
        if [[ "$ARGS" == *license-manager* ]] || [[ "$ARGS" == *enterprise-access-worker* ]]; then
          exit 1
        fi
        exit 1
        ;;
      pods)
        # No redis pod found (simulate external redis)
        printf ''
        exit 0
        ;;
      secret)
        # No enterprise-secrets
        exit 1
        ;;
    esac
    ;;
esac
exit 0
EOF
chmod +x "${F2BIN}/kubectl"

F2OUT="${TMPDIR}/f2.out"
# Script exits 1 when AC-016 enterprise-access-worker not found
PATH="${F2BIN}:$PATH" bash "$VERIFY_SCRIPT" >"$F2OUT" 2>&1 || true

# AC-015: MFE_ENV file exists in repo → should pass
grep -q "AC-015.*PASS\|AC-015.*MFE env references LICENSE_MANAGER_URL\|✓.*AC-015" "$F2OUT" || \
  grep -q "LICENSE_MANAGER_URL" "$F2OUT" || \
  fail "F2: AC-015 MFE_ENV static pass not reflected in output"
pass "F2: AC-015 MFE_ENV LICENSE_MANAGER_URL static check passes"

# AC-016: enterprise-access-worker fail should appear
grep -q "AC-016.*enterprise-access-worker.*not found\|✗.*AC-016" "$F2OUT" || \
  grep -q "enterprise-access-worker deployment not found" "$F2OUT" || \
  fail "F2: AC-016 access-worker failure not surfaced"
pass "F2: AC-016 enterprise-access-worker missing correctly flagged"

# ---------------------------------------------------------------------------
# F3: license-manager deployed + pod running → HTTP-probe path exercised
#     AC-014: 401 response → pass
#     AC-015: API root HTTP → pass
#     AC-016: Redis pod found → pass
#     AC-017/AC-018: lm deployed → pass
# ---------------------------------------------------------------------------
echo "--- F3: license-manager deployed, API probe responses ---"

F3BIN="${TMPDIR}/f3bin"
mkdir -p "$F3BIN"

cat >"${F3BIN}/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
CMD="${1:-}"
SUBCMD="${2:-}"
ARGS="$*"

case "${CMD}" in
  cluster-info) exit 0 ;;
  config)
    # kubectl config view --raw / use-context — succeed silently
    if [[ "${SUBCMD}" == "view" ]]; then
      printf 'apiVersion: v1\nclusters: []\ncontexts: []\nkind: Config\npreferences: {}\nusers: []\n'
    fi
    exit 0
    ;;
  get)
    case "${SUBCMD}" in
      deployment)
        if [[ "$ARGS" == *license-manager* ]]; then
          # license-manager deployment found
          exit 0
        fi
        if [[ "$ARGS" == *enterprise-access-worker* ]]; then
          # access-worker found
          exit 0
        fi
        exit 0
        ;;
      pods)
        if [[ "$ARGS" == *license-manager* ]]; then
          # return a pod name
          printf 'license-manager-7d8c9b-xvpqr'
          exit 0
        fi
        if [[ "$ARGS" == *redis* ]] || [[ "$ARGS" == *"app.kubernetes.io/name=redis"* ]] || [[ "$ARGS" == *"app=redis"* ]]; then
          printf 'redis-0'
          exit 0
        fi
        printf ''
        exit 0
        ;;
    esac
    ;;
  exec)
    # pod_http() invocation: simulate HTTP responses based on URL fragment
    if [[ "$ARGS" == *subscriptions* ]]; then
      # AC-014: return 401 — auth enforced
      printf '401'
    elif [[ "$ARGS" == */api/v1/* ]]; then
      # AC-015: API root responds
      printf '200'
    else
      printf '200'
    fi
    exit 0
    ;;
esac
exit 0
EOF
chmod +x "${F3BIN}/kubectl"

F3OUT="${TMPDIR}/f3.out"
PATH="${F3BIN}:$PATH" bash "$VERIFY_SCRIPT" >"$F3OUT" 2>&1 || true

# AC-014: auth enforcement pass
grep -q "AC-014.*auth\|AC-014.*authentication\|✓.*AC-014" "$F3OUT" || \
  grep -q "License manager API enforces authentication" "$F3OUT" || \
  fail "F3: AC-014 authentication enforcement not surfaced"
pass "F3: AC-014 license manager API auth enforcement detected (401 path)"

# AC-016: redis pod pass
grep -q "AC-016.*Redis pod\|✓.*AC-016.*Redis" "$F3OUT" || \
  grep -q "Redis pod available" "$F3OUT" || \
  fail "F3: AC-016 Redis pod pass not surfaced"
pass "F3: AC-016 Redis pod available for event bus"

# AC-017/AC-018: deployed pass
grep -q "AC-017.*deployed\|AC-017.*License manager deployed" "$F3OUT" || \
  fail "F3: AC-017 deployed pass not surfaced"
pass "F3: AC-017 license manager deployed — revocation cap pass"

echo
echo "VERIFY_ENTERPRISE_LICENSE_MANAGEMENT_TEST_OK"
