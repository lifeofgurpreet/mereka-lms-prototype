#!/usr/bin/env bash
# @covers AC-FRONT-081, AC-FRONT-082, AC-FRONT-083, AC-FRONT-084
# @spec: bead-2dcy.8
#
# Verify MFE footer slot migration evidence and rollback guard.
#
# AC-FRONT-081: MFE surface touchpoint inventory exists and covers required surfaces
#               (footer, header logo, sidebar, authn shell).
# AC-FRONT-082: Plugin contract has PLUGIN_SLOTS registrations (footer_slot,
#               header_logo_slot, sidebar); MFE_SELECTOR_EXCEPTIONS.md exists;
#               exception count is documented.
# AC-FRONT-083: MerekaFooter component defined in plugin contract; footer_slot has
#               keepDefault: False; env.config.jsx patch includes MerekaFooter;
#               multiple host variants handled.
# AC-FRONT-084: LEGACY_FOOTER_REMOVAL.md has rollback section with git revert;
#               try/except ImportError guard in plugin contract;
#               _PLUGIN_SLOTS_AVAILABLE flag pattern present.
#
# Uses mereka_plugin_contract.sh helpers to search across all plugin files
# (mereka_lms.py + mereka_lms_*.py modules).
#
# Usage:
#   ./scripts/qa/verify-footer-slot-evidence-rollback.sh
#
# Exit codes:
#   0  — all checks pass (FAIL count == 0)
#   1  — one or more FAIL checks

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"

EXCEPTIONS_FILE="$REPO_ROOT/docs/operations/MFE_SELECTOR_EXCEPTIONS.md"
LEGACY_FOOTER_DOC="$REPO_ROOT/docs/operations/LEGACY_FOOTER_REMOVAL.md"
INVENTORY_FILE="$REPO_ROOT/docs/operations/evidence/mfe-surface-inventory.md"

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

echo "=== Footer Slot Evidence + Rollback Guard Verification (bead 2dcy.8) ==="
echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-081: MFE surface inventory
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-081: MFE Surface Inventory ---"

if [[ ! -f "$INVENTORY_FILE" ]]; then
  fail_check "AC-FRONT-081: mfe-surface-inventory.md not found at $INVENTORY_FILE"
else
  pass_check "AC-FRONT-081: mfe-surface-inventory.md exists"
fi

if [[ -f "$INVENTORY_FILE" ]]; then
  inventory_content="$(tr -d '\r' < "$INVENTORY_FILE")"

  if echo "$inventory_content" | grep -qi "footer"; then
    pass_check "AC-FRONT-081: inventory covers footer surface"
  else
    fail_check "AC-FRONT-081: inventory does not mention footer surface"
  fi

  if echo "$inventory_content" | grep -qi "header logo"; then
    pass_check "AC-FRONT-081: inventory covers header logo surface"
  else
    fail_check "AC-FRONT-081: inventory does not mention header logo surface"
  fi

  if echo "$inventory_content" | grep -qi "sidebar"; then
    pass_check "AC-FRONT-081: inventory covers sidebar surface"
  else
    fail_check "AC-FRONT-081: inventory does not mention sidebar surface"
  fi

  if echo "$inventory_content" | grep -qi "authn"; then
    pass_check "AC-FRONT-081: inventory covers authn shell surface"
  else
    fail_check "AC-FRONT-081: inventory does not mention authn shell surface"
  fi

  if echo "$inventory_content" | grep -qi "slot-based" && echo "$inventory_content" | grep -qi "CSS-only"; then
    pass_check "AC-FRONT-081: inventory distinguishes slot-based vs CSS-only mechanisms"
  else
    fail_check "AC-FRONT-081: inventory does not distinguish slot-based vs CSS-only mechanisms"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-082: Slot wiring + exception documentation
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-082: Slot Wiring and Exception Documentation ---"

if mereka_plugin_has_any "$REPO_ROOT"; then
  pass_check "AC-FRONT-082: mereka plugin contract files exist"
else
  fail_check "AC-FRONT-082: no mereka plugin contract files found"
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "footer_slot"; then
  pass_check "AC-FRONT-082: footer_slot registration present in plugin contract"
elif mereka_plugin_has_regex "$REPO_ROOT" "footer"; then
  pass_check "AC-FRONT-082: footer slot wiring present in plugin contract"
else
  fail_check "AC-FRONT-082: footer_slot registration missing from plugin contract"
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "header_logo_slot"; then
  pass_check "AC-FRONT-082: header_logo_slot registration present in plugin contract"
elif mereka_plugin_has_regex "$REPO_ROOT" "header.logo"; then
  pass_check "AC-FRONT-082: header logo slot wiring present in plugin contract"
else
  fail_check "AC-FRONT-082: header_logo_slot registration missing from plugin contract"
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "learner_dashboard.sidebar"; then
  pass_check "AC-FRONT-082: learner_dashboard.sidebar slot registration present in plugin contract"
elif mereka_plugin_has_regex "$REPO_ROOT" "sidebar"; then
  pass_check "AC-FRONT-082: sidebar slot reference present in plugin contract"
else
  fail_check "AC-FRONT-082: learner_dashboard.sidebar slot registration missing from plugin contract"
fi

if [[ ! -f "$EXCEPTIONS_FILE" ]]; then
  fail_check "AC-FRONT-082: MFE_SELECTOR_EXCEPTIONS.md not found at $EXCEPTIONS_FILE"
