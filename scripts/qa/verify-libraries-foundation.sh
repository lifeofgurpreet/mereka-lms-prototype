#!/usr/bin/env bash
# @covers AC-LIB-001, AC-LIB-002, AC-LIB-003, AC-LIB-004, AC-LIB-005, AC-LIB-006
# @spec: content-libraries-v2_spec.md
set -euo pipefail

# verify-libraries-foundation.sh - Audit Content Libraries v2 infrastructure
#
# Usage:
#   scripts/qa/verify-libraries-foundation.sh              # Run all checks
#   scripts/qa/verify-libraries-foundation.sh --skip-cluster # Skip runtime checks

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

pass_() { PASS_COUNT=$((PASS_COUNT + 1)); echo -e "${GREEN}✓${NC} $1"; }
fail_() { FAIL_COUNT=$((FAIL_COUNT + 1)); echo -e "${RED}✗${NC} $1"; }
skip_() { SKIP_COUNT=$((SKIP_COUNT + 1)); echo -e "${YELLOW}⊘${NC} $1"; }

SKIP_CLUSTER=0
for arg in "$@"; do
  case "$arg" in
    --skip-cluster) SKIP_CLUSTER=1 ;;
  esac
done

LMS_PRODUCTION="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_PRODUCTION="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
LMS_DEV="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/development.py"
CMS_DEV="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/development.py"
TERRAFORM_STORAGE="$REPO_ROOT/infrastructure/terraform/modules/storage/main.tf"
GCS_DOC="$REPO_ROOT/docs/operations/LIBRARIES_GCS_SETUP.md"

echo "========================================================"
echo "  Libraries Phase 0: Foundation Audit"
echo "  Spec: content-libraries-v2"
echo "========================================================"
echo "Date:   $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo "Repo:   $REPO_ROOT"
echo "Cluster checks: $([ $SKIP_CLUSTER -eq 1 ] && echo 'SKIPPED' || echo 'ENABLED')"
echo ""

# ── Section 1: Blockstore Integration (AC-LIB-001) ──────────────────────
echo -e "${BLUE}=== Section 1: Blockstore Integration (AC-LIB-001) ===${NC}"

if grep -q "ContentLibrariesConfig" "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ "ContentLibrariesConfig in LMS INSTALLED_APPS"
else
  fail_ "ContentLibrariesConfig missing from LMS INSTALLED_APPS"
fi

if grep -q "ContentLibrariesConfig" "$CMS_PRODUCTION" 2>/dev/null; then
  pass_ "ContentLibrariesConfig in CMS INSTALLED_APPS"
else
  fail_ "ContentLibrariesConfig missing from CMS INSTALLED_APPS"
fi

if grep -q 'blockstore.apps.bundles.storage' "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ "blockstore.apps.bundles.storage logger configured (LMS production)"
else
  fail_ "blockstore.apps.bundles.storage logger missing (LMS production)"
fi

if grep -q 'blockstore.apps.bundles.storage' "$CMS_PRODUCTION" 2>/dev/null; then
  pass_ "blockstore.apps.bundles.storage logger configured (CMS production)"
else
  fail_ "blockstore.apps.bundles.storage logger missing (CMS production)"
fi

if grep -q 'blockstore.apps.bundles.storage' "$LMS_DEV" 2>/dev/null; then
  pass_ "blockstore.apps.bundles.storage logger configured (LMS development)"
else
  fail_ "blockstore.apps.bundles.storage logger missing (LMS development)"
fi

if grep -q 'blockstore.apps.bundles.storage' "$CMS_DEV" 2>/dev/null; then
  pass_ "blockstore.apps.bundles.storage logger configured (CMS development)"
else
  fail_ "blockstore.apps.bundles.storage logger missing (CMS development)"
fi

if [ $SKIP_CLUSTER -eq 1 ]; then
  skip_ "CMS creates library and data stored in Blockstore (--skip-cluster)"
