#!/usr/bin/env bash
# @covers AC-003
# @spec: observability-stack_spec.md
# Verify Sentry wiring contract for Open edX services (repo + optional runtime).
#
# Usage:
#   ./scripts/qa/verify-sentry-wiring.sh
#   ./scripts/qa/verify-sentry-wiring.sh --mode runtime
#   STRICT_RUNTIME=1 ./scripts/qa/verify-sentry-wiring.sh --mode all
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

MODE="local" # local|runtime|all
JSON_OUT=0
STRICT_RUNTIME="${STRICT_RUNTIME:-0}"
K8S_CONTEXT="${K8S_CONTEXT:-gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster}"
APP_NS="${APP_NS:-mereka-lms}"
REQUIRED_DEPLOYS="${REQUIRED_DEPLOYS:-lms cms lms-worker cms-worker discovery ecommerce credentials ecommerce-worker}"

CHECK_NAMES=()
CHECK_OK=()
CHECK_CODE=()
CHECK_MSG=()
failures=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/verify-sentry-wiring.sh [--mode local|runtime|all] [--json]
Env:
  STRICT_RUNTIME=1      Fail if runtime Sentry env/sdk checks fail
  K8S_CONTEXT=...       Kubernetes context for runtime checks
  APP_NS=mereka-lms     Application namespace
  REQUIRED_DEPLOYS="..." Space-separated deployment names to validate
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode) MODE="${2:-}"; shift 2 ;;
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ "$MODE" != "local" && "$MODE" != "runtime" && "$MODE" != "all" ]]; then
  echo "Invalid --mode: $MODE" >&2
  usage
  exit 1
fi

json_escape() {
  local s="${1:-}"
  s="${s//\\/\\\\}"
  s="${s//\"/\\\"}"
  s="${s//$'\n'/\\n}"
  printf "%s" "$s"
}

run_check() {
  local name="$1"; shift
  local tmp code ok tail
  tmp="$(mktemp -t verify-sentry-wiring.XXXXXX)"
  set +e
  "$@" >"$tmp" 2>&1
  code=$?
  set -e

  ok=0
  [[ "$code" -eq 0 ]] && ok=1
  CHECK_NAMES+=("$name")
  CHECK_OK+=("$ok")
  CHECK_CODE+=("$code")

  if [[ "$ok" -eq 1 ]]; then
    CHECK_MSG+=("")
    [[ "$JSON_OUT" -eq 0 ]] && printf "OK   %s\n" "$name"
  else
    failures=$((failures + 1))
    tail="$(tail -n 40 "$tmp" | sed 's/\r$//')"
    CHECK_MSG+=("$tail")
    if [[ "$JSON_OUT" -eq 0 ]]; then
      printf "FAIL %s (exit=%s)\n" "$name" "$code" >&2
      printf "%s\n" "$tail" | sed 's/^/  /' >&2
    fi
  fi

  rm -f "$tmp"
}

local_contract_files_have_sentry_hooks() {
  local required_files=(
    "deploy/k8s/base/apps/openedx/settings/lms/production.py"
    "deploy/k8s/base/apps/openedx/settings/cms/production.py"
    "deploy/k8s/base/plugins/discovery/apps/settings/tutor/production.py"
    "deploy/k8s/base/plugins/ecommerce/apps/ecommerce/settings/production.py"
    "deploy/k8s/base/plugins/ecommerce/apps/ecommerce-worker/settings/production.py"
    "deploy/k8s/base/plugins/credentials/apps/credentials/settings/production.py"
  )

  local file
  for file in "${required_files[@]}"; do
    rg -Fq -- "def _init_sentry(" "$file"
    rg -Fq -- "_init_sentry(" "$file"
    rg -Fq -- "SENTRY_DSN" "$file"
  done
}

runtime_preflight() {
  command -v kubectl >/dev/null
  command -v python3 >/dev/null
}

runtime_cluster_reachable_or_skip() {
  if kubectl --context "$K8S_CONTEXT" get namespace "$APP_NS" >/dev/null 2>&1; then
    return 0
  fi
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    echo "Cannot reach context=$K8S_CONTEXT namespace=$APP_NS"
    return 1
  fi
  echo "SKIP: cannot reach context=$K8S_CONTEXT namespace=$APP_NS"
  return 0
}

