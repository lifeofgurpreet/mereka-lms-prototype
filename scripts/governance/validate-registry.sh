#!/usr/bin/env bash
# validate-registry.sh — Validates the script governance registry.
#
# Checks:
#   1. script-registry.yaml is valid YAML (requires python3 + PyYAML)
#   2. Every registered critical-script path actually exists
#   3. Every registered critical script is executable
#   4. ci_static_inventory entries exist and are executable
#   5. ci_runtime_inventory entries exist and are executable
#   6. Validates the governed orphan-script baseline
#   7. Validates the governed active-but-unregistered critical-script baseline
#
# Usage:
#   bash scripts/governance/validate-registry.sh
#   WARN_UNREGISTERED=0 bash scripts/governance/validate-registry.sh  # skip governed drift scans

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
# REGISTRY_OVERRIDE: fixture injection point for self-tests (bead q69f.1).
# Defaults to the canonical in-repo registry when unset.
REGISTRY="${REGISTRY_OVERRIDE:-${SCRIPT_DIR}/script-registry.yaml}"
SCOPE_MODE="${VALIDATE_REGISTRY_SCOPE:-}"
CHANGED_FILES_RAW="${VALIDATE_REGISTRY_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

# Optional: skip the governed orphan/registration drift validation
WARN_UNREGISTERED="${WARN_UNREGISTERED:-1}"
ACTIVE_UNREGISTERED_ALLOWLIST="${ACTIVE_UNREGISTERED_ALLOWLIST_OVERRIDE:-${REPO_ROOT}/scripts/qa/fixtures/script-governance-active-unregistered-allowlist.txt}"

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

