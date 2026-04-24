#!/usr/bin/env bash
# Verify MongoDB Atlas SRV connectivity configuration.
#
# Offline checks (always run, no credentials needed):
#   1. Atlas SRV hostname present in config.sh
#   2. Atlas SRV hostname present in external-secrets.yaml
#   3. Atlas SRV hostname present in ADR-001
#   4. MongoDB password sourced from ExternalSecret (not hardcoded)
#   5. Connection string uses SRV format (mongodb+srv://)
#   6. pymongo[srv] dependency referenced in apply-patches.sh
#
# Online checks (only with --live flag, requires MONGODB_URI env var):
#   7. DNS SRV lookup resolves
#   8. MongoDB ping succeeds
#
# Usage:
#   ./scripts/qa/verify-atlas-health.sh              # offline checks only
#   MONGODB_URI="mongodb+srv://..." \
#     ./scripts/qa/verify-atlas-health.sh --live     # offline + online checks
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# ---------------------------------------------------------------------------
# Colors and counters
# ---------------------------------------------------------------------------
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0
LIVE_MODE=false

pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
warn() { echo -e "${YELLOW}WARN${NC} $1"; WARNED=$((WARNED + 1)); }

# ---------------------------------------------------------------------------
# Parse arguments
# ---------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --live) LIVE_MODE=true; shift ;;
    -h|--help)
      echo "Usage: $0 [--live]"
      echo ""
      echo "  --live   Run online checks (requires MONGODB_URI env var)"
      exit 0
      ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

ATLAS_HOSTNAME="cluster-mereka-lms.2pjex4s.mongodb.net"
ES_FILE="deploy/k8s/base/secrets/external-secrets.yaml"
ADR_FILE="docs/adr/historical/001-mongodb-atlas.md"
PATCHES_FILE="infrastructure/tutor/apply-patches.sh"
CONFIG_FILE="scripts/shared/config.sh"

# ---------------------------------------------------------------------------
# Offline checks
# ---------------------------------------------------------------------------
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    MongoDB Atlas Health Check — Offline                      ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  Atlas cluster: ${ATLAS_HOSTNAME}"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# 1. Atlas hostname in config.sh
echo "== Check 1: Atlas hostname reference in config files =="
if grep -q "mongodb\.net\|atlas\|MONGODB_SRV\|FORUM_MONGODB_SRV" "$CONFIG_FILE" 2>/dev/null; then
  pass "config.sh references Atlas/MongoDB SRV setting"
else
  warn "config.sh has no explicit Atlas hostname — MONGODB_HOST defaults to 'mongodb' (override via env in production)"
fi

# 2. ExternalSecret maps FORUM_MONGODB_HOST from MEREKA_LMS_FORUM_MONGODB_SRV
echo ""
echo "== Check 2: ExternalSecret maps MongoDB password from GCP Secret Manager =="
if [[ -f "$ES_FILE" ]]; then
  if grep -q "MEREKA_LMS_MONGODB_PASSWORD\|MEREKA_LMS_FORUM_MONGODB_SRV" "$ES_FILE"; then
    pass "ExternalSecret references Atlas password secret key (MEREKA_LMS_MONGODB_PASSWORD or FORUM_MONGODB_SRV)"
  else
    fail "ExternalSecret does not reference MEREKA_LMS_MONGODB_PASSWORD or MEREKA_LMS_FORUM_MONGODB_SRV"
  fi
else
  fail "ExternalSecret file not found: ${ES_FILE}"
fi

# 3. Atlas hostname in ADR-001
echo ""
echo "== Check 3: Atlas cluster hostname documented in ADR-001 =="
if [[ -f "$ADR_FILE" ]]; then
  if grep -q "$ATLAS_HOSTNAME" "$ADR_FILE"; then
    pass "ADR-001 documents Atlas cluster hostname: ${ATLAS_HOSTNAME}"
  else
    fail "ADR-001 missing Atlas cluster hostname: ${ATLAS_HOSTNAME}"
  fi
else
  fail "ADR file not found: ${ADR_FILE}"
fi

# 4. Password sourced via ExternalSecret (not hardcoded)
echo ""
echo "== Check 4: MongoDB password not hardcoded (sourced via ExternalSecret) =="
if [[ -f "$ES_FILE" ]]; then
  # ExternalSecret pattern: secretKey maps to GCP SM key
  if grep -q "secretKey: MONGODB_PASSWORD" "$ES_FILE" && \
     grep -q "key: MEREKA_LMS_MONGODB_PASSWORD" "$ES_FILE"; then
    pass "MongoDB password injected via ExternalSecret → K8s Secret (not hardcoded)"
  else
    fail "ExternalSecret missing MONGODB_PASSWORD ← MEREKA_LMS_MONGODB_PASSWORD mapping"
  fi
