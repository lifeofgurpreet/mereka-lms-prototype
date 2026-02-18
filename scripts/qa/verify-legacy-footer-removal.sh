#!/usr/bin/env bash
# @covers AC-UI-401, AC-UI-402, AC-UI-403, AC-UI-404, AC-UI-405
# @spec: bead-1rns
#
# Verify legacy footer patch removal and plugin slot migration.
#
# AC-UI-401: No active (uncommented) sed or string-rewrite targeting footer HTML
#            structure in infrastructure/tutor/apply-patches.sh. The MIGRATED-TO-SLOT
#            annotations from 2dcy.6 must now be fully disabled.
# AC-UI-402: infrastructure/tutor/plugins/mereka_lms.py has footer_slot configuration
#            via PLUGIN_SLOTS (no fallback flag — slot is the only path).
# AC-UI-403: MFE config (authn, dashboard, learning) env.config.jsx coverage exists
#            via slot mechanism in the plugin.
# AC-UI-404: docs/operations/LEGACY_FOOTER_REMOVAL.md exists and contains rollback steps.
# AC-UI-405: Before/after diff evidence file exists.
#
# Usage:
#   ./scripts/qa/verify-legacy-footer-removal.sh
#
# Exit codes:
#   0  — all checks pass (FAIL count == 0)
#   1  — one or more FAIL checks

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

PATCHES_FILE="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
PLUGIN_FILE="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
OPS_DOC="$REPO_ROOT/docs/operations/LEGACY_FOOTER_REMOVAL.md"
EVIDENCE_FILE="$REPO_ROOT/docs/operations/evidence/footer-migration-diff.md"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

echo "=== Legacy Footer Removal Verification (bead 1rns) ==="
echo ""

# ---------------------------------------------------------------------------
# AC-UI-401: No active footer string-rewrite in apply-patches.sh
# ---------------------------------------------------------------------------
echo "--- AC-UI-401: Legacy Patch Disabled in apply-patches.sh ---"

if [[ ! -f "$PATCHES_FILE" ]]; then
  fail "AC-UI-401: apply-patches.sh not found at $PATCHES_FILE"
