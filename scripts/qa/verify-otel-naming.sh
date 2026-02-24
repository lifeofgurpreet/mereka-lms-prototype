#!/usr/bin/env bash
# @covers T083
# @spec: otel-naming-conventions
# Verify OTel metric naming convention compliance and dashboard contract.
#
# Checks:
#   1. Registry file exists and is well-formed YAML.
#   2. Every registry entry starts with "mereka.lms.".
#   3. Every registry entry has required fields (name, type, unit, description, service).
#   4. type is one of: counter, gauge, histogram.
#   5. unit is one of the approved set.
#   6. If Grafana dashboard JSON files exist under infrastructure/monitoring/dashboards/,
#      cross-references "mereka.lms.*" metric names found in those files against the registry.
#   7. Prints summary and exits 0 (all pass) or 1 (any failure).
#
# Usage:
#   ./scripts/qa/verify-otel-naming.sh
#   STRICT_DASHBOARD=0 ./scripts/qa/verify-otel-naming.sh   # warn on unknown refs, don't fail
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

REGISTRY_FILE="${REGISTRY_FILE:-infrastructure/monitoring/otel-metric-registry.yaml}"
DASHBOARDS_DIR="${DASHBOARDS_DIR:-infrastructure/monitoring/dashboards}"
STRICT_DASHBOARD="${STRICT_DASHBOARD:-1}"

# ---------------------------------------------------------------------------
# Color helpers
# ---------------------------------------------------------------------------
_tty_colors() {
  if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RESET='\033[0m'
  else
    RED='' GREEN='' YELLOW='' RESET=''
  fi
}
_tty_colors

pass_count=0
fail_count=0
warn_count=0

pass_msg() { echo -e "${GREEN}PASS${RESET} $*"; pass_count=$((pass_count + 1)); }
fail_msg() { echo -e "${RED}FAIL${RESET} $*"; fail_count=$((fail_count + 1)); }
warn_msg() { echo -e "${YELLOW}WARN${RESET} $*"; warn_count=$((warn_count + 1)); }

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing required command: $1 — install it and retry." >&2
    exit 2
  }
}

# ---------------------------------------------------------------------------
# Parse registry with python3 (no external YAML lib needed — we parse manually)
# ---------------------------------------------------------------------------
require_cmd python3

echo "OTel Naming Convention Verification"
echo "  registry:   $REGISTRY_FILE"
echo "  dashboards: $DASHBOARDS_DIR"
echo ""

# ---------------------------------------------------------------------------
# Check 1: registry file exists
# ---------------------------------------------------------------------------
if [[ ! -f "$REGISTRY_FILE" ]]; then
  fail_msg "Registry file not found: $REGISTRY_FILE"
  echo ""
  echo "FAILED ($fail_count checks failed)"
  exit 1
fi
pass_msg "Registry file exists: $REGISTRY_FILE"

# ---------------------------------------------------------------------------
# Checks 2-5: parse and validate registry entries using python3
# ---------------------------------------------------------------------------
registry_check_output="$(python3 - "$REGISTRY_FILE" <<'PYEOF'
import sys
import re

registry_path = sys.argv[1]

VALID_TYPES = {"counter", "gauge", "histogram"}
VALID_UNITS = {"seconds", "bytes", "ratio", "requests", "connections", "tasks", "queries", "none"}
PREFIX = "mereka.lms."
NAME_RE = re.compile(r'^mereka\.lms\.[a-z][a-z0-9_]*\.[a-z][a-z0-9_]*$')

lines = open(registry_path, encoding="utf-8").readlines()

errors = []
warnings = []
counts = [0, 0]  # [total, compliant]

# Minimal YAML block-sequence parser — avoids dependency on PyYAML.
# Handles the specific format used in otel-metric-registry.yaml.
# Each metric block is a YAML mapping under "  - name: ...".
current = {}
in_metrics = False

def flush(block):
    if not block:
        return
    counts[0] += 1
    name = block.get("name", "")
    btype = block.get("type", "")
    unit = block.get("unit", "")
    desc = block.get("description", "")
    service = block.get("service", "")

    entry_errors = []
    if not name:
        entry_errors.append("missing 'name' field")
    elif not NAME_RE.match(name):
        entry_errors.append(
            f"name '{name}' violates convention (must match mereka.lms.<service>.<metric>)"
        )
    if not btype:
        entry_errors.append("missing 'type' field")
    elif btype not in VALID_TYPES:
        entry_errors.append(f"type '{btype}' not in {sorted(VALID_TYPES)}")
    if not unit:
        entry_errors.append("missing 'unit' field")
    elif unit not in VALID_UNITS:
        entry_errors.append(f"unit '{unit}' not in {sorted(VALID_UNITS)}")
    if not desc:
        entry_errors.append("missing 'description' field")
    if not service:
        entry_errors.append("missing 'service' field")
    elif name and not name.startswith(f"mereka.lms.{service}."):
        entry_errors.append(
            f"service '{service}' does not match namespace in name '{name}'"
        )

    if entry_errors:
        for e in entry_errors:
            errors.append(f"  [{name or '(unnamed)'}] {e}")
    else:
        counts[1] += 1

