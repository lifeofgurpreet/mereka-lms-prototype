#!/usr/bin/env bash
# verify-oep65-readiness.sh
# @spec: tutor-configuration_spec.md
#
# Audit OEP-65 (Frontend Composability) readiness for the Mereka MFE build.
# Checks the static repo artifacts — no live cluster or Docker daemon required.
#
# Reports:
#   PASS  — requirement is met
#   FAIL  — requirement is not met (should be fixed)
#   SKIP  — cannot be checked statically (requires live cluster or built image)
#
# Usage:
#   ./scripts/qa/verify-oep65-readiness.sh
#   ./scripts/qa/verify-oep65-readiness.sh --fail-on-skip
#
# Exit codes:
#   0 — all checks PASS (or SKIP, unless --fail-on-skip)
#   1 — at least one FAIL
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
PLUGIN_BUNDLE=""

if mereka_plugin_has_any "$REPO_ROOT"; then
  PLUGIN_BUNDLE="$(mktemp -t mereka-plugin-contract.XXXXXX)"
  while IFS= read -r plugin_file; do
    cat "$plugin_file" >>"$PLUGIN_BUNDLE"
    printf '\n' >>"$PLUGIN_BUNDLE"
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
fi

cleanup() {
  if [[ -n "$PLUGIN_BUNDLE" && -f "$PLUGIN_BUNDLE" ]]; then
    rm -f "$PLUGIN_BUNDLE"
  fi
}
trap cleanup EXIT

# ---------------------------------------------------------------------------
# CLI options
# ---------------------------------------------------------------------------
FAIL_ON_SKIP=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fail-on-skip) FAIL_ON_SKIP=1; shift ;;
    -h|--help)
      echo "Usage: $0 [--fail-on-skip]"
      exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# Counters and helpers
# ---------------------------------------------------------------------------
PASS=0
FAIL=0
SKIP=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }
skip() { echo "  SKIP  $1"; SKIP=$((SKIP + 1)); }

section() { echo ""; echo "── $1 ──"; }

# Paths
RENDERED_DOCKERFILE="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
SNAPSHOT_DOCKERFILE="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"
if [[ -f "$RENDERED_DOCKERFILE" ]]; then
  DOCKERFILE="$RENDERED_DOCKERFILE"
else
  DOCKERFILE="$SNAPSHOT_DOCKERFILE"
fi
ENV_CONFIG_JSX="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/mereka/env.config.jsx"
PLUGIN_PY="${PLUGIN_BUNDLE:-$PLUGIN_MAIN}"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
READINESS_DOC="$REPO_ROOT/docs/reference/architecture/OEP65_MODULE_READINESS.md"
RUNTIME_CONFIG_DOC="$REPO_ROOT/docs/reference/architecture/MFE_RUNTIME_CONFIG.md"
PATCHES_INVENTORY_DOC="$REPO_ROOT/docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md"

# ---------------------------------------------------------------------------
echo "OEP-65 Frontend Composability Readiness Check"
echo "Repository: $REPO_ROOT"
echo "Date: $(date -u +%Y-%m-%dT%H:%MZ)"

# ===========================================================================
section "1. Documentation completeness"
# ===========================================================================

if [[ -f "$READINESS_DOC" ]]; then
  pass "OEP65_MODULE_READINESS.md exists"
else
  fail "OEP65_MODULE_READINESS.md missing at $READINESS_DOC"
fi

if [[ -f "$RUNTIME_CONFIG_DOC" ]]; then
  pass "MFE_RUNTIME_CONFIG.md exists (T108)"
else
  fail "MFE_RUNTIME_CONFIG.md missing (T108 output expected)"
fi

if [[ -f "$PATCHES_INVENTORY_DOC" ]]; then
  pass "TUTOR_PATCHES_INVENTORY.md exists (T109)"
else
  fail "TUTOR_PATCHES_INVENTORY.md missing (T109 output expected)"
fi

# ===========================================================================
section "2. Plugin Framework installation (OEP-65 prerequisite)"
# ===========================================================================

