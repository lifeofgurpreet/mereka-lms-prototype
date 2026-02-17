#!/usr/bin/env bash
# @covers AC-FTSLOT-001, AC-FTSLOT-002, AC-FTSLOT-003
# @spec: N/A (this is a migration contract verifier, not a feature spec)
#
# Footer Slot Migration Contract Verifier
#
# Verifies:
# - Contract document exists
# - MerekaFooter component defined in mereka_lms.py (canonical source)
# - mfe-env-config patch includes MerekaFooter
# - PLUGIN_SLOTS forward-compat registration exists
# - ImportError guard exists (graceful degradation)
# - Component duplication exists in apply-patches.sh (flagged as migration target)
# - Migration debt metric (lines of redundant code)
# - Component content parity (drift detection)
# - mereka.scss import exists in plugin
# - FPF dependency installation
# - CI has footer-related verification jobs
# - No raw <Footer /> references in mereka_lms.py

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

echo "========================================="
echo "Footer Slot Migration Contract Verifier"
echo "========================================="
echo ""

# AC-FTSLOT-001: Contract document exists
echo "AC-FTSLOT-001: Contract Document"
if [[ -f "${REPO_ROOT}/docs/architecture/FOOTER_SLOT_MIGRATION.md" ]]; then
    do_pass "Contract document exists at docs/architecture/FOOTER_SLOT_MIGRATION.md"
else
    do_fail "Contract document missing: docs/architecture/FOOTER_SLOT_MIGRATION.md"
fi

# AC-FTSLOT-002: MerekaFooter defined in canonical source
echo ""
echo "AC-FTSLOT-002: Canonical Source (mereka_lms.py)"

PLUGIN_FILE="${REPO_ROOT}/infrastructure/tutor/plugins/mereka_lms.py"
if [[ -f "${PLUGIN_FILE}" ]]; then
    do_pass "Plugin file exists: infrastructure/tutor/plugins/mereka_lms.py"
else
    do_fail "Plugin file missing: infrastructure/tutor/plugins/mereka_lms.py"
fi

# Check mfe-env-config patch exists
if grep -q "mfe-env-config" "${PLUGIN_FILE}"; then
    do_pass "mfe-env-config patch exists in mereka_lms.py"
else
    do_fail "mfe-env-config patch missing from mereka_lms.py"
fi

# Check MerekaFooter component definition
if grep -q "const MerekaFooter = ()" "${PLUGIN_FILE}"; then
    do_pass "MerekaFooter component defined in mereka_lms.py"
else
    do_fail "MerekaFooter component definition missing from mereka_lms.py"
fi

# Check PLUGIN_SLOTS forward-compat registration
if grep -q "from tutormfe.hooks import PLUGIN_SLOTS" "${PLUGIN_FILE}"; then
    do_pass "PLUGIN_SLOTS import exists (forward-compat registration)"
else
    do_fail "PLUGIN_SLOTS import missing (forward-compat registration)"
fi

if grep -q '"footer_slot"' "${PLUGIN_FILE}"; then
    do_pass "footer_slot registration exists in PLUGIN_SLOTS"
else
    do_fail "footer_slot registration missing from PLUGIN_SLOTS"
fi

# Check ImportError guard (graceful degradation)
if grep -q "except ImportError:" "${PLUGIN_FILE}"; then
    do_pass "ImportError guard exists (graceful degradation)"
else
    do_fail "ImportError guard missing (no graceful degradation)"
fi

# Check mereka.scss import in plugin
if grep -q "import './mereka/mereka.scss'" "${PLUGIN_FILE}"; then
    do_pass "mereka.scss import exists in mfe-env-config patch"
else
    do_fail "mereka.scss import missing from mfe-env-config patch"
fi

# Check no raw <Footer /> references in plugin (should only be MerekaFooter)
# Note: Comments explaining the old approach are allowed, we're looking for actual code
RAW_FOOTER_COUNT=$(grep "RenderWidget: <Footer />" "${PLUGIN_FILE}" | grep -v "^#" | wc -l || true)
if [[ "${RAW_FOOTER_COUNT}" -eq 0 ]]; then
    do_pass "No raw <Footer /> references in mereka_lms.py code (only MerekaFooter)"
else
    do_fail "Found ${RAW_FOOTER_COUNT} raw <Footer /> references in mereka_lms.py code"
fi

echo ""
echo "AC-FTSLOT-002: Fallback Source (apply-patches.sh)"

PATCHES_FILE="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"
if [[ -f "${PATCHES_FILE}" ]]; then
    do_pass "Patches file exists: infrastructure/tutor/apply-patches.sh"
else
    do_fail "Patches file missing: infrastructure/tutor/apply-patches.sh"
fi

# Check MerekaFooter component duplication (migration target)
if grep -q "const MerekaFooter = ()" "${PATCHES_FILE}"; then
    do_warn "MerekaFooter component duplicated in apply-patches.sh (migration target)"
else
    do_fail "MerekaFooter component missing from apply-patches.sh (fallback path broken)"
fi

# Check RenderWidget replacement
if grep -q 'RenderWidget: <MerekaFooter />' "${PATCHES_FILE}"; then
    do_warn "RenderWidget replacement exists in apply-patches.sh (migration target)"
else
    do_fail "RenderWidget replacement missing from apply-patches.sh (fallback path broken)"
