#!/usr/bin/env bash
# Verify visual regression baseline governance.
#
# Checks:
#   1. visual-baselines/ directory exists
#   2. visual-baselines/baselines.json exists and is valid JSON
#   3. Each baseline entry has all required fields
#   4. Each baseline's screenshot file exists on disk
#   5. No baseline is older than MAX_BASELINE_AGE_DAYS (default: 90)
#
# Usage:
#   ./scripts/qa/verify-visual-baselines.sh
#   MAX_BASELINE_AGE_DAYS=30 ./scripts/qa/verify-visual-baselines.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# ---------------------------------------------------------------------------
# Config (allow env overrides for testing)
# ---------------------------------------------------------------------------
BASELINES_DIR="${BASELINES_DIR:-${REPO_ROOT}/visual-baselines}"
BASELINES_JSON="${BASELINES_JSON:-${BASELINES_DIR}/baselines.json}"
SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-${BASELINES_DIR}/screenshots}"
MAX_BASELINE_AGE_DAYS="${MAX_BASELINE_AGE_DAYS:-90}"

# Required fields in each baseline entry
REQUIRED_FIELDS="page,viewport,filename,capture_date,approved_by,git_sha"

# Expected page/viewport combinations once the baseline set is fully populated.
# The script warns (but does not fail) if fewer entries are present, allowing
# a bootstrap state where only some pages have been captured so far.
EXPECTED_PAGES=(
  "login--desktop"
  "login--mobile"
  "dashboard--desktop"
  "dashboard--mobile"
  "course--desktop"
  "course--mobile"
  "footer--desktop"
  "footer--mobile"
)

# ---------------------------------------------------------------------------
# Colors + counters
# ---------------------------------------------------------------------------
GREEN="\033[0;32m"
RED="\033[0;31m"
YELLOW="\033[0;33m"
NC="\033[0m"

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo -e "${GREEN}PASS${NC}  $*"; }
fail() { FAIL=$((FAIL + 1)); echo -e "${RED}FAIL${NC}  $*"; }
warn() { WARN=$((WARN + 1)); echo -e "${YELLOW}WARN${NC}  $*"; }

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------
if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required for JSON parsing" >&2
  exit 2
fi

# ---------------------------------------------------------------------------
# 1. Directory exists
# ---------------------------------------------------------------------------
if [[ -d "$BASELINES_DIR" ]]; then
  pass "visual-baselines/ directory exists ($BASELINES_DIR)"
else
  fail "visual-baselines/ directory not found: $BASELINES_DIR"
  echo ""
  echo "  Create it with:"
  echo "    mkdir -p ${BASELINES_DIR}/screenshots"
  echo "    echo '{\"schema_version\":1,\"baselines\":[]}' > ${BASELINES_JSON}"
  echo ""
  echo -e "  ${RED}RESULT: FAIL${NC} (${FAIL} failed, ${PASS} passed, ${WARN} warnings)"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. baselines.json exists and is valid JSON
# ---------------------------------------------------------------------------
if [[ ! -f "$BASELINES_JSON" ]]; then
  fail "baselines.json not found: $BASELINES_JSON"
  echo -e "  ${RED}RESULT: FAIL${NC} (${FAIL} failed, ${PASS} passed, ${WARN} warnings)"
  exit 1
fi

if python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$BASELINES_JSON" 2>/dev/null; then
  pass "baselines.json is valid JSON"
else
  fail "baselines.json is not valid JSON: $BASELINES_JSON"
  echo -e "  ${RED}RESULT: FAIL${NC} (${FAIL} failed, ${PASS} passed, ${WARN} warnings)"
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Parse baseline count
# ---------------------------------------------------------------------------
baseline_count="$(python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
print(len(data.get('baselines', [])))
" "$BASELINES_JSON")"

if [[ "$baseline_count" -eq 0 ]]; then
  warn "baselines.json contains 0 entries — bootstrap state (acceptable until first capture run)"
  echo ""
  echo -e "  ${YELLOW}RESULT: WARN${NC} (${FAIL} failed, ${PASS} passed, ${WARN} warnings)"
  echo "  No baseline entries to validate. Run capture-branding-screenshots.sh to populate."
  exit 0
fi

pass "baselines.json contains ${baseline_count} baseline entries"

# ---------------------------------------------------------------------------
# 4 & 5. Per-entry validation (required fields, file exists, age)
# ---------------------------------------------------------------------------
py_summary="$(python3 - "$BASELINES_JSON" "$SCREENSHOTS_DIR" "$MAX_BASELINE_AGE_DAYS" "$REQUIRED_FIELDS" <<'PYEOF'
import json, sys, os, datetime