if [[ ! -f "$DOCKERFILE" ]]; then
  skip "Dockerfile not found at $DOCKERFILE — cannot check FPF installation"
else
  # Count MFE stages that install frontend-plugin-framework
  fpf_count="$(grep -c "@openedx/frontend-plugin-framework" "$DOCKERFILE" || true)"
  if [[ "$fpf_count" -ge 1 ]]; then
    pass "@openedx/frontend-plugin-framework installed in Dockerfile ($fpf_count occurrence(s))"
  else
    fail "@openedx/frontend-plugin-framework not found in $DOCKERFILE"
  fi

  # Verify it is installed with --legacy-peer-deps (required for ^1.8.0)
  if grep -q "legacy-peer-deps.*frontend-plugin-framework\|frontend-plugin-framework.*legacy-peer-deps" "$DOCKERFILE"; then
    pass "frontend-plugin-framework installed with --legacy-peer-deps"
  else
    fail "frontend-plugin-framework not installed with --legacy-peer-deps (peer dep conflicts expected)"
  fi
fi

if [[ -f "$PLUGIN_PY" ]]; then
  if grep -q "mfe-dockerfile-post-npm-install" "$PLUGIN_PY"; then
    pass "mereka_lms.py declares mfe-dockerfile-post-npm-install ENV_PATCH (FPF via Tutor hook)"
  else
    fail "mereka_lms.py missing mfe-dockerfile-post-npm-install ENV_PATCH"
  fi
else
  skip "mereka_lms.py not found — cannot verify ENV_PATCH declarations"
fi

# ===========================================================================
section "3. Plugin Slots (OEP-65 primary extension point)"
# ===========================================================================

if [[ ! -f "$PLUGIN_PY" ]]; then
  skip "mereka_lms.py not found — cannot verify PLUGIN_SLOTS registration"
else
  if grep -q "PLUGIN_SLOTS" "$PLUGIN_PY"; then
    pass "mereka_lms.py uses PLUGIN_SLOTS for slot registration"
  else
    fail "mereka_lms.py does not use PLUGIN_SLOTS — footer may not be slot-driven"
  fi

  if grep -q "footer_slot" "$PLUGIN_PY"; then
    pass "footer_slot registered in mereka_lms.py"
  else
    fail "footer_slot not registered in mereka_lms.py"
  fi

  if grep -q "mfe-env-config-runtime-definitions" "$PLUGIN_PY"; then
    pass "mereka_lms.py declares mfe-env-config-runtime-definitions patch (slot component injection)"
  else
    fail "mereka_lms.py missing mfe-env-config-runtime-definitions patch"
  fi
fi

if [[ -f "$ENV_CONFIG_JSX" ]]; then
  if grep -q "PLUGIN_OPERATIONS" "$ENV_CONFIG_JSX"; then
    pass "env.config.jsx uses PLUGIN_OPERATIONS from frontend-plugin-framework"
  else
    fail "env.config.jsx does not reference PLUGIN_OPERATIONS"
  fi

  if grep -q "footer_slot" "$ENV_CONFIG_JSX"; then
    pass "env.config.jsx wires footer_slot"
  else
    fail "env.config.jsx does not wire footer_slot"
  fi

  if grep -q "DIRECT_PLUGIN" "$ENV_CONFIG_JSX"; then
    pass "env.config.jsx uses DIRECT_PLUGIN (OEP-50 slot pattern)"
  else
    fail "env.config.jsx does not use DIRECT_PLUGIN"
  fi
else
  skip "env.config.jsx not found at $ENV_CONFIG_JSX (run apply-patches.sh to generate)"
fi

# ===========================================================================
section "4. Brand package pattern (OEP-65 endorsed customisation)"
# ===========================================================================

if [[ ! -f "$DOCKERFILE" ]]; then
  skip "Dockerfile not found — cannot check brand package"