else
  pass "AC-UI-401: apply-patches.sh exists"

  # Check that the RenderWidget: <Footer /> replacement is NOT active (uncommented)
  # Active = line is NOT a comment (no leading #) AND contains the replace call
  ACTIVE_FOOTER_REWRITES=$(python3 - "$PATCHES_FILE" <<'PY'
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text().splitlines()
active = []
for idx, line in enumerate(lines):
    stripped = line.strip()
    # Skip pure comment lines
    if stripped.startswith('#'):
        continue
    # Look for active (uncommented) footer RenderWidget replacement
    if ('replace("RenderWidget: <Footer />"' in line or
            "replace('RenderWidget: <Footer />'" in line):
        active.append(f"Line {idx+1}: {stripped[:120]}")
for a in active:
    print(a)
PY
)

  if [[ -z "$ACTIVE_FOOTER_REWRITES" ]]; then
    pass "AC-UI-401: No active (uncommented) RenderWidget: <Footer /> string-rewrite found"
  else
    ACTIVE_COUNT=$(echo "$ACTIVE_FOOTER_REWRITES" | grep -c . || true)
    fail "AC-UI-401: $ACTIVE_COUNT active footer string-rewrite(s) still present (should be commented out):"
    echo "$ACTIVE_FOOTER_REWRITES" | head -5
  fi

  # Verify the removal comment block is present (documents what was done)
  if grep -q 'REMOVED.*bead 1rns\|REMOVED (bead 1rns' "$PATCHES_FILE"; then
    pass "AC-UI-401: Removal comment block (bead 1rns) present in apply-patches.sh"
  else
    warn "AC-UI-401: Removal comment block not found — expected '# REMOVED (bead 1rns' annotation"
  fi

  # Verify the MerekaFooter component definition is still injected
  # (component must remain available as a symbol even though slot wiring is canonical)
  if grep -q 'const MerekaFooter' "$PATCHES_FILE"; then
    pass "AC-UI-401: MerekaFooter component definition still present in apply-patches.sh"
  else
    fail "AC-UI-401: MerekaFooter component definition missing — env.config.jsx symbol will be undefined"
  fi

  # Verify no bare sed commands targeting footer HTML structure
  ACTIVE_SED_FOOTER=$(grep -n 'sed' "$PATCHES_FILE" | grep -i 'footer\|Footer' | grep -v '^\s*#' || true)
  if [[ -z "$ACTIVE_SED_FOOTER" ]]; then
    pass "AC-UI-401: No active sed commands targeting footer HTML"
  else
    fail "AC-UI-401: Active sed command(s) targeting footer HTML found:"
    echo "$ACTIVE_SED_FOOTER" | head -5
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-402: footer_slot in mereka_lms.py (slot-only, no fallback flag)
# ---------------------------------------------------------------------------
echo "--- AC-UI-402: footer_slot Slot Configuration in mereka_lms.py ---"

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "AC-UI-402: mereka_lms.py not found at $PLUGIN_FILE"
else
  pass "AC-UI-402: mereka_lms.py exists"

  # Check footer_slot PLUGIN_SLOTS.add_item registration
  if grep -q '"footer_slot"' "$PLUGIN_FILE"; then
    pass "AC-UI-402: footer_slot registered via PLUGIN_SLOTS.add_item"
  else
    fail "AC-UI-402: footer_slot not found in mereka_lms.py"
  fi

  # Check for keepDefault: False (slot must replace, not append)
  if grep -q '"keepDefault": False' "$PLUGIN_FILE"; then
    pass "AC-UI-402: keepDefault: False set (footer replaces default)"
  else
    warn "AC-UI-402: keepDefault: False not found — footer may append instead of replace"
  fi

  # Check for DIRECT_PLUGIN type
  if grep -q '"DIRECT_PLUGIN"' "$PLUGIN_FILE"; then
    pass "AC-UI-402: DIRECT_PLUGIN type specified (not iFrame)"
  else
    fail "AC-UI-402: DIRECT_PLUGIN type not found in slot registration"
  fi

  # No fallback flag — plugin slot is the only path (no dead code)
  if grep -q 'FOOTER_PLUGIN_FALLBACK_ENABLED' "$PLUGIN_FILE"; then
    fail "AC-UI-402: FOOTER_PLUGIN_FALLBACK_ENABLED should be removed (no fallback needed)"
  else
    pass "AC-UI-402: No fallback flag — clean slot-only path"
  fi

  # Verify forward-compatible try/except ImportError guard
  if grep -q 'except ImportError' "$PLUGIN_FILE"; then
    pass "AC-UI-402: try/except ImportError guard present (handles missing PLUGIN_SLOTS)"
  else
    fail "AC-UI-402: try/except ImportError guard missing"
  fi

  # MerekaFooter component must exist in mfe-env-config patch
  if grep -q 'const MerekaFooter' "$PLUGIN_FILE"; then
    pass "AC-UI-402: MerekaFooter component defined in mfe-env-config patch"
  else
    fail "AC-UI-402: MerekaFooter component missing from mfe-env-config patch in mereka_lms.py"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-403: MFE coverage — authn, dashboard, learning referenced via slot/env-config
# ---------------------------------------------------------------------------
echo "--- AC-UI-403: MFE Route Coverage via Slot Mechanism ---"

if [[ ! -f "$PLUGIN_FILE" ]]; then
  fail "AC-UI-403: mereka_lms.py not found — cannot verify MFE coverage"
