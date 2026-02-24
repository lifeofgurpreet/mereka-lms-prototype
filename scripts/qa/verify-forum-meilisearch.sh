#!/usr/bin/env bash
# @covers T030
# @spec: forum-service-migration_spec.md
# Offline validation: Forum service Meilisearch dependency
# Checks config files and K8s manifests — no network connections made.
set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNINGS=0

check_pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASSED=$((PASSED + 1))
}

check_fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAILED=$((FAILED + 1))
}

check_warn() {
  echo -e "${YELLOW}WARN${NC}  $1"
  WARNINGS=$((WARNINGS + 1))
}

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo -e "${BOLD}Forum / Meilisearch Dependency Validation (offline)${NC}"
echo "Repository: $REPO_ROOT"
echo "────────────────────────────────────────────────────"
echo ""

# ── 1. Meilisearch Deployment manifest ───────────────────────────────────────
echo "[1/8] Meilisearch Deployment in base manifests..."
DEPLOY_FILE="$REPO_ROOT/deploy/k8s/base/deployments.yml"
if [ -f "$DEPLOY_FILE" ]; then
  if grep -q "name: meilisearch" "$DEPLOY_FILE" 2>/dev/null; then
    check_pass "Meilisearch Deployment found in deploy/k8s/base/deployments.yml"
  else
    check_fail "Meilisearch Deployment NOT found in deploy/k8s/base/deployments.yml"
  fi
else
  check_fail "deploy/k8s/base/deployments.yml not found"
fi

# ── 2. Meilisearch image pinned (not :latest) ─────────────────────────────────
echo "[2/8] Meilisearch image version pinned..."
if [ -f "$DEPLOY_FILE" ]; then
  if grep -E "getmeili/meilisearch:v[0-9]" "$DEPLOY_FILE" 2>/dev/null | grep -qv ":latest"; then
    VERSION=$(grep -Eo "getmeili/meilisearch:v[0-9][^ \"']*" "$DEPLOY_FILE" | head -1)
    check_pass "Meilisearch image pinned: $VERSION"
  else
    check_fail "Meilisearch image not pinned to a version tag (found :latest or no tag)"
  fi
else
  check_warn "deployments.yml not found, skipping image version check"
fi

# ── 3. Meilisearch Service manifest ──────────────────────────────────────────
echo "[3/8] Meilisearch Service in base manifests..."
SVC_FILE="$REPO_ROOT/deploy/k8s/base/services.yml"
if [ -f "$SVC_FILE" ]; then
  if grep -q "name: meilisearch" "$SVC_FILE" 2>/dev/null; then
    check_pass "Meilisearch Service found in deploy/k8s/base/services.yml"
  else
    check_fail "Meilisearch Service NOT found in deploy/k8s/base/services.yml"
  fi
else
  check_fail "deploy/k8s/base/services.yml not found"
fi

# ── 4. MEILISEARCH_URL in LMS Django settings ─────────────────────────────────
echo "[4/8] MEILISEARCH_URL in LMS production settings..."
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q "MEILISEARCH_URL" "$LMS_SETTINGS" 2>/dev/null; then
    URL=$(grep "MEILISEARCH_URL" "$LMS_SETTINGS" | head -1 | sed 's/.*= *//')
    check_pass "MEILISEARCH_URL set in LMS settings: $URL"
  else
    check_fail "MEILISEARCH_URL missing from deploy/k8s/base/apps/openedx/settings/lms/production.py"
  fi
else
  check_warn "LMS production.py not found at expected path"
fi

# ── 5. MEILISEARCH_API_KEY in LMS Django settings ─────────────────────────────
echo "[5/8] MEILISEARCH_API_KEY in LMS production settings..."
if [ -f "$LMS_SETTINGS" ]; then
  if grep -q "MEILISEARCH_API_KEY" "$LMS_SETTINGS" 2>/dev/null; then
    # Must use os.environ, not a hardcoded literal
    if grep "MEILISEARCH_API_KEY" "$LMS_SETTINGS" | grep -q "os.environ"; then
      check_pass "MEILISEARCH_API_KEY sourced from os.environ in LMS settings"
    else
      check_warn "MEILISEARCH_API_KEY found but may be hardcoded — verify it uses os.environ.get()"
    fi
  else
    check_fail "MEILISEARCH_API_KEY missing from LMS production settings"
  fi
else
  check_warn "LMS production.py not found, skipping API key check"
fi

