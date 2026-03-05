#!/usr/bin/env bash
# verify-build-optimizations.sh
#
# Audits infrastructure/tutor/patches/build-optimizations.sh:
#   1. File existence and shebang.
#   2. Bash syntax validity (bash -n).
#   3. Shellcheck (skipped if shellcheck is not installed).
#   4. Function signature matches expected name.
#   5. Module boundary markers are present (section headers).
#   6. Phase A Python heredoc is properly opened and closed.
#   7. Phase B bash sync section is present.
#   8. All sentinel strings that enforce idempotency are present.
#   9. Target file variables are all referenced.
#  10. Line count is documented (reports current LOC vs 300-line module target).
#  11. Refactor plan document exists.
#
# Output: PASS / FAIL / SKIP per check, then overall result.
# Exit:   0 = all checks pass or skipped, 1 = any check fails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TARGET="$REPO_ROOT/infrastructure/tutor/patches/build-optimizations.sh"
PLAN_DOC="$REPO_ROOT/docs/architecture/BUILD_OPTIMIZATIONS_REFACTOR.md"

pass_count=0
fail_count=0
skip_count=0

_pass() { echo "PASS $1"; (( pass_count++ )) || true; }
_fail() { echo "FAIL $1"; (( fail_count++ )) || true; }
_skip() { echo "SKIP $1"; (( skip_count++ )) || true; }

echo "=== verify-build-optimizations.sh ==="
echo ""

###############################################################################
# Check 1: File exists
###############################################################################
echo "--- 1. File existence ---"
if [[ -f "$TARGET" ]]; then
  _pass "build-optimizations.sh exists"
else
  _fail "build-optimizations.sh does not exist at: $TARGET"
  echo ""
  echo "Results: ${pass_count} PASS  ${fail_count} FAIL  ${skip_count} SKIP"
  echo "OVERALL: FAIL"
  exit 1
fi

###############################################################################
# Check 2: Correct shebang
###############################################################################
echo ""
echo "--- 2. Shebang ---"
if head -1 "$TARGET" | grep -q '#!/usr/bin/env bash'; then
  _pass "correct shebang (#!/usr/bin/env bash)"
else
  _fail "missing or incorrect shebang — expected '#!/usr/bin/env bash'"
fi

###############################################################################
# Check 3: Bash syntax (bash -n)
###############################################################################
echo ""
echo "--- 3. Bash syntax ---"
if bash -n "$TARGET" 2>/dev/null; then
  _pass "bash -n syntax check passes"
else
  _fail "bash -n reports syntax errors in build-optimizations.sh"
fi

###############################################################################
# Check 4: Shellcheck (skip if not installed)
###############################################################################
echo ""
echo "--- 4. Shellcheck ---"
if command -v shellcheck >/dev/null 2>&1; then
  # Exclude SC2016 (single-quoted variables) and SC1090 (source non-constant)
  # which are common in Python-heredoc-containing scripts.
  if shellcheck -e SC2016,SC1090,SC1091 "$TARGET" 2>/dev/null; then
    _pass "shellcheck passes (SC2016, SC1090, SC1091 excluded)"
  else
    _fail "shellcheck reports errors in build-optimizations.sh"
  fi
else
  _skip "shellcheck not installed — install with: apt install shellcheck"
fi

###############################################################################
# Check 5: Function signature
###############################################################################
echo ""
echo "--- 5. Function signature ---"
expected_func="apply_build_optimizations_patch"
if grep -q "^${expected_func}()" "$TARGET"; then
  _pass "defines ${expected_func}()"
else
  _fail "does not define ${expected_func}() — expected function not found"
fi

# Only one apply_* function should be defined
func_count=$(grep -cE '^apply_[a-z_]+\(\)' "$TARGET" || true)
if [[ "$func_count" -eq 1 ]]; then
  _pass "defines exactly 1 apply_* function"
else
  _fail "defines ${func_count} apply_* functions (expected 1)"
fi

###############################################################################
# Check 6: Phase A section boundary markers
###############################################################################
echo ""
echo "--- 6. Phase A section boundary markers ---"

declare -a SECTION_MARKERS=(
  "# ── openedx Dockerfile patches"
  "# ── production.py patches"
  "# ── assets.py patches"
  "# ── lms.conf patches"
  "# ── Caddyfile patches"
)

for marker in "${SECTION_MARKERS[@]}"; do
  if grep -qF "$marker" "$TARGET"; then
    _pass "section marker present: '$marker'"
  else
    _fail "section marker missing: '$marker'"
  fi