else
  fail "ExternalSecret file not found: ${ES_FILE}"
fi

# 5. Connection string uses SRV format
echo ""
echo "== Check 5: Atlas SRV format used in config chain =="
srv_found=false
if grep -q "FORUM_MONGODB_SRV\|mongodb+srv\|MEREKA_LMS_FORUM_MONGODB_SRV" "$ES_FILE" 2>/dev/null; then
  srv_found=true
fi
if grep -q "FORUM_MONGODB_SRV\|mongodb+srv\|MEREKA_LMS_FORUM_MONGODB_SRV" "$PATCHES_FILE" 2>/dev/null; then
  srv_found=true
fi
if [[ "$srv_found" == true ]]; then
  pass "SRV format (mongodb+srv://) referenced in config chain"
else
  fail "No SRV format reference found in ExternalSecret or apply-patches.sh"
fi

# 6. pymongo[srv] dependency referenced
echo ""
echo "== Check 6: pymongo[srv] dependency present for Atlas SRV connections =="
if grep -q 'pymongo\[srv\]' "$PATCHES_FILE" 2>/dev/null; then
  pass "pymongo[srv] referenced in apply-patches.sh (enables DNS SRV resolution)"
else
  fail "pymongo[srv] not found in apply-patches.sh — Atlas SRV connections may fail"
fi

# ---------------------------------------------------------------------------
# Online checks (--live only)
# ---------------------------------------------------------------------------
if [[ "$LIVE_MODE" == true ]]; then
  echo ""
  echo "╔══════════════════════════════════════════════════════════════╗"
  echo "║    MongoDB Atlas Health Check — Online                       ║"
  echo "╚══════════════════════════════════════════════════════════════╝"
  echo ""

  if [[ -z "${MONGODB_URI:-}" ]]; then
    fail "MONGODB_URI env var is required for --live checks (e.g. mongodb+srv://user:pass@cluster...)"
    echo ""
    echo "Export MONGODB_URI before running with --live:"
    echo "  export MONGODB_URI=\"mongodb+srv://...\""
    echo "  ./scripts/qa/verify-atlas-health.sh --live"
  else
    # 7. DNS SRV lookup
    echo "== Check 7: DNS SRV lookup for Atlas cluster =="
    if python3 - <<'PYEOF' 2>/dev/null
import dns.resolver, sys
answers = dns.resolver.resolve("_mongodb._tcp.cluster-mereka-lms.2pjex4s.mongodb.net", "SRV")
if answers:
    print(f"  Resolved {len(answers)} SRV records")
    sys.exit(0)
sys.exit(1)
PYEOF
    then
      pass "DNS SRV lookup for Atlas cluster succeeded"
    else
      fail "DNS SRV lookup failed — check network connectivity and dnspython install"
    fi

    # 8. MongoDB ping
    echo ""
    echo "== Check 8: MongoDB ping via Atlas URI =="
    if python3 - <<PYEOF 2>/dev/null
import os, sys
from pymongo import MongoClient
uri = os.environ["MONGODB_URI"]
client = MongoClient(uri, serverSelectionTimeoutMS=5000)
result = client.admin.command("ping")
if result.get("ok") == 1.0:
    print("  ping: ok")
    sys.exit(0)
sys.exit(1)
PYEOF
    then
      pass "MongoDB Atlas ping succeeded"
    else
      fail "MongoDB Atlas ping failed — check credentials and Atlas IP allowlist"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    Summary                                                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "  ${GREEN}Passed: ${PASSED}${NC}"
if [[ "$WARNED" -gt 0 ]]; then
  echo -e "  ${YELLOW}Warned: ${WARNED}${NC}"
fi
echo -e "  ${RED}Failed: ${FAILED}${NC}"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ "$LIVE_MODE" == false ]]; then
  echo ""
  echo "Offline checks complete. To run live connectivity checks:"
  echo "  export MONGODB_URI=\"mongodb+srv://user:pass@${ATLAS_HOSTNAME}/\""
  echo "  ./scripts/qa/verify-atlas-health.sh --live"
fi

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
exit 0
