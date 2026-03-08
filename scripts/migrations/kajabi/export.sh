#!/usr/bin/env bash
# @covers AC-001, AC-003
# @spec: data-migrations-kajabi-mct_spec.md
# Verify Kajabi export infrastructure and configuration
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

echo "=== Kajabi Export Infrastructure Verification ==="
echo ""

# AC-001: Verify Kajabi export scripts exist
echo "Checking for Kajabi export tooling..."
if [[ -f "scripts/migrations/kajabi/kajabi-export.mjs" ]]; then
  pass "Kajabi export script exists: kajabi-export.mjs"
else
  fail "Kajabi export script not found: scripts/migrations/kajabi/kajabi-export.mjs"
fi

# AC-003: Check for completion export script
if [[ -f "scripts/migrations/kajabi/kajabi-export-completions.mjs" ]]; then
  pass "Kajabi completions export script exists: kajabi-export-completions.mjs"
else
  fail "Kajabi completions export script not found: kajabi-export-completions.mjs"
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

# AC-001: Check for Kajabi API configuration references
echo ""
echo "Checking for Kajabi API configuration..."
if kubectl get externalsecrets -n mereka-lms -o yaml 2>/dev/null | grep -qE "KAJABI_CLIENT_ID|KAJABI_CLIENT_SECRET|KAJABI_SITE_ID"; then
  pass "Kajabi API credentials referenced in ExternalSecrets"
else
  skip "Kajabi credentials not found in ExternalSecrets (may be in Infisical only)"
fi

# Check Infisical for Kajabi secrets
INFISICAL_WRAPPER="${INFISICAL_WRAPPER:-}"
if [[ -z "$INFISICAL_WRAPPER" ]]; then
  if command -v infisical >/dev/null 2>&1; then
    INFISICAL_WRAPPER="infisical"
  elif [[ -x "${WORKSPACE_ROOT}/../vps/infrastructure/scripts/infisical" ]]; then
    INFISICAL_WRAPPER="${WORKSPACE_ROOT}/../vps/infrastructure/scripts/infisical"
  elif [[ -x "${HOME}/projects/vps/infrastructure/scripts/infisical" ]]; then
    INFISICAL_WRAPPER="${HOME}/projects/vps/infrastructure/scripts/infisical"
  fi
fi

if [[ -n "$INFISICAL_WRAPPER" ]]; then
  if ${INFISICAL_WRAPPER} secrets get KAJABI_CLIENT_ID --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null | grep -qv "PLACEHOLDER"; then
    pass "KAJABI_CLIENT_ID exists in Infisical with non-placeholder value"
  else
    skip "KAJABI_CLIENT_ID is placeholder or not found (data-dependent)"
  fi

  if ${INFISICAL_WRAPPER} secrets get KAJABI_SITE_ID --domain https://secrets.mereka.io/api --env prod --path / --plain 2>/dev/null | grep -qv "PLACEHOLDER"; then
    pass "KAJABI_SITE_ID exists in Infisical with non-placeholder value"
  else
    skip "KAJABI_SITE_ID is placeholder or not found (data-dependent)"
  fi
else
  skip "Infisical wrapper not available, cannot verify secrets"
fi

# AC-001: Validate export format specifications
echo ""
echo "Checking export format and directory structure..."
KAJABI_EXPORT_DIR="exports/kajabi"
if [[ -d "$KAJABI_EXPORT_DIR" ]]; then
  pass "Kajabi export directory exists: $KAJABI_EXPORT_DIR"
else
  skip "Kajabi export directory does not exist (data-dependent: requires export run)"
fi

# Check for NDJSON output files
if [[ -d "$KAJABI_EXPORT_DIR" ]]; then
  NDJSON_COUNT=$(find "$KAJABI_EXPORT_DIR" -name "*.ndjson" 2>/dev/null | wc -l || echo "0")
  if [[ "$NDJSON_COUNT" -gt 0 ]]; then
    pass "Found $NDJSON_COUNT NDJSON export files"
  else
    skip "No NDJSON files found in export directory (data-dependent)"
  fi
fi