else
  if grep -q "/openedx/app/node_modules/@edx/brand" "$DOCKERFILE" \
    && grep -q "materialized local brand package" "$DOCKERFILE"; then
    pass "Brand package materialized via local brand-mereka overlay at @edx/brand"
  elif grep -q "@edx/brand@file:./brand-mereka" "$DOCKERFILE"; then
    fail "Brand package still uses post-npm @edx/brand file install instead of deterministic materialization"
  else
    fail "Local @edx/brand materialization not found in Dockerfile — current brand package pattern not applied"
  fi
fi

if [[ -f "$ENV_CONFIG_JSX" ]]; then
  if grep -q "mereka.scss\|mereka/mereka" "$ENV_CONFIG_JSX"; then
    pass "env.config.jsx imports Mereka SCSS (brand compiled into bundle)"
  else
    fail "env.config.jsx does not import Mereka SCSS"
  fi
else
  skip "env.config.jsx not found — cannot check SCSS import"
fi

# ===========================================================================
section "5. Runtime config alignment (OEP-65 gap: cookie domain baking)"
# ===========================================================================

if [[ ! -f "$DOCKERFILE" ]]; then
  skip "Dockerfile not found — cannot check cookie domain baking"
else
  # Count hardcoded cookie domain ARGs — OEP-65 says these should NOT be build-time
  cookie_count="$(grep -c "SESSION_COOKIE_DOMAIN\|CSRF_COOKIE_DOMAIN" "$DOCKERFILE" || true)"
  if [[ "$cookie_count" -eq 0 ]]; then
    pass "No build-time cookie domain ARGs found (runtime-driven — Gap 2 resolved)"
  else
    fail "Build-time cookie domain baking detected ($cookie_count line(s)) — violates OEP-65 runtime-first principle (see Gap 2 in OEP65_MODULE_READINESS.md)"
  fi

  # Check ENABLE_NEW_RELIC baking
  newrelic_count="$(grep -c "ARG ENABLE_NEW_RELIC\|ENV ENABLE_NEW_RELIC" "$DOCKERFILE" || true)"
  if [[ "$newrelic_count" -eq 0 ]]; then
    pass "ENABLE_NEW_RELIC not baked at build time (runtime-driven — Gap 2 resolved)"
  else
    fail "ENABLE_NEW_RELIC baked at build time ($newrelic_count line(s)) — should be LMS mfe_config key (see Gap 2 in OEP65_MODULE_READINESS.md)"
  fi

  # MFE_CONFIG_API_URL should be relative (not hardcoded LMS URL)
  if grep -q "MFE_CONFIG_API_URL=/api/mfe_config/v1" "$DOCKERFILE"; then
    pass "MFE_CONFIG_API_URL is relative (/api/mfe_config/v1) — not hardcoded to LMS host"
  else
    fail "MFE_CONFIG_API_URL is missing or not set to relative path in Dockerfile"
  fi
fi

# ===========================================================================
section "6. Build-time hostname coupling (OEP-65 gap: SITE_VARIANTS)"
# ===========================================================================

if [[ ! -f "$ENV_CONFIG_JSX" ]]; then
  skip "env.config.jsx not found — cannot check SITE_VARIANTS coupling"
else
  if grep -q "SITE_VARIANTS" "$ENV_CONFIG_JSX"; then
    fail "SITE_VARIANTS hostname map found in env.config.jsx — tenant domains are build-time coupled (Gap 4 in OEP65_MODULE_READINESS.md; fix: use getConfig().MEREKA_SITE_VARIANT)"
  else
    pass "No SITE_VARIANTS hostname map in env.config.jsx (Gap 4 resolved)"
  fi

  # Check for hardcoded footer nav links
  if grep -q "navLinks\s*=" "$ENV_CONFIG_JSX"; then
    fail "Hardcoded navLinks array in env.config.jsx — nav changes require MFE rebuild (Gap 5 in OEP65_MODULE_READINESS.md; fix: use getConfig().MEREKA_FOOTER_CONFIG)"
  else
    pass "No hardcoded navLinks in env.config.jsx (Gap 5 resolved)"
  fi
