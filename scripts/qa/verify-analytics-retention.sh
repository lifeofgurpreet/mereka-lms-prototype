#!/usr/bin/env bash
# verify-analytics-retention.sh — Validate the analytics data retention policy config.
#
# Reads infrastructure/tutor/analytics-retention-config.yaml and verifies:
#   - All required fields are present
#   - retention_days values are within acceptable range (30–730)
#   - last_reviewed date is not older than 180 days
#   - Prints a summary of all retention tiers
#
# Usage:
#   ./scripts/qa/verify-analytics-retention.sh
#
# Requirements: python3 (for YAML parsing via PyYAML or stdlib fallback)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
CONFIG_FILE="${REPO_ROOT}/infrastructure/tutor/analytics-retention-config.yaml"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASS=0
FAIL=0

pass() {
  echo -e "${GREEN}PASS${NC}  $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}FAIL${NC}  $1"
  FAIL=$((FAIL + 1))
}

echo "=== Analytics Data Retention — Policy Verification ==="
echo "Config: ${CONFIG_FILE}"
echo ""

# --- Prerequisite: python3 ---
if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}ERROR${NC} python3 is required but not found."
  exit 1
fi

# --- Check config file exists ---
if [[ ! -f "${CONFIG_FILE}" ]]; then
  fail "Config file not found: ${CONFIG_FILE}"
  echo ""
  echo -e "${RED}FAILED${NC} (${FAIL} failures)"
  exit 1
fi
pass "Config file exists"

# --- Parse and validate via Python ---
PY_EXIT=0
python3 - "${CONFIG_FILE}" <<'PYEOF' || PY_EXIT=$?
import sys
import datetime

config_path = sys.argv[1]

# Try PyYAML first, fall back to a minimal YAML subset parser
try:
    import yaml
    with open(config_path) as fh:
        doc = yaml.safe_load(fh)
except ImportError:
    # Minimal fallback: use json after converting trivial YAML (no nested lists/anchors)
    # This is intentionally limited — install pyyaml for full support.
    print("WARN  PyYAML not installed; using minimal fallback parser (install pyyaml for reliability)")

    with open(config_path) as fh:
        raw = fh.read()

    def minimal_yaml_to_dict(text):
        """Convert a simple key: value YAML (no lists, no anchors) to a nested dict."""
        result = {}
        stack = [(result, -1)]
        for line in text.splitlines():
            stripped = line.rstrip()
            if not stripped or stripped.lstrip().startswith('#'):
                continue
            indent = len(stripped) - len(stripped.lstrip())
            key_val = stripped.lstrip()
            if ':' not in key_val:
                continue
            key, _, val = key_val.partition(':')
            key = key.strip()
            val = val.strip().strip('"').strip("'")
            if val == 'null':
                val = None
            # Pop stack to correct level
            while len(stack) > 1 and stack[-1][1] >= indent:
                stack.pop()
            parent = stack[-1][0]
            if val == '' or (val is None and key_val.endswith(':')):
                child = {}
                parent[key] = child
                stack.append((child, indent))
            else:
                parent[key] = val
        return result

    doc = minimal_yaml_to_dict(raw)

RED   = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW= '\033[1;33m'
CYAN  = '\033[0;36m'
NC    = '\033[0m'

PASS = 0
FAIL = 0

MIN_RETENTION_DAYS = 30
MAX_RETENTION_DAYS = 730
MAX_REVIEW_AGE_DAYS = 180

def ok(msg):
    global PASS
    print(f"{GREEN}PASS{NC}  {msg}")
    PASS += 1

def err(msg):
    global FAIL
    print(f"{RED}FAIL{NC}  {msg}")
    FAIL += 1

# --- Top-level structure ---
policy = doc.get('retention_policy', {})

if not policy:
    err("Missing top-level 'retention_policy' key")
    sys.exit(1)
ok("Top-level 'retention_policy' key present")