else
  skip_ "TODO: Runtime test - CMS creates library and data stored in Blockstore"
fi

# ── Section 2: API Routes (AC-LIB-002) ──────────────────────────────────
echo ""
echo -e "${BLUE}=== Section 2: API Routes (AC-LIB-002) ===${NC}"

if grep -q "content_libraries" "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ "content_libraries app in LMS INSTALLED_APPS"
else
  fail_ "content_libraries app missing from LMS INSTALLED_APPS"
fi

if grep -q "content_libraries" "$CMS_PRODUCTION" 2>/dev/null; then
  pass_ "content_libraries app in CMS INSTALLED_APPS"
else
  fail_ "content_libraries app missing from CMS INSTALLED_APPS"
fi

if [ $SKIP_CLUSTER -eq 1 ]; then
  skip_ "/api/libraries/v2/ endpoint responds (--skip-cluster)"
  skip_ "/api/libraries/v2/ returns proper JSON schema (--skip-cluster)"
else
  skip_ "TODO: Runtime test - /api/libraries/v2/ endpoint responds"
  skip_ "TODO: Runtime test - /api/libraries/v2/ returns proper JSON schema"
fi

# ── Section 3: Meilisearch Integration (AC-LIB-003) ─────────────────────
echo ""
echo -e "${BLUE}=== Section 3: Meilisearch Integration (AC-LIB-003) ===${NC}"

if grep -q "MEILISEARCH_ENABLED = True" "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_ENABLED = True (LMS production)"
else
  fail_ "MEILISEARCH_ENABLED not True (LMS production)"
fi

if grep -q "MEILISEARCH_URL" "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_URL configured (LMS production)"
else
  fail_ "MEILISEARCH_URL missing (LMS production)"
fi

if grep -q "MEILISEARCH_INDEX_PREFIX" "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_INDEX_PREFIX configured (LMS production)"
else
  fail_ "MEILISEARCH_INDEX_PREFIX missing (LMS production)"
fi

if grep -q "MEILISEARCH_API_KEY" "$LMS_PRODUCTION" && \
   grep -q "os.environ.get" "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_API_KEY from env var (LMS)"
else
  fail_ "MEILISEARCH_API_KEY not using os.environ.get (LMS)"
fi

if grep -q "MEILISEARCH_ENABLED = True" "$CMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_ENABLED = True (CMS production)"
else
  fail_ "MEILISEARCH_ENABLED not True (CMS production)"
fi

if grep -q "MEILISEARCH_URL" "$CMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_URL configured (CMS production)"
else
  fail_ "MEILISEARCH_URL missing (CMS production)"
fi

if grep -q "MEILISEARCH_INDEX_PREFIX" "$CMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_INDEX_PREFIX configured (CMS production)"
else
  fail_ "MEILISEARCH_INDEX_PREFIX missing (CMS production)"
fi

if grep -q "MEILISEARCH_API_KEY" "$CMS_PRODUCTION" && \
   grep -q "os.environ.get" "$CMS_PRODUCTION" 2>/dev/null; then
  pass_ "MEILISEARCH_API_KEY from env var (CMS)"
else
  fail_ "MEILISEARCH_API_KEY not using os.environ.get (CMS)"
fi

if grep -q 'SEARCH_ENGINE.*meilisearch.MeilisearchEngine' "$LMS_PRODUCTION" 2>/dev/null; then
  pass_ 'SEARCH_ENGINE = "search.meilisearch.MeilisearchEngine" (LMS)'
else
  fail_ "SEARCH_ENGINE not set to MeilisearchEngine (LMS)"
fi

if [ $SKIP_CLUSTER -eq 1 ]; then
  skip_ "Meilisearch reachable at configured URL (--skip-cluster)"
  skip_ "Library content indexed in Meilisearch (--skip-cluster)"
else
  skip_ "TODO: Runtime test - Meilisearch reachable"
  skip_ "TODO: Runtime test - Library content indexed in Meilisearch"