done

###############################################################################
# Check 7: Phase A Python heredoc is present and properly terminated
###############################################################################
echo ""
echo "--- 7. Phase A Python heredoc ---"
if grep -q "python - \"\${targets\[@\]}\"" "$TARGET"; then
  _pass "Python heredoc opening found: python - \"\${targets[@]}\""
else
  _fail "Python heredoc opening not found — expected: python - \"\${targets[@]}\""
fi

heredoc_open=$(grep -c "<<'PY'" "$TARGET" || true)
heredoc_close=$(grep -c "^PY$" "$TARGET" || true)
if [[ "$heredoc_open" -ge 1 ]]; then
  _pass "Python heredoc delimiter <<'PY' present (${heredoc_open} occurrence(s))"
else
  _fail "Python heredoc delimiter <<'PY' not found"
fi
if [[ "$heredoc_close" -ge 1 ]]; then
  _pass "Python heredoc terminator ^PY present (${heredoc_close} occurrence(s))"
else
  _fail "Python heredoc terminator ^PY not found"
fi

###############################################################################
# Check 8: Phase B bash sync section
###############################################################################
echo ""
echo "--- 8. Phase B bash sync section ---"
if grep -q "# ── File sync operations" "$TARGET"; then
  _pass "Phase B marker present: '# ── File sync operations'"
else
  _fail "Phase B marker missing: '# ── File sync operations'"
fi

# Verify key Phase B operations exist
declare -a PHASE_B_MARKERS=(
  "Syncing logo files from theme source"
  "Syncing font files from theme source"
  "Sync custom apps into build context"
  "Sync multi-tenancy plugin into build context"
  "THEME_BUILD_DIR"
  "CUSTOM_APPS_SRC"
  "TENANCY_PLUGIN_SRC"
)

for marker in "${PHASE_B_MARKERS[@]}"; do
  if grep -qF "$marker" "$TARGET"; then
    _pass "Phase B marker present: '${marker}'"
  else
    _fail "Phase B marker missing: '${marker}'"
  fi
done

###############################################################################
# Check 9: Idempotency sentinels
###############################################################################
echo ""
echo "--- 9. Idempotency sentinels ---"

declare -a SENTINELS=(
  # Dockerfile sentinels
  "openedx_node_cache"               # node cache reuse
  "_build_safe_join"                 # assets.py safe_join
  "JS_COMPRESSOR"                    # pipeline compression disable
  "mfe_oauth_fix"                    # MFE OAuth fix
  "mereka_tenancy"                   # multi-tenancy
  "DEFAULT_SITE_THEME"               # theme name
  "Stripped google font imports"     # brand SASS compile
  "compile-sass skipped"             # conditional compile guard
  "mereka-overrides.css"             # CSS bake
  "location = /health"               # nginx health endpoint
  "Cache-Control"                    # Caddyfile cache headers
)

for sentinel in "${SENTINELS[@]}"; do
  if grep -qF "$sentinel" "$TARGET"; then
    _pass "idempotency sentinel present: '${sentinel}'"
  else
    _fail "idempotency sentinel missing: '${sentinel}'"
  fi
done

###############################################################################
# Check 10: Target variable references
###############################################################################
echo ""
echo "--- 10. Target variable references ---"

declare -a TARGET_VARS=(
  'OPENEDX_TEMPLATE'
  'LMS_SETTINGS_TEMPLATE'
  'LMS_ASSETS_TEMPLATE'
  'CMS_ASSETS_TEMPLATE'
  'NGINX_LMS_TEMPLATE'
  'CADDY_TEMPLATE'
  'REPO_ROOT'
)

for var in "${TARGET_VARS[@]}"; do
  if grep -qF "\$$var" "$TARGET" || grep -qF "\${$var}" "$TARGET"; then
    _pass "target variable referenced: \$$var"
  else
    _fail "target variable NOT referenced: \$$var"
  fi
done

###############################################################################
# Check 11: Line count report and module boundary documentation
###############################################################################
echo ""
echo "--- 11. Line count and module boundary report ---"

loc=$(wc -l < "$TARGET")
echo "  INFO: current LOC = ${loc}"
echo "  INFO: module target = <300 lines per module"

if [[ "$loc" -gt 600 ]]; then
  _pass "LOC=${loc} — confirms refactor is warranted (exceeds 300-line target)"
