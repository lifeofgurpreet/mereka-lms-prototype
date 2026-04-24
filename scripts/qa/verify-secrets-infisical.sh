#!/usr/bin/env bash
# @covers AC-006, AC-007, AC-008, AC-011
# @spec: secrets-management_spec.md
# Verify secrets in Infisical
#
# Checks:
#   AC-006: No MEREKA_LMS_* keys outside canonical path
#   AC-007: Validation script passes (all keys present)
#   AC-008: Strict validation passes (no empty/placeholder values)
#   AC-011: Atlas secrets exist under /k8s/mereka-lms/atlas
#
# Usage:
#   ./scripts/qa/verify-secrets-infisical.sh              # Auto-detect infisical
#   ./scripts/qa/verify-secrets-infisical.sh --require-infisical  # Fail if no infisical
#   ./scripts/qa/verify-secrets-infisical.sh --skip-infisical     # Skip all checks

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_ROOT="${PROJECTS_ROOT:-$(cd "$REPO_ROOT/../.." && pwd)}"
cd "$REPO_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASS=0
FAIL=0
SKIP=0

# Settings
REQUIRE_INFISICAL=false
SKIP_INFISICAL=false
INFISICAL_ENV="${INFISICAL_ENV:-prod}"

# Helper functions
pass() { echo -e "${GREEN}PASS${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAIL=$((FAIL + 1)); }
skip() { echo -e "${YELLOW}SKIP${NC} $1"; SKIP=$((SKIP + 1)); }

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --require-infisical)
      REQUIRE_INFISICAL=true
      shift
      ;;
    --skip-infisical)
      SKIP_INFISICAL=true
      shift
      ;;
    *)
      echo "Unknown argument: $1" >&2
      echo "Usage: $0 [--require-infisical|--skip-infisical]" >&2
      exit 1
      ;;
  esac
done

# Check for infisical CLI
INFISICAL_AVAILABLE=false
if [[ "$SKIP_INFISICAL" == "false" ]]; then
  if command -v infisical >/dev/null 2>&1; then
    INFISICAL_AVAILABLE=true
  fi
fi

if [[ "$INFISICAL_AVAILABLE" == "false" ]]; then
  if [[ "$REQUIRE_INFISICAL" == "true" ]]; then
    echo -e "${RED}ERROR:${NC} Infisical CLI required but not available" >&2
    exit 1
  fi

  echo -e "${YELLOW}Infisical CLI not detected. Skipping all checks.${NC}"
  echo ""
  skip "AC-006: No MEREKA_LMS_* keys outside canonical path (no infisical)"
  skip "AC-007: Validation script passes (no infisical)"
  skip "AC-008: Strict validation passes (no infisical)"
  skip "AC-011: Atlas secrets exist (no infisical)"

  echo ""
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"
  exit 0
fi

echo "=== Secrets Infisical Verification ==="
echo "Environment: $INFISICAL_ENV"
echo ""

# AC-006: Run audit script to check for keys outside canonical path
echo "Checking AC-006: No MEREKA_LMS_* keys outside canonical path..."

audit_script="$REPO_ROOT/scripts/infra/infisical-audit-mereka-lms.sh"

if [[ ! -f "$audit_script" ]]; then
  fail "AC-006: Audit script not found: $audit_script"
elif [[ ! -x "$audit_script" ]]; then
  fail "AC-006: Audit script not executable: $audit_script"
else
  # Run audit script and capture output
  if INFISICAL_ENV="$INFISICAL_ENV" "$audit_script" >/dev/null 2>&1; then
    pass "AC-006: No MEREKA_LMS_* keys outside /k8s/mereka-lms ($INFISICAL_ENV)"
  else
    fail "AC-006: Audit script found keys outside canonical path ($INFISICAL_ENV)"
    echo "  Run: INFISICAL_ENV=$INFISICAL_ENV $audit_script"
  fi
fi

echo ""

# AC-007: Run validation script (basic)
echo "Checking AC-007: Validation script passes..."

validate_script="$REPO_ROOT/scripts/infra/infisical-validate-mereka-lms.sh"

if [[ ! -f "$validate_script" ]]; then
  fail "AC-007: Validation script not found: $validate_script"
elif [[ ! -x "$validate_script" ]]; then
  fail "AC-007: Validation script not executable: $validate_script"
