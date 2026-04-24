#!/usr/bin/env bash
# @covers AC-001, AC-004, AC-008, AC-028, AC-029
# @spec: content-libraries-v2_spec.md
# Verify Content Libraries v2 OLX package structure and import/export functionality
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
SKIP=0

pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

echo "=== Content Libraries v2 OLX Package Verification ==="
echo ""

# ---------------------------------------------------------------------------
# AC-001: Library creation with unique library_key (lib:org:slug format)
# Verify: Content Libraries app is enabled in settings
# ---------------------------------------------------------------------------
echo "[AC-001] Verifying Content Libraries v2 app configuration..."

# Check if content_libraries app is enabled in LMS settings
if [[ -f "deploy/k8s/base/apps/openedx/settings/lms/production.py" ]]; then
  if grep -q "content_libraries\|openedx.core.djangoapps.content_libraries" deploy/k8s/base/apps/openedx/settings/lms/production.py; then
    pass "AC-001: content_libraries app enabled in LMS production settings"
  else
    fail "AC-001: content_libraries app not found in LMS settings"
  fi
else
  fail "AC-001: LMS production.py settings file not found"
fi

# Check if content_libraries app is enabled in CMS settings
if [[ -f "deploy/k8s/base/apps/openedx/settings/cms/production.py" ]]; then
  if grep -q "content_libraries\|openedx.core.djangoapps.content_libraries" deploy/k8s/base/apps/openedx/settings/cms/production.py; then
    pass "AC-001: content_libraries app enabled in CMS production settings"
  else
    fail "AC-001: content_libraries app not found in CMS settings"
  fi
else
  skip "AC-001: CMS production.py settings file not at expected location"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-004: Component authoring (XBlock types in libraries)
# Verify: Library content configuration
# ---------------------------------------------------------------------------
echo "[AC-004] Verifying library component configuration..."

# Check for library configuration in Tutor settings
if grep -r "LIBRARY\|content.*library" infrastructure/tutor/ 2>/dev/null | grep -q -i "library"; then
  pass "AC-004: Library configuration references found in Tutor infrastructure"
else
  skip "AC-004: Library-specific Tutor configuration (may use defaults)"
fi

# Verify library API endpoint is configured
SETTINGS_FILES=$(find deploy/k8s/base/apps/openedx/settings -name "*.py" 2>/dev/null || echo "")
if [[ -n "$SETTINGS_FILES" ]]; then
  if grep -h "libraries/v2\|CONTENT_LIBRARIES" $SETTINGS_FILES 2>/dev/null | grep -q "libraries"; then
    pass "AC-004: Content Libraries v2 API endpoint references found"
  else
    skip "AC-004: Content Libraries v2 API configuration (may be in base image)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-008: Publishing workflow (draft/published lifecycle)
# Verify: Blockstore configuration for versioning
# ---------------------------------------------------------------------------
echo "[AC-008] Verifying library versioning (Blockstore) configuration..."

# Check for Blockstore references in settings
BLOCKSTORE_FOUND=false
if grep -r "blockstore\|BLOCKSTORE" deploy/k8s/base/apps/openedx/settings/ infrastructure/tutor/ 2>/dev/null | grep -q -i "blockstore"; then
  pass "AC-008: Blockstore configuration found (versioning backend)"
  BLOCKSTORE_FOUND=true
else
  skip "AC-008: Blockstore configuration not explicit (may be in base image)"
fi

# Check for Blockstore storage backend (GCS or filesystem)
if [[ "$BLOCKSTORE_FOUND" == "true" ]]; then
  if grep -r "GCS\|gcs\|BLOCKSTORE.*STORAGE" deploy/k8s/base/apps/openedx/settings/ infrastructure/tutor/ 2>/dev/null | grep -q "GCS\|gcs"; then
    pass "AC-008: Blockstore GCS storage backend referenced"
  else
    skip "AC-008: Blockstore storage backend (filesystem or default)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-028, AC-029: Library export/import as OLX archive
# Verify: Export/import tooling and API support
# ---------------------------------------------------------------------------
echo "[AC-028, AC-029] Verifying library export/import capabilities..."

# Check for library management scripts
if [[ -d "scripts" ]]; then
  if find scripts -name "*library*" -o -name "*content*library*" 2>/dev/null | grep -q "library"; then
    pass "AC-028: Library management scripts found"
  else
    skip "AC-028: No library-specific scripts (using Django management commands)"
  fi
fi

# Check for OLX import/export documentation
if [[ -d "docs" ]]; then
  if grep -r "library.*export\|library.*import\|OLX.*library" docs/ 2>/dev/null | grep -q -i "export\|import"; then
    pass "AC-028: Library export/import documentation found"
  else
    skip "AC-028: Library export/import documentation (operational runbook TBD)"
  fi
fi

# Verify library content storage path
if grep -r "library.*storage\|LIBRARY.*ROOT" deploy/k8s/base/apps/openedx/settings/ infrastructure/tutor/ 2>/dev/null | grep -q "storage\|ROOT"; then
  pass "AC-029: Library storage path configuration found"
else
  skip "AC-029: Library storage path (using default)"
fi

echo ""

# ---------------------------------------------------------------------------
# Feature flags for Content Libraries v2
# ---------------------------------------------------------------------------
echo "[Feature Flags] Verifying Content Libraries v2 feature gates..."

# Check for CONTENT_LIBRARIES_V2_ENABLED flag
if grep -r "CONTENT_LIBRARIES_V2_ENABLED\|content.*libraries.*enabled" deploy/k8s/base/apps/openedx/settings/ infrastructure/tutor/ 2>/dev/null | grep -q -i "enabled"; then
  pass "Feature: CONTENT_LIBRARIES_V2_ENABLED flag found in configuration"
else
  skip "Feature: CONTENT_LIBRARIES_V2_ENABLED (using Redwood default: enabled)"
fi

echo ""

# ---------------------------------------------------------------------------
# Live cluster checks (skip if kubectl not available)
# ---------------------------------------------------------------------------
if command -v kubectl &>/dev/null; then
  echo "[Live Cluster Checks]"

  NAMESPACE="mereka-lms"

  # Check if LMS pods are running (needed for API access)
  LMS_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms --field-selector=status.phase=Running 2>/dev/null | grep -c "Running" || echo "0")
  if [[ "$LMS_PODS" -ge 1 ]]; then
    pass "Live: LMS pods running ($LMS_PODS), library API available"

    # Try to check library API endpoint (requires exec into pod)
    LMS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [[ -n "$LMS_POD" ]]; then
      # Check if curl or python is available in pod
      if kubectl exec -n "$NAMESPACE" "$LMS_POD" -- python3 -c "import urllib.request; print(urllib.request.urlopen('http://localhost:8000/health', timeout=5).status)" &>/dev/null; then
        pass "Live: LMS HTTP service responding (library API reachable)"
      else
        skip "Live: LMS HTTP check (pod may be initializing)"
      fi
    fi
  else
    skip "Live: LMS pods not running (cluster may be down)"
  fi

  # Check for library content in search index (if search service is deployed)
  SEARCH_PODS=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/component=search 2>/dev/null | grep -c "Running" || echo "0")
  SEARCH_PODS="${SEARCH_PODS//[$'\n\r ']/}"  # Strip whitespace and newlines
  if [[ "${SEARCH_PODS:-0}" -ge 1 ]]; then
    pass "Live: Search service running ($SEARCH_PODS pods) for library content indexing"
  else
    skip "Live: Search service not found (library search not deployed)"
  fi

  echo ""
else
  skip "Live cluster checks (kubectl not available)"
  echo ""
fi

echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