fi

# ===========================================================================
section "7. Dockerfile surgery maintainability (OEP-65 gap: regex anchors)"
# ===========================================================================

if [[ ! -f "$APPLY_PATCHES" ]]; then
  skip "apply-patches.sh not found — cannot check Dockerfile surgery"
else
  if grep -q '^[^#]*mfe-node\.sh\|^[^#]*mfe_node' "$APPLY_PATCHES"; then
    fail "mfe-node.sh Dockerfile surgery still active in apply-patches.sh (Gap 3 in OEP65_MODULE_READINESS.md — will break when upstream MFE Dockerfile structure changes)"
  else
    pass "mfe-node.sh Dockerfile surgery not present in apply-patches.sh (Gap 3 mitigated)"
  fi

  # Verify ENV_PATCHES are declared in the Tutor plugin (parallel path to bash surgery)
  if [[ -f "$PLUGIN_PY" ]] && grep -q "mfe-dockerfile-pre-npm-install\|mfe-dockerfile-post-npm-install" "$PLUGIN_PY"; then
    pass "mereka_lms.py declares MFE ENV_PATCH hooks (Tutor hook pattern alongside bash surgery)"
  else
    skip "mereka_lms.py missing MFE ENV_PATCH hooks — bash surgery is only customisation path"
  fi
fi

# ===========================================================================
section "8. Shell / Module Federation (OEP-65 full adoption — upstream blocked)"
# ===========================================================================

# These checks verify the *absence* of Module Federation (expected for Ulmo).
# When upstream Tutor MFE plugin adds MF support, these should be revisited.

if [[ -f "$DOCKERFILE" ]]; then
  if grep -q "ModuleFederation\|module-federation\|remoteName\|exposes:" "$DOCKERFILE"; then
    pass "Module Federation configuration detected in Dockerfile (OEP-65 full adoption)"
  else
    skip "No Module Federation in Dockerfile — expected for Ulmo; track openedx/frontend-base for shell adoption"
  fi
else
  skip "Dockerfile not found — cannot check Module Federation status"
fi

# Check for frontend-base shell reference
if [[ -f "$DOCKERFILE" ]]; then
  if grep -q "frontend-base\|@openedx/frontend-base" "$DOCKERFILE"; then
    pass "frontend-base shell referenced in Dockerfile"
  else
    skip "frontend-base shell not referenced — expected for Ulmo; upstream adoption pending"
  fi
fi

# ===========================================================================
section "9. legacy-peer-deps dependency health (tracking)"
# ===========================================================================

if [[ ! -f "$DOCKERFILE" ]]; then
  skip "Dockerfile not found — cannot check --legacy-peer-deps usage"
else
  lpd_count="$(grep -c "legacy-peer-deps" "$DOCKERFILE" || true)"
  if [[ "$lpd_count" -eq 0 ]]; then
    pass "No --legacy-peer-deps in Dockerfile (peer dep conflicts resolved)"
  else
    # Not a FAIL — this is expected and tracked. Report for awareness.
    skip "--legacy-peer-deps used $lpd_count time(s) in Dockerfile (tracking: FPF peer dep conflicts; see Gap 6)"
  fi
fi

# ===========================================================================
# Summary
# ===========================================================================
echo ""
echo "══════════════════════════════════════════════════════"
echo "Results: PASS=$PASS  FAIL=$FAIL  SKIP=$SKIP"
echo "══════════════════════════════════════════════════════"

if [[ "$FAIL" -gt 0 ]]; then
  echo ""
  echo "FAIL: $FAIL check(s) failed."
  echo "See docs/reference/architecture/OEP65_MODULE_READINESS.md for remediation guidance."
  exit 1
fi

if [[ "$FAIL_ON_SKIP" -eq 1 && "$SKIP" -gt 0 ]]; then
  echo ""
  echo "FAIL: $SKIP check(s) were skipped (--fail-on-skip mode)."
  exit 1
fi

echo ""
echo "PASS: All checks passed."
exit 0