baselines_json   = sys.argv[1]
screenshots_dir  = sys.argv[2]
max_age_days     = int(sys.argv[3])
required_fields  = [f for f in sys.argv[4].split(",") if f]

data      = json.load(open(baselines_json))
baselines = data.get("baselines", [])

GREEN  = "\033[0;32m"
RED    = "\033[0;31m"
NC     = "\033[0m"

py_pass = 0
py_fail = 0
today   = datetime.date.today()

for i, entry in enumerate(baselines):
    label = entry.get("filename") or f"entry[{i}]"

    # Required fields
    missing = [f for f in required_fields if not entry.get(f)]
    if missing:
        print(f"{RED}FAIL{NC}  [{label}] missing required fields: {', '.join(missing)}")
        py_fail += 1
    else:
        print(f"{GREEN}PASS{NC}  [{label}] all required fields present")
        py_pass += 1

    # Screenshot file on disk
    filename = entry.get("filename", "")
    if filename:
        filepath = os.path.join(screenshots_dir, filename)
        if os.path.isfile(filepath):
            print(f"{GREEN}PASS{NC}  [{label}] screenshot file exists")
            py_pass += 1
        else:
            print(f"{RED}FAIL{NC}  [{label}] screenshot file not found: {filepath}")
            py_fail += 1

    # Age check
    capture_date_str = entry.get("capture_date", "")
    if capture_date_str:
        try:
            capture_date = datetime.date.fromisoformat(capture_date_str)
            age_days = (today - capture_date).days
            if age_days > max_age_days:
                print(f"{RED}FAIL{NC}  [{label}] baseline is {age_days} days old (max {max_age_days}); update required")
                py_fail += 1
            else:
                print(f"{GREEN}PASS{NC}  [{label}] baseline age {age_days}d is within {max_age_days}d limit")
                py_pass += 1
        except ValueError:
            print(f"{RED}FAIL{NC}  [{label}] invalid capture_date format (expected YYYY-MM-DD): {capture_date_str!r}")
            py_fail += 1

# Last two lines: pass count, fail count (shell reads these)
print(f"__counts__ {py_pass} {py_fail}")
PYEOF
)"

# Extract per-entry output (print all lines except the __counts__ line)
while IFS= read -r line; do
  if [[ "$line" == __counts__* ]]; then
    read -r _ py_pass py_fail <<<"$line"
  else
    echo -e "$line"
  fi
done <<<"$py_summary"

PASS=$((PASS + py_pass))
FAIL=$((FAIL + py_fail))

# ---------------------------------------------------------------------------
# 6. Coverage warning — expected pages not yet in index
# ---------------------------------------------------------------------------
declare -A present_keys=()
while IFS= read -r key; do
  [[ -n "$key" ]] && present_keys["$key"]=1
done < <(python3 -c "
import json, sys
data = json.load(open(sys.argv[1]))
for e in data.get('baselines', []):
    page     = e.get('page', '')
    viewport = e.get('viewport', '')
    if page and viewport:
        print(f'{page}--{viewport}')
" "$BASELINES_JSON")

missing_coverage=()
for key in "${EXPECTED_PAGES[@]}"; do
  if [[ -z "${present_keys[$key]:-}" ]]; then
    missing_coverage+=("$key")
  fi
done

if [[ "${#missing_coverage[@]}" -gt 0 ]]; then
  warn "The following expected page/viewport combinations have no baseline yet:"
  for key in "${missing_coverage[@]}"; do
    echo "      - $key"
  done
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "--------------------------------------------------------------"
echo "  Baselines checked : ${baseline_count}"
echo "  Max baseline age  : ${MAX_BASELINE_AGE_DAYS} days"
echo "  Checks passed     : ${PASS}"
echo "  Checks failed     : ${FAIL}"
echo "  Warnings          : ${WARN}"
echo "--------------------------------------------------------------"

if [[ "$FAIL" -gt 0 ]]; then
  echo -e "  ${RED}RESULT: FAIL${NC}"
  echo ""
  echo "  Remediation:"
  echo "    1. Run capture-branding-screenshots.sh to refresh screenshots."
  echo "    2. Update visual-baselines/baselines.json with new capture_date,"
  echo "       approved_by, and git_sha."
  echo "    3. Open a PR for baseline approval per docs/ops/runbooks/VISUAL_REGRESSION_RUNBOOK.md."
  exit 1
fi

echo -e "  ${GREEN}RESULT: PASS${NC}"
exit 0
