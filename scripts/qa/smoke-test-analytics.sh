#!/usr/bin/env bash
set -euo pipefail

# smoke-test-analytics.sh - Static verification of analytics configuration
#
# Usage:
#   scripts/qa/smoke-test-analytics.sh

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPTS_DIR="${REPO_ROOT}/scripts/analytics"
SHARED_CONFIG="${REPO_ROOT}/scripts/shared/config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

echo "=== Analytics Smoke Test (Static Verification) ==="
echo "Repository: $REPO_ROOT"
echo

# Check 1: Analytics scripts have valid bash syntax
echo "[1] Checking bash script syntax..."
if [[ -d "$SCRIPTS_DIR" ]]; then
  bash_scripts=()
  mapfile -t bash_scripts < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh" 2>/dev/null || true)

  if [[ ${#bash_scripts[@]} -eq 0 ]]; then
    warn "No bash scripts found in $SCRIPTS_DIR"
  else
    syntax_errors=0

    for script in "${bash_scripts[@]}"; do
      if bash -n "$script" 2>/dev/null; then
        pass "Valid syntax: $(basename "$script")"
      else
        fail "Syntax error in: $(basename "$script")"
        bash -n "$script" 2>&1 | head -3 | while IFS= read -r line; do
          echo "    $line"
        done
        syntax_errors=$((syntax_errors + 1))
      fi
    done

    if [[ $syntax_errors -eq 0 ]]; then
      pass "All bash scripts have valid syntax"
    fi
  fi
else
  fail "Analytics scripts directory not found: $SCRIPTS_DIR"
fi
echo

# Check 2: Python scripts have valid syntax
echo "[2] Checking Python script syntax..."
if [[ -d "$SCRIPTS_DIR" ]]; then
  python_scripts=()
  mapfile -t python_scripts < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.py" 2>/dev/null || true)

  if [[ ${#python_scripts[@]} -eq 0 ]]; then
    warn "No Python scripts found in $SCRIPTS_DIR"
  else
    syntax_errors=0

    for script in "${python_scripts[@]}"; do
      if python3 -m py_compile "$script" 2>/dev/null; then
        pass "Valid syntax: $(basename "$script")"
      else
        fail "Syntax error in: $(basename "$script")"
        python3 -m py_compile "$script" 2>&1 | head -3 | while IFS= read -r line; do
          echo "    $line"
        done
        syntax_errors=$((syntax_errors + 1))
      fi
    done

    if [[ $syntax_errors -eq 0 ]]; then
      pass "All Python scripts have valid syntax"
    fi
  fi
fi
echo

# Check 3: Export output directory structure
echo "[3] Checking export output directory configuration..."
export_dir="${REPO_ROOT}/exports"
analytics_export_dir="${REPO_ROOT}/exports/analytics"

if [[ -d "$export_dir" ]]; then
  pass "Export directory exists: $export_dir"
else
  warn "Export directory not found (will be created on first export): $export_dir"
fi

# Check if scripts reference configurable output paths
if grep -rqE "(OUTPUT_DIR|EXPORT_DIR|output.*directory)" "$SCRIPTS_DIR"/*.sh 2>/dev/null; then
  pass "Analytics scripts use configurable output directories"
else
  warn "Scripts may not use configurable output directories"
fi
echo

# Check 4: Analytics scripts source shared config
echo "[4] Checking shared config usage..."
if [[ -f "$SHARED_CONFIG" ]]; then
  pass "Shared config exists: $SHARED_CONFIG"

  # Count how many analytics scripts source it
  sourcing_count=0
  bash_scripts=()
  mapfile -t bash_scripts < <(find "$SCRIPTS_DIR" -maxdepth 1 -type f -name "*.sh" 2>/dev/null || true)

  for script in "${bash_scripts[@]}"; do
    if grep -qE "(source|\\.).*scripts/shared/config\\.sh" "$script"; then
      sourcing_count=$((sourcing_count + 1))
    fi
  done

  if [[ $sourcing_count -gt 0 ]]; then
    pass "$sourcing_count analytics script(s) source shared config"
  else
    warn "No analytics scripts source shared config (may not need it)"
  fi
else
  warn "Shared config not found: $SHARED_CONFIG"
fi
echo

# Check 5: ClickHouse connection uses secrets (not hardcoded)
echo "[5] Checking for hardcoded credentials..."
hardcoded_found=false

# Scan for hardcoded passwords in analytics files
search_patterns=(
  "password\s*=\s*['\"][^'\"]+['\"]"
  "CLICKHOUSE_PASSWORD\s*=\s*['\"][^'\"]+['\"]"
  "clickhouse://[^:]+:[^@]+@"
)

for pattern in "${search_patterns[@]}"; do
  if grep -rE "$pattern" "$SCRIPTS_DIR" 2>/dev/null | grep -v "^\s*#" | grep -qv "password.*\$"; then
    fail "Found potential hardcoded credential matching pattern: $pattern"
    hardcoded_found=true
  fi
done

if [[ "$hardcoded_found" == "false" ]]; then
  pass "No hardcoded credentials found in analytics scripts"
fi

# Check that scripts reference environment variables or secrets
if grep -rqE "(os\\.environ|getenv|\\$\\{.*PASSWORD\\}|secretKeyRef)" "$SCRIPTS_DIR" 2>/dev/null; then
  pass "Scripts reference environment variables/secrets for credentials"
else
  warn "Scripts may not properly reference secrets (check connection config)"
fi
echo

# Check 6: Analytics scripts are executable
echo "[6] Checking script permissions..."
executable_count=0
non_executable=()

for script in "$SCRIPTS_DIR"/*.sh; do
  [[ -f "$script" ]] || continue

  if [[ -x "$script" ]]; then
    executable_count=$((executable_count + 1))
  else
    non_executable+=("$(basename "$script")")
  fi
done

if [[ ${#non_executable[@]} -eq 0 ]]; then
  pass "All $executable_count shell scripts are executable"
else
  warn "${#non_executable[@]} script(s) not executable: ${non_executable[*]}"
  echo "    Run: chmod +x scripts/analytics/*.sh"
fi

# Summary
echo
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS"
echo -e "${RED}FAIL:${NC} $FAIL"

if [[ $FAIL -gt 0 ]]; then
  echo
  echo "ACTION REQUIRED: Fix failing checks before running analytics pipeline."
  exit 1
fi

echo
echo "✓ Static verification complete. Analytics configuration looks good."
echo "  Note: This does NOT test actual ClickHouse connectivity."
echo "  Run with live services to verify end-to-end functionality."

exit 0
