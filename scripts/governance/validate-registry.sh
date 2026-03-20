#!/usr/bin/env bash
# validate-registry.sh — Validates the script governance registry.
#
# Checks:
#   1. script-registry.yaml is valid YAML (requires python3 + PyYAML)
#   2. Every registered critical-script path actually exists
#   3. Every registered critical script is executable
#   4. ci_static_inventory entries exist and are executable
#   5. Warns about unregistered scripts in critical directories
#
# Usage:
#   bash scripts/governance/validate-registry.sh
#   WARN_UNREGISTERED=0 bash scripts/governance/validate-registry.sh  # skip orphan scan

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REGISTRY="${SCRIPT_DIR}/script-registry.yaml"

# Optional: skip the unregistered-script scan (e.g. in constrained CI envs)
WARN_UNREGISTERED="${WARN_UNREGISTERED:-1}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $*"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $*"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; WARN=$((WARN + 1)); }

echo "=== Script Governance Registry Validation ==="
echo "Registry: ${REGISTRY}"
echo ""

# ── 1. Registry file exists ───────────────────────────────────────────────────
echo "--- 1. Registry file exists ---"
if [[ -f "${REGISTRY}" ]]; then
  pass "script-registry.yaml exists"
else
  fail "script-registry.yaml not found at ${REGISTRY}"
  exit 1
fi

# ── 2. YAML syntax validation ─────────────────────────────────────────────────
echo ""
echo "--- 2. YAML syntax validation ---"
if command -v python3 >/dev/null 2>&1; then
  if python3 -c "
import sys
try:
    import yaml
except ImportError:
    sys.exit(2)
with open('${REGISTRY}') as f:
    yaml.safe_load(f)
" 2>/dev/null; then
    pass "YAML syntax valid"
  elif [[ $? -eq 2 ]]; then
    warn "PyYAML not installed — skipping deep YAML validation (install: pip install pyyaml)"
    # Fallback: basic structure check
    if python3 -c "
import sys
content = open('${REGISTRY}').read()
if 'version:' not in content or 'scripts:' not in content:
    sys.exit(1)
" 2>/dev/null; then
      pass "YAML basic structure check passed (PyYAML unavailable)"
    else
      fail "YAML basic structure check failed — missing 'version:' or 'scripts:' keys"
    fi
  else
    fail "YAML syntax error in script-registry.yaml"
  fi
else
  warn "python3 not found — skipping YAML validation"
fi

# ── 3. Extract registered paths and validate each ─────────────────────────────
echo ""
echo "--- 3. Registered script paths exist and are executable ---"

# Extract 'path:' values from registry (grep-based; avoids PyYAML dep)
mapfile -t REGISTERED_PATHS < <(
  grep -E '^\s+- path: ' "${REGISTRY}" | sed 's/^\s*- path: //' | sed "s/'//g" | sed 's/"//g' | tr -d ' '
)

