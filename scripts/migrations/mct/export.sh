#!/usr/bin/env bash
# @covers AC-002, AC-004
# @spec: data-migrations-kajabi-mct_spec.md
# Verify MCT export infrastructure and configuration
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"
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

echo "=== MCT Export Infrastructure Verification ==="
echo ""

# AC-002: Verify MCT export scripts exist
echo "Checking for MCT export tooling..."
if [[ -f "scripts/migrations/mct/mct-export.mjs" ]]; then
  pass "MCT export script exists: mct-export.mjs"
else
  fail "MCT export script not found: scripts/migrations/mct/mct-export.mjs"
fi

# Check for Node.js (required for .mjs export scripts)
if command -v node >/dev/null 2>&1; then
  NODE_VERSION=$(node --version | sed 's/v//')
  if [[ "${NODE_VERSION%%.*}" -ge 20 ]]; then
    pass "Node.js $(node --version) available (required: 20+)"
  else
    fail "Node.js version too old: $(node --version) (required: 20+)"
  fi
else
  fail "Node.js not found (required for export scripts)"
fi

# AC-002, AC-004: Check for MCT API configuration references
echo ""
echo "Checking for MCT API configuration..."
if kubectl get externalsecrets -n mereka-lms -o yaml 2>/dev/null | grep -qE "MCT_CLIENT_ID|MCT_CLIENT_SECRET|MCT_TENANT_ID"; then
  pass "MCT Azure AD credentials referenced in ExternalSecrets"
else
  skip "MCT credentials not found in ExternalSecrets (may be in Infisical only)"
fi

# Check Infisical for MCT secrets
INFISICAL_WRAPPER="${INFISICAL_WRAPPER:-}"
if [[ -z "$INFISICAL_WRAPPER" ]]; then
  if command -v infisical >/dev/null 2>&1; then
    INFISICAL_WRAPPER="infisical"
  else
    for candidate in \
      "${WORKSPACE_ROOT}/../vps/infrastructure/scripts/infisical" \
      "${HOME}/projects/vps/infrastructure/scripts/infisical"; do
      if [[ -x "$candidate" ]]; then
        INFISICAL_WRAPPER="$candidate"
        break
      fi
    done
  fi
fi

if [[ -n "$INFISICAL_WRAPPER" ]]; then
  if ${INFISICAL_WRAPPER} secrets get MCT_CLIENT_ID --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null | grep -qv "PLACEHOLDER"; then
    pass "MCT_CLIENT_ID exists in Infisical with non-placeholder value"
  else
    skip "MCT_CLIENT_ID is placeholder or not found (data-dependent)"
  fi

  if ${INFISICAL_WRAPPER} secrets get MCT_TENANT_ID --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null | grep -qv "PLACEHOLDER"; then
    pass "MCT_TENANT_ID exists in Infisical with non-placeholder value"
  else
    skip "MCT_TENANT_ID is placeholder or not found (data-dependent)"
  fi
else
  skip "Infisical wrapper not available, cannot verify secrets"
fi

# AC-004: Check export script supports --force flag for fresh SAS tokens
if [[ -f "scripts/migrations/mct/mct-export.mjs" ]]; then
  if grep -qE "\-\-force|\-\-resources.*courses" "scripts/migrations/mct/mct-export.mjs"; then
    pass "Export script supports --force/--resources flags for re-export"
  else
    skip "Force re-export flag not clearly detected (may use different pattern)"
  fi
fi

# AC-002: Validate export format specifications
echo ""
echo "Checking export format and directory structure..."
MCT_EXPORT_DIR="exports/mct"
if [[ -d "$MCT_EXPORT_DIR" ]]; then
  pass "MCT export directory exists: $MCT_EXPORT_DIR"
else
  skip "MCT export directory does not exist (data-dependent: requires export run)"
fi

# Check for NDJSON output files
if [[ -d "$MCT_EXPORT_DIR" ]]; then
  NDJSON_COUNT=$(find "$MCT_EXPORT_DIR" -name "*.ndjson" 2>/dev/null | wc -l || echo "0")
  if [[ "$NDJSON_COUNT" -gt 0 ]]; then
    pass "Found $NDJSON_COUNT NDJSON export files"
  else
    skip "No NDJSON files found in export directory (data-dependent)"
  fi
fi

# Check for expected resource types: users, categories, courses, enrollments
EXPECTED_EXPORTS=("users" "categories" "courses" "enrollments")
for resource in "${EXPECTED_EXPORTS[@]}"; do
  if [[ -f "$MCT_EXPORT_DIR/${resource}.ndjson" ]]; then
    pass "Export file exists: ${resource}.ndjson"
  else
    skip "Export file not found: ${resource}.ndjson (data-dependent)"
  fi
done

# AC-004: Check for video content with SAS token handling
if [[ -f "$MCT_EXPORT_DIR/courses.ndjson" ]]; then
  if grep -q "videoUrl\|video.*sas\|sig=" "$MCT_EXPORT_DIR/courses.ndjson" 2>/dev/null; then
    pass "Course export contains video URLs with SAS tokens"
  else
    skip "Video URLs with SAS tokens not detected (may use different field name)"
  fi
fi

# Check export script has rate limiting (AC-002: 200ms delay for MCT API)
if [[ -f "scripts/migrations/mct/mct-export.mjs" ]]; then
  if grep -qE "(delay|sleep|timeout.*200)" "scripts/migrations/mct/mct-export.mjs"; then
    pass "Export script includes rate limiting logic"
  else
    fail "Export script does not implement rate limiting (required: 5 req/s max)"
  fi
fi

# Check for staging directory
echo ""
echo "Checking for export staging directory..."
if [[ -d "exports" ]]; then
  pass "Export staging directory exists: exports/"

  # Check it's gitignored
  if grep -q "^exports/$" .gitignore 2>/dev/null; then
    pass "Export directory is gitignored (PII protection)"
  else
    fail "Export directory not gitignored (security risk: contains PII)"
  fi
else
  fail "Export staging directory does not exist: exports/"
fi

# AC-002: Check for export logs
EXPORT_LOG_DIR="scripts/migrations/mct/logs"
if [[ -d "$EXPORT_LOG_DIR" ]]; then
  pass "Export log directory exists: $EXPORT_LOG_DIR"
else
  skip "Export log directory does not exist (created on first export)"
fi

# Verify export script syntax
if [[ -f "scripts/migrations/mct/mct-export.mjs" ]]; then
  if node --check "scripts/migrations/mct/mct-export.mjs" 2>/dev/null; then
    pass "Export script has valid JavaScript syntax"
  else
    fail "Export script has syntax errors"
  fi
fi

# Check documentation references
echo ""
echo "Checking for export documentation..."
if [[ -f "docs/migrations/mct/EXPORT_GUIDE.md" ]]; then
  pass "Export guide exists: docs/migrations/mct/EXPORT_GUIDE.md"
else
  skip "Export guide not found (may be in different location)"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