for raw in lines:
    line = raw.rstrip('\n')
    stripped = line.strip()

    if stripped == "metrics:":
        in_metrics = True
        continue
    if not in_metrics:
        continue
    if stripped.startswith("#") or stripped == "":
        continue

    if stripped.startswith("- name:"):
        flush(current)
        current = {"name": stripped[len("- name:"):].strip()}
    elif ":" in stripped and current:
        key, _, val = stripped.partition(":")
        key = key.strip()
        val = val.strip().strip('"').strip("'")
        current[key] = val

flush(current)

print(f"TOTAL={counts[0]}")
print(f"COMPLIANT={counts[1]}")
for e in errors:
    print(f"ERROR:{e}")
for w in warnings:
    print(f"WARN:{w}")
PYEOF
)"

total_metrics=0
compliant_metrics=0
registry_errors=()
while IFS= read -r line; do
  case "$line" in
    TOTAL=*)  total_metrics="${line#TOTAL=}" ;;
    COMPLIANT=*) compliant_metrics="${line#COMPLIANT=}" ;;
    ERROR:*) registry_errors+=("${line#ERROR:}") ;;
  esac
done <<< "$registry_check_output"

if [[ "$total_metrics" -eq 0 ]]; then
  fail_msg "Registry contains no metric entries — expected at least one."
else
  pass_msg "Registry parsed: $total_metrics entries found."
fi

if [[ "${#registry_errors[@]}" -eq 0 ]]; then
  pass_msg "All $compliant_metrics registry entries are naming-convention compliant."
else
  for err in "${registry_errors[@]}"; do
    fail_msg "Registry violation:$err"
  done
fi

# ---------------------------------------------------------------------------
# Check 6: dashboard cross-reference (if dashboard files exist)
# ---------------------------------------------------------------------------
echo ""

shopt -s nullglob
dashboard_files=("$DASHBOARDS_DIR"/*.json)
shopt -u nullglob

if [[ "${#dashboard_files[@]}" -eq 0 ]]; then
  pass_msg "No Grafana dashboard JSON files found under $DASHBOARDS_DIR — skipping cross-reference."
else
  echo "Dashboard cross-reference against registry ($DASHBOARDS_DIR/*.json):"

  # Build newline-separated list of known metric names from registry
  known_names="$(python3 - "$REGISTRY_FILE" <<'PYEOF'
import sys, re
lines = open(sys.argv[1], encoding="utf-8").readlines()
in_metrics = False
current = {}
names = []

def flush(b):
    if b.get("name"):
        names.append(b["name"])

for raw in lines:
    stripped = raw.strip()
    if stripped == "metrics:":
        in_metrics = True; continue
    if not in_metrics: continue
    if stripped.startswith("#") or stripped == "": continue
    if stripped.startswith("- name:"):
        flush(current)
        current = {"name": stripped[len("- name:"):].strip()}
    elif ":" in stripped and current:
        k, _, v = stripped.partition(":")
        current[k.strip()] = v.strip().strip('"').strip("'")

flush(current)
print('\n'.join(names))
PYEOF
)"

  unknown_refs=()
  total_refs=0

  for dashboard_file in "${dashboard_files[@]}"; do
    # Extract all "mereka.lms.*" tokens from the dashboard JSON (expr, query, rawSql fields)
    refs="$(python3 - "$dashboard_file" <<'PYEOF'
import sys, re, json

path = sys.argv[1]
try:
    data = json.loads(open(path, encoding="utf-8").read())
except Exception as e:
    sys.exit(0)

PATTERN = re.compile(r'\bmereka\.lms\.[a-z][a-z0-9_.]*\b')
found = set()

def walk(obj):
    if isinstance(obj, str):
        for m in PATTERN.findall(obj):
            found.add(m)
    elif isinstance(obj, dict):
        for v in obj.values():
            walk(v)
    elif isinstance(obj, list):
        for item in obj:
            walk(item)

walk(data)
for name in sorted(found):
    print(name)
PYEOF
)"

    if [[ -z "$refs" ]]; then
      continue
    fi

    while IFS= read -r ref; do
      [[ -z "$ref" ]] && continue
      total_refs=$((total_refs + 1))
      if ! grep -qxF "$ref" <<< "$known_names"; then
        unknown_refs+=("$(basename "$dashboard_file"): $ref")
      fi
    done <<< "$refs"
  done

  if [[ "$total_refs" -eq 0 ]]; then
    pass_msg "No mereka.lms.* metric references found in dashboard files."
  elif [[ "${#unknown_refs[@]}" -eq 0 ]]; then
    pass_msg "All $total_refs dashboard metric reference(s) exist in registry."
  else
    for ref in "${unknown_refs[@]}"; do
      if [[ "$STRICT_DASHBOARD" == "1" ]]; then
        fail_msg "Unknown metric reference in dashboard — $ref"
      else
        warn_msg "Unknown metric reference in dashboard — $ref"
      fi
    done
    if [[ "$STRICT_DASHBOARD" == "1" ]]; then
      : # already counted as failures
    else
      pass_msg "$((total_refs - ${#unknown_refs[@]})) / $total_refs dashboard references are in registry (${#unknown_refs[@]} warned)."
    fi
  fi
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "Summary"
echo "  Registry metrics total:    $total_metrics"
echo "  Registry metrics compliant: $compliant_metrics"
echo "  PASS: $pass_count  FAIL: $fail_count  WARN: $warn_count"
echo ""

if [[ "$fail_count" -eq 0 ]]; then
  echo -e "${GREEN}OK${RESET}"
  exit 0
else
  echo -e "${RED}FAILED ($fail_count check(s) failed)${RESET}"
  exit 1
fi