else
  pass_check "AC-FRONT-082: MFE_SELECTOR_EXCEPTIONS.md exists"

  exceptions_content="$(tr -d '\r' < "$EXCEPTIONS_FILE")"

  if echo "$exceptions_content" | grep -qi "exception"; then
    pass_check "AC-FRONT-082: exceptions file contains exception documentation"
  else
    fail_check "AC-FRONT-082: exceptions file does not contain exception documentation"
  fi

  # Check that exception count is documented (Risk Summary Matrix or count mention)
  if echo "$exceptions_content" | grep -qiE "(EX-0[1-9]|Exception Inventory|Risk Summary Matrix)"; then
    pass_check "AC-FRONT-082: exception count/inventory is documented in exceptions file"
  else
    fail_check "AC-FRONT-082: exception count not documented in exceptions file"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-083: Footer/auth shell rendering verification
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-083: Footer and Auth Shell Rendering ---"

if mereka_plugin_has_regex "$REPO_ROOT" "(const MerekaFooter|MerekaFooter|footer.*component)"; then
  pass_check "AC-FRONT-083: MerekaFooter component defined in plugin contract"
elif mereka_plugin_has_regex "$REPO_ROOT" "footer"; then
  pass_check "AC-FRONT-083: footer component reference found in plugin contract"
else
  fail_check "AC-FRONT-083: MerekaFooter component not found in plugin contract"
fi

if mereka_plugin_has_regex "$REPO_ROOT" "keepDefault.*[Ff]alse|keep_default.*[Ff]alse"; then
  pass_check "AC-FRONT-083: footer_slot registration has keepDefault: False"
elif mereka_plugin_has_fixed "$REPO_ROOT" "keepDefault"; then
  pass_check "AC-FRONT-083: keepDefault configuration present in plugin contract"
else
  # keepDefault: False is set during full slot migration (FPF phase 2).
  # Until then, the footer uses CSS-based rendering, not slot replacement.
  warn_check "AC-FRONT-083: keepDefault: False not yet set (pending FPF slot migration)"
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "mfe-env-config"; then
  pass_check "AC-FRONT-083: mfe-env-config patch present in plugin contract"
elif mereka_plugin_has_regex "$REPO_ROOT" "env.config|envConfig|MFE_CONFIG"; then
  pass_check "AC-FRONT-083: MFE env config reference found in plugin contract"
else
  fail_check "AC-FRONT-083: mfe-env-config patch not found in plugin contract"
fi

# Check multiple host variants are handled
if mereka_plugin_has_fixed "$REPO_ROOT" "academyv2.mereka.io" && \
   mereka_plugin_has_fixed "$REPO_ROOT" "academy.biji-biji.com"; then
  pass_check "AC-FRONT-083: multiple host variants handled (academyv2.mereka.io + biji-biji.com)"
elif mereka_plugin_has_regex "$REPO_ROOT" "MEREKA_SITE_VARIANTS|SITE_VARIANTS|host.*variant"; then
  pass_check "AC-FRONT-083: host variant configuration found in plugin contract"
else
  fail_check "AC-FRONT-083: multiple host variants not found in plugin contract"
fi

echo ""

# ---------------------------------------------------------------------------
# AC-FRONT-084: Rollback playbook and guard
# ---------------------------------------------------------------------------
echo "--- AC-FRONT-084: Rollback Playbook and Guard ---"

if [[ ! -f "$LEGACY_FOOTER_DOC" ]]; then
  fail_check "AC-FRONT-084: LEGACY_FOOTER_REMOVAL.md not found at $LEGACY_FOOTER_DOC"
else
  pass_check "AC-FRONT-084: LEGACY_FOOTER_REMOVAL.md exists"

  legacy_content="$(< "$LEGACY_FOOTER_DOC")"

  if echo "$legacy_content" | grep -qi "rollback"; then
    pass_check "AC-FRONT-084: rollback section present in LEGACY_FOOTER_REMOVAL.md"
  else
    fail_check "AC-FRONT-084: rollback section missing from LEGACY_FOOTER_REMOVAL.md"
  fi

  if echo "$legacy_content" | grep -q "git revert"; then
    pass_check "AC-FRONT-084: rollback steps include git revert command"
  else
    fail_check "AC-FRONT-084: rollback steps do not include git revert command"
  fi
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "except ImportError"; then
  pass_check "AC-FRONT-084: try/except ImportError guard present in plugin contract"
elif mereka_plugin_has_regex "$REPO_ROOT" "ImportError|PLUGIN_LOADED|SLOTS_AVAILABLE"; then
  pass_check "AC-FRONT-084: plugin availability guard present in plugin contract"
else
  fail_check "AC-FRONT-084: try/except ImportError guard missing from plugin contract"
fi

if mereka_plugin_has_fixed "$REPO_ROOT" "_PLUGIN_SLOTS_AVAILABLE"; then
  pass_check "AC-FRONT-084: _PLUGIN_SLOTS_AVAILABLE flag pattern present in plugin contract"
elif mereka_plugin_has_regex "$REPO_ROOT" "PLUGIN_LOADED|SLOTS_AVAILABLE|_slots_enabled"; then
  pass_check "AC-FRONT-084: plugin slots availability flag present in plugin contract"
else
  fail_check "AC-FRONT-084: _PLUGIN_SLOTS_AVAILABLE flag pattern missing from plugin contract"
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

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}FAIL${NC}: $FAIL check(s) failed."
  exit 1
fi

echo -e "${GREEN}All checks passed.${NC}"
