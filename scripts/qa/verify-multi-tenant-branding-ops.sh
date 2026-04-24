#!/usr/bin/env bash
# @covers AC-FRONT-041, AC-FRONT-042, AC-FRONT-043, AC-FRONT-044
# @spec: bead-2dcy
#
# Verify the multi-tenant branding operations model document (bead 2dcy.4).
#
# Checks:
#   AC-FRONT-041: MULTI_TENANT_BRANDING_OPS.md exists, references override precedence,
#                 SITE_VARIANTS, and design tokens.
#   AC-FRONT-042: Document contains per-tenant onboarding steps, DNS, ConfigMap, and
#                 provision-tenant.sh references.
#   AC-FRONT-043: Document references CI validation, verify scripts (at least 3 by name),
#                 and runtime branding resolution.
#   AC-FRONT-044: Document contains owner/signoff section and escalation path.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

source "$REPO_ROOT/scripts/shared/ci-skip-guards.sh"
require_file "docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md" "multi-tenant branding ops doc" || exit 0

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass_check() { echo -e "  ${GREEN}PASS${NC}: $1"; PASS=$((PASS + 1)); }
fail_check() { echo -e "  ${RED}FAIL${NC}: $1"; FAIL=$((FAIL + 1)); }
warn_check() { echo -e "  ${YELLOW}WARN${NC}: $1"; WARN=$((WARN + 1)); }

OPS_DOC="$REPO_ROOT/docs/guides/branding/MULTI_TENANT_BRANDING_OPS.md"

# Helper: grep the document content without SIGPIPE from echo|grep -q under pipefail.
# Uses herestring (<<<) instead of pipe so grep -q closing stdin early doesn't kill echo.
doc_grep()    { grep -qiE  -- "$1" <<< "$content"; }
doc_grep_f()  { grep -qF   -- "$1" <<< "$content"; }

echo "========================================================"
echo "Multi-Tenant Branding Operations Model Verifier (bead 2dcy.4)"
echo "AC-FRONT-041..044"
echo "========================================================"
echo ""

# -----------------------------------------------------------------------
# AC-FRONT-041: Document exists; references override precedence, SITE_VARIANTS,
#               and design tokens / _tokens.scss
# -----------------------------------------------------------------------
echo "AC-FRONT-041: Branding scope and override precedence"

if [[ ! -f "$OPS_DOC" ]]; then
  fail_check "MULTI_TENANT_BRANDING_OPS.md not found at $OPS_DOC"
else
  pass_check "MULTI_TENANT_BRANDING_OPS.md exists"

  content="$(tr -d '\r' < "$OPS_DOC")"

  # Check for precedence section
  if doc_grep "override precedence|precedence chain|Override Precedence"; then
    pass_check "Document contains 'override precedence' section"
  else
    fail_check "Document does not contain 'override precedence' section"
  fi

  # Check for SITE_VARIANTS reference
  if doc_grep_f "SITE_VARIANTS"; then
    pass_check "Document references SITE_VARIANTS"
  else
    fail_check "Document does not reference SITE_VARIANTS"
  fi

  # Check for design tokens or _tokens.scss reference
  if doc_grep "_tokens\.scss|design.token"; then
    pass_check "Document references design tokens (_tokens.scss)"
  else
    fail_check "Document does not reference design tokens / _tokens.scss"
  fi

  # Check for plugin slot reference
  if doc_grep "plugin slot|mfe-env-config|footer.slot"; then
    pass_check "Document references plugin slot configuration"
  else
    warn_check "Document does not explicitly reference plugin slot — consider adding"
  fi

  # Check for tenant registry / ConfigMap reference
  if doc_grep "configmap-tenants|tenant.registry|tenant-registry"; then
    pass_check "Document references tenant registry ConfigMap"
  else
    fail_check "Document does not reference tenant registry ConfigMap"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-042: Per-tenant onboarding runbook
# -----------------------------------------------------------------------
echo "AC-FRONT-042: Per-tenant onboarding runbook"

if [[ ! -f "$OPS_DOC" ]]; then
  fail_check "OPS document missing — cannot check AC-FRONT-042"