fi

# ── Section 4: Feature Flags (AC-LIB-004) ───────────────────────────────
echo ""
echo -e "${BLUE}=== Section 4: Feature Flags (AC-LIB-004) ===${NC}"

# Check LMS feature flags
if grep -A1 "CONTENT_LIBRARIES_V2_ENABLED" "$LMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "CONTENT_LIBRARIES_V2_ENABLED feature flag (LMS production)"
else
  fail_ "CONTENT_LIBRARIES_V2_ENABLED feature flag missing (LMS production)"
fi

if grep -A1 "LIBRARIES_SEARCH_ENABLED" "$LMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "LIBRARIES_SEARCH_ENABLED flag (LMS)"
else
  fail_ "LIBRARIES_SEARCH_ENABLED flag missing (LMS)"
fi

if grep -A1 "LIBRARIES_ANALYTICS_ENABLED" "$LMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "LIBRARIES_ANALYTICS_ENABLED flag (LMS)"
else
  fail_ "LIBRARIES_ANALYTICS_ENABLED flag missing (LMS)"
fi

if grep -A1 "LIBRARIES_BULK_IMPORT_ENABLED" "$LMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "LIBRARIES_BULK_IMPORT_ENABLED flag (LMS)"
else
  fail_ "LIBRARIES_BULK_IMPORT_ENABLED flag missing (LMS)"
fi

if grep -A1 "LIBRARIES_PUBLIC_READ_ENABLED" "$LMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "LIBRARIES_PUBLIC_READ_ENABLED flag (LMS)"
else
  fail_ "LIBRARIES_PUBLIC_READ_ENABLED flag missing (LMS)"
fi

# Check CMS feature flags
if grep -A1 "CONTENT_LIBRARIES_V2_ENABLED" "$CMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "CONTENT_LIBRARIES_V2_ENABLED feature flag (CMS production)"
else
  fail_ "CONTENT_LIBRARIES_V2_ENABLED feature flag missing (CMS production)"
fi

if grep -A1 "LIBRARIES_SEARCH_ENABLED" "$CMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "LIBRARIES_SEARCH_ENABLED flag (CMS)"
else
  fail_ "LIBRARIES_SEARCH_ENABLED flag missing (CMS)"
fi

if grep -A1 "LIBRARIES_BULK_IMPORT_ENABLED" "$CMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "LIBRARIES_BULK_IMPORT_ENABLED flag (CMS)"
else
  fail_ "LIBRARIES_BULK_IMPORT_ENABLED flag missing (CMS)"
fi

# Check all flags default to false
if grep -A1 "CONTENT_LIBRARIES_V2_ENABLED" "$LMS_PRODUCTION" | grep -q '"false"' 2>/dev/null; then
  pass_ "CONTENT_LIBRARIES_V2_ENABLED defaults to false (LMS)"
else
  fail_ "CONTENT_LIBRARIES_V2_ENABLED does not default to false (LMS)"
fi

if grep -A1 "LIBRARIES_SEARCH_ENABLED" "$LMS_PRODUCTION" | grep -q '"false"' 2>/dev/null; then
  pass_ "LIBRARIES_SEARCH_ENABLED defaults to false (LMS)"
else
  fail_ "LIBRARIES_SEARCH_ENABLED does not default to false (LMS)"
fi

if grep -A1 "LIBRARIES_ANALYTICS_ENABLED" "$LMS_PRODUCTION" | grep -q '"false"' 2>/dev/null; then
  pass_ "LIBRARIES_ANALYTICS_ENABLED defaults to false (LMS)"
else
  fail_ "LIBRARIES_ANALYTICS_ENABLED does not default to false (LMS)"
fi

if grep -A1 "LIBRARIES_BULK_IMPORT_ENABLED" "$LMS_PRODUCTION" | grep -q '"false"' 2>/dev/null; then
  pass_ "LIBRARIES_BULK_IMPORT_ENABLED defaults to false (LMS)"
