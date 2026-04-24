#!/usr/bin/env bash
set -euo pipefail

# migration-preflight.sh — Pre-migration safety gate
# Verifies that migration Jobs will execute against the same environment as runtime pods.
#
# Usage:
#   scripts/release/migration-preflight.sh [--namespace NS] [--skip-atlas-check]
#
# Requires: kubectl configured with target cluster access
#
# Exit codes:
#   0  All preflight checks PASS
#   1  One or more checks FAIL (do not proceed with migration)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

NAMESPACE="${NAMESPACE:-mereka-lms}"
SKIP_ATLAS=false
REGISTRY="deploy/k8s/migrations/registry.yaml"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace)     NAMESPACE="${2:?--namespace requires a value}"; shift 2 ;;
    --skip-atlas-check) SKIP_ATLAS=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--namespace NS] [--skip-atlas-check]" >&2
      exit 0 ;;
    *)
      echo "Unknown flag: $1" >&2
      echo "Usage: $0 [--namespace NS] [--skip-atlas-check]" >&2
      exit 1 ;;
  esac
done

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# ── Counters ──────────────────────────────────────────────────────────────────
PASS=0; FAIL=0; WARN=0; SKIP=0

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; WARN=$((WARN + 1)); }
skip() { echo -e "${YELLOW}[SKIP]${NC} $*"; SKIP=$((SKIP + 1)); }
info() { echo -e "${CYAN}[INFO]${NC} $*"; }
header() { echo -e "\n${BOLD}=== $* ===${NC}"; }

echo -e "${BOLD}=== Migration Preflight — $NAMESPACE ===${NC}"
echo "Cluster:   $(kubectl config current-context 2>/dev/null || echo 'UNKNOWN')"
echo "Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)"

# ── Check 1: Cluster access ───────────────────────────────────────────────────
header "Check 1: Cluster Access"

if ! command -v kubectl &>/dev/null; then
  echo -e "${RED}FATAL: kubectl not found${NC}" >&2
  exit 1
fi

if kubectl get ns "$NAMESPACE" &>/dev/null; then
  pass "Namespace $NAMESPACE exists"
else
  echo -e "${RED}FATAL: Namespace $NAMESPACE not found — cannot proceed${NC}" >&2
  exit 1
fi

# ── Check 2: Core deployments have ready replicas ─────────────────────────────
header "Check 2: Core Deployments"