else
  content="$(tr -d '\r' < "$OPS_DOC")"

  # Check for onboarding or new tenant steps
  if doc_grep "onboarding|new tenant|per.tenant"; then
    pass_check "Document contains onboarding / new tenant steps"
  else
    fail_check "Document does not contain onboarding steps"
  fi

  # Check for DNS steps
  if doc_grep "dns|cloudflare|hostname"; then
    pass_check "Document references DNS/hostname registration steps"
  else
    fail_check "Document does not reference DNS steps"
  fi

  # Check for provision-tenant.sh reference
  if doc_grep_f "provision-tenant"; then
    pass_check "Document references provision-tenant.sh"
  else
    fail_check "Document does not reference provision-tenant.sh"
  fi

  # Check for ConfigMap reference in onboarding context
  if doc_grep "configmap|tenant-config|configmap-tenants"; then
    pass_check "Document references ConfigMap entries in onboarding"
  else
    fail_check "Document does not reference ConfigMap in onboarding section"
  fi

  # Check for smoke test / verification step in runbook
  if doc_grep "smoke test|verify|Step.*[0-9].*[Ss]moke|Step.*[0-9].*[Vv]erif"; then
    pass_check "Document includes smoke test / verification step in runbook"
  else
    warn_check "Runbook does not mention smoke test verification step"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-043: CI and runtime validation
# -----------------------------------------------------------------------
echo "AC-FRONT-043: CI and runtime validation"

if [[ ! -f "$OPS_DOC" ]]; then
  fail_check "OPS document missing — cannot check AC-FRONT-043"
else
  content="$(tr -d '\r' < "$OPS_DOC")"

  # Check for CI validation mention
  if doc_grep "ci|continuous integration|github.actions|ci.yml"; then
    pass_check "Document references CI validation"
  else
    fail_check "Document does not reference CI validation"
  fi

  # Check for runtime resolution mention
  if doc_grep "runtime|domain resolution|TenantResolutionMiddleware|middleware"; then
    pass_check "Document references runtime branding resolution"
  else
    fail_check "Document does not reference runtime domain resolution"
  fi

  # Count named verify scripts referenced in the document
  VERIFY_COUNT=0

  if doc_grep_f "verify-tenant-branding-contract.sh"; then
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
  fi
  if doc_grep_f "verify-branding-multi-domain.sh"; then
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
  fi
  if doc_grep_f "verify-multi-tenancy-foundation.sh"; then
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
  fi
  if doc_grep_f "verify-tenant-configmap.sh"; then
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
  fi
  if doc_grep_f "verify-tenant-branding.sh"; then
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
  fi
  if doc_grep_f "verify-tenant-branding-runtime.sh"; then
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
  fi
  if doc_grep_f "verify-plugin-slot-migration-register.sh"; then
    VERIFY_COUNT=$((VERIFY_COUNT + 1))
  fi

  if [[ "$VERIFY_COUNT" -ge 3 ]]; then
    pass_check "Document references at least 3 existing verify scripts by name (found: $VERIFY_COUNT)"
  else
    fail_check "Document references fewer than 3 verify scripts by name (found: $VERIFY_COUNT, need >= 3)"
  fi

  # Check for branding regression detection mention
  if doc_grep "regression|regression detection|regression guard"; then
    pass_check "Document references branding regression detection"
  else
    warn_check "Document does not mention branding regression detection"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-FRONT-044: Owner/signoff and escalation
# -----------------------------------------------------------------------
echo "AC-FRONT-044: Owner, signoff, and escalation"

if [[ ! -f "$OPS_DOC" ]]; then
  fail_check "OPS document missing — cannot check AC-FRONT-044"
else
  content="$(tr -d '\r' < "$OPS_DOC")"

  # Check for owner section
  if doc_grep "owner|ownership|owns"; then
    pass_check "Document contains owner / ownership section"
  else
    fail_check "Document does not contain owner / ownership section"
  fi

  # Check for signoff mention
  if doc_grep "signoff|sign.off|approval|pr approval"; then
    pass_check "Document contains signoff / approval expectations"
  else
    fail_check "Document does not mention signoff requirements"
  fi

  # Check for escalation mention
  if doc_grep "escalation|escalate|pagerduty|on.call|p1|p2"; then
    pass_check "Document contains escalation path"
  else
    fail_check "Document does not contain escalation path"
  fi

  # Check for Mereka Academy / Biji-Biji / SkilOurFuture tenant owners
  TENANT_OWNER_COUNT=0
  if doc_grep "mereka academy"; then
    TENANT_OWNER_COUNT=$((TENANT_OWNER_COUNT + 1))
  fi
  if doc_grep "biji-biji|biji biji"; then
    TENANT_OWNER_COUNT=$((TENANT_OWNER_COUNT + 1))
  fi
  if doc_grep "skil our future|skilourfuture|skillourfuture"; then
    TENANT_OWNER_COUNT=$((TENANT_OWNER_COUNT + 1))
  fi

  if [[ "$TENANT_OWNER_COUNT" -ge 2 ]]; then
    pass_check "Document names branding owners for at least 2 tenants (found: $TENANT_OWNER_COUNT)"
  else
    warn_check "Document names branding owners for fewer than 2 tenants (found: $TENANT_OWNER_COUNT)"
  fi
fi

echo ""
echo "========================================================"
echo "Summary"
echo "========================================================"
echo ""
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
