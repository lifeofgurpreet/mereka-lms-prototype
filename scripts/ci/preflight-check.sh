#!/usr/bin/env bash
# Preflight check: validates the generated MFE/OpenEdX Dockerfiles
# against known invariants BEFORE a 30-60 minute build cycle.
#
# Usage:
#   ./scripts/ci/preflight-check.sh              # uses existing .ci-venv or creates one
#   TUTOR_VENV=/path/to/venv ./scripts/ci/...    # use a specific venv
#
# Runtime: ~30 seconds (config save + patch + grep checks)
#
# WHY THIS EXISTS:
# Tutor generates Dockerfiles from templates. Patches in apply-patches.sh and
# mereka_lms.py modify those templates. Errors are only caught after a 30-45 min
# build. This script catches them in < 1 minute by rendering + validating locally.
#
# The build stack is pinned in requirements-tutor.txt (currently Tutor 21.0.0 Ulmo).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
TUTOR_VENV="${TUTOR_VENV:-$REPO_ROOT/.ci-venv}"
TUTOR_REQ="$REPO_ROOT/requirements-tutor.txt"
PASS=0
FAIL=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1" >&2; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

# ── Setup CI-matching Tutor environment ──────────────────────────
echo "=== Preflight Check: MFE/OpenEdX Dockerfile Invariants ==="

if [[ ! -f "$TUTOR_VENV/bin/tutor" ]]; then
  echo "Creating CI-matching venv at $TUTOR_VENV..."
  python3 -m venv "$TUTOR_VENV"
  "$TUTOR_VENV/bin/pip" install -q -r "$TUTOR_REQ"
fi

TUTOR_ROOT=$(mktemp -d)
export TUTOR_ROOT
export REPO_ROOT

echo "Generating Dockerfiles (tutor config save + apply-patches.sh)..."
"$TUTOR_VENV/bin/tutor" config save \
  --set LMS_HOST=preflight-check.test \
  --set CMS_HOST=studio.preflight-check.test \
  --set ENABLE_HTTPS=true \
  >/dev/null 2>&1

# Apply patches to the rendered Dockerfile.
# We can't use apply-patches.sh directly because it hardcodes paths relative
# to tutor_env/ and discovers template paths from Python imports. Instead, run
# the MFE_TEMPLATE-aware patching with MFE_TEMPLATE pointing at our rendered file.
export MFE_TEMPLATE="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
RENDERED_DF="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
if [[ -f "$RENDERED_DF" && -f "$REPO_ROOT/infrastructure/tutor/patches/mfe-node.sh" ]]; then
  (
    export VIRTUAL_ENV="$TUTOR_VENV"
    export PATH="$TUTOR_VENV/bin:$PATH"
    export REPO_ROOT TUTOR_ROOT MFE_TEMPLATE
    # Symlink so hardcoded tutor_env path in mfe-node.sh also finds the file
    mkdir -p "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe" 2>/dev/null || true
    ln -sf "$RENDERED_DF" "$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile" 2>/dev/null || true
    cd "$REPO_ROOT"
    source infrastructure/tutor/patches/_common.sh
    _discover_template_paths 2>/dev/null || true
    source infrastructure/tutor/patches/mfe-node.sh
    apply_mfe_node_patch
    source infrastructure/tutor/patches/brand-package.sh
    apply_brand_package_patch 2>/dev/null || true
    source infrastructure/tutor/patches/footer-component.sh
    apply_footer_component_patch 2>/dev/null || true
  ) >/dev/null 2>&1
fi

MFE_DF="$TUTOR_ROOT/env/plugins/mfe/build/mfe/Dockerfile"
OPENEDX_DF="$TUTOR_ROOT/env/build/openedx/Dockerfile"

if [[ ! -f "$MFE_DF" ]]; then
  echo "ERROR: MFE Dockerfile not generated at $MFE_DF" >&2
  rm -rf "$TUTOR_ROOT"
  exit 1
fi

# Helper: extract a Dockerfile stage block
stage_block() {
  local df="$1" stage="$2"
  python3 -c "
import sys
lines = open('$df').read().splitlines()
start = None
for i, l in enumerate(lines):
    if 'FROM ' in l and ' AS $stage' in l:
        start = i
        break
if start is None:
    sys.exit(1)
end = len(lines)
for i in range(start+1, len(lines)):
    if lines[i].startswith('FROM '):
        end = i
        break
print('\n'.join(lines[start:end]))
" 2>/dev/null
}

# ── MFE Dockerfile Checks ───────────────────────────────────────
echo ""
echo "--- MFE Dockerfile Invariants ---"