if [[ ${#REGISTERED_PATHS[@]} -eq 0 ]]; then
  fail "No script paths found in registry — check YAML structure"
else
  pass "Found ${#REGISTERED_PATHS[@]} registered scripts"
fi

for rel_path in "${REGISTERED_PATHS[@]}"; do
  abs_path="${REPO_ROOT}/${rel_path}"
  if [[ ! -f "${abs_path}" ]]; then
    fail "Registered script not found: ${rel_path}"
  elif [[ ! -x "${abs_path}" ]]; then
    fail "Registered script is not executable: ${rel_path}"
  else
    pass "${rel_path}"
  fi
done

# ── 4. CI static inventory entries exist and are executable ───────────────────
echo ""
echo "--- 4. ci_static_inventory entries exist and are executable ---"

if command -v python3 >/dev/null 2>&1; then
  if inventory_summary="$(python3 - "$REGISTRY" "$REPO_ROOT" <<'PY'
import os
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("PY_YAML_MISSING")
    raise SystemExit(2)

registry_path = Path(sys.argv[1])
repo_root = Path(sys.argv[2])
payload = yaml.safe_load(registry_path.read_text(encoding="utf-8")) or {}
inventory = payload.get("ci_static_inventory")
if not isinstance(inventory, dict):
    raise SystemExit("ci_static_inventory missing from script-registry.yaml")

entries = inventory.get("entries")
if not isinstance(entries, list) or not entries:
    raise SystemExit("ci_static_inventory.entries must be a non-empty list")

seen = set()
count = 0
for index, entry in enumerate(entries, start=1):
    if not isinstance(entry, dict):
        raise SystemExit(f"ci_static_inventory.entries[{index}] must be a mapping")
    script = entry.get("script")
    if not isinstance(script, str) or not script.strip():
        raise SystemExit(f"ci_static_inventory.entries[{index}] missing script")
    args = entry.get("args", [])
    if args is None:
        args = []
    if not isinstance(args, list) or any(not isinstance(arg, str) or not arg for arg in args):
        raise SystemExit(f"ci_static_inventory.entries[{index}] args must be a list of non-empty strings")

    key = " ".join([script, *args])
    if key in seen:
        raise SystemExit(f"duplicate ci_static_inventory entry: {key}")
    seen.add(key)

    script_path = repo_root / script
    if not script_path.is_file():
        raise SystemExit(f"ci_static_inventory entry not found on disk: {script}")
    if not os.access(script_path, os.X_OK):
        raise SystemExit(f"ci_static_inventory entry is not executable: {script}")
    count += 1

print(count)
PY
  )"; then
    pass "ci_static_inventory validates ${inventory_summary} executable entries"
  elif [[ $? -eq 2 ]]; then
    warn "PyYAML not installed — skipping ci_static_inventory validation"
  else
    fail "ci_static_inventory validation failed"
  fi
else
  warn "python3 not found — skipping ci_static_inventory validation"
fi

# ── 5. Scan for unregistered scripts in critical directories ──────────────────
echo ""
echo "--- 5. Unregistered scripts in critical directories ---"

if [[ "${WARN_UNREGISTERED}" != "1" ]]; then
  echo "  (skipped — WARN_UNREGISTERED=0)"
else
  # Directories considered critical (release-path scripts live here)
  CRITICAL_DIRS=(
    "scripts/infra"
    "scripts/qa"
    "scripts/ci"
    "scripts/branding"
    "scripts/migrations"
    "scripts/tenants"
  )

  # Build a lookup set of registered paths
  declare -A REGISTERED_SET
  for p in "${REGISTERED_PATHS[@]}"; do
    REGISTERED_SET["${p}"]=1
  done

  if command -v python3 >/dev/null 2>&1; then
    while IFS= read -r ci_path; do
      [[ -n "$ci_path" ]] && REGISTERED_SET["${ci_path}"]=1
    done < <(python3 - "$REGISTRY" <<'PY'
from pathlib import Path
import sys

import yaml

payload = yaml.safe_load(Path(sys.argv[1]).read_text(encoding="utf-8")) or {}
inventory = payload.get("ci_static_inventory") or {}
for entry in inventory.get("entries", []):
    if isinstance(entry, dict):
        script = entry.get("script")
        if isinstance(script, str) and script:
            print(script)
PY
    )
  fi

  UNREGISTERED_CRITICAL=()

  for dir in "${CRITICAL_DIRS[@]}"; do
    abs_dir="${REPO_ROOT}/${dir}"
    if [[ ! -d "${abs_dir}" ]]; then
      continue
    fi
    while IFS= read -r abs_script; do
      rel_script="${abs_script#"${REPO_ROOT}/"}"
      if [[ -z "${REGISTERED_SET["${rel_script}"]:-}" ]]; then
        UNREGISTERED_CRITICAL+=("${rel_script}")
      fi
    done < <(find "${abs_dir}" -maxdepth 1 -name '*.sh' -type f | sort)
  done

  if [[ ${#UNREGISTERED_CRITICAL[@]} -eq 0 ]]; then
    pass "All scripts in critical directories are registered"
  else
    warn "${#UNREGISTERED_CRITICAL[@]} scripts in critical directories are NOT registered:"
    for s in "${UNREGISTERED_CRITICAL[@]}"; do
      echo "  - ${s}"
    done
    echo ""
    echo "  Review these scripts and add release-critical ones to script-registry.yaml."
    echo "  See scripts/governance/ORPHAN_SHORTLIST.md for a categorized list."
  fi
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "=== Validation Summary ==="
echo "  PASS: ${PASS}"
echo "  WARN: ${WARN}"
echo "  FAIL: ${FAIL}"
echo ""

if [[ "${FAIL}" -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL — ${FAIL} validation error(s) must be fixed${NC}"
  exit 1
elif [[ "${WARN}" -gt 0 ]]; then
  echo -e "${YELLOW}RESULT: WARN — ${WARN} warning(s) (non-blocking)${NC}"
  exit 0
else
  echo -e "${GREEN}RESULT: PASS${NC}"
  exit 0
fi