# --- Required top-level fields ---
for field in ('version', 'last_reviewed', 'tiers'):
    if field in policy:
        ok(f"Field '{field}' present")
    else:
        err(f"Required field '{field}' is missing")

# --- last_reviewed date check ---
last_reviewed_raw = policy.get('last_reviewed', '')
if last_reviewed_raw:
    try:
        last_reviewed = datetime.date.fromisoformat(str(last_reviewed_raw))
        age_days = (datetime.date.today() - last_reviewed).days
        if age_days <= MAX_REVIEW_AGE_DAYS:
            ok(f"last_reviewed is {age_days} days ago (limit: {MAX_REVIEW_AGE_DAYS} days)")
        else:
            err(f"last_reviewed is {age_days} days ago — policy review overdue (limit: {MAX_REVIEW_AGE_DAYS} days)")
    except ValueError:
        err(f"last_reviewed '{last_reviewed_raw}' is not a valid ISO date (YYYY-MM-DD)")

# --- Tiers ---
tiers = policy.get('tiers', {})
if not tiers:
    err("'tiers' is empty or missing")
    sys.exit(1)

REQUIRED_TIERS = ('raw_events', 'pii_events', 'debug_traces', 'aggregated_reports')
for tier_name in REQUIRED_TIERS:
    if tier_name in tiers:
        ok(f"Tier '{tier_name}' defined")
    else:
        err(f"Required tier '{tier_name}' is missing")

# --- Per-tier field validation ---
print(f"\n{CYAN}--- Retention Tier Summary ---{NC}")
for tier_name, tier in tiers.items():
    retention_days_raw = tier.get('retention_days')
    retention_indefinite = tier.get('retention') == 'indefinite'
    enforcement = tier.get('enforcement', '')
    target_table = tier.get('target_table')

    if retention_indefinite:
        print(f"  {CYAN}{tier_name:<20}{NC}  indefinite        enforcement: {enforcement}")
        ok(f"Tier '{tier_name}': indefinite retention is valid")
        continue

    # retention_days must be present and numeric for non-indefinite tiers
    if retention_days_raw is None:
        err(f"Tier '{tier_name}': 'retention_days' is required (or set retention: indefinite)")
        continue

    try:
        retention_days = int(retention_days_raw)
    except (ValueError, TypeError):
        err(f"Tier '{tier_name}': 'retention_days' must be an integer, got: {retention_days_raw!r}")
        continue

    range_ok = MIN_RETENTION_DAYS <= retention_days <= MAX_RETENTION_DAYS
    status = "OK" if range_ok else "OUT-OF-RANGE"
    print(f"  {CYAN}{tier_name:<20}{NC}  {retention_days:>4} days  ({status:<11})  enforcement: {enforcement}  table: {target_table or 'n/a'}")

    if range_ok:
        ok(f"Tier '{tier_name}': retention_days={retention_days} is within [{MIN_RETENTION_DAYS}, {MAX_RETENTION_DAYS}]")
    else:
        err(f"Tier '{tier_name}': retention_days={retention_days} is outside acceptable range [{MIN_RETENTION_DAYS}, {MAX_RETENTION_DAYS}]")

    if not enforcement:
        err(f"Tier '{tier_name}': 'enforcement' field is missing")
    else:
        ok(f"Tier '{tier_name}': enforcement='{enforcement}'")

print(f"\n=== Python validation summary ===")
print(f"{GREEN}PASS:{NC} {PASS}  {RED}FAIL:{NC} {FAIL}")

if FAIL > 0:
    sys.exit(1)
sys.exit(0)
PYEOF

echo ""
if [[ $PY_EXIT -eq 0 && $FAIL -eq 0 ]]; then
  echo -e "${GREEN}OK${NC} — Analytics retention policy is valid."
  exit 0
else
  echo -e "${RED}FAILED${NC} — Analytics retention policy has validation errors."
  exit 1
fi