else
  _skip "LOC=${loc} — file may have already been partially refactored"
fi

# Detect the approximate line ranges of each section
dockerfile_start=$(grep -n "# ── openedx Dockerfile patches" "$TARGET" | head -1 | cut -d: -f1)
production_start=$(grep -n "# ── production.py patches" "$TARGET" | head -1 | cut -d: -f1)
assets_start=$(grep -n "# ── assets.py patches" "$TARGET" | head -1 | cut -d: -f1)
lmsconf_start=$(grep -n "# ── lms.conf patches" "$TARGET" | head -1 | cut -d: -f1)
caddy_start=$(grep -n "# ── Caddyfile patches" "$TARGET" | head -1 | cut -d: -f1)
filesync_start=$(grep -n "# ── File sync operations" "$TARGET" | head -1 | cut -d: -f1)

if [[ -n "$dockerfile_start" && -n "$production_start" ]]; then
  dockerfile_lines=$(( production_start - dockerfile_start ))
  echo "  INFO: Dockerfile section starts at line ${dockerfile_start} (~${dockerfile_lines} lines)"
  _pass "Dockerfile section boundary detected at line ${dockerfile_start}"
else
  _fail "could not detect Dockerfile section boundary"
fi

if [[ -n "$production_start" && -n "$assets_start" ]]; then
  production_lines=$(( assets_start - production_start ))
  echo "  INFO: production.py section starts at line ${production_start} (~${production_lines} lines)"
  _pass "production.py section boundary detected at line ${production_start}"
else
  _fail "could not detect production.py section boundary"
fi

if [[ -n "$assets_start" && -n "$lmsconf_start" ]]; then
  assets_lines=$(( lmsconf_start - assets_start ))
  echo "  INFO: assets.py section starts at line ${assets_start} (~${assets_lines} lines)"
  _pass "assets.py section boundary detected at line ${assets_start}"
else
  _fail "could not detect assets.py section boundary"
fi

if [[ -n "$lmsconf_start" && -n "$caddy_start" ]]; then
  lmsconf_lines=$(( caddy_start - lmsconf_start ))
  echo "  INFO: lms.conf section starts at line ${lmsconf_start} (~${lmsconf_lines} lines)"
  _pass "lms.conf section boundary detected at line ${lmsconf_start}"
else
  _fail "could not detect lms.conf section boundary"
fi

if [[ -n "$caddy_start" && -n "$filesync_start" ]]; then
  caddy_lines=$(( filesync_start - caddy_start ))
  echo "  INFO: Caddyfile section starts at line ${caddy_start} (~${caddy_lines} lines)"
  _pass "Caddyfile section boundary detected at line ${caddy_start}"
else
  _fail "could not detect Caddyfile section boundary"
fi

if [[ -n "$filesync_start" ]]; then
  filesync_lines=$(( loc - filesync_start ))
  echo "  INFO: File sync (Phase B) starts at line ${filesync_start} (~${filesync_lines} lines)"
  _pass "Phase B (file sync) boundary detected at line ${filesync_start}"
else
  _fail "could not detect Phase B (file sync) boundary"
fi

###############################################################################
# Check 12: Refactor plan document exists
###############################################################################
echo ""
echo "--- 12. Refactor plan document ---"
if [[ -f "$PLAN_DOC" ]]; then
  _pass "refactor plan doc exists: docs/architecture/BUILD_OPTIMIZATIONS_REFACTOR.md"
else
  _fail "refactor plan doc missing: docs/architecture/BUILD_OPTIMIZATIONS_REFACTOR.md"
fi

# Check plan doc covers all 4 proposed modules
declare -a PLAN_MODULES=(
  "build-opt-dockerfile.sh"
  "build-opt-settings.sh"
  "build-opt-routing.sh"
  "build-opt-theme-sync.sh"
)

for mod in "${PLAN_MODULES[@]}"; do
  if grep -qF "$mod" "$PLAN_DOC" 2>/dev/null; then
    _pass "refactor plan documents proposed module: ${mod}"
  else
    _fail "refactor plan does not document proposed module: ${mod}"
  fi
done

###############################################################################
# Summary
###############################################################################
echo ""
echo "=== Summary ==="
echo "Results: ${pass_count} PASS  ${fail_count} FAIL  ${skip_count} SKIP"
echo ""

if (( fail_count > 0 )); then
  echo "OVERALL: FAIL"
  exit 1
else
  echo "OVERALL: PASS"
  exit 0
fi
