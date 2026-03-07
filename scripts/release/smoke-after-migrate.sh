#!/usr/bin/env bash
set -euo pipefail

# smoke-after-migrate.sh — Post-migration smoke verification
# Verifies that critical services are functional after migration Jobs complete.
# Drives health endpoint list from contract.json to stay in sync with the workload manifest.
#
# Usage:
#   scripts/release/smoke-after-migrate.sh [--namespace NS] [--domain DOMAIN] [--json]
#
# Reads:   deploy/k8s/contract.json (health endpoints + ports)
# Requires: kubectl, python3 (stdlib json), curl (for --domain checks)
#
# Exit codes:
#   0  All internal checks pass (external checks excluded from exit code when --domain not set)
#   1  One or more checks fail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

NAMESPACE="${NAMESPACE:-mereka-lms}"
DOMAIN=""
JSON_OUTPUT=false
CONTRACT="deploy/k8s/contract.json"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --domain)    DOMAIN="${2:?--domain requires a value}"; shift 2 ;;
    --json)      JSON_OUTPUT=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NS] [--domain DOMAIN] [--json]" >&2
      exit 0 ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--namespace NS] [--domain DOMAIN] [--json]" >&2
      exit 1 ;;
  esac
done

# ── Colours (suppressed in JSON mode) ─────────────────────────────────────────
if [[ "$JSON_OUTPUT" == "false" ]]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
  CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; YELLOW=''; CYAN=''; BOLD=''; NC=''
fi

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; SKIP=0
RESULT_OBJECTS=()

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; SKIP=$((SKIP + 1)); }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

[[ "$JSON_OUTPUT" == "false" ]] && {
  echo -e "${BOLD}=== Post-Migration Smoke Test ===${NC}"
  echo "Namespace: $NAMESPACE"
  [[ -n "$DOMAIN" ]] && echo "Domain:    $DOMAIN"
  echo ""
}

if [[ ! -f "$CONTRACT" ]]; then
  echo "ERROR: contract.json not found: $CONTRACT" >&2
  exit 1
fi

# ── Internal health checks driven by contract.json ────────────────────────────
[[ "$JSON_OUTPUT" == "false" ]] && header "Internal Health Endpoints (kubectl exec)"

# Build list of workloads that have a health endpoint defined in contract.json
WORKLOADS_JSON=$(python3 - <<PYEOF 2>/dev/null
import json
with open("$CONTRACT") as f:
    contract = json.load(f)
result = []
for w in contract.get("workloads", []):
    h = w.get("health")
    if h and h.get("path") and h.get("port"):
        result.append({"name": w["name"], "path": h["path"], "port": h["port"]})
import sys
print(json.dumps(result))
PYEOF
)

while IFS= read -r wl_json; do
  NAME=$(python3 -c "import json,sys; print(json.load(sys.stdin)['name'])" <<< "$wl_json")
  PATH_=$(python3 -c "import json,sys; print(json.load(sys.stdin)['path'])" <<< "$wl_json")
  PORT=$(python3 -c "import json,sys; print(json.load(sys.stdin)['port'])" <<< "$wl_json")

  if ! kubectl get deploy "$NAME" -n "$NAMESPACE" &>/dev/null; then
    skip "$NAME (not deployed)"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"type\":\"internal\",\"status\":\"skip\",\"reason\":\"not_deployed\"}")
    continue
  fi

  READY=$(kubectl get deploy "$NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [[ "${READY:-0}" -eq 0 ]]; then
    fail "$NAME — 0 ready replicas (${PATH_}:${PORT})"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"type\":\"internal\",\"status\":\"fail\",\"reason\":\"no_ready_replicas\",\"endpoint\":\"${PATH_}:${PORT}\"}")
    continue
  fi

  # Use wget inside the container — present in all Open edX images; avoids curl dependency
  HTTP_STATUS=$(kubectl exec "deploy/$NAME" -n "$NAMESPACE" -- \
    wget -q -O /dev/null --server-response \
    "http://localhost:${PORT}${PATH_}" 2>&1 \
    | grep -o 'HTTP/[^ ]* [0-9]*' | tail -1 \
    || echo "UNREACHABLE")

  if [[ "$HTTP_STATUS" == *"200"* || "$HTTP_STATUS" == *"204"* ]]; then
    pass "$NAME  ${PATH_}:${PORT}  →  $HTTP_STATUS"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"type\":\"internal\",\"status\":\"pass\",\"http_status\":\"$HTTP_STATUS\",\"endpoint\":\"${PATH_}:${PORT}\"}")
  else
    fail "$NAME  ${PATH_}:${PORT}  →  $HTTP_STATUS"
    RESULT_OBJECTS+=("{\"name\":\"$NAME\",\"type\":\"internal\",\"status\":\"fail\",\"http_status\":\"$HTTP_STATUS\",\"endpoint\":\"${PATH_}:${PORT}\"}")
  fi

