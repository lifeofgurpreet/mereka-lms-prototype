#!/usr/bin/env bash
# verify-mfe-footer-plugin-slot.sh
# Checks that the MFE footer is registered via Tutor plugin slots (not string surgery).
#
# Exit codes: 0 = all checks PASS/SKIP, 1 = one or more FAIL
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PLUGIN_PY="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
FOOTER_SH="$REPO_ROOT/infrastructure/tutor/patches/footer-component.sh"

pass=0
fail=0
skip=0

_pass() { echo "PASS: $1"; (( pass++ )) || true; }
_fail() { echo "FAIL: $1"; (( fail++ )) || true; }
_skip() { echo "SKIP: $1"; (( skip++ )) || true; }

echo "=== verify-mfe-footer-plugin-slot ==="

# 1. mereka_lms.py exists
if [ -f "$PLUGIN_PY" ]; then
  _pass "mereka_lms.py exists"
else
  _fail "mereka_lms.py not found at $PLUGIN_PY"
fi

# 2. PLUGIN_SLOTS imported from tutormfe.hooks
if grep -qF "from tutormfe.hooks import PLUGIN_SLOTS" "$PLUGIN_PY"; then
  _pass "PLUGIN_SLOTS imported unconditionally from tutormfe.hooks"
else
  _fail "PLUGIN_SLOTS not imported from tutormfe.hooks in mereka_lms.py"
fi

# 3. Canonical footer slot name is registered
if grep -qF "org.openedx.frontend.layout.footer.v1" "$PLUGIN_PY"; then
  _pass "footer slot 'org.openedx.frontend.layout.footer.v1' registered in mereka_lms.py"
else
  _fail "footer slot 'org.openedx.frontend.layout.footer.v1' NOT found in mereka_lms.py"
fi

# 4. MerekaFooter component defined in mfe-env-config-runtime-definitions patch
if grep -qF "mfe-env-config-runtime-definitions" "$PLUGIN_PY" && \
   grep -qF "const MerekaFooter" "$PLUGIN_PY"; then
  _pass "MerekaFooter component defined in mfe-env-config-runtime-definitions patch"
else
  _fail "MerekaFooter not found in mfe-env-config-runtime-definitions patch in mereka_lms.py"
fi

# 5. SCSS import is in mfe-env-config-buildtime-imports (not string surgery)
if grep -qF "mfe-env-config-buildtime-imports" "$PLUGIN_PY" && \
   grep -qF "mereka/mereka.scss" "$PLUGIN_PY"; then
  _pass "mereka.scss import in mfe-env-config-buildtime-imports patch"
else
  _fail "mereka.scss import not found in mfe-env-config-buildtime-imports in mereka_lms.py"
fi

# 6. footer-component.sh does NOT contain old JSX string surgery code
# Note: check for code patterns, not comment references to them.
if [ -f "$FOOTER_SH" ]; then
  if grep -qF "RenderWidget: IndigoFooter," "$FOOTER_SH" || \
     grep -qF "const themePluginSlot" "$FOOTER_SH" || \
     grep -qF "FOOTERPY" "$FOOTER_SH"; then
    _fail "footer-component.sh still contains old string surgery code — remove it"
  else
    _pass "footer-component.sh free of JSX string surgery"
  fi
else
  _fail "footer-component.sh not found at $FOOTER_SH"
fi

# 7. footer-component.sh does NOT inject MerekaFooter component via Python heredoc
if [ -f "$FOOTER_SH" ]; then
  if grep -qF "const MerekaFooter" "$FOOTER_SH"; then
    _fail "footer-component.sh still injects MerekaFooter via string surgery"
  else
    _pass "footer-component.sh does not inject MerekaFooter (correct: it belongs in mereka_lms.py)"
  fi
fi

# 8. Rendered env.config.jsx (if present) uses slot-based MerekaFooter
RENDERED_ENV="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/env.config.jsx"
if [ -f "$RENDERED_ENV" ]; then
  if grep -qF "MerekaFooter" "$RENDERED_ENV"; then
    _pass "rendered env.config.jsx contains MerekaFooter reference"
  else
    _skip "rendered env.config.jsx exists but lacks MerekaFooter — may be stale; run 'tutor config save'"
  fi
  # Must NOT contain the old fallback comment that indicated string surgery was used
  if grep -qF "MIGRATED-TO-SLOT: footer_slot (fallback)" "$RENDERED_ENV"; then
    _fail "rendered env.config.jsx still has old 'MIGRATED-TO-SLOT (fallback)' marker — string surgery still running"
  else
    _pass "rendered env.config.jsx has no old string surgery marker"
  fi
else
  _skip "tutor_env not rendered yet — run 'tutor config save' to generate env.config.jsx"
fi

# 9. Python import check: tutormfe.hooks.PLUGIN_SLOTS is importable
if command -v python3 &>/dev/null; then
  if python3 -c "from tutormfe.hooks import PLUGIN_SLOTS" 2>/dev/null; then
    _pass "tutormfe.hooks.PLUGIN_SLOTS importable in current Python environment"
  else
    _skip "tutormfe.hooks.PLUGIN_SLOTS not importable (venv not active or tutormfe not installed)"
  fi
else
  _skip "python3 not found — skipping import check"
fi

echo ""
echo "Results: ${pass} PASS, ${fail} FAIL, ${skip} SKIP"

if [ "$fail" -gt 0 ]; then
  exit 1
fi
exit 0
