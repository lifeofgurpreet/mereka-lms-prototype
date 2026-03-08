#!/usr/bin/env bash
set -euo pipefail

# verify-zero-pending-migrations.sh — Post-migration proof
# Verifies that all schema-owning services have zero pending migrations.
# Run this AFTER migration Jobs complete to confirm the schema is clean.
#
# Usage:
#   scripts/release/verify-zero-pending-migrations.sh [--namespace NS] [--service NAME] [--json]
#
# Reads:   deploy/k8s/migrations/registry.yaml (source of truth for services + check commands)
# Requires: kubectl, python3 (stdlib yaml + json)
#
# Exit codes:
#   0  All enabled services have 0 pending migrations
#   1  One or more services still have pending migrations (or check failed)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$SCRIPT_DIR/../.." && pwd)}"
cd "$REPO_ROOT"

NAMESPACE="${NAMESPACE:-mereka-lms}"
JSON_OUTPUT=false
SERVICE_FILTER=""
REGISTRY="deploy/k8s/migrations/registry.yaml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --service)
      if [[ -n "$SERVICE_FILTER" ]]; then
        SERVICE_FILTER="${SERVICE_FILTER},${2:?--service requires a value}"
      else
        SERVICE_FILTER="${2:?--service requires a value}"
      fi
      shift 2 ;;
    --json)      JSON_OUTPUT=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NS] [--service NAME] [--json]" >&2
      exit 0 ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--namespace NS] [--service NAME] [--json]" >&2
      exit 1 ;;
  esac
done

# ── Colours (suppressed in JSON mode) ─────────────────────────────────────────
if [[ "$JSON_OUTPUT" == "false" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
fi

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0

# Accumulate JSON result objects in a bash array
RESULT_OBJECTS=()
REQUESTED_SERVICES=()

pass() {
  [[ "$JSON_OUTPUT" == "false" ]] && echo -e "${GREEN}[PASS]${NC} $*"
  PASS=$((PASS + 1))
}
fail() {
  [[ "$JSON_OUTPUT" == "false" ]] && echo -e "${RED}[FAIL]${NC} $*"
  FAIL=$((FAIL + 1))
}
skip() {
  [[ "$JSON_OUTPUT" == "false" ]] && echo -e "${YELLOW}[SKIP]${NC} $*"
  SKIP=$((SKIP + 1))
}

[[ "$JSON_OUTPUT" == "false" ]] && {
  echo -e "${BOLD}=== Zero-Pending Migration Verification ===${NC}"
  echo "Namespace: $NAMESPACE"
  echo "Registry:  $REGISTRY"
  echo ""
}

if [[ ! -f "$REGISTRY" ]]; then
  echo "ERROR: Registry not found: $REGISTRY" >&2
  exit 1
fi

if [[ -n "$SERVICE_FILTER" ]]; then
  IFS=',' read -r -a raw_requested <<< "$SERVICE_FILTER"
  for svc in "${raw_requested[@]}"; do
    svc_trimmed="$(echo "$svc" | xargs)"
    [[ -n "$svc_trimmed" ]] && REQUESTED_SERVICES+=("$svc_trimmed")
  done
fi

# Validate requested services against registry before any kubectl calls.
if [[ ${#REQUESTED_SERVICES[@]} -gt 0 ]]; then
  REGISTRY_SERVICES="$(
    python3 - <<PYEOF 2>/dev/null
import yaml
with open("$REGISTRY") as f:
    reg = yaml.safe_load(f) or {}
for svc in reg.get("services", []):
    name = svc.get("name")
    if name:
        print(name)
PYEOF
  )"

  for req in "${REQUESTED_SERVICES[@]}"; do
    if ! grep -Fxq "$req" <<<"$REGISTRY_SERVICES"; then
      fail "$req — unknown service selector (not found in migration registry)"
      RESULT_OBJECTS+=("{\"name\":\"$req\",\"status\":\"fail\",\"reason\":\"unknown_service\"}")
    fi
  done
fi

# ── Parse registry and verify each service ────────────────────────────────────
while IFS= read -r svc_json; do
  NAME=$(python3 -c "import json,sys; print(json.load(sys.stdin)['name'])" <<< "$svc_json")
  DISABLED=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('disabled', False))" <<< "$svc_json")
  PENDING_CMD=$(python3 -c "import json,sys; print(json.load(sys.stdin)['pending_check'])" <<< "$svc_json")
  DB=$(python3 -c "import json,sys; print(json.load(sys.stdin)['database'])" <<< "$svc_json")
  CRITICAL=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('release_critical', False))" <<< "$svc_json")

  if [[ ${#REQUESTED_SERVICES[@]} -gt 0 ]]; then
    requested=false
    for req in "${REQUESTED_SERVICES[@]}"; do
      if [[ "$req" == "$NAME" ]]; then
        requested=true
        break
      fi
    done
    [[ "$requested" == "false" ]] && continue
  fi

  if [[ "$DISABLED" == "True" ]]; then
    skip "$NAME (disabled in registry)"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"status\":\"skip\",\"reason\":\"disabled\",\"database\":\"$DB\"}")
    continue
  fi

  if ! kubectl get deploy "$NAME" -n "$NAMESPACE" &>/dev/null; then
    skip "$NAME (deployment not found in $NAMESPACE)"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"status\":\"skip\",\"reason\":\"not_deployed\",\"database\":\"$DB\"}")
    continue
  fi

  # Execute the pending_check from the registry (outputs an integer; 0 = clean)
  PENDING=$(kubectl exec "deploy/$NAME" -n "$NAMESPACE" -- \
    bash -c "$PENDING_CMD" 2>/dev/null | tr -d '[:space:]' || echo "ERROR")

  if [[ "$PENDING" == "0" ]]; then
    pass "$NAME — 0 pending ($DB, release_critical=$CRITICAL)"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"status\":\"pass\",\"pending\":0,\"database\":\"$DB\",\"release_critical\":$( [[ "$CRITICAL" == "True" ]] && echo true || echo false)}")
  elif [[ "$PENDING" == "ERROR" ]]; then
    fail "$NAME — cannot exec pending check (pod unreachable or command failed)"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"status\":\"fail\",\"reason\":\"check_error\",\"database\":\"$DB\",\"release_critical\":$( [[ "$CRITICAL" == "True" ]] && echo true || echo false)}")
  else
    fail "$NAME — $PENDING pending migration(s) still unapplied ($DB)"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"status\":\"fail\",\"pending\":$PENDING,\"database\":\"$DB\",\"release_critical\":$( [[ "$CRITICAL" == "True" ]] && echo true || echo false)}")
  fi