else
  # env.config.jsx patch present (covers ALL MFEs that load it)
  if grep -q 'mfe-env-config' "$PLUGIN_FILE"; then
    pass "AC-UI-403: mfe-env-config patch present (covers authn, dashboard, learning MFEs)"
  else
    fail "AC-UI-403: mfe-env-config patch missing — MFEs will not receive footer customization"
  fi

  # mereka.scss import for branded CSS
  if grep -q "mereka/mereka.scss" "$PLUGIN_FILE"; then
    pass "AC-UI-403: mereka.scss import present in mfe-env-config (CSS coverage)"
  else
    fail "AC-UI-403: mereka.scss import missing from mfe-env-config patch"
  fi

  # frontend-plugin-framework dependency installed in MFE build
  if grep -q 'frontend-plugin-framework' "$PLUGIN_FILE"; then
    pass "AC-UI-403: frontend-plugin-framework installed in MFE Dockerfile (slot infra)"
  else
    fail "AC-UI-403: frontend-plugin-framework not installed — PLUGIN_OPERATIONS will be undefined"
  fi

  # PLUGIN_OPERATIONS referenced (confirms slot API usage)
  if grep -q 'PLUGIN_OPERATIONS' "$PLUGIN_FILE"; then
    pass "AC-UI-403: PLUGIN_OPERATIONS referenced (FPF slot API in use)"
  else
    fail "AC-UI-403: PLUGIN_OPERATIONS not referenced in plugin"
  fi

  # Verify authn shell coverage (authn MFE loads env.config.jsx)
  # Evidence: mfe-env-config is the env.config.jsx patch, loaded by all MFEs
  SITE_VARIANTS_COUNT=$(grep -c 'SITE_VARIANTS\|academyv2.mereka.io\|biji-biji.com' "$PLUGIN_FILE" || true)
  if [[ "$SITE_VARIANTS_COUNT" -ge 3 ]]; then
    pass "AC-UI-403: Multi-site variant mapping present (LMS, Biji-Biji, SkilOurFuture routes covered)"
  else
    warn "AC-UI-403: Multi-site variant coverage may be incomplete (found $SITE_VARIANTS_COUNT references)"
  fi

  # Check admin is explicitly excluded from slot coverage (expected)
  # Admin uses Django admin UI — no MFE footer slot applies there
  if grep -q '/admin/' "$PLUGIN_FILE"; then
    warn "AC-UI-403: /admin/ path found in plugin — admin should use Django default footer, not slot"
  else
    pass "AC-UI-403: Admin path not referenced in plugin (admin uses Django default footer as expected)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-404: LEGACY_FOOTER_REMOVAL.md exists with rollback steps
# ---------------------------------------------------------------------------
echo "--- AC-UI-404: Rollback Documentation ---"

if [[ ! -f "$OPS_DOC" ]]; then
  fail "AC-UI-404: docs/operations/LEGACY_FOOTER_REMOVAL.md not found"
else
  pass "AC-UI-404: docs/operations/LEGACY_FOOTER_REMOVAL.md exists"

  # Check for rollback section
  if grep -qi 'rollback' "$OPS_DOC"; then
    pass "AC-UI-404: Rollback procedure section present"
  else
    fail "AC-UI-404: Rollback procedure section missing from LEGACY_FOOTER_REMOVAL.md"
  fi

  # Check for specific rollback instruction (uncomment the line)
  if grep -q 'uncomment' "$OPS_DOC"; then
    pass "AC-UI-404: Rollback instructions include 'uncomment' step"
  else
    warn "AC-UI-404: Rollback section does not mention 'uncomment' — instructions may be incomplete"
  fi

  # Check for what was removed section
  if grep -qi 'what was removed\|before state\|before.*bead' "$OPS_DOC"; then
    pass "AC-UI-404: 'What Was Removed' / before state documented"
  else
    warn "AC-UI-404: Before state description not found in ops doc"
  fi

  # Check for what replaced it section
  if grep -qi 'what replaced\|replaced it\|after state' "$OPS_DOC"; then
    pass "AC-UI-404: 'What Replaced It' / after state documented"
  else
    warn "AC-UI-404: After state description not found in ops doc"
  fi

  # Check for slot reversion steps
  if grep -q 'rollback\|revert\|Rollback\|Revert\|git revert' "$OPS_DOC"; then
    pass "AC-UI-404: Rollback steps documented"
  else
    warn "AC-UI-404: Slot reversion steps not explicitly documented"
  fi

  # Check for route coverage matrix
  if grep -qi 'route.*coverage\|coverage.*matrix\|LMS.*Studio\|Studio.*LMS' "$OPS_DOC"; then
    pass "AC-UI-404: Route coverage matrix present"
  else
    warn "AC-UI-404: Route coverage matrix not found in ops doc"
  fi

  # Check for smoke check commands
  if grep -q 'smoke check\|smoke-check\|Smoke Check\|grep\|verify' "$OPS_DOC"; then
    pass "AC-UI-404: Smoke check commands present"
  else
    warn "AC-UI-404: No smoke check commands found in ops doc"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# AC-UI-405: Before/after diff evidence file exists