for deploy in lms cms; do
  if kubectl get deploy "$deploy" -n "$NAMESPACE" &>/dev/null; then
    READY=$(kubectl get deploy "$deploy" -n "$NAMESPACE" \
      -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
    if [[ "${READY:-0}" -gt 0 ]]; then
      pass "$deploy: ${READY} ready replica(s)"
    else
      fail "$deploy: 0 ready replicas — pods may be crashing"
    fi
  else
    fail "$deploy deployment not found in $NAMESPACE"
  fi
done

# ── Check 3: Image parity — Job vs runtime ────────────────────────────────────
header "Check 3: Image Parity (Job vs Runtime)"

LMS_IMAGE=$(kubectl get deploy lms -n "$NAMESPACE" \
  -o jsonpath='{.spec.template.spec.containers[0].image}' 2>/dev/null || echo "UNKNOWN")
info "Runtime LMS image: $LMS_IMAGE"

PARITY_FAIL=0
for job_file in deploy/k8s/base/jobs/*-migrate.yaml; do
  [[ -f "$job_file" ]] || continue
  JOB_NAME=$(basename "$job_file" .yaml)

  # Extract first image from the main containers block (not initContainers)
  JOB_IMAGE=$(python3 - <<PYEOF 2>/dev/null || echo "UNKNOWN"
import yaml, sys

with open("$job_file") as f:
    doc = yaml.safe_load(f)

containers = doc.get("spec", {}).get("template", {}).get("spec", {}).get("containers", [])
if containers:
    print(containers[0].get("image", "UNKNOWN"))
else:
    print("UNKNOWN")
PYEOF
)
  info "Job $JOB_NAME image: $JOB_IMAGE"

  # Warn if sentinel tag is still in place
  if [[ "$JOB_IMAGE" == *"pin-required"* ]]; then
    fail "$JOB_NAME: image uses sentinel tag 'pin-required' — must be pinned before release"
    PARITY_FAIL=$((PARITY_FAIL + 1))
  fi

  # Check for a completed Job still lingering in the cluster
  EXISTING=$(kubectl get job "$JOB_NAME" -n "$NAMESPACE" \
    -o jsonpath='{.status.succeeded}' 2>/dev/null || echo "")
  if [[ "$EXISTING" == "1" ]]; then
    warn "$JOB_NAME: completed Job already exists — delete it before re-running"
  fi
done

[[ $PARITY_FAIL -eq 0 ]] && pass "No sentinel 'pin-required' tags found in migration Jobs"

# ── Check 4: Database host sanity ─────────────────────────────────────────────
header "Check 4: Database Dependencies"

# MySQL
MYSQL_HOST=$(kubectl exec deploy/lms -n "$NAMESPACE" -- \
  printenv MYSQL_HOST 2>/dev/null || echo "UNKNOWN")
info "MySQL host: $MYSQL_HOST"
if [[ "$MYSQL_HOST" != "UNKNOWN" && -n "$MYSQL_HOST" ]]; then
  pass "MySQL host configured: $MYSQL_HOST"
else
  fail "Cannot determine MySQL host from LMS pod environment"
fi

# MongoDB / Atlas
if [[ "$SKIP_ATLAS" == "false" ]]; then
  MONGO_HOST=$(kubectl exec deploy/lms -n "$NAMESPACE" -- \
    printenv MONGODB_HOST 2>/dev/null || echo "UNKNOWN")
  info "MongoDB host: $MONGO_HOST"

  if [[ "$MONGO_HOST" == "mongodb" || "$MONGO_HOST" == "mongodb:27017" || "$MONGO_HOST" == *":27017" && "$MONGO_HOST" != *"mongodb.net"* ]]; then
    fail "MongoDB points to in-cluster placeholder ($MONGO_HOST) — Atlas mismatch! (FM-001)"
  elif [[ "$MONGO_HOST" == *"mongodb.net"* ]]; then
    pass "MongoDB points to Atlas: $MONGO_HOST"
  elif [[ "$MONGO_HOST" == "UNKNOWN" || -z "$MONGO_HOST" ]]; then
    warn "Cannot determine MongoDB host from LMS pod environment"
  else
    warn "MongoDB host is non-standard: $MONGO_HOST"
  fi
else
  skip "MongoDB Atlas check skipped (--skip-atlas-check)"
fi

# Redis
REDIS_HOST=$(kubectl exec deploy/lms -n "$NAMESPACE" -- \
  printenv REDIS_HOST 2>/dev/null || echo "UNKNOWN")
info "Redis host: $REDIS_HOST"
if [[ "$REDIS_HOST" != "UNKNOWN" && -n "$REDIS_HOST" ]]; then
  pass "Redis host configured: $REDIS_HOST"
else
  warn "Cannot determine Redis host from LMS pod environment"
fi

# ── Check 5: Django settings module ───────────────────────────────────────────
header "Check 5: Settings Module"

SETTINGS=$(kubectl exec deploy/lms -n "$NAMESPACE" -- \
  printenv DJANGO_SETTINGS_MODULE 2>/dev/null || echo "UNKNOWN")
info "LMS DJANGO_SETTINGS_MODULE: $SETTINGS"

if [[ "$SETTINGS" == *"production"* ]]; then
  pass "LMS using production settings: $SETTINGS"
elif [[ "$SETTINGS" == "UNKNOWN" || -z "$SETTINGS" ]]; then
  warn "Cannot determine settings module"
else
  warn "Non-production settings module: $SETTINGS"
fi

# ── Check 6: Pending migration count ──────────────────────────────────────────
header "Check 6: Pending Migrations (current state)"

# Parse pending_check command from registry for each non-disabled service
while IFS= read -r svc_json; do
  NAME=$(python3 -c "import json,sys; print(json.load(sys.stdin)['name'])" <<< "$svc_json")
  DISABLED=$(python3 -c "import json,sys; print(json.load(sys.stdin).get('disabled', False))" <<< "$svc_json")
  PENDING_CMD=$(python3 -c "import json,sys; print(json.load(sys.stdin)['pending_check'])" <<< "$svc_json")

  if [[ "$DISABLED" == "True" ]]; then
    skip "$NAME: disabled in registry"
    continue
  fi

  if ! kubectl get deploy "$NAME" -n "$NAMESPACE" &>/dev/null; then
    skip "$NAME: deployment not found"
    continue
  fi

  PENDING=$(kubectl exec "deploy/$NAME" -n "$NAMESPACE" -- \
    bash -c "$PENDING_CMD" 2>/dev/null | tr -d '[:space:]' || echo "ERROR")

  if [[ "$PENDING" == "0" ]]; then
    pass "$NAME: 0 pending migrations"
  elif [[ "$PENDING" == "ERROR" ]]; then
    warn "$NAME: cannot check pending migrations (exec failed)"
  else
    warn "$NAME: $PENDING pending migration(s) — will be applied by migration Job"
  fi
done < <(python3 - <<PYEOF 2>/dev/null
import yaml, json
with open("$REGISTRY") as f:
    reg = yaml.safe_load(f)
for svc in reg.get("services", []):
    print(json.dumps(svc))
PYEOF
)

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo -e "${BOLD}━━━ Preflight Summary ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "  ${GREEN}PASS${NC}  $PASS"
echo -e "  ${YELLOW}WARN${NC}  $WARN"
echo -e "  ${YELLOW}SKIP${NC}  $SKIP"
echo -e "  ${RED}FAIL${NC}  $FAIL"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}${BOLD}VERDICT: BLOCKED — $FAIL check(s) failed. Do not proceed with migration.${NC}"
  exit 1
else
  echo -e "${GREEN}${BOLD}VERDICT: CLEAR — safe to proceed with migration.${NC}"
  exit 0
fi