# 1. Check env.config.jsx imports vs installed packages per MFE stage.
# The key invariant: if an MFE's env.config.jsx imports a package, that package
# MUST be installed in that MFE's build stage. Otherwise webpack fails with
# "Module not found" at build time.
ENV_CONFIG="$TUTOR_ROOT/env/plugins/mfe/build/mfe/env.config.jsx"
INDIGO_ENV_CONFIG="$TUTOR_ROOT/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
# Determine which env.config.jsx will be used (varies by Tutor version)
ACTIVE_ENV_CONFIG=""
if [[ -f "$INDIGO_ENV_CONFIG" ]]; then
  ACTIVE_ENV_CONFIG="$INDIGO_ENV_CONFIG"
elif [[ -f "$ENV_CONFIG" ]]; then
  ACTIVE_ENV_CONFIG="$ENV_CONFIG"
fi

# Check if env.config.jsx imports the indigo footer package
ENV_CONFIG_IMPORTS_FOOTER=false
if [[ -n "$ACTIVE_ENV_CONFIG" ]] && grep -q "indigo-frontend-component-footer" "$ACTIVE_ENV_CONFIG" 2>/dev/null; then
  ENV_CONFIG_IMPORTS_FOOTER=true
fi

for mfe in authn learning discussions learner-dashboard profile account; do
  block=$(stage_block "$MFE_DF" "${mfe}-common") || true
  if [[ -z "$block" ]]; then
    skip "${mfe}-common stage not found"
    continue
  fi

  has_env_config=$(echo "$block" | grep -c "env.config.jsx" || true)
  has_footer_pkg=$(echo "$block" | grep -c "indigo-frontend-component-footer" || true)

  if [[ "$has_env_config" -gt 0 && "$ENV_CONFIG_IMPORTS_FOOTER" == "true" && "$has_footer_pkg" -eq 0 ]]; then
    fail "${mfe}-common has env.config.jsx that imports footer, but footer package is NOT installed"
  elif [[ "$has_env_config" -gt 0 && "$ENV_CONFIG_IMPORTS_FOOTER" == "true" && "$has_footer_pkg" -gt 0 ]]; then
    pass "${mfe}-common has env.config.jsx + footer package installed"
  elif [[ "$has_env_config" -gt 0 && "$ENV_CONFIG_IMPORTS_FOOTER" == "false" ]]; then
    pass "${mfe}-common has env.config.jsx (no footer import — safe)"
  elif [[ "$has_env_config" -eq 0 ]]; then
    pass "${mfe}-common: no env.config.jsx (OK for this MFE)"
  fi
done

# 3. All indigo component installs must use --legacy-peer-deps
bad_installs=$(grep -E "RUN npm install.*indigo-frontend-component" "$MFE_DF" | grep -v "legacy-peer-deps" || true)
if [[ -n "$bad_installs" ]]; then
  fail "indigo component install without --legacy-peer-deps: $bad_installs"
else
  pass "all indigo component installs use --legacy-peer-deps"
fi

# 4. Node version check
if head -5 "$MFE_DF" | grep -q "node:2[0-9]"; then
  pass "MFE uses Node 20+ ($(head -1 "$MFE_DF" | grep -oP 'node:[^ ]+'))"
else
  fail "MFE not using Node 20+ (found: $(head -1 "$MFE_DF"))"
fi

# 5. Brand-mereka local package (not npm registry)
if grep -q "brand@file:./brand-mereka" "$MFE_DF"; then
  pass "brand package uses local file (brand-mereka)"
else
  if grep -q "indigo-brand-openedx" "$MFE_DF"; then
    fail "brand package still points to npm registry (should be local brand-mereka)"
  else
    skip "brand package pattern not found"
  fi
fi

# 6. mereka theme assets present for authn
authn_block_check=$(stage_block "$MFE_DF" "authn-common") || true
if [[ -n "$authn_block_check" ]]; then
  if echo "$authn_block_check" | grep -q "mereka"; then
    pass "authn-common has mereka theme assets"
  else
    fail "authn-common MISSING mereka theme assets"
  fi
fi

# ── OpenEdX Dockerfile Checks ───────────────────────────────────
echo ""
echo "--- OpenEdX Dockerfile Invariants ---"

if [[ -f "$OPENEDX_DF" ]]; then
  if grep -q "mysql_native_password" "$OPENEDX_DF" 2>/dev/null; then
    pass "MySQL auth plugin patch present"
  else
    skip "MySQL auth plugin not checked (may be in settings, not Dockerfile)"
  fi
else
  skip "OpenEdX Dockerfile not found"
fi

# ── Summary ──────────────────────────────────────────────────────
echo ""
echo "=== Preflight Summary: $PASS PASS, $FAIL FAIL, $SKIP SKIP ==="

# Cleanup
rm -rf "$TUTOR_ROOT"

if [[ $FAIL -gt 0 ]]; then
  echo "Preflight FAILED. Fix the above issues before triggering a full build." >&2
  exit 1
fi

echo "Preflight PASSED. Safe to trigger full build."
exit 0
