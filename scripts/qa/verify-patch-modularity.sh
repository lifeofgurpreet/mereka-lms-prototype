#!/usr/bin/env bash
# Verify that apply-patches.sh patch modules are properly structured.
# Checks: file existence, sourceability, function export, wiring in apply-patches.sh.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PATCHES_DIR="$REPO_ROOT/infrastructure/tutor/patches"
APPLY_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"

PASS=0
FAIL=0

pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# Expected patch files and their corresponding function names
declare -A PATCH_FILES=(
  [mysql-auth.sh]=apply_mysql_auth_patch
  [mfe-node.sh]=apply_mfe_node_patch
  [domain-names.sh]=apply_domain_names_patch
  [webpack-memory.sh]=apply_webpack_memory_patch
  [csrf-origins.sh]=apply_csrf_origins_patch
  [footer-component.sh]=apply_footer_component_patch
  [prometheus-metrics.sh]=apply_prometheus_metrics_patch
  [mongodb-atlas.sh]=apply_mongodb_atlas_patch
  [build-optimizations.sh]=apply_build_optimizations_patch
)

echo "=== Patch Module Structure Verification ==="
echo ""

# 1. Verify _common.sh exists and is sourceable
echo "--- Shared setup (_common.sh) ---"
if [ -f "$PATCHES_DIR/_common.sh" ]; then
  pass "_common.sh exists"
else
  fail "_common.sh does not exist"
fi

# 2. Verify each patch file
echo ""
echo "--- Patch files ---"
for file in "${!PATCH_FILES[@]}"; do
  func="${PATCH_FILES[$file]}"
  filepath="$PATCHES_DIR/$file"

  # File exists
  if [ -f "$filepath" ]; then
    pass "$file exists"
  else
    fail "$file does not exist"
    continue
  fi

  # File has bash shebang
  if head -1 "$filepath" | grep -q '#!/usr/bin/env bash'; then
    pass "$file has correct shebang"
  else
    fail "$file missing shebang (#!/usr/bin/env bash)"
  fi

  # File defines exactly one apply_* function
  func_count=$(grep -cE '^apply_[a-z_]+_patch\(\)' "$filepath" || true)
  if [ "$func_count" -eq 1 ]; then
    pass "$file defines exactly 1 apply_* function"
  else
    fail "$file defines $func_count apply_* functions (expected 1)"
  fi

  # File defines the expected function name
  if grep -qE "^${func}\(\)" "$filepath"; then
    pass "$file defines $func"
  else
    fail "$file does not define $func"
  fi

  # Bash syntax check
  if bash -n "$filepath" 2>/dev/null; then
    pass "$file passes syntax check"
  else
    fail "$file has syntax errors"
  fi
done

# 3. Verify apply-patches.sh sources all patch files
echo ""
echo "--- apply-patches.sh wiring ---"
for file in "${!PATCH_FILES[@]}"; do
  func="${PATCH_FILES[$file]}"

  # Check source line (matches both literal path and $PATCHES_DIR variable)
  if grep -qE "source.*(patches/|PATCHES_DIR.*/)$file" "$APPLY_SCRIPT"; then
    pass "apply-patches.sh sources $file"
  else
    fail "apply-patches.sh does not source $file"
  fi

  # Check function call
  if grep -q "^${func}$" "$APPLY_SCRIPT"; then
    pass "apply-patches.sh calls $func"
  else
    fail "apply-patches.sh does not call $func"
  fi
done

# Check that _common.sh is sourced
if grep -qE 'source.*(patches/|PATCHES_DIR.*/)_common.sh' "$APPLY_SCRIPT"; then
  pass "apply-patches.sh sources _common.sh"
else
  fail "apply-patches.sh does not source _common.sh"
fi

# 4. Verify no orphan patch files (files in patches/ not wired into apply-patches.sh)
echo ""
echo "--- Orphan check ---"
for filepath in "$PATCHES_DIR"/*.sh; do
  file="$(basename "$filepath")"
  [ "$file" = "_common.sh" ] && continue
  if grep -qE "source.*(patches/|PATCHES_DIR.*/)$file" "$APPLY_SCRIPT"; then
    pass "$file is wired into apply-patches.sh"
  else
    fail "$file exists but is NOT wired into apply-patches.sh"
  fi
done

# Summary
echo ""
echo "=== Summary ==="
echo "PASS: $PASS  FAIL: $FAIL"
if [ "$FAIL" -gt 0 ]; then
  echo "RESULT: FAIL"
  exit 1
else
  echo "RESULT: PASS"
  exit 0
fi
