#!/usr/bin/env bash
# @spec: cross-cutting-requirements_spec.md
#
# Verify that motion transforms in the MFE stylesheet are guarded by
# @media (prefers-reduced-motion: no-preference).

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"
MFE_SCSS_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/scss"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }

find_mfe_scss_files() {
  find "$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe" \
    -type f \
    -name '*.scss' \
    | sort
}

echo "=== MFE Reduced-Motion Guard Verification ==="
echo ""

if [[ ! -f "$MFE_SCSS" ]]; then
  fail "mereka.scss missing: $MFE_SCSS"
  echo ""
  echo "PASS: $PASS | FAIL: $FAIL | WARN: $WARN"
  exit 1
fi

echo "--- Check 1: Guard block exists ---"
if find_mfe_scss_files | xargs -r grep -q '@media (prefers-reduced-motion: no-preference)'; then
  pass "Found prefers-reduced-motion guard block"
else
  fail "Missing @media (prefers-reduced-motion: no-preference) guard block"
fi

echo "--- Check 2: transform rules are guarded ---"
PY_OUT="$(python3 - "$REPO_ROOT" <<'PY'
import json, sys
import re
from pathlib import Path

violations = []
transform_count = 0
guard_depth_hits = 0

root = Path(sys.argv[1]) / "infrastructure/tutor/themes/mereka/mfe"
for path in sorted(root.rglob("*.scss")):
    lines = path.read_text(encoding="utf-8").splitlines()
    stack = []

    for i, raw in enumerate(lines, start=1):
        s = raw.strip()
        if s.startswith("//") or s.startswith("/*") or s.startswith("*"):
            continue

        opens = raw.count("{")
        if opens:
            header = raw.split("{", 1)[0].strip()
            block = "other"
            if "@media" in header and "prefers-reduced-motion" in header:
                if "no-preference" in header:
                    block = "motion_ok"
                else:
                    block = "motion_other"
            for _ in range(opens):
                stack.append(block)

        if re.search(r"(?<![-\w])transform\s*:", s):
            transform_count += 1
            if "motion_ok" in stack:
                guard_depth_hits += 1
            else:
                violations.append({"file": str(path), "line": i, "text": s})

        closes = raw.count("}")
        for _ in range(closes):
            if stack:
                stack.pop()

print(json.dumps({
    "transform_count": transform_count,
    "guard_depth_hits": guard_depth_hits,
    "violations": violations,
}))
PY
)"

read -r TRANSFORM_COUNT GUARDED_COUNT VIOLATIONS_COUNT <<< "$(PY_OUT="$PY_OUT" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["PY_OUT"])
print(data["transform_count"], data["guard_depth_hits"], len(data["violations"]))
PY
)"

echo "  transform declarations: $TRANSFORM_COUNT"
echo "  guarded transform declarations: $GUARDED_COUNT"

if [[ "$TRANSFORM_COUNT" -eq 0 ]]; then
  warn "No transform declarations found in mereka.scss (nothing to validate)"
elif [[ "$VIOLATIONS_COUNT" -eq 0 ]]; then
  pass "All transform declarations are inside reduced-motion guard blocks"
else
  fail "Found unguarded transform declaration(s):"
  PY_OUT="$PY_OUT" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["PY_OUT"])
for item in data["violations"]:
    print(f"  - {item['file']}:{item['line']}: {item['text']}")
PY
fi

echo ""
echo "PASS: $PASS | FAIL: $FAIL | WARN: $WARN"

if [[ "$FAIL" -ne 0 ]]; then
  exit 1
fi