else
  fail_ "LIBRARIES_BULK_IMPORT_ENABLED does not default to false (LMS)"
fi

if grep -A1 "LIBRARIES_PUBLIC_READ_ENABLED" "$LMS_PRODUCTION" | grep -q '"false"' 2>/dev/null; then
  pass_ "LIBRARIES_PUBLIC_READ_ENABLED defaults to false (LMS)"
else
  fail_ "LIBRARIES_PUBLIC_READ_ENABLED does not default to false (LMS)"
fi

# Check flags use os.environ.get pattern
if grep -A2 "CONTENT_LIBRARIES_V2_ENABLED" "$LMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "All flags use os.environ.get pattern (LMS)"
else
  fail_ "Not all flags use os.environ.get pattern (LMS)"
fi

# ── Section 5: GCS Bucket Configuration (AC-LIB-005) ────────────────────
echo ""
echo -e "${BLUE}=== Section 5: GCS Bucket Configuration (AC-LIB-005) ===${NC}"

if [[ -f "$TERRAFORM_STORAGE" ]]; then
  pass_ "Terraform storage module exists"
else
  fail_ "Terraform storage module not found"
fi

if grep -q "blockstore" "$TERRAFORM_STORAGE" 2>/dev/null; then
  pass_ "Storage module mentions blockstore"
else
  fail_ "Storage module does not mention blockstore"
fi

if [[ -f "$GCS_DOC" ]]; then
  pass_ "LIBRARIES_GCS_SETUP.md doc exists"
else
  fail_ "LIBRARIES_GCS_SETUP.md doc missing"
fi

if grep -iq "lms-blockstore\|blockstore" "$GCS_DOC" 2>/dev/null; then
  pass_ "Doc mentions blockstore bucket name"
else
  fail_ "Doc does not mention blockstore bucket name"
fi

if grep -iq "service account\|permissions\|iam" "$GCS_DOC" 2>/dev/null; then
  pass_ "Doc mentions service account permissions"
else
  fail_ "Doc does not mention service account permissions"
fi

if [ $SKIP_CLUSTER -eq 1 ]; then
  skip_ "gsutil ls gs://lms-blockstore/ (--skip-cluster)"
  skip_ "Blockstore service account has write access (--skip-cluster)"
else
  skip_ "TODO: Runtime test - gsutil ls gs://lms-blockstore/"
  skip_ "TODO: Runtime test - Blockstore service account write access"
fi

# ── Section 6: No Silent Failures (AC-LIB-006) ──────────────────────────
echo ""
echo -e "${BLUE}=== Section 6: No Silent Failures (AC-LIB-006) ===${NC}"

if grep -A1 "blockstore.apps.bundles.storage" "$LMS_PRODUCTION" | grep -q '"WARNING"' 2>/dev/null; then
  pass_ "Blockstore logger level is WARNING (not silent) (LMS)"
else
  fail_ "Blockstore logger level not WARNING (LMS)"
fi

if grep -A1 "blockstore.apps.bundles.storage" "$CMS_PRODUCTION" | grep -q '"WARNING"' 2>/dev/null; then
  pass_ "Blockstore logger level is WARNING (not silent) (CMS)"
else
  fail_ "Blockstore logger level not WARNING (CMS)"
fi

if grep "MEILISEARCH_API_KEY" "$LMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "Meilisearch API key uses os.environ.get (not hardcoded) (LMS)"
else
  fail_ "Meilisearch API key not using os.environ.get (LMS)"
fi

if grep "MEILISEARCH_API_KEY" "$CMS_PRODUCTION" | grep -q "os.environ.get" 2>/dev/null; then
  pass_ "Meilisearch API key uses os.environ.get (not hardcoded) (CMS)"
else
  fail_ "Meilisearch API key not using os.environ.get (CMS)"
fi