else
  # Run validation script (basic mode)
  if INFISICAL_ENV="$INFISICAL_ENV" "$validate_script" >/dev/null 2>&1; then
    pass "AC-007: Validation script passes ($INFISICAL_ENV)"
  else
    fail "AC-007: Validation script failed ($INFISICAL_ENV)"
    echo "  Run: INFISICAL_ENV=$INFISICAL_ENV $validate_script"
  fi
fi

echo ""

# AC-008: Run validation script in STRICT mode
echo "Checking AC-008: Strict validation passes..."

if [[ ! -f "$validate_script" ]]; then
  skip "AC-008: Validation script not found"
else
  # Run validation script with STRICT=1
  if STRICT=1 INFISICAL_ENV="$INFISICAL_ENV" "$validate_script" >/dev/null 2>&1; then
    pass "AC-008: Strict validation passes ($INFISICAL_ENV)"
  else
    fail "AC-008: Strict validation failed ($INFISICAL_ENV)"
    echo "  Run: STRICT=1 INFISICAL_ENV=$INFISICAL_ENV $validate_script"
  fi
fi

echo ""

# AC-011: Check Atlas secrets exist
echo "Checking AC-011: Atlas secrets exist under /k8s/mereka-lms/atlas..."

# Query Infisical for Atlas secrets
atlas_path="/k8s/mereka-lms/atlas"
required_atlas_keys=("ATLAS_PUBLIC_KEY" "ATLAS_PRIVATE_KEY" "ATLAS_ORG_ID" "ATLAS_PROJECT_ID")

# Try to resolve Infisical directory
INFISICAL_DIR=""
candidates=(
  "${PROJECTS_ROOT}/secrets-management"
  "${HOME}/projects/secrets-management"
  "$REPO_ROOT"
)
for candidate in "${candidates[@]}"; do
  if [[ -f "${candidate}/.infisical.json" ]]; then
    INFISICAL_DIR="$candidate"
    break
  fi
done

if [[ -z "$INFISICAL_DIR" ]]; then
  INFISICAL_DIR="$REPO_ROOT"
fi

# Try to get project ID
INFISICAL_PROJECT_ID="${INFISICAL_PROJECT_ID:-}"
if [[ -z "$INFISICAL_PROJECT_ID" ]] && [[ -f "$INFISICAL_DIR/.infisical.json" ]]; then
  INFISICAL_PROJECT_ID=$(jq -r '.workspaceId // empty' "$INFISICAL_DIR/.infisical.json" 2>/dev/null || true)
fi

# Try backup directory
if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  backup_dir="${HOME}/.infisical/secrets-backup"
  if [[ -d "$backup_dir" ]]; then
    candidate=$(ls "$backup_dir"/project_secrets_* 2>/dev/null | head -n 1 || true)
    if [[ -n "$candidate" ]]; then
      INFISICAL_PROJECT_ID=$(basename "$candidate" | sed -E 's/^project_secrets_([^_]+)_.*/\1/')
    fi
  fi
fi

if [[ -z "$INFISICAL_PROJECT_ID" ]]; then
  skip "AC-011: Cannot determine Infisical project ID"
else
  ac011_pass=true

  # Fetch keys from atlas path
  atlas_keys=$(cd "$INFISICAL_DIR" && infisical secrets \
    --domain "${INFISICAL_DOMAIN:-https://secrets.mereka.io/api}" \
    --env "$INFISICAL_ENV" \
    --path "$atlas_path" \
    --projectId "$INFISICAL_PROJECT_ID" \
    --output json --silent 2>/dev/null | jq -r '.[].secretKey' | sort -u || echo "")

  if [[ -z "$atlas_keys" ]]; then
    fail "AC-011: Could not fetch secrets from $atlas_path"
    ac011_pass=false
  else
    for key in "${required_atlas_keys[@]}"; do
      if echo "$atlas_keys" | grep -q "^${key}$"; then
        pass "AC-011: Atlas secret '$key' exists"
      else
        fail "AC-011: Atlas secret '$key' missing from $atlas_path"
        ac011_pass=false
      fi
    done
  fi
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}SKIP:${NC} $SKIP"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "Some checks failed. Review the output above."
  exit 1
fi

exit 0