# ── 6. ExternalSecret maps MEREKA_LMS_MEILISEARCH_* keys ─────────────────────
echo "[6/8] ExternalSecret mappings for Meilisearch secrets..."
ES_FILE="$REPO_ROOT/deploy/k8s/base/secrets/external-secrets.yaml"
if [ -f "$ES_FILE" ]; then
  MASTER_KEY_FOUND=false
  API_KEY_FOUND=false

  if grep -q "MEREKA_LMS_MEILISEARCH_MASTER_KEY" "$ES_FILE" 2>/dev/null; then
    MASTER_KEY_FOUND=true
  fi
  if grep -q "MEREKA_LMS_MEILISEARCH_API_KEY" "$ES_FILE" 2>/dev/null; then
    API_KEY_FOUND=true
  fi

  if $MASTER_KEY_FOUND && $API_KEY_FOUND; then
    check_pass "ExternalSecret maps MEREKA_LMS_MEILISEARCH_MASTER_KEY and MEREKA_LMS_MEILISEARCH_API_KEY"
  elif $API_KEY_FOUND; then
    check_warn "MEREKA_LMS_MEILISEARCH_API_KEY mapped but MEREKA_LMS_MEILISEARCH_MASTER_KEY missing"
  else
    check_fail "ExternalSecret missing MEREKA_LMS_MEILISEARCH_* mappings"
  fi
else
  check_fail "deploy/k8s/base/secrets/external-secrets.yaml not found"
fi

# ── 7. Tutor config / apply-patches.sh reference Meilisearch ─────────────────
echo "[7/8] Meilisearch reference in Tutor configuration..."
PATCHES_FILE="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
TUTOR_CONFIG="$REPO_ROOT/tutor_env/config.yml"
MEILI_IN_TUTOR=false

if [ -f "$PATCHES_FILE" ]; then
  if grep -qi "meilisearch" "$PATCHES_FILE" 2>/dev/null; then
    MEILI_IN_TUTOR=true
  fi
fi
if [ -f "$TUTOR_CONFIG" ]; then
  if grep -qi "meilisearch" "$TUTOR_CONFIG" 2>/dev/null; then
    MEILI_IN_TUTOR=true
  fi
fi

if $MEILI_IN_TUTOR; then
  check_pass "Meilisearch referenced in Tutor config or apply-patches.sh"
else
  check_warn "Meilisearch not found in apply-patches.sh or tutor_env/config.yml (tutor_env/ may be gitignored)"
fi

# ── 8. No hardcoded Meilisearch API key value in tracked files ────────────────
echo "[8/8] No hardcoded Meilisearch API key in tracked config files..."
HARDCODED=false
for f in \
  "$REPO_ROOT/deploy/k8s/base/deployments.yml" \
  "$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py" \
  "$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"; do
  if [ -f "$f" ]; then
    # Flag a literal key assignment longer than 16 chars that is not an env lookup
    if grep -E "MEILISEARCH_API_KEY\s*=\s*['\"][a-f0-9]{16,}['\"]" "$f" 2>/dev/null; then
      check_fail "Hardcoded Meilisearch API key found in: $f"
      HARDCODED=true
    fi
  fi
done
if ! $HARDCODED; then
  check_pass "No hardcoded Meilisearch API key values in tracked config files"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "────────────────────────────────────────────────────"
echo -e "${BOLD}Summary${NC}"
echo -e "  ${GREEN}PASS${NC}  $PASSED"
echo -e "  ${RED}FAIL${NC}  $FAILED"
echo -e "  ${YELLOW}WARN${NC}  $WARNINGS"
echo ""

if [ "$FAILED" -eq 0 ]; then
  if [ "$WARNINGS" -gt 0 ]; then
    echo -e "${YELLOW}CONFIGURED (with warnings)${NC} — Forum Meilisearch dependency is present."
    echo "  Review warnings above; they may indicate optional config that is missing."
  else
    echo -e "${GREEN}CONFIGURED${NC} — Forum Meilisearch dependency fully validated."
  fi
  echo ""
  echo "Meilisearch deployment summary:"
  echo "  Image  : docker.io/getmeili/meilisearch:v1.8.4"
  echo "  Service: meilisearch.mereka-lms.svc.cluster.local:7700"
  echo "  Secrets: MEREKA_LMS_MEILISEARCH_MASTER_KEY / MEREKA_LMS_MEILISEARCH_API_KEY"
  echo "  Doc    : docs/operations/FORUM_MEILISEARCH.md"
  exit 0
else
  echo -e "${RED}NOT CONFIGURED${NC} — Forum Meilisearch dependency has gaps."
  echo ""
  echo "Fix guidance:"
  echo "  Deployment missing  : Add Meilisearch Deployment/Service to deploy/k8s/base/"
  echo "  Settings missing    : Add MEILISEARCH_URL/API_KEY to lms/production.py"
  echo "  ExternalSecret gap  : Map MEREKA_LMS_MEILISEARCH_* in external-secrets.yaml"
  echo "  Full doc            : docs/operations/FORUM_MEILISEARCH.md"
  exit 1
fi