done < <(python3 - <<PYEOF 2>/dev/null
import yaml, json
with open("$REGISTRY") as f:
    reg = yaml.safe_load(f)
for svc in reg.get("services", []):
    print(json.dumps(svc))
PYEOF
)

# ── JSON output ───────────────────────────────────────────────────────────────
if [[ "$JSON_OUTPUT" == "true" ]]; then
  RESULTS_JSON=$(printf '%s\n' "${RESULT_OBJECTS[@]}" | python3 -c "
import json, sys
items = [json.loads(line) for line in sys.stdin if line.strip()]
print(json.dumps(items, indent=2))
")
  ALL_ZERO=$( [[ $FAIL -eq 0 ]] && echo "true" || echo "false" )
  cat <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "namespace": "$NAMESPACE",
  "registry": "$REGISTRY",
  "results": $RESULTS_JSON,
  "summary": {
    "pass": $PASS,
    "fail": $FAIL,
    "skip": $SKIP
  },
  "all_zero": $ALL_ZERO
}
JSON
fi

# ── Summary ───────────────────────────────────────────────────────────────────
if [[ "$JSON_OUTPUT" == "false" ]]; then
  echo ""
  echo -e "${BOLD}━━━ Results: $PASS pass, $FAIL fail, $SKIP skip ━━━${NC}"
  if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}${BOLD}VERDICT: FAIL — schema not clean. Do not proceed.${NC}"
  else
    echo -e "${GREEN}${BOLD}VERDICT: PASS — all schemas clean.${NC}"
  fi
fi

[[ $FAIL -eq 0 ]]
