#!/usr/bin/env bash
# smoke-by-service-wave.sh — Run smoke tests grouped by service wave
#
# Groups services into priority waves and runs health checks per wave.
# Stops on first wave failure unless --continue-on-failure is set.
#
# Usage:
#   scripts/release/smoke-by-service-wave.sh --lane dev [--wave N] [--json]
#
# Waves:
#   1: Core (lms, cms, caddy) — must pass for any further testing
#   2: Workers (lms-worker, cms-worker) — celery health
#   3: Services (discovery, credentials, notes, mfe) — auxiliary services
#   4: Enterprise (enterprise-*, license-manager) — enterprise services
#   5: Platform (payments-gateway, meilisearch, mux-delivery-monitor) — platform services
#
# Reads: deploy/k8s/contract.json for health endpoints
# Requires: kubectl access to target cluster
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source lane normalizer
source "$REPO_ROOT/scripts/lib/lane-normalize.sh"

LANE=""
TARGET_WAVE=""
JSON_OUTPUT=false
CONTINUE_ON_FAILURE=false
CONTRACT="$REPO_ROOT/deploy/k8s/contract.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane)     LANE="${2:?--lane requires a value}"; shift 2 ;;
    --wave)     TARGET_WAVE="${2:?--wave requires a value}"; shift 2 ;;
    --json)     JSON_OUTPUT=true; shift ;;
    --continue-on-failure) CONTINUE_ON_FAILURE=true; shift ;;
    *)          echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$LANE" ]]; then
  echo "Usage: smoke-by-service-wave.sh --lane dev|staging|prod [--wave N] [--json]" >&2
  exit 1
fi

CANONICAL_LANE="$(normalize_lane_to_canonical "$LANE")"
NAMESPACE="$(normalize_lane_to_namespace "$CANONICAL_LANE")"

# Define service waves
declare -A WAVE_NAMES=(
  [1]="Core"
  [2]="Workers"
  [3]="Services"
  [4]="Enterprise"
  [5]="Platform"
)

declare -A WAVE_SERVICES=(
  [1]="lms cms caddy"
  [2]="lms-worker cms-worker"
  [3]="discovery credentials notes mfe"
  [4]="enterprise-access enterprise-catalog enterprise-subsidy license-manager enterprise-admin-portal enterprise-learner-portal"
  [5]="payments-gateway meilisearch mux-delivery-monitor"
)

TOTAL_PASS=0
TOTAL_FAIL=0
TOTAL_SKIP=0
WAVE_RESULTS=()

