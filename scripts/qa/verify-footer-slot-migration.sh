#!/usr/bin/env bash
# @covers AC-FTSLOT-001, AC-FTSLOT-002, AC-FTSLOT-003
# @spec: N/A (this is a migration contract verifier, not a feature spec)
#
# Footer Slot Migration Contract Verifier
#
# Updated for current phase:
# - Canonical footer implementation is in infrastructure/tutor/plugins/mereka_lms.py
#   via PLUGIN_SLOTS + mfe-env-config runtime definitions.
# - apply-patches now only runs footer-component asset-copy logic.
# - CI gate execution is driven by .github/ci-scripts-static.txt.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PASS=0
FAIL=0
WARN=0

PLUGIN_FILE="${REPO_ROOT}/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES_FILE="${REPO_ROOT}/infrastructure/tutor/apply-patches.sh"
FOOTER_PATCH_FILE="${REPO_ROOT}/infrastructure/tutor/patches/footer-component.sh"
CONTRACT_DOC="${REPO_ROOT}/docs/architecture/FOOTER_SLOT_MIGRATION.md"
CI_STATIC_FILE="${REPO_ROOT}/.github/ci-scripts-static.txt"

do_pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }


echo "========================================="
echo "Footer Slot Migration Contract Verifier"
echo "========================================="
echo ""

# AC-FTSLOT-001: Contract document exists
# ---------------------------------------------------------------------------
echo "AC-FTSLOT-001: Contract Document"
if [[ -f "${CONTRACT_DOC}" ]]; then
    do_pass "Contract document exists at docs/architecture/FOOTER_SLOT_MIGRATION.md"
else
    do_fail "Contract document missing: docs/architecture/FOOTER_SLOT_MIGRATION.md"
fi

# AC-FTSLOT-002: Canonical source checks (mereka_lms.py)
# ---------------------------------------------------------------------------
echo ""
echo "AC-FTSLOT-002: Canonical Source (mereka_lms.py)"

if [[ -f "${PLUGIN_FILE}" ]]; then
    do_pass "Plugin file exists: infrastructure/tutor/plugins/mereka_lms.py"
else
    do_fail "Plugin file missing: infrastructure/tutor/plugins/mereka_lms.py"
fi

if grep -q "mfe-env-config-runtime-definitions" "${PLUGIN_FILE}"; then
    do_pass "mfe-env-config-runtime-definitions patch exists in plugin"
else
    do_fail "mfe-env-config-runtime-definitions patch missing from plugin"
fi

if grep -q "const MerekaFooter =" "${PLUGIN_FILE}"; then
    do_pass "MerekaFooter component defined in plugin runtime definitions"
else
    do_fail "MerekaFooter component definition missing from plugin"
fi

if grep -q "from tutormfe\.hooks import PLUGIN_SLOTS" "${PLUGIN_FILE}"; then
    do_pass "PLUGIN_SLOTS import exists"
else
    do_fail "PLUGIN_SLOTS import missing"
fi

if grep -q 'org\.openedx\.frontend\.layout\.footer\.v1' "${PLUGIN_FILE}"; then
    do_pass "Footer slot registration targets org.openedx.frontend.layout.footer.v1"
else
    do_fail "Footer slot target org.openedx.frontend.layout.footer.v1 missing"
fi

if grep -q 'org\.openedx\.frontend\.layout\.header_logo\.v1' "${PLUGIN_FILE}"; then
    do_pass "Header logo slot registration present"
else
    do_fail "Header logo slot registration missing"
fi

if grep -Eq 'org\.openedx\.frontend\.learner_dashboard\.(widget_sidebar|sidebar)\.v1' "${PLUGIN_FILE}"; then
    do_pass "Learner dashboard slot registration present"
else
    do_fail "Learner dashboard slot registration missing"
fi

if grep -q "PLUGIN_SLOTS.add_items\|PLUGIN_SLOTS.add_item" "${PLUGIN_FILE}"; then
    do_pass "PLUGIN_SLOTS registration block present"
else
    do_fail "PLUGIN_SLOTS registration block missing"
fi

if grep -q "except ImportError:" "${PLUGIN_FILE}"; then
    do_warn "ImportError guard detected (legacy fallback marker); not blocking in current phase"
else
    do_pass "No ImportError guard required for current active PLUGIN_SLOTS-first path"
fi

if grep -q "import './mereka/mereka.scss'" "${PLUGIN_FILE}"; then
    do_pass "mereka.scss import exists in mfe-env-config patch"
else
    do_fail "mereka.scss import missing from mfe-env-config patch"
fi

# No inline Indigo footer widgets should remain in plugin runtime JS patch.
RAW_FOOTER_COUNT=$(grep -c "RenderWidget: <Footer />" "${PLUGIN_FILE}" || true)
if [[ "${RAW_FOOTER_COUNT}" -eq 0 ]]; then
    do_pass "No RenderWidget: <Footer /> references in plugin patch"
else
    do_fail "Found ${RAW_FOOTER_COUNT} RenderWidget: <Footer /> references in plugin patch"
fi

# AC-FTSLOT-002: Fallback source checks (apply-patches)
# ---------------------------------------------------------------------------
echo ""
echo "AC-FTSLOT-002: Fallback Source (apply-patches.sh)"

if [[ -f "${PATCHES_FILE}" ]]; then
    do_pass "Patches file exists: infrastructure/tutor/apply-patches.sh"
else
    do_fail "Patches file missing: infrastructure/tutor/apply-patches.sh"
fi

if [[ -f "${FOOTER_PATCH_FILE}" ]]; then
    do_pass "Footer patch module exists: infrastructure/tutor/patches/footer-component.sh"