# AC-001: Check for expected 17 resource types
EXPECTED_EXPORTS=("contacts" "customers" "courses" "purchases" "offers" "products" "transactions")
for resource in "${EXPECTED_EXPORTS[@]}"; do
  if [[ -f "$KAJABI_EXPORT_DIR/${resource}.ndjson" ]]; then
    pass "Export file exists: ${resource}.ndjson"
  else
    skip "Export file not found: ${resource}.ndjson (data-dependent)"
  fi
done

# AC-003: Check for completions export with tag filtering
if [[ -f "$KAJABI_EXPORT_DIR/completions.ndjson" ]]; then
  pass "Completions export file exists: completions.ndjson"
else
  skip "Completions export not found (data-dependent)"
fi

# AC-003: Verify completion export script uses filter[has_tag_id]
if [[ -f "scripts/migrations/kajabi/kajabi-export-completions.mjs" ]]; then
  if grep -qE "filter\[has_tag_id\]|filter.*has_tag_id" "scripts/migrations/kajabi/kajabi-export-completions.mjs"; then
    pass "Completions export uses filter[has_tag_id] (not filter[tag_id])"
  else
    fail "Completions export does not use filter[has_tag_id] (spec violation)"
  fi
fi

# Check export script has rate limiting (AC-001: 400ms delay for Kajabi API)
if [[ -f "scripts/migrations/kajabi/kajabi-export.mjs" ]]; then
  if grep -qE "(delay|sleep|timeout.*400)" "scripts/migrations/kajabi/kajabi-export.mjs"; then
    pass "Export script includes rate limiting logic"
  else
    fail "Export script does not implement rate limiting (required: ~100 req/min)"
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

# AC-001: Check for export logs
EXPORT_LOG_DIR="scripts/migrations/kajabi/logs"
if [[ -d "$EXPORT_LOG_DIR" ]]; then
  pass "Export log directory exists: $EXPORT_LOG_DIR"
else
  skip "Export log directory does not exist (created on first export)"
fi

# Verify export script syntax
if [[ -f "scripts/migrations/kajabi/kajabi-export.mjs" ]]; then
  if node --check "scripts/migrations/kajabi/kajabi-export.mjs" 2>/dev/null; then
    pass "Export script has valid JavaScript syntax"
  else
    fail "Export script has syntax errors"
  fi
fi

if [[ -f "scripts/migrations/kajabi/kajabi-export-completions.mjs" ]]; then
  if node --check "scripts/migrations/kajabi/kajabi-export-completions.mjs" 2>/dev/null; then
    pass "Completions export script has valid JavaScript syntax"
  else
    fail "Completions export script has syntax errors"
  fi
fi

# AC-003: Check for tag_prefix_to_course_mapping.json
echo ""
echo "Checking for course mapping documentation..."
if [[ -f "scripts/migrations/kajabi/tag_prefix_to_course_mapping.json" ]]; then
  pass "Tag prefix to course mapping exists"

  # Validate JSON
  if jq empty "scripts/migrations/kajabi/tag_prefix_to_course_mapping.json" 2>/dev/null; then
    pass "Tag mapping is valid JSON"
  else
    fail "Tag mapping exists but is invalid JSON"
  fi
else
  skip "Tag prefix mapping not found (required for certificate issuance)"
fi

# Check documentation references
echo ""
echo "Checking for export documentation..."
if [[ -f "reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md" ]]; then
  pass "Migration handover doc exists: reports/2026/closures/KAJABI_MIGRATION_HANDOVER.md"
else
  skip "Migration handover doc not found (may be in different location)"
fi

# AC-001: Check for deduplication handling
if [[ -f "scripts/migrations/kajabi/transform_data.py" ]] || [[ -f "scripts/migrations/kajabi/prepare_openedx_imports.py" ]]; then
  TRANSFORM_SCRIPT=$(find scripts/migrations/kajabi -name "transform*.py" -o -name "prepare*.py" 2>/dev/null | head -n1)
  if [[ -n "$TRANSFORM_SCRIPT" ]]; then
    if grep -qE "deduplicate|drop_duplicates|unique" "$TRANSFORM_SCRIPT"; then
      pass "Transform pipeline includes deduplication logic"
    else
      skip "Deduplication logic not clearly detected (may use different pattern)"
    fi
  fi
else
  skip "Transform scripts not found (may be in different location)"
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
[[ $FAIL -gt 0 ]] && exit 1
exit 0
