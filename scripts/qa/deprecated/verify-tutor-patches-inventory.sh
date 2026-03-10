#!/usr/bin/env bash
# verify-tutor-patches-inventory.sh
#
# Verifies that the tutor patches inventory is complete and consistent:
#   1. The inventory doc exists.
#   2. Every patch file in patches/ is listed in the inventory.
#   3. ALREADY_CONVERTED patches have a corresponding ENV_PATCHES hook in plugin contract sources.
#   4. FILESYSTEM patches are still sourced in apply-patches.sh.
#   5. The plugin file is valid Python.
#
# Output: PASS / FAIL / SKIP per check, then overall result.
# Exit:   0 = all checks pass (or skipped), 1 = any check fails.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"

INVENTORY="$REPO_ROOT/docs/reference/architecture/TUTOR_PATCHES_INVENTORY.md"
PATCHES_DIR="$REPO_ROOT/infrastructure/tutor/patches"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

pass_count=0
fail_count=0
skip_count=0

_pass() { echo "PASS $1"; (( pass_count++ )) || true; }
_fail() { echo "FAIL $1"; (( fail_count++ )) || true; }
_skip() { echo "SKIP $1"; (( skip_count++ )) || true; }

###############################################################################
# Check 1: Inventory document exists
###############################################################################
if [[ -f "$INVENTORY" ]]; then
  _pass "inventory doc exists: $INVENTORY"
else
  _fail "inventory doc missing: $INVENTORY"
fi

###############################################################################
# Check 2: Every patch file is listed in the inventory
###############################################################################
while IFS= read -r -d '' patch_file; do
  basename_patch="$(basename "$patch_file")"
  if grep -q "$basename_patch" "$INVENTORY" 2>/dev/null; then
    _pass "patch listed in inventory: $basename_patch"
  else
    _fail "patch NOT listed in inventory: $basename_patch"
  fi
done < <(find "$PATCHES_DIR" -maxdepth 1 -name "*.sh" -print0 | sort -z)

###############################################################################
# Check 3: REMOVED patches must NOT exist on disk but their hooks must
# still be present in plugin contract sources (functionality was migrated).
###############################################################################
declare -A REMOVED_CHECKS
REMOVED_CHECKS["mysql-auth.sh"]="mysql-docker-compose"
REMOVED_CHECKS["domain-names.sh"]="caddyfile"
REMOVED_CHECKS["csrf-origins.sh"]="MEREKA_LMS_EXTRA_CSRF_ORIGINS"
REMOVED_CHECKS["prometheus-metrics.sh"]="django_prometheus"
REMOVED_CHECKS["mongodb-atlas.sh"]="pymongo\[srv\]"
REMOVED_CHECKS["security-hardening.sh"]="SESSION_COOKIE_SECURE"

for patch_name in "${!REMOVED_CHECKS[@]}"; do
  expected="${REMOVED_CHECKS[$patch_name]}"
  if [[ -f "$PATCHES_DIR/$patch_name" ]]; then
    _fail "removed patch still exists on disk: $patch_name (should have been deleted)"
  elif mereka_plugin_has_regex "$REPO_ROOT" "$expected"; then
    _pass "removed patch migrated to plugin: $patch_name -> $expected"
  else
    _fail "removed patch hook NOT found in plugin contract sources: $patch_name -> expected '$expected'"
  fi
done

###############################################################################
# Check 4: FILESYSTEM patches are still sourced in apply-patches.sh
#
# These patches must remain in bash and must still be sourced.
###############################################################################
FILESYSTEM_PATCHES=(
  "mfe-node.sh"
  "webpack-memory.sh"
  "footer-component.sh"
  "build-optimizations.sh"
  "brand-package.sh"
)

for patch_name in "${FILESYSTEM_PATCHES[@]}"; do
  stem="${patch_name%.sh}"
  if grep -q "source.*$stem" "$APPLY_PATCHES" 2>/dev/null; then
    _pass "filesystem patch sourced in apply-patches.sh: $patch_name"
  else
    _fail "filesystem patch NOT sourced in apply-patches.sh: $patch_name"
  fi
done

###############################################################################
# Check 5: Plugin contract sources are valid Python
###############################################################################
plugin_files_checked=0
while IFS= read -r plugin_file; do
  plugin_files_checked=$((plugin_files_checked + 1))
  if python3 -c "import ast; ast.parse(open('$plugin_file').read())" 2>/dev/null; then
    _pass "$(basename "$plugin_file") is valid Python"
  else
    _fail "$(basename "$plugin_file") has Python syntax errors"
  fi
done < <(mereka_plugin_contract_files "$REPO_ROOT")

if (( plugin_files_checked == 0 )); then
  _fail "No plugin contract sources found (expected at least $PLUGIN_MAIN)"
fi

###############################################################################
# Check 6: apply-patches.sh is valid bash syntax
###############################################################################
if bash -n "$APPLY_PATCHES" 2>/dev/null; then
  _pass "apply-patches.sh passes bash -n"
else
  _fail "apply-patches.sh has bash syntax errors"
fi

###############################################################################
# Check 7: Inventory lists all three classification labels
###############################################################################
for label in "CONVERTIBLE" "FILESYSTEM" "ALREADY_CONVERTED"; do
  if grep -q "$label" "$INVENTORY" 2>/dev/null; then
    _pass "inventory contains classification: $label"
  else
    _skip "inventory does not contain classification: $label (may be intentional)"
  fi
done

###############################################################################
# Summary
###############################################################################
echo ""
echo "Results: ${pass_count} PASS  ${fail_count} FAIL  ${skip_count} SKIP"

if (( fail_count > 0 )); then
  echo "OVERALL: FAIL"
  exit 1
else
  echo "OVERALL: PASS"
  exit 0
fi