should_skip_scope() {
  local changed_path

  if [[ "$SCOPE_MODE" != "changed" ]]; then
    return 1
  fi

  if [[ -z "${CHANGED_FILES_RAW//[[:space:]]/}" ]]; then
    return 1
  fi

  while IFS= read -r changed_path; do
    [[ -z "$changed_path" ]] && continue
    case "$changed_path" in
      scripts/*)
        return 1
        ;;
    esac
  done <<<"$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "RESULT: PASS (scope skip — no script-registry-relevant changes)"
  exit 0
fi

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

shard_files = inventory.get("shard_files", [])
if shard_files is None:
    shard_files = []
if not isinstance(shard_files, list):
    raise SystemExit("ci_static_inventory.shard_files must be a list when present")

seen_shards = set()
for index, shard_file in enumerate(shard_files, start=1):
    if not isinstance(shard_file, str) or not shard_file.strip():
        raise SystemExit(f"ci_static_inventory.shard_files[{index}] must be a non-empty string")
    if shard_file in seen_shards:
        raise SystemExit(f"duplicate ci_static_inventory shard file: {shard_file}")
    seen_shards.add(shard_file)

precheck_files = inventory.get("precheck_files", [])
if precheck_files is None:
    precheck_files = []
if not isinstance(precheck_files, list):
    raise SystemExit("ci_static_inventory.precheck_files must be a list when present")

seen_precheck = set()
for index, precheck_file in enumerate(precheck_files, start=1):
    if not isinstance(precheck_file, str) or not precheck_file.strip():
        raise SystemExit(f"ci_static_inventory.precheck_files[{index}] must be a non-empty string")
    if precheck_file in seen_precheck:
        raise SystemExit(f"duplicate ci_static_inventory precheck file: {precheck_file}")
    seen_precheck.add(precheck_file)

entries = inventory.get("entries")
if not isinstance(entries, list) or not entries:
    raise SystemExit("ci_static_inventory.entries must be a non-empty list")

seen = set()
seen_scripts = set()
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
    timeout_seconds = entry.get("timeout_seconds")
    if timeout_seconds is not None and (
        not isinstance(timeout_seconds, int) or timeout_seconds <= 0
    ):
        raise SystemExit(
            f"ci_static_inventory.entries[{index}] timeout_seconds must be a positive integer when present"
        )

    key = " ".join([script, *args])
    if key in seen:
        raise SystemExit(f"duplicate ci_static_inventory entry: {key}")
    seen.add(key)

    script_path = repo_root / script
    if not script_path.is_file():
        raise SystemExit(f"ci_static_inventory entry not found on disk: {script}")
    if not os.access(script_path, os.X_OK):
        raise SystemExit(f"ci_static_inventory entry is not executable: {script}")
    seen_scripts.add(script)
    count += 1

for precheck_file in precheck_files:
    if precheck_file not in seen_scripts:
        raise SystemExit(
            f"ci_static_inventory.precheck_files entry is not registered in entries: {precheck_file}"
        )

print(
    f"{count} executable entries; {len(shard_files)} shard manifest(s); "
    f"{len(precheck_files)} serial precheck file(s)"
)
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

# ── 5. CI runtime inventory entries exist and are executable ──────────────────
echo ""
echo "--- 5. ci_runtime_inventory entries exist and are executable ---"

if command -v python3 >/dev/null 2>&1; then
  if runtime_summary="$(python3 - "$REGISTRY" "$REPO_ROOT" <<'PY'
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
inventory = payload.get("ci_runtime_inventory")
if not isinstance(inventory, dict):
    raise SystemExit("ci_runtime_inventory missing from script-registry.yaml")

categories = inventory.get("categories")
if not isinstance(categories, list) or not categories:
    raise SystemExit("ci_runtime_inventory.categories must be a non-empty list")

category_keys = set()
for index, item in enumerate(categories, start=1):
    if not isinstance(item, dict):
        raise SystemExit(f"ci_runtime_inventory.categories[{index}] must be a mapping")
    key = item.get("key")
    if not isinstance(key, str) or not key.strip():
        raise SystemExit(f"ci_runtime_inventory.categories[{index}] missing key")
    category_keys.add(key)

entries = inventory.get("entries")
if not isinstance(entries, list):
    raise SystemExit("ci_runtime_inventory.entries must be a list")

seen = set()
count = 0
for index, entry in enumerate(entries, start=1):
    if not isinstance(entry, dict):
        raise SystemExit(f"ci_runtime_inventory.entries[{index}] must be a mapping")
    script = entry.get("script")
    if not isinstance(script, str) or not script.strip():
        raise SystemExit(f"ci_runtime_inventory.entries[{index}] missing script")
    category = entry.get("category")
    if not isinstance(category, str) or not category.strip():
        raise SystemExit(f"ci_runtime_inventory.entries[{index}] missing category")
    if category not in category_keys:
        raise SystemExit(
            f"ci_runtime_inventory.entries[{index}] references unknown category: {category}"
        )
    args = entry.get("args", [])
    if args is None:
        args = []
    if not isinstance(args, list) or any(not isinstance(arg, str) or not arg for arg in args):
        raise SystemExit(f"ci_runtime_inventory.entries[{index}] args must be a list of non-empty strings")

    key = " ".join([script, *args])
    if key in seen:
        raise SystemExit(f"duplicate ci_runtime_inventory entry: {key}")
    seen.add(key)

    script_path = repo_root / script
    if not script_path.is_file():
        raise SystemExit(f"ci_runtime_inventory entry not found on disk: {script}")
    if not os.access(script_path, os.X_OK):
        raise SystemExit(f"ci_runtime_inventory entry is not executable: {script}")
    count += 1

print(count)
PY
  )"; then
    pass "ci_runtime_inventory validates ${runtime_summary} executable entries"
  elif [[ $? -eq 2 ]]; then
    warn "PyYAML not installed — skipping ci_runtime_inventory validation"
  else
    fail "ci_runtime_inventory validation failed"
  fi
else
  warn "python3 not found — skipping ci_runtime_inventory validation"
fi

# ── 6. Validate governed orphan-script baseline ───────────────────────────────
echo ""
echo "--- 6. Governed orphan-script baseline ---"

if [[ "${WARN_UNREGISTERED}" != "1" ]]; then
  echo "  (skipped — WARN_UNREGISTERED=0)"
else
  ORPHAN_VERIFY_SCRIPT="${REPO_ROOT}/scripts/qa/verify-script-governance-orphans.sh"

  if [[ ! -f "${ORPHAN_VERIFY_SCRIPT}" ]]; then
    fail "Governed orphan verifier missing: scripts/qa/verify-script-governance-orphans.sh"
  else
    orphan_output=""
    if orphan_output="$(bash "${ORPHAN_VERIFY_SCRIPT}" 2>&1)"; then
      if grep -q '^WARN:' <<<"${orphan_output}"; then
        warn "Governed orphan baseline matches, but the allowlist still has stale entries"
      else
        pass "Governed orphan baseline matches the authoritative allowlist"
      fi
    else
      fail "Governed orphan baseline drift detected"
    fi
    while IFS= read -r line; do
      [[ -n "${line}" ]] && echo "  ${line}"
    done <<<"${orphan_output}"
  fi
fi

# ── 7. Validate governed active-but-unregistered baseline ────────────────────
echo ""
echo "--- 7. Governed active-but-unregistered baseline ---"

if [[ "${WARN_UNREGISTERED}" != "1" ]]; then
  echo "  (skipped — WARN_UNREGISTERED=0)"
elif [[ ! -f "${ACTIVE_UNREGISTERED_ALLOWLIST}" ]]; then
  fail "Active-unregistered allowlist missing: ${ACTIVE_UNREGISTERED_ALLOWLIST}"
elif ! command -v python3 >/dev/null 2>&1; then
  warn "python3 not found — skipping active-but-unregistered validation"
else
  active_output=""
  if active_output="$(
    python3 - "${REPO_ROOT}" "${REGISTRY}" "${ACTIVE_UNREGISTERED_ALLOWLIST}" <<'PY'
from __future__ import annotations

import json
import subprocess
import sys
import tempfile
from pathlib import Path

try:
    import yaml
except ImportError as exc:
    raise SystemExit("PyYAML is required to validate active-but-unregistered scripts") from exc

repo_root = Path(sys.argv[1])
registry_path = Path(sys.argv[2])
allowlist_path = Path(sys.argv[3])
generator = repo_root / "scripts/qa/generate-script-governance-catalog.py"

if not generator.is_file():
    raise SystemExit("catalog generator missing: scripts/qa/generate-script-governance-catalog.py")

with tempfile.TemporaryDirectory(prefix="validate-registry-active-") as tmpdir:
    catalog_path = Path(tmpdir) / "catalog.json"
    summary_path = Path(tmpdir) / "summary.md"
    subprocess.run(
        [
            "python3",
            str(generator),
            "--repo-root",
            str(repo_root),
            "--out",
            str(catalog_path),
            "--summary-out",
            str(summary_path),
        ],
        check=True,
        stdout=subprocess.DEVNULL,
    )
    catalog = json.loads(catalog_path.read_text(encoding="utf-8"))

registry = yaml.safe_load(registry_path.read_text(encoding="utf-8")) or {}
registered: set[str] = set()

for index, entry in enumerate(registry.get("scripts", []), start=1):
    if not isinstance(entry, dict):
        raise SystemExit(f"scripts[{index}] must be a mapping")
    path = entry.get("path")
    if isinstance(path, str) and path.strip():
        registered.add(path)

for inventory_key in ("ci_static_inventory", "ci_runtime_inventory"):
    inventory = registry.get(inventory_key) or {}
    for index, entry in enumerate(inventory.get("entries", []), start=1):
        if not isinstance(entry, dict):
            raise SystemExit(f"{inventory_key}.entries[{index}] must be a mapping")
        script = entry.get("script")
        if isinstance(script, str) and script.strip():
            registered.add(script)

critical_dirs = {
    "scripts/infra",
    "scripts/qa",
    "scripts/ci",
    "scripts/branding",
    "scripts/migrations",
    "scripts/tenants",
}
execution_caller_types = {"script", "makefile", "ci_workflow"}

current: list[str] = []
for entry in catalog.get("scripts", []):
    if not isinstance(entry, dict):
        continue
    path = entry.get("path")
    if not isinstance(path, str) or not path.endswith(".sh"):
        continue
    script_path = Path(path)
    if script_path.parent.as_posix() not in critical_dirs:
        continue
    if path in registered:
        continue
    caller_types = {
        item
        for item in entry.get("caller_types", [])
        if isinstance(item, str)
    }
    if caller_types & execution_caller_types:
        current.append(path)

allowlisted = [
    line.split("#", 1)[0].strip()
    for line in allowlist_path.read_text(encoding="utf-8").splitlines()
]
allowlisted = [line for line in allowlisted if line]

current_set = set(sorted(current))
allowlisted_set = set(allowlisted)
unexpected = sorted(current_set - allowlisted_set)
stale = sorted(allowlisted_set - current_set)

if unexpected:
    print("FAIL: new active-but-unregistered critical scripts detected.")
    for path in unexpected:
        print(f"  {path}")
    raise SystemExit(1)

if stale:
    print("WARN: stale active-unregistered allowlist entries detected (safe to remove):")
    for path in stale:
        print(f"  {path}")

print(
    "PASS: active-but-unregistered critical scripts match allowlisted baseline "
    f"({len(current_set)} paths)."
)
PY
  )"; then
    if grep -q '^WARN:' <<<"${active_output}"; then
      warn "Active-but-unregistered critical script baseline matches, but the allowlist has stale entries"
    else
      pass "Active-but-unregistered critical script baseline matches the authoritative allowlist"
    fi
  else
    fail "Active-but-unregistered critical script drift detected"
  fi
  while IFS= read -r line; do
    [[ -n "${line}" ]] && echo "  ${line}"
  done <<<"${active_output}"
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
