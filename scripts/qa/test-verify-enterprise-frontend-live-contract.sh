#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-enterprise-frontend-live-contract.sh"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "${TMPDIR}"' EXIT

fail() {
  echo "[FAIL] $1" >&2
  exit 1
}

pass() {
  echo "[PASS] $1"
}

if bash "$VERIFY_SCRIPT" --namespace >/tmp/m3_missing_namespace.out 2>&1; then
  fail "--namespace without value should fail"
fi
grep -q "Missing value for --namespace" /tmp/m3_missing_namespace.out || fail "missing-value error not surfaced for --namespace"
grep -q "Usage: verify-enterprise-frontend-live-contract.sh" /tmp/m3_missing_namespace.out || fail "usage not printed for --namespace failure"
pass "missing --namespace value fails cleanly"

if bash "$VERIFY_SCRIPT" --context >/tmp/m3_missing_context.out 2>&1; then
  fail "--context without value should fail"
fi
grep -q "Missing value for --context" /tmp/m3_missing_context.out || fail "missing-value error not surfaced for --context"
grep -q "Usage: verify-enterprise-frontend-live-contract.sh" /tmp/m3_missing_context.out || fail "usage not printed for --context failure"
pass "missing --context value fails cleanly"

FAKEBIN="${TMPDIR}/bin"
mkdir -p "$FAKEBIN"
LOGFILE="${TMPDIR}/kubectl.log"

cat >"${FAKEBIN}/kubectl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
LOGFILE="${KUBECTL_LOG:?}"
printf '%s\n' "$*" >>"$LOGFILE"
for arg in "$@"; do
  printf 'ARG=%s\n' "$arg" >>"$LOGFILE"
done

if [[ "${1:-}" == "get" && "${2:-}" == "ns" ]]; then
  exit 0
fi

if [[ "${1:-}" == "get" && "${2:-}" == "pods" ]]; then
  joined="$*"
  case "$joined" in
    *enterprise-learner-portal*) printf 'learner-pod'; exit 0 ;;
    *enterprise-admin-portal*) printf 'admin-pod'; exit 0 ;;
    *'app.kubernetes.io/name=caddy'*) printf 'caddy-pod'; exit 0 ;;
  esac
fi

if [[ "${1:-}" == "get" && "${2:-}" == "deploy" ]]; then
  cat <<'YAML'
mountPath: /openedx/dist/env.config.js
name: enterprise-mfe-env
mountPath: /etc/caddy/
Fixing empty-string config defaults in baked JS
Fixing MISSING_ENV_VAR sentinels in baked JS
Rewriting domains: $BUILD_LMS_DOMAIN -> $RUNTIME_LMS_DOMAIN
YAML
  exit 0
fi

if [[ "${1:-}" == "exec" ]]; then
  last_arg="${@: -1}"
  case "$last_arg" in
    "couponCodeRedemptionCount:0"|"t&&t.validUntil&&await"|"/api/v1/academies?"|"/api/v1/customer-configurations/")
      if [[ "$*" == *admin-pod* ]]; then
        printf 'no'
      else
        printf 'yes'
      fi
      ;;
    *)
      printf 'yes'
      ;;
  esac
  exit 0
fi

fail "unexpected fake kubectl invocation: $*" >&2
EOF
chmod +x "${FAKEBIN}/kubectl"

PATH="${FAKEBIN}:$PATH" KUBECTL_LOG="$LOGFILE" bash "$VERIFY_SCRIPT" --namespace test-ns >/tmp/m3_fake_run.out 2>&1

grep -q "ENTERPRISE_FRONTEND_LIVE_CONTRACT_OK" /tmp/m3_fake_run.out || fail "verifier did not complete under fake kubectl"
grep -Fq "ARG=ENTERPRISE_ACCESS_BASE_URL: ''" "$LOGFILE" || fail "single-quote env pattern was not passed safely as an argument"
grep -Fq "ARG=/openedx/dist/env.config.js" "$LOGFILE" || fail "file path not passed as a separate argument"
pass "single-quote patterns are passed safely to kubectl exec"

echo "VERIFY_ENTERPRISE_FRONTEND_LIVE_CONTRACT_TEST_OK"