done < <(python3 -c "
import json, sys
items = json.loads(sys.argv[1])
for item in items:
    print(json.dumps(item))
" "$WORKLOADS_JSON" 2>/dev/null)

# ── External checks (only when --domain is provided) ──────────────────────────
if [[ -n "$DOMAIN" ]]; then
  [[ "$JSON_OUTPUT" == "false" ]] && header "External Endpoints (curl)"

  check_external() {
    local label="$1" url="$2"
    local http_code
    http_code=$(curl -sf -o /dev/null -w '%{http_code}' \
      --max-time 15 --connect-timeout 5 "$url" 2>/dev/null || echo "000")

    if [[ "$http_code" == "200" || "$http_code" == "302" ]]; then
      pass "$label  ($url)  →  $http_code"
      RESULT_OBJECTS+=("{\"name\":\"$label\",\"type\":\"external\",\"status\":\"pass\",\"http_code\":\"$http_code\",\"url\":\"$url\"}")
    else
      fail "$label  ($url)  →  $http_code"
      RESULT_OBJECTS+=("{\"name\":\"$label\",\"type\":\"external\",\"status\":\"fail\",\"http_code\":\"$http_code\",\"url\":\"$url\"}")
    fi
  }

  check_external "LMS homepage"  "https://$DOMAIN/"
  check_external "LMS heartbeat" "https://$DOMAIN/heartbeat"
  check_external "Studio"        "https://studio.$DOMAIN/heartbeat"
  check_external "MFE login"     "https://apps.$DOMAIN/authn/login"
fi

# ── JSON output ───────────────────────────────────────────────────────────────
if [[ "$JSON_OUTPUT" == "true" ]]; then
  CHECKS_JSON=$(printf '%s\n' "${RESULT_OBJECTS[@]}" | python3 -c "
import json, sys
items = [json.loads(line) for line in sys.stdin if line.strip()]
print(json.dumps(items, indent=2))
")
  ALL_OK=$( [[ $FAIL -eq 0 ]] && echo "true" || echo "false" )
  cat <<JSON
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "namespace": "$NAMESPACE",
  "domain": "$DOMAIN",
  "checks": $CHECKS_JSON,
  "summary": {
    "pass": $PASS,
    "fail": $FAIL,
    "skip": $SKIP
  },
  "all_ok": $ALL_OK
}
JSON
fi

# ── Summary ───────────────────────────────────────────────────────────────────
if [[ "$JSON_OUTPUT" == "false" ]]; then
  echo ""
  echo -e "${BOLD}━━━ Smoke Results: $PASS pass, $FAIL fail, $SKIP skip ━━━${NC}"
  if [[ $FAIL -gt 0 ]]; then
    echo -e "${RED}${BOLD}VERDICT: FAIL — services not healthy after migration.${NC}"
  else
    echo -e "${GREEN}${BOLD}VERDICT: PASS — all checked services healthy.${NC}"
  fi
fi

[[ $FAIL -eq 0 ]]
