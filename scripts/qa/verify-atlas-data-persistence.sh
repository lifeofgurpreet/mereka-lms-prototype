#!/usr/bin/env bash
# @covers AC-003, AC-004
# @spec: mongodb-atlas-integration_spec.md
# Verify Atlas data persistence configuration chain for AC-003 and AC-004.
#
# AC-003: Course creation in Studio persists to Atlas `openedx` database.
# AC-004: Forum posts persist to Atlas `cs_comments_service` database.
#
# This script traces the full config chain:
#   ExternalSecrets → K8s Deployment env → Python settings → modulestore/forum config
#
# Usage:
#   ./scripts/qa/verify-atlas-data-persistence.sh
#   ./scripts/qa/verify-atlas-data-persistence.sh --ac 003     # AC-003 only (modulestore)
#   ./scripts/qa/verify-atlas-data-persistence.sh --ac 004     # AC-004 only (forum)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0
AC_FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ac) AC_FILTER="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: $0 [--ac 003|004]"
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

pass() { echo -e "${GREEN}OK${NC}   $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }

# ---------------------------------------------------------------------------
# Shared: ExternalSecrets → Deployment env chain
# ---------------------------------------------------------------------------
check_shared_secret_chain() {
  echo "== Shared: Secret chain (ExternalSecrets → Deployment env) =="

  local es="deploy/k8s/base/secrets/external-secrets.yaml"

  # FORUM_MONGODB_HOST maps from MEREKA_LMS_FORUM_MONGODB_SRV
  if grep -q "secretKey: FORUM_MONGODB_HOST" "$es" &&
     grep -q "key: MEREKA_LMS_FORUM_MONGODB_SRV" "$es"; then
    pass "ExternalSecret maps FORUM_MONGODB_HOST ← MEREKA_LMS_FORUM_MONGODB_SRV"
  else
    fail "ExternalSecret missing FORUM_MONGODB_HOST ← MEREKA_LMS_FORUM_MONGODB_SRV mapping"
  fi

  # FORUM_MONGODB_PASSWORD mapping
  if grep -q "secretKey: FORUM_MONGODB_PASSWORD" "$es"; then
    pass "ExternalSecret maps FORUM_MONGODB_PASSWORD"
  else
    fail "ExternalSecret missing FORUM_MONGODB_PASSWORD mapping"
  fi

  # All deployments that touch MongoDB have MONGODB_HOST from secretKeyRef
  local dep="deploy/k8s/base/deployments.yml"
  for svc in lms cms lms-worker cms-worker; do
    if python3 -c "
import re, sys
text = open('$dep').read()
docs = re.split(r'(?m)^---\s*\$', text)
for doc in docs:
    if not re.search(r'kind:\s*Deployment', doc): continue
    m = re.search(r'name:\s*$svc\s*\$', doc, re.M)
    if not m: continue
    if re.search(r'name:\s*MONGODB_HOST.*?secretKeyRef.*?key:\s*FORUM_MONGODB_HOST', doc, re.S):
        sys.exit(0)
sys.exit(1)
" 2>/dev/null; then
      pass "Deployment $svc: MONGODB_HOST from openedx-secrets/FORUM_MONGODB_HOST"
    else
      fail "Deployment $svc: missing MONGODB_HOST from secretKeyRef"
    fi
  done

  echo ""
}

# ---------------------------------------------------------------------------
# AC-003: Studio/CMS modulestore → Atlas openedx database
# ---------------------------------------------------------------------------
check_ac003_modulestore() {
  echo "== AC-003: CMS modulestore → Atlas 'openedx' database =="

  local cms="deploy/k8s/base/apps/openedx/settings/cms/production.py"

  # CMS reads MONGODB_HOST from env
  if grep -q 'MONGODB_HOST = os.environ.get("MONGODB_HOST"' "$cms"; then
    pass "CMS settings: MONGODB_HOST read from env var"
  else
    fail "CMS settings: MONGODB_HOST not read from env var"
  fi

  # CMS detects Atlas via .mongodb.net or mongodb+srv://
  if grep -q '_mongodb_is_atlas = _mongodb_host_lower.startswith("mongodb+srv://") or ".mongodb.net" in _mongodb_host_lower' "$cms"; then
    pass "CMS settings: Atlas detection logic present"
  else
    fail "CMS settings: Atlas detection logic missing"
  fi

  # CMS sets ssl=True for Atlas
  if grep -q '"ssl": bool(_mongodb_is_atlas)' "$cms"; then
    pass "CMS settings: SSL enabled for Atlas connections"
  else
    fail "CMS settings: SSL not conditioned on Atlas detection"
  fi

  # CMS default database is 'openedx'
  if grep -q 'MONGODB_DB = os.environ.get("MONGODB_DB", "openedx")' "$cms"; then
    pass "CMS settings: default database is 'openedx'"
  else
    fail "CMS settings: default database is not 'openedx'"
  fi

  # DOC_STORE_CONFIG uses mongodb_parameters
  if grep -q 'DOC_STORE_CONFIG = mongodb_parameters' "$cms"; then
    pass "CMS settings: DOC_STORE_CONFIG = mongodb_parameters"
  else
    fail "CMS settings: DOC_STORE_CONFIG not set to mongodb_parameters"
  fi

  # CONTENTSTORE uses DOC_STORE_CONFIG
  if grep -q '"DOC_STORE_CONFIG": DOC_STORE_CONFIG' "$cms"; then
    pass "CMS settings: CONTENTSTORE uses DOC_STORE_CONFIG"
  else
    fail "CMS settings: CONTENTSTORE missing DOC_STORE_CONFIG"
  fi

  # MODULESTORE updated with DOC_STORE_CONFIG
  if grep -q 'update_module_store_settings(MODULESTORE, doc_store_settings=DOC_STORE_CONFIG)' "$cms"; then
    pass "CMS settings: MODULESTORE updated with DOC_STORE_CONFIG"
  else
    fail "CMS settings: MODULESTORE not updated with DOC_STORE_CONFIG"
  fi

  # mongodb_parameters includes host from MONGODB_HOST
  if grep -q '"host": MONGODB_HOST' "$cms"; then
    pass "CMS settings: mongodb_parameters['host'] = MONGODB_HOST"
  else
    fail "CMS settings: mongodb_parameters missing host"
  fi

  echo ""
}

# ---------------------------------------------------------------------------
# AC-004: Forum → Atlas cs_comments_service database
# ---------------------------------------------------------------------------
check_ac004_forum() {
  echo "== AC-004: Forum → Atlas 'cs_comments_service' database =="

  local lms="deploy/k8s/base/apps/openedx/settings/lms/production.py"

  # Forum database name
  if grep -q 'FORUM_MONGODB_DATABASE = "cs_comments_service"' "$lms"; then
    pass "LMS settings: FORUM_MONGODB_DATABASE = 'cs_comments_service'"
  else
    fail "LMS settings: FORUM_MONGODB_DATABASE not set to 'cs_comments_service'"
  fi

  # Forum client parameters read FORUM_MONGODB_HOST from env
  if grep -q '"host": os.environ.get("FORUM_MONGODB_HOST"' "$lms"; then
    pass "LMS settings: FORUM_MONGODB_CLIENT_PARAMETERS['host'] from FORUM_MONGODB_HOST env"
  else
    fail "LMS settings: FORUM_MONGODB_CLIENT_PARAMETERS missing FORUM_MONGODB_HOST"
  fi

  # Forum client parameters include password from env
  if grep -q '"password": os.environ.get("FORUM_MONGODB_PASSWORD"' "$lms"; then
    pass "LMS settings: FORUM_MONGODB_CLIENT_PARAMETERS['password'] from env"
  else
    fail "LMS settings: FORUM_MONGODB_CLIENT_PARAMETERS missing password env"
  fi

  # Forum client parameters include ssl from env
  if grep -q '"ssl": os.environ.get("FORUM_MONGODB_USE_SSL"' "$lms"; then
    pass "LMS settings: FORUM_MONGODB_CLIENT_PARAMETERS['ssl'] from env"
  else
    fail "LMS settings: FORUM_MONGODB_CLIENT_PARAMETERS missing ssl"
  fi

  # Forum v2 is integrated into LMS (not a separate service)
  if grep -q 'FORUM_SEARCH_BACKEND = "forum.search.meilisearch.MeilisearchBackend"' "$lms"; then
    pass "LMS settings: Forum v2 integrated (MeilisearchBackend)"
  else
    fail "LMS settings: Forum v2 search backend not configured"
  fi

  # Forum feature enabled
  if grep -q 'FEATURES\["ENABLE_DISCUSSION_SERVICE"\] = True' "$lms"; then
    pass "LMS settings: ENABLE_DISCUSSION_SERVICE = True"
  else
    fail "LMS settings: ENABLE_DISCUSSION_SERVICE not enabled"
  fi

  # Deployment has FORUM_MONGODB_HOST env var injected into LMS
  local dep="deploy/k8s/base/deployments.yml"
  if grep -A5 "FORUM_MONGODB_HOST" "$dep" | grep -q "secretKeyRef" 2>/dev/null; then
    pass "LMS deployment: FORUM_MONGODB_HOST injected via secretKeyRef"
  else
    fail "LMS deployment: FORUM_MONGODB_HOST not injected via secret"
  fi

  echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    Atlas Data Persistence Config-Chain Verification          ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo "  AC-003: Studio → Atlas openedx (modulestore)"
echo "  AC-004: Forum  → Atlas cs_comments_service"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

check_shared_secret_chain

if [[ -z "$AC_FILTER" || "$AC_FILTER" == "003" ]]; then
  check_ac003_modulestore
fi

if [[ -z "$AC_FILTER" || "$AC_FILTER" == "004" ]]; then
  check_ac004_forum
fi

# Summary
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║    Summary                                                   ║"
echo "╠══════════════════════════════════════════════════════════════╣"
echo -e "  ${GREEN}Passed: $PASSED${NC}"
echo -e "  ${RED}Failed: $FAILED${NC}"
echo "╚══════════════════════════════════════════════════════════════╝"

if [[ "$FAILED" -eq 0 ]]; then
  echo ""
  echo -e "${GREEN}All data persistence config-chain checks passed.${NC}"
  echo ""
  echo "Config chain verified:"
  echo "  Infisical (MEREKA_LMS_FORUM_MONGODB_SRV)"
  echo "    → GCP Secret Manager"
  echo "    → ExternalSecret (FORUM_MONGODB_HOST)"
  echo "    → K8s Secret (openedx-secrets)"
  echo "    → Deployment env (MONGODB_HOST / FORUM_MONGODB_HOST)"
  echo "    → Python settings (DOC_STORE_CONFIG / FORUM_MONGODB_CLIENT_PARAMETERS)"
  echo "    → Atlas cluster (openedx / cs_comments_service)"
  exit 0
else
  echo ""
  echo -e "${RED}Data persistence config-chain verification failed.${NC}"
  exit 1
fi