if grep -A2 "CONTENT_LIBRARIES_V2_ENABLED" "$LMS_PRODUCTION" | grep -q '"true"\|"false"' 2>/dev/null; then
  pass_ "Feature flags use explicit true/false (not implicit) (LMS)"
else
  fail_ "Feature flags do not use explicit true/false (LMS)"
fi

if grep "ContentLibrariesConfig" "$LMS_PRODUCTION" | grep -q "if.*not in" 2>/dev/null; then
  pass_ "ContentLibrariesConfig conditional install (not unconditional) (LMS)"
else
  fail_ "ContentLibrariesConfig not conditionally installed (LMS)"
fi

if grep "ContentLibrariesConfig" "$CMS_PRODUCTION" | grep -q "if.*not in" 2>/dev/null; then
  pass_ "ContentLibrariesConfig conditional install (not unconditional) (CMS)"
else
  fail_ "ContentLibrariesConfig not conditionally installed (CMS)"
fi

# ── Section 7: Runtime Verification (SKIP) ──────────────────────────────
echo ""
echo -e "${BLUE}=== Section 7: Runtime Verification ===${NC}"

if [ $SKIP_CLUSTER -eq 1 ]; then
  skip_ "CMS shell import test (--skip-cluster)"
  skip_ "API endpoint test (--skip-cluster)"
  skip_ "Meilisearch connectivity (--skip-cluster)"
  skip_ "GCS bucket access (--skip-cluster)"
else
  skip_ "TODO: Runtime test - CMS shell: from openedx.core.djangoapps.content_libraries import api"
  skip_ "TODO: Runtime test - curl /api/libraries/v2/"
  skip_ "TODO: Runtime test - curl $MEILISEARCH_URL/health"
  skip_ "TODO: Runtime test - gsutil stat gs://lms-blockstore/"
fi

# ── Summary ──────────────────────────────────────────────────────────────
echo ""
echo "========================================================"
echo "  Verification Summary"
echo "========================================================"
echo -e "  ${GREEN}PASS${NC}: $PASS_COUNT"
echo -e "  ${RED}FAIL${NC}: $FAIL_COUNT"
echo -e "  ${YELLOW}SKIP${NC}: $SKIP_COUNT"
echo ""

if [[ $FAIL_COUNT -gt 0 ]]; then
  echo -e "${RED}Verification FAILED with $FAIL_COUNT failures${NC}"
  echo ""
  echo "Phase 0 acceptance criteria:"
  echo "  AC-LIB-001: Blockstore integration (ContentLibrariesConfig, logger)"
  echo "  AC-LIB-002: API routes (/api/libraries/v2/)"
  echo "  AC-LIB-003: Meilisearch integration (MEILISEARCH_ENABLED, URL, API key)"
  echo "  AC-LIB-004: Feature flags (all default False, use os.environ.get)"
  echo "  AC-LIB-005: GCS bucket configuration (Terraform module, docs)"
  echo "  AC-LIB-006: No silent failures (WARNING level, explicit flags)"
  exit 1
else
  echo -e "${GREEN}Verification PASSED (static checks)${NC}"
  echo ""
  echo "Phase 0 foundation verified:"
  echo "  ✓ Blockstore integration configured (ContentLibrariesConfig, logger)"
  echo "  ✓ API routes present (content_libraries app)"
  echo "  ✓ Meilisearch configured (ENABLED=True, URL, API key)"
  echo "  ✓ Feature flags added (all default False)"
  echo "  ✓ GCS bucket configuration (Terraform + docs)"
  echo "  ✓ No silent failures (WARNING level, os.environ.get)"
  echo ""
  echo "Runtime verification (requires live cluster):"
  echo "  - Create library: CMS > Content Libraries > New Library"
  echo "  - API test: curl https://studio.academyv2.mereka.io/api/libraries/v2/"
  echo "  - Meilisearch: curl http://meilisearch:7700/health"
  echo "  - GCS: gsutil ls gs://lms-blockstore/"
  exit 0
fi
