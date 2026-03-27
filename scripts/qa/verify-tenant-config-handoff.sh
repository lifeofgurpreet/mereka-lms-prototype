#!/usr/bin/env bash
# @covers AC-UI-601, AC-UI-602, AC-UI-603, AC-UI-604, AC-UI-605
# @spec: bead-31yg
#
# Verify the multi-tenant branding config handoff guide.
#
# AC-UI-601: Per-tenant precedence for assets, domains, and plugin overrides is defined.
# AC-UI-602: New-tenant onboarding checklist covers DNS/hostname and domain mapping.
# AC-UI-603: Validation commands for tenant-specific branding and plugin config are present.
# AC-UI-604: Rollback and recovery actions for tenant misconfiguration are documented.
# AC-UI-605: Links to enterprise host and subsystem mappings docs are present.
#
# Usage:
#   ./scripts/qa/verify-tenant-config-handoff.sh
#
# Exit codes:
#   0  — all checks pass (FAIL count == 0)
#   1  — one or more FAIL checks

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

HANDOFF_DOC="$REPO_ROOT/docs/guides/branding/TENANT_CONFIG_HANDOFF.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass_check() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }
doc_contains() { grep -qiE "$1" <<<"$content"; }
doc_count() { grep -cE "$1" <<<"$content" || true; }

echo "=== Tenant Config Handoff Verification (bead 31yg) ==="
echo ""

# ---------------------------------------------------------------------------
# Prerequisite: document exists
# ---------------------------------------------------------------------------
if [[ ! -f "$HANDOFF_DOC" ]]; then
  fail_check "TENANT_CONFIG_HANDOFF.md not found at $HANDOFF_DOC"
  echo ""
  echo "=== Results ==="
  echo -e "  ${GREEN}PASS${NC}: $PASS"
  echo -e "  ${RED}FAIL${NC}: $FAIL"
  echo -e "  ${YELLOW}WARN${NC}: $WARN"
  echo ""
  echo -e "${RED}FAIL${NC}: $FAIL check(s) failed."
  exit 1
fi

pass_check "TENANT_CONFIG_HANDOFF.md exists"
content="$(tr -d '\r' < "$HANDOFF_DOC")"

echo ""

# ---------------------------------------------------------------------------
# AC-UI-601: Per-tenant precedence
# ---------------------------------------------------------------------------
echo "--- AC-UI-601: Per-Tenant Asset and Config Precedence ---"

if doc_contains "precedence"; then
  pass_check "AC-UI-601: document contains 'precedence' section"
else
  fail_check "AC-UI-601: document does not contain 'precedence' section"
fi

if doc_contains "SITE_VARIANTS"; then
  pass_check "AC-UI-601: document references SITE_VARIANTS"
else
  fail_check "AC-UI-601: document does not reference SITE_VARIANTS"
fi

if doc_contains "_tokens.scss|design token"; then
  pass_check "AC-UI-601: document references _tokens.scss or design tokens"
else
  fail_check "AC-UI-601: document does not reference _tokens.scss or design tokens"
fi

if doc_contains "mereka_lms.py"; then
  pass_check "AC-UI-601: document references mereka_lms.py"
else
  fail_check "AC-UI-601: document does not reference mereka_lms.py"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-602: New tenant onboarding checklist
# ---------------------------------------------------------------------------
echo "--- AC-UI-602: New Tenant Onboarding Checklist ---"

if doc_contains "checklist|onboarding"; then
  pass_check "AC-UI-602: document contains 'checklist' or 'onboarding' section"
else
  fail_check "AC-UI-602: document does not contain 'checklist' or 'onboarding' section"
fi

if doc_contains "dns|hostname"; then
  pass_check "AC-UI-602: document mentions DNS/hostname steps"
else
  fail_check "AC-UI-602: document does not mention DNS/hostname steps"
fi

if doc_contains "domain mapping|verify domain"; then
  pass_check "AC-UI-602: document mentions domain mapping verification"
else
  fail_check "AC-UI-602: document does not mention domain mapping verification"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-603: Validation commands
# ---------------------------------------------------------------------------
echo "--- AC-UI-603: Validation Commands ---"

if doc_contains "validation|validate"; then
  pass_check "AC-UI-603: document contains 'validation' or 'validate' section"
else
  fail_check "AC-UI-603: document does not contain a validation section"
fi

# Count backtick code blocks that contain curl, grep, or scripts/ references
code_block_count=$(doc_count '^\`\`\`|curl |grep |scripts/')
if [[ "$code_block_count" -ge 2 ]]; then
  pass_check "AC-UI-603: document includes at least 2 concrete command examples"
else
  fail_check "AC-UI-603: document does not include at least 2 concrete command examples"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-604: Rollback and recovery
# ---------------------------------------------------------------------------
echo "--- AC-UI-604: Rollback and Recovery ---"

if doc_contains "rollback"; then
  pass_check "AC-UI-604: document contains 'rollback' section"
else
  fail_check "AC-UI-604: document does not contain a rollback section"
fi

if doc_contains "git revert|kubectl rollout"; then
  pass_check "AC-UI-604: document mentions git revert or kubectl rollout"
else
  fail_check "AC-UI-604: document does not mention git revert or kubectl rollout"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-605: Links to enterprise host and subsystem docs
# ---------------------------------------------------------------------------
echo "--- AC-UI-605: Enterprise Host and Subsystem Mappings ---"

if doc_contains "MULTI_TENANT_BRANDING_OPS|MULTITENANT_BRAND_PLATFORM|BRANDING_OPERATING_MODEL"; then
  pass_check "AC-UI-605: document references MULTI_TENANT_BRANDING_OPS or BRANDING_OPERATING_MODEL"
else
  fail_check "AC-UI-605: document does not reference MULTI_TENANT_BRANDING_OPS or BRANDING_OPERATING_MODEL"
fi

if doc_contains "mereka_lms.py"; then
  pass_check "AC-UI-605: document references mereka_lms.py in subsystem mappings"
else
  fail_check "AC-UI-605: document does not reference mereka_lms.py in subsystem mappings"
fi

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Results ==="
echo -e "  ${GREEN}PASS${NC}: $PASS"
echo -e "  ${RED}FAIL${NC}: $FAIL"
echo -e "  ${YELLOW}WARN${NC}: $WARN"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "${RED}FAIL${NC}: $FAIL check(s) failed."
  exit 1
fi

echo -e "${GREEN}All checks passed.${NC}"
exit 0