else
    do_fail "Footer patch module missing: infrastructure/tutor/patches/footer-component.sh"
fi

if grep -q 'source "$PATCHES_DIR/footer-component.sh"' "${PATCHES_FILE}"; then
    do_pass "apply-patches sources footer-component.sh"
else
    do_fail "apply-patches does not source footer-component.sh"
fi

if grep -q 'apply_footer_component_patch' "${PATCHES_FILE}"; then
    do_pass "apply-patches calls apply_footer_component_patch"
else
    do_fail "apply-patches does not invoke apply_footer_component_patch"
fi

# Footer fallback logic in apply-patches should be limited to asset sync, not component duplication.
if grep -q "MerekaFooter" "${PATCHES_FILE}"; then
    do_fail "Duplicate footer component logic found in apply-patches.sh"
else
    do_pass "No footer component logic duplicated in apply-patches.sh"
fi

if grep -q "RenderWidget: <MerekaFooter" "${PATCHES_FILE}"; then
    do_fail "Footer RenderWidget replacement still exists in apply-patches.sh"
else
    do_pass "No footer RenderWidget replacement in apply-patches.sh"
fi

# Migration debt metric (current state): count duplicate footer block indicators in apply-patches.
DUP_FOOTER_LINES=$(
  { grep -E "RenderWidget: <Footer|RenderWidget: <MerekaFooter|<Footer />|footer-slot|footer-container|site variants|mereka-footer--v2" "${PATCHES_FILE}" || true; } \
    | wc -l | tr -d ' '
)
if [[ "${DUP_FOOTER_LINES}" -eq 0 ]]; then
    do_pass "Migration debt is 0 lines of footer duplication in apply-patches.sh"
else
    do_warn "Migration debt is ${DUP_FOOTER_LINES} footer-logic line(s) in apply-patches.sh"
fi

# AC-FTSLOT-002: Drift detection (guards)
# ---------------------------------------------------------------------------
echo ""
echo "AC-FTSLOT-002: Drift / Duplication Guards"

KEY_IDENTIFIERS=(
  "SITE_VARIANTS"
  "mereka-footer--v2"
  "footer-social"
  "footer-nav"
  "footer-body"
  "footer-legal"
)

for identifier in "${KEY_IDENTIFIERS[@]}"; do
    if grep -F -q "${identifier}" "${PLUGIN_FILE}"; then
        PLUGIN_HAS=1
    else
        PLUGIN_HAS=0
    fi

    if grep -F -q "${identifier}" "${PATCHES_FILE}"; then
        PATCHES_HAS=1
    else
        PATCHES_HAS=0
    fi

    if [[ "${PLUGIN_HAS}" -eq 1 && "${PATCHES_HAS}" -eq 0 ]]; then
        do_pass "Identifier '${identifier}' present in canonical plugin and intentionally not duplicated in apply-patches"
    elif [[ "${PLUGIN_HAS}" -eq 1 && "${PATCHES_HAS}" -eq 1 ]]; then
        do_fail "Identifier '${identifier}' duplicated in apply-patches (drift risk)"
    else
        do_fail "Identifier '${identifier}' missing from canonical plugin"
    fi

done

# AC-FTSLOT-003: CI gate wiring
# ---------------------------------------------------------------------------
echo ""
echo "AC-FTSLOT-003: CI Gates"

if [[ -f "${CI_STATIC_FILE}" ]]; then
    do_pass "Static CI script manifest exists: .github/ci-scripts-static.txt"
else
    do_fail "Static CI script manifest missing: .github/ci-scripts-static.txt"
fi

if [[ -f "${CI_STATIC_FILE}" ]] && grep -q "verify-mfe-footer-slot.sh" "${CI_STATIC_FILE}"; then
    do_pass "Static CI includes verify-mfe-footer-slot.sh"
else
    do_fail "Static CI missing verify-mfe-footer-slot.sh"
fi

if [[ -f "${CI_STATIC_FILE}" ]] && grep -q "verify-plugin-slot-wiring.sh" "${CI_STATIC_FILE}"; then
    do_pass "Static CI includes verify-plugin-slot-wiring.sh"
else
    do_fail "Static CI missing verify-plugin-slot-wiring.sh"
fi

if [[ -f "${CI_STATIC_FILE}" ]] && grep -q "verify-footer-slot-migration.sh" "${CI_STATIC_FILE}"; then
    do_pass "Static CI includes verify-footer-slot-migration.sh"
elif [[ -f "${CI_STATIC_FILE}" ]]; then
    do_warn "Static CI does not include verify-footer-slot-migration.sh (informational)"
else
    do_fail "Static CI script manifest missing: .github/ci-scripts-static.txt"
fi

# Additional checks
# ---------------------------------------------------------------------------
echo ""
echo "Additional Checks"

if grep -q "@openedx/frontend-plugin-framework" "${PLUGIN_FILE}"; then
    do_pass "FPF dependency (@openedx/frontend-plugin-framework) referenced in plugin"
else
    do_warn "FPF dependency not explicitly referenced in plugin"
fi

if grep -q "ADR-014" "${CONTRACT_DOC}"; then
    do_pass "Contract document references ADR-014"
else
    do_warn "Contract document missing ADR-014 reference"
fi

# Summary
# ---------------------------------------------------------------------------
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
    echo "Current state: plugin-first, single-source runtime definitions + slot registration;"
    echo "apply-patches is safety-net asset path only."
    echo ""
    echo "Next steps:"
    echo "  1. Keep plugin registration stable across Tutor releases"
    echo "  2. Keep duplicate footer JSX removal checks green"
    echo "  3. Re-run this verifier after any apply-patches refactors"
    exit 0
else
    echo "❌ ${FAIL} check(s) failed. Review issues above."
    exit 1
fi