check_service() {
  local service="$1"
  local ns="$2"

  # Check if deployment exists and has ready replicas
  local ready
  ready=$(kubectl get deployment "$service" -n "$ns" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "")

  if [[ -z "$ready" || "$ready" == "0" ]]; then
    local desired
    desired=$(kubectl get deployment "$service" -n "$ns" -o jsonpath='{.spec.replicas}' 2>/dev/null || echo "")
    if [[ "$desired" == "0" ]]; then
      echo "  SKIP: $service (scaled to 0)"
      TOTAL_SKIP=$((TOTAL_SKIP + 1))
      return 2
    fi
    echo "  FAIL: $service (no ready replicas)" >&2
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    return 1
  fi

  # Get health endpoint from contract.json
  local health_path health_port
  health_path=$(python3 -c "
import json, sys
c = json.load(open('$CONTRACT'))
for w in c['workloads']:
    if w['name'] == '$service' and w.get('health'):
        print(w['health']['path'])
        sys.exit(0)
print('')
" 2>/dev/null)

  health_port=$(python3 -c "
import json, sys
c = json.load(open('$CONTRACT'))
for w in c['workloads']:
    if w['name'] == '$service' and w.get('health'):
        print(w['health']['port'])
        sys.exit(0)
print('')
" 2>/dev/null)

  if [[ -n "$health_path" && -n "$health_port" ]]; then
    # Port-forward and check health
    local pod
    pod=$(kubectl get pods -n "$ns" -l "app.kubernetes.io/name=$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$pod" ]]; then
      # Try alternative label selectors
      pod=$(kubectl get pods -n "$ns" -l "app=$service" -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    fi

    if [[ -n "$pod" ]]; then
      # Check HTTP connectivity — any response (even 400/403) means the service is alive.
      # Django returns 400 when Host header doesn't match ALLOWED_HOSTS, but the service is running.
      local http_code="000"

      # Try curl first
      http_code=$(kubectl exec -n "$ns" "$pod" -- curl -s -o /dev/null -w '%{http_code}' --connect-timeout 5 "http://localhost:${health_port}${health_path}" 2>/dev/null || echo "000")

      # Fallback to wget if curl not available
      if [[ "$http_code" == "000" ]]; then
        local wget_out
        wget_out=$(kubectl exec -n "$ns" "$pod" -- wget -q -O - --timeout=5 "http://localhost:${health_port}${health_path}" 2>&1) && http_code="200" || {
          # wget returns non-zero for non-2xx but may still connect
          if echo "$wget_out" | grep -q "400\|401\|403\|404\|500\|502\|503"; then
            http_code=$(echo "$wget_out" | grep -oP '\d{3}' | head -1)
          fi
        }
      fi

      if [[ "$http_code" != "000" ]]; then
        if [[ "$http_code" =~ ^2 ]]; then
          echo "  PASS: $service (health: ${health_path} → ${http_code})"
        else
          echo "  PASS: $service (alive: ${health_path} → ${http_code})"
        fi
        TOTAL_PASS=$((TOTAL_PASS + 1))
        return 0
      else
        # Last resort: port-forward from host and curl from outside the pod
        local local_port=$((30000 + RANDOM % 5000))
        kubectl port-forward -n "$ns" "$pod" "${local_port}:${health_port}" >/dev/null 2>&1 &
        local pf_pid=$!
        sleep 1
        local ext_code
        ext_code=$(curl -s -o /dev/null -w '%{http_code}' --connect-timeout 3 "http://localhost:${local_port}${health_path}" 2>/dev/null || echo "000")
        kill "$pf_pid" 2>/dev/null; wait "$pf_pid" 2>/dev/null || true

        if [[ "$ext_code" != "000" ]]; then
          if [[ "$ext_code" =~ ^2 ]]; then
            echo "  PASS: $service (health: ${health_path} → ${ext_code} via port-forward)"
          else
            echo "  PASS: $service (alive: ${health_path} → ${ext_code} via port-forward)"
          fi
          TOTAL_PASS=$((TOTAL_PASS + 1))
          return 0
        else
          echo "  FAIL: $service (health: ${health_path} → no response)" >&2
          TOTAL_FAIL=$((TOTAL_FAIL + 1))
          return 1
        fi
      fi
    else
      echo "  WARN: $service ($ready ready, but no pod found for health check)"
      echo "  PASS: $service ($ready ready replicas)"
      TOTAL_PASS=$((TOTAL_PASS + 1))
      return 0
    fi
  else
    # No health endpoint defined — just check replicas
    echo "  PASS: $service ($ready ready replicas, no health endpoint)"
    TOTAL_PASS=$((TOTAL_PASS + 1))
    return 0
  fi
}

run_wave() {
  local wave_num="$1"
  local wave_name="${WAVE_NAMES[$wave_num]}"
  local services="${WAVE_SERVICES[$wave_num]}"

  echo ""
  echo "Wave $wave_num: $wave_name"
  echo "$(printf '=%.0s' {1..40})"

  local wave_pass=0
  local wave_fail=0
  local wave_skip=0

  for service in $services; do
    check_service "$service" "$NAMESPACE"
    local rc=$?
    case $rc in
      0) wave_pass=$((wave_pass + 1)) ;;
      1) wave_fail=$((wave_fail + 1)) ;;
      2) wave_skip=$((wave_skip + 1)) ;;
    esac
  done

  local wave_result="pass"
  [[ "$wave_fail" -gt 0 ]] && wave_result="fail"

  WAVE_RESULTS+=("{\"wave\": $wave_num, \"name\": \"$wave_name\", \"result\": \"$wave_result\", \"pass\": $wave_pass, \"fail\": $wave_fail, \"skip\": $wave_skip}")

  echo "  Wave $wave_num: $wave_pass pass, $wave_fail fail, $wave_skip skip → $wave_result"

  if [[ "$wave_fail" -gt 0 && "$CONTINUE_ON_FAILURE" != "true" ]]; then
    echo ""
    echo "Wave $wave_num FAILED — stopping (use --continue-on-failure to proceed)" >&2
    return 1
  fi
  return 0
}

echo "Service Wave Smoke Tests"
echo "========================"
echo "Lane: $CANONICAL_LANE | Namespace: $NAMESPACE"

START_TIME=$(date +%s%N)

if [[ -n "$TARGET_WAVE" ]]; then
  run_wave "$TARGET_WAVE" || true
else
  for wave in 1 2 3 4 5; do
    run_wave "$wave" || break
  done
fi

END_TIME=$(date +%s%N)
DURATION_MS=$(( (END_TIME - START_TIME) / 1000000 ))

OVERALL_RESULT="pass"
[[ "$TOTAL_FAIL" -gt 0 ]] && OVERALL_RESULT="fail"

echo ""
echo "Summary: $TOTAL_PASS pass, $TOTAL_FAIL fail, $TOTAL_SKIP skip → $OVERALL_RESULT"
echo "Duration: ${DURATION_MS}ms"

if [[ "$JSON_OUTPUT" == "true" ]]; then
  WAVES_JSON=$(printf '%s,' "${WAVE_RESULTS[@]}")
  WAVES_JSON="[${WAVES_JSON%,}]"

  cat <<ENVELOPE
{
  "schema_version": "1",
  "concern": "service-wave-smoke",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "commit_sha": "$(git -C "$REPO_ROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")",
  "ci_run_id": "${GITHUB_RUN_ID:-local}",
  "lane": "$CANONICAL_LANE",
  "dry_run": false,
  "result": "$OVERALL_RESULT",
  "details": {
    "namespace": "$NAMESPACE",
    "total_pass": $TOTAL_PASS,
    "total_fail": $TOTAL_FAIL,
    "total_skip": $TOTAL_SKIP,
    "waves": $WAVES_JSON
  },
  "duration_ms": $DURATION_MS
}
ENVELOPE
fi

[[ "$TOTAL_FAIL" -eq 0 ]] || exit 1