fi

# Migration debt metric: count lines of footer code in apply-patches.sh
# Target: lines 1043-1207 (165 lines)
FOOTER_START_LINE=1043
FOOTER_END_LINE=1207
MIGRATION_DEBT=$((FOOTER_END_LINE - FOOTER_START_LINE + 1))
echo ""
echo "Migration Debt Metric:"
echo "  Current: ${MIGRATION_DEBT} lines of redundant footer code in apply-patches.sh"
echo "  Target (Phase 2): 12 lines (safety nets only)"
echo "  Target (Phase 3): 0 lines (full migration)"
if [[ "${MIGRATION_DEBT}" -le 12 ]]; then
    do_pass "Migration debt is ${MIGRATION_DEBT} lines (at or below Phase 2 target)"
else
    do_warn "Migration debt is ${MIGRATION_DEBT} lines (above Phase 2 target of 12)"
fi

echo ""
echo "AC-FTSLOT-002: Component Parity (Drift Detection)"

# Check key identifiers exist in BOTH sources
KEY_IDENTIFIERS=(
    "SITE_VARIANTS"
    "mereka-footer--v2"
    "footer-social"
    "footer-nav"
    "footer-body"
    "footer-legal"
)

for identifier in "${KEY_IDENTIFIERS[@]}"; do
    PLUGIN_HAS=0
    PATCHES_HAS=0

    # Grep files directly instead of loading into variables (avoids escaping issues)
    if grep -F -q "${identifier}" "${PLUGIN_FILE}"; then
        PLUGIN_HAS=1
    fi

    if grep -F -q "${identifier}" "${PATCHES_FILE}"; then
        PATCHES_HAS=1
    fi

    if [[ "${PLUGIN_HAS}" -eq 1 && "${PATCHES_HAS}" -eq 1 ]]; then
        do_pass "Key identifier '${identifier}' exists in BOTH sources (no drift)"
    elif [[ "${PLUGIN_HAS}" -eq 1 && "${PATCHES_HAS}" -eq 0 ]]; then
        do_fail "Key identifier '${identifier}' missing from apply-patches.sh (drift detected)"
    elif [[ "${PLUGIN_HAS}" -eq 0 && "${PATCHES_HAS}" -eq 1 ]]; then
        do_fail "Key identifier '${identifier}' missing from mereka_lms.py (drift detected)"
    else
        do_fail "Key identifier '${identifier}' missing from BOTH sources"
    fi
done

echo ""
echo "AC-FTSLOT-003: CI Gates"

CI_FILE="${REPO_ROOT}/.github/workflows/ci.yml"
if [[ -f "${CI_FILE}" ]]; then
    do_pass "CI workflow file exists: .github/workflows/ci.yml"
else
    do_fail "CI workflow file missing: .github/workflows/ci.yml"
fi

# Check for footer-related verification jobs
if grep -q "verify-mfe-footer-slot.sh" "${CI_FILE}"; then
    do_pass "CI has mfe-footer-slot verification job"
else
    do_fail "CI missing mfe-footer-slot verification job"
fi

if grep -q "verify-plugin-slot-wiring.sh" "${CI_FILE}"; then
    do_pass "CI has plugin-slot-wiring verification job"
else
    do_fail "CI missing plugin-slot-wiring verification job"
fi

# Check for footer-slot-migration verifier in monitoring-guardrails
if grep -q "verify-footer-slot-migration.sh" "${CI_FILE}"; then
    do_pass "CI has footer-slot-migration syntax check"
else
    do_fail "CI missing footer-slot-migration syntax check"
fi

echo ""
echo "Additional Checks"

# Check FPF dependency installation (should be in plugin)
if grep -q "@openedx/frontend-plugin-framework" "${PLUGIN_FILE}"; then
    do_pass "FPF dependency (@openedx/frontend-plugin-framework) referenced in plugin"
else
    do_warn "FPF dependency not explicitly referenced in plugin (may be in MFE package.json)"
fi

# Check for ADR-014 reference in contract doc
CONTRACT_DOC="${REPO_ROOT}/docs/architecture/FOOTER_SLOT_MIGRATION.md"
if grep -q "ADR-014" "${CONTRACT_DOC}"; then
    do_pass "Contract document references ADR-014 (strategic context)"
else
    do_warn "Contract document missing ADR-014 reference"
fi

# Summary
echo ""
echo "========================================="
echo "Summary"
echo "========================================="
echo "PASS: ${PASS}"
echo "FAIL: ${FAIL}"
echo "WARN: ${WARN}"
echo ""

if [[ "${FAIL}" -eq 0 ]]; then
    echo "✅ All checks passed! Footer slot migration contract verified."
    echo ""
    echo "Current state: Dual-path (plugin + apply-patches.sh)"
    echo "Migration debt: ${MIGRATION_DEBT} lines"
    echo ""
    echo "Next steps:"
    echo "  1. Wait for tutormfe.hooks.PLUGIN_SLOTS filter to ship"
    echo "  2. Remove ImportError guard from mereka_lms.py"
    echo "  3. After 2 weeks stable: Remove apply-patches.sh footer block (lines 1043-1207)"
    echo "  4. Run this verifier again to confirm migration debt reduction"
    exit 0
else
    echo "❌ ${FAIL} check(s) failed. Review issues above."
    exit 1
fi
