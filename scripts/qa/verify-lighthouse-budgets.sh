#!/usr/bin/env bash
# @covers AC-T084
# @spec: lighthouse-budgets_spec.md
# Verify that the Lighthouse CI budget file is present, valid, and within
# acceptable threshold ranges.
#
# Checks:
#   1. infrastructure/monitoring/lighthouse-budgets.json exists
#   2. File is valid JSON
#   3. All required MFE paths are present
#   4. JS budgets are within absolute ceiling (< 2 MB per page)
#   5. CSS budgets are within absolute ceiling (< 500 KB per page)
#   6. INP metric is referenced (not FID — FID was retired March 2024)
#   7. CLS budget is <= 0.1 (expressed as 100 in Lighthouse units)
#   8. LCP budget is <= 2500 ms
#
# Usage:
#   ./scripts/qa/verify-lighthouse-budgets.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

PASSED=0
FAILED=0

pass() { echo -e "${GREEN}OK${NC}   $1"; PASSED=$((PASSED + 1)); }
fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }

BUDGET_FILE="infrastructure/monitoring/lighthouse-budgets.json"

# ---------------------------------------------------------------------------
# 1. File existence
# ---------------------------------------------------------------------------
echo "== Checking: ${BUDGET_FILE} =="

if [[ -f "$BUDGET_FILE" ]]; then
  pass "budget file exists: ${BUDGET_FILE}"
else
  fail "budget file missing: ${BUDGET_FILE}"
  echo ""
  echo "Summary: PASSED=${PASSED} FAILED=${FAILED}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 2. Valid JSON
# ---------------------------------------------------------------------------
if python3 -c "import json, sys; json.load(open(sys.argv[1]))" "$BUDGET_FILE" 2>/dev/null; then
  pass "budget file is valid JSON"
else
  fail "budget file is not valid JSON"
  echo ""
  echo "Summary: PASSED=${PASSED} FAILED=${FAILED}"
  exit 1
fi

# ---------------------------------------------------------------------------
# 3. Required MFE paths present
# ---------------------------------------------------------------------------
echo ""
echo "== Checking: required MFE paths =="

REQUIRED_PATHS=(
  "/authn/login"
  "/dashboard"
  "/learning/course"
  "/profile"
  "/account"
  "/discussions"
)

for required_path in "${REQUIRED_PATHS[@]}"; do
  if python3 - "$BUDGET_FILE" "$required_path" <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))
needle = sys.argv[2]
found = any(entry.get("path", "").startswith(needle) for entry in data)
sys.exit(0 if found else 1)
PY
  then
    pass "path covered: ${required_path}"
  else
    fail "path missing: ${required_path}"
  fi
done

# ---------------------------------------------------------------------------
# 4 + 5. JS and CSS absolute ceilings
# ---------------------------------------------------------------------------
echo ""
echo "== Checking: resource size ceilings (JS < 2048 KB, CSS < 500 KB) =="

JS_CEILING_KB=2048
CSS_CEILING_KB=500

if python3 - "$BUDGET_FILE" "$JS_CEILING_KB" "$CSS_CEILING_KB" <<'PY'
import json, sys

data        = json.load(open(sys.argv[1]))
js_ceil     = int(sys.argv[2])
css_ceil    = int(sys.argv[3])
violations  = []

for entry in data:
  path = entry.get("path", "<unknown>")
  for rs in entry.get("resourceSizes", []):
    rt      = rs.get("resourceType", "")
    budget  = rs.get("budget", 0)
    if rt == "script" and budget > js_ceil:
      violations.append(f"  JS budget {budget} KB > ceiling {js_ceil} KB on path: {path}")
    if rt == "stylesheet" and budget > css_ceil:
      violations.append(f"  CSS budget {budget} KB > ceiling {css_ceil} KB on path: {path}")

for v in violations:
  print(v, file=sys.stderr)
sys.exit(1 if violations else 0)
PY
then
  pass "all JS budgets <= ${JS_CEILING_KB} KB"
  pass "all CSS budgets <= ${CSS_CEILING_KB} KB"
else
  fail "one or more JS/CSS budgets exceed absolute ceilings"
fi

# ---------------------------------------------------------------------------
# 6. INP referenced (not FID)
# ---------------------------------------------------------------------------
echo ""
echo "== Checking: INP metric present, FID absent =="

RAW_CONTENT="$(python3 -c "import json,sys; print(json.dumps(json.load(open(sys.argv[1]))))" "$BUDGET_FILE")"

if grep -q "interaction-to-next-paint" <<<"$RAW_CONTENT"; then
  pass "INP metric present (interaction-to-next-paint)"
else
  fail "INP metric missing — add 'experimental-interaction-to-next-paint' timings"
fi

if grep -qi '"first-input-delay"\|"fid"' <<<"$RAW_CONTENT"; then
  fail "FID metric found — FID was retired in March 2024, replace with INP"
else
  pass "FID metric absent (correctly omitted)"
fi

# ---------------------------------------------------------------------------
# 7. CLS budget <= 100 (0.1 in Lighthouse units)
# ---------------------------------------------------------------------------
echo ""
echo "== Checking: CLS budgets <= 100 (0.10) =="

if python3 - "$BUDGET_FILE" <<'PY'
import json, sys

data       = json.load(open(sys.argv[1]))
violations = []

for entry in data:
  path = entry.get("path", "<unknown>")
  for t in entry.get("timings", []):
    if "cumulative-layout-shift" in t.get("metric", ""):
      budget = t.get("budget", 0)
      if budget > 100:
        violations.append(f"  CLS budget {budget} > 100 on path: {path}")

for v in violations:
  print(v, file=sys.stderr)
sys.exit(1 if violations else 0)
PY
then
  pass "all CLS budgets <= 100 (0.10)"
else
  fail "one or more CLS budgets exceed 0.10"
fi

# ---------------------------------------------------------------------------
# 8. LCP budget <= 2500 ms
# ---------------------------------------------------------------------------
echo ""
echo "== Checking: LCP budgets <= 2500 ms =="

if python3 - "$BUDGET_FILE" <<'PY'
import json, sys

data       = json.load(open(sys.argv[1]))
violations = []

for entry in data:
  path = entry.get("path", "<unknown>")
  for t in entry.get("timings", []):
    if "largest-contentful-paint" in t.get("metric", ""):
      budget = t.get("budget", 0)
      if budget > 2500:
        violations.append(f"  LCP budget {budget} ms > 2500 ms on path: {path}")

for v in violations:
  print(v, file=sys.stderr)
sys.exit(1 if violations else 0)
PY
then
  pass "all LCP budgets <= 2500 ms"
else
  fail "one or more LCP budgets exceed 2500 ms"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "=============================="
echo "Summary: PASSED=${PASSED} FAILED=${FAILED}"
echo "=============================="

if [[ "$FAILED" -gt 0 ]]; then
  exit 1
fi