runtime_required_deployments_exist() {
  local d
  for d in $REQUIRED_DEPLOYS; do
    kubectl --context "$K8S_CONTEXT" -n "$APP_NS" get deploy "$d" >/dev/null
  done
}

runtime_sentry_env_present() {
  local missing=()
  local d
  for d in $REQUIRED_DEPLOYS; do
    if ! kubectl --context "$K8S_CONTEXT" -n "$APP_NS" exec "deploy/$d" -- sh -lc \
      'test -n "${SENTRY_DSN:-}"' >/dev/null 2>&1; then
      missing+=("$d")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    return 0
  fi
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    echo "Missing SENTRY_DSN in deployments: ${missing[*]}"
    return 1
  fi
  echo "WARN: Missing SENTRY_DSN in deployments: ${missing[*]}"
  return 0
}

runtime_sentry_sdk_available() {
  local missing=()
  local d
  for d in $REQUIRED_DEPLOYS; do
    # Only require SDK where SENTRY_DSN is configured.
    if ! kubectl --context "$K8S_CONTEXT" -n "$APP_NS" exec "deploy/$d" -- sh -lc \
      'test -n "${SENTRY_DSN:-}"' >/dev/null 2>&1; then
      continue
    fi
    if ! kubectl --context "$K8S_CONTEXT" -n "$APP_NS" exec "deploy/$d" -- sh -lc \
      'python - <<'"'"'PY'"'"'
import importlib.util
raise SystemExit(0 if importlib.util.find_spec("sentry_sdk") else 1)
PY' >/dev/null 2>&1; then
      missing+=("$d")
    fi
  done

  if [[ "${#missing[@]}" -eq 0 ]]; then
    return 0
  fi
  if [[ "$STRICT_RUNTIME" == "1" ]]; then
    echo "sentry_sdk missing in deployments with SENTRY_DSN: ${missing[*]}"
    return 1
  fi
  echo "WARN: sentry_sdk missing in deployments with SENTRY_DSN: ${missing[*]}"
  return 0
}

if [[ "$JSON_OUT" -eq 0 ]]; then
  echo "Verify: Sentry wiring"
  echo "  mode:           $MODE"
  echo "  strict runtime: $STRICT_RUNTIME"
  echo "  context:        $K8S_CONTEXT"
  echo "  app namespace:  $APP_NS"
  echo "  required deploys: $REQUIRED_DEPLOYS"
  echo
fi

if [[ "$MODE" == "local" || "$MODE" == "all" ]]; then
  run_check "local: production settings include sentry hooks" local_contract_files_have_sentry_hooks
fi

if [[ "$MODE" == "runtime" || "$MODE" == "all" ]]; then
  run_check "runtime: command/tooling preflight" runtime_preflight
  run_check "runtime: cluster reachable or skipped" runtime_cluster_reachable_or_skip
  run_check "runtime: required deployments exist" runtime_required_deployments_exist
  run_check "runtime: sentry dsn env present" runtime_sentry_env_present
  run_check "runtime: sentry sdk available where dsn set" runtime_sentry_sdk_available
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "{"
  printf "\"mode\":\"%s\"," "$(json_escape "$MODE")"
  printf "\"strict_runtime\":%s," "$STRICT_RUNTIME"
  printf "\"context\":\"%s\"," "$(json_escape "$K8S_CONTEXT")"
  printf "\"checks\":["
  for i in "${!CHECK_NAMES[@]}"; do
    [[ "$i" -gt 0 ]] && printf ","
    printf "{"
    printf "\"name\":\"%s\"," "$(json_escape "${CHECK_NAMES[$i]}")"
    printf "\"ok\":%s," "${CHECK_OK[$i]}"
    printf "\"exit_code\":%s" "${CHECK_CODE[$i]}"
    if [[ -n "${CHECK_MSG[$i]}" ]]; then
      printf ",\"message\":\"%s\"" "$(json_escape "${CHECK_MSG[$i]}")"
    fi
    printf "}"
  done
  printf "],"
  printf "\"failures\":%s" "$failures"
  printf "}\n"
else
  echo
  if [[ "$failures" -gt 0 ]]; then
    echo "FAILED ($failures checks failed)"
  else
    echo "OK"
  fi
fi

[[ "$failures" -eq 0 ]]