# ---------------------------------------------------------------------------
echo "--- AC-UI-405: Before/After Diff Evidence ---"

if [[ ! -f "$EVIDENCE_FILE" ]]; then
  fail "AC-UI-405: docs/operations/evidence/footer-migration-diff.md not found"
else
  pass "AC-UI-405: docs/operations/evidence/footer-migration-diff.md exists"

  # Check for before state
  if grep -qi 'before state\|before.*bead\|before.*dual-path' "$EVIDENCE_FILE"; then
    pass "AC-UI-405: Before state documented in evidence file"
  else
    fail "AC-UI-405: Before state not documented in evidence file"
  fi

  # Check for after state
  if grep -qi 'after state\|after.*bead\|after.*removed\|after.*disabled' "$EVIDENCE_FILE"; then
    pass "AC-UI-405: After state documented in evidence file"
  else
    fail "AC-UI-405: After state not documented in evidence file"
  fi

  # Check for key differences section
  if grep -qi 'key difference\|differences\|before.*after' "$EVIDENCE_FILE"; then
    pass "AC-UI-405: Key differences highlighted in evidence file"
  else
    warn "AC-UI-405: Key differences section not found in evidence file"
  fi

  # Check for code diff snippets (backtick code blocks)
  CODEBLOCK_COUNT=$(grep -c '```' "$EVIDENCE_FILE" || true)
  if [[ "$CODEBLOCK_COUNT" -ge 4 ]]; then
    pass "AC-UI-405: Evidence file contains code diff snippets ($CODEBLOCK_COUNT code block markers)"
  else
    warn "AC-UI-405: Only $CODEBLOCK_COUNT code block markers found — may lack sufficient diff evidence"
  fi

  # Check evidence references the bead
  if grep -q '1rns\|AC-UI-401\|AC-UI-402' "$EVIDENCE_FILE"; then
    pass "AC-UI-405: Evidence file references bead 1rns and AC IDs"
  else
    warn "AC-UI-405: Evidence file does not reference bead 1rns — traceability incomplete"
  fi
fi

echo ""
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS | ${RED}FAIL:${NC} $FAIL | ${YELLOW}WARN:${NC} $WARN"
echo ""

if [[ "$FAIL" -gt 0 ]]; then
  echo "Remediation:"
  echo "  AC-UI-401: Comment out the 'updated = updated.replace(\"RenderWidget: <Footer />\"...' line"
  echo "             in infrastructure/tutor/apply-patches.sh"
  echo "  AC-UI-402: Ensure footer_slot PLUGIN_SLOTS.add_item is present in mereka_lms.py"
  echo "  AC-UI-403: Ensure mfe-env-config patch and frontend-plugin-framework are in mereka_lms.py"
  echo "  AC-UI-404: Create docs/operations/LEGACY_FOOTER_REMOVAL.md with rollback steps"
  echo "  AC-UI-405: Create docs/operations/evidence/footer-migration-diff.md with before/after diff"
  exit 1
fi

exit 0
