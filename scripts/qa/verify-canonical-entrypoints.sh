#!/usr/bin/env bash
# verify-canonical-entrypoints.sh — Validate the canonical entrypoint map.
#
# Checks:
#   1. canonical-entrypoints.yaml exists in scripts/governance/
#   2. YAML is syntactically valid (requires python3 + PyYAML)
#   3. Required top-level fields are present (version, entrypoints)
#   4. All 6 required workflow_ids are declared
#   5. Each entrypoint has required fields (workflow_id, canonical_script,
#      owner, invocation, proof_output, status)
#   6. Each canonical_script path exists in the repo
#   7. Each status value is one of: canonical | legacy | deprecated
#   8. Each alternative path is distinct from the canonical_script
#
# Usage:
#   bash scripts/qa/verify-canonical-entrypoints.sh
#   REPO_ROOT_OVERRIDE=/tmp/fixture bash scripts/qa/verify-canonical-entrypoints.sh
#
# Exit codes:
#   0  All checks PASS (warnings do not fail)
#   1  One or more checks FAIL

set -euo pipefail

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
CANONICAL_MAP="${REPO_ROOT}/scripts/governance/canonical-entrypoints.yaml"

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

echo "=== Canonical Entrypoint Map Validation ==="
echo "Map:  ${CANONICAL_MAP}"
echo "Root: ${REPO_ROOT}"
echo ""

# ── 1. File exists ────────────────────────────────────────────────────────────
echo "--- 1. File exists ---"
if [[ -f "${CANONICAL_MAP}" ]]; then
  pass "canonical-entrypoints.yaml found"
else
  fail "canonical-entrypoints.yaml not found at ${CANONICAL_MAP}"
  echo ""
  echo -e "${RED}RESULT: FAIL${NC} — map file missing; cannot continue."
  exit 1
fi

# ── 2. YAML syntax ────────────────────────────────────────────────────────────
echo ""
echo "--- 2. YAML syntax ---"
if python3 -c "import yaml; yaml.safe_load(open('${CANONICAL_MAP}'))" 2>/dev/null; then
  pass "YAML parses without error"
else
  fail "YAML syntax error in canonical-entrypoints.yaml"
  python3 -c "import yaml; yaml.safe_load(open('${CANONICAL_MAP}'))" 2>&1 || true
  echo ""
  echo -e "${RED}RESULT: FAIL${NC} — cannot parse YAML; halting further checks."
  exit 1
fi

# ── 3. Top-level structure ────────────────────────────────────────────────────
echo ""
echo "--- 3. Top-level structure ---"
HAS_VERSION=$(python3 -c "
import yaml
d = yaml.safe_load(open('${CANONICAL_MAP}'))
print('yes' if 'version' in d else 'no')
")
HAS_ENTRYPOINTS=$(python3 -c "
import yaml
d = yaml.safe_load(open('${CANONICAL_MAP}'))
print('yes' if isinstance(d.get('entrypoints'), list) else 'no')
")

[[ "$HAS_VERSION" == "yes" ]] && pass "version field present" || fail "version field missing"
[[ "$HAS_ENTRYPOINTS" == "yes" ]] && pass "entrypoints list present" || fail "entrypoints list missing or not a list"

# ── 4. Required workflow IDs ──────────────────────────────────────────────────
echo ""
echo "--- 4. Required workflow_ids ---"
REQUIRED_IDS="release migrate promote publish-image deploy runtime-validation"

DECLARED_IDS=$(python3 -c "
import yaml
d = yaml.safe_load(open('${CANONICAL_MAP}'))
for ep in d.get('entrypoints', []):
    wid = ep.get('workflow_id', '')
    if wid:
        print(wid)
")

for wid in $REQUIRED_IDS; do
  if echo "$DECLARED_IDS" | grep -qxF "$wid"; then
    pass "workflow_id '$wid' declared"
  else
    fail "workflow_id '$wid' is MISSING from entrypoints"
  fi
done

# ── 5. Required fields per entrypoint ─────────────────────────────────────────
echo ""
echo "--- 5. Required fields per entrypoint ---"
FIELD_CHECK_OUTPUT=$(python3 - "${CANONICAL_MAP}" <<'PY'
import yaml, sys

required = ["workflow_id", "canonical_script", "owner", "invocation", "proof_output", "status"]
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)

errors = []
for ep in data.get("entrypoints", []):
    wid = ep.get("workflow_id", "<unknown>")
    for field in required:
        if field not in ep or not ep[field]:
            errors.append(f"{wid}: missing required field '{field}'")

if errors:
    for e in errors:
        print("  MISSING: " + e)
    sys.exit(1)

print(f"  All {len(data.get('entrypoints', []))} entrypoints have required fields")
PY
) && FIELD_CHECK_RC=0 || FIELD_CHECK_RC=$?
echo "$FIELD_CHECK_OUTPUT"
[[ $FIELD_CHECK_RC -eq 0 ]] && pass "All entrypoints have required fields" || fail "One or more entrypoints missing required fields"

# ── 6. Canonical script paths exist ──────────────────────────────────────────
echo ""
echo "--- 6. Canonical script paths exist ---"
CANONICAL_PATHS=$(python3 -c "
import yaml
d = yaml.safe_load(open('${CANONICAL_MAP}'))
for ep in d.get('entrypoints', []):
    p = ep.get('canonical_script', '')
    if p:
        print(p)
")

while IFS= read -r script_path; do
  [[ -z "$script_path" ]] && continue
  full_path="${REPO_ROOT}/${script_path}"
  if [[ -f "$full_path" ]]; then
    pass "exists: ${script_path}"
  else
    fail "NOT FOUND: ${script_path}"
  fi
done <<< "$CANONICAL_PATHS"

# ── 7. Status values are valid ────────────────────────────────────────────────
echo ""
echo "--- 7. Status values ---"
VALID_STATUSES="canonical legacy deprecated"

STATUS_LINES=$(python3 -c "
import yaml
d = yaml.safe_load(open('${CANONICAL_MAP}'))
for ep in d.get('entrypoints', []):
    print(ep.get('workflow_id','?') + ':' + ep.get('status',''))
")

while IFS= read -r status_line; do
  [[ -z "$status_line" ]] && continue
  wid="${status_line%%:*}"
  status="${status_line#*:}"
  if echo "$VALID_STATUSES" | grep -qwF "$status"; then
    pass "${wid}: status='${status}' is valid"
  else
    fail "${wid}: status='${status}' is not one of: ${VALID_STATUSES}"
  fi
done <<< "$STATUS_LINES"

# ── 8. Alternatives are distinct from canonical ───────────────────────────────
echo ""
echo "--- 8. Alternatives distinct from canonical ---"
ALT_CHECK_OUTPUT=$(python3 - "${CANONICAL_MAP}" <<'PY'
import yaml, sys

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f)

errors = []
for ep in data.get("entrypoints", []):
    wid = ep.get("workflow_id", "<unknown>")
    canon = ep.get("canonical_script", "")
    for alt in ep.get("alternatives", []) or []:
        alt_path = alt.get("path", "") if isinstance(alt, dict) else str(alt)
        if alt_path == canon:
            errors.append(f"{wid}: alternative path is same as canonical_script: {alt_path}")

if errors:
    for e in errors:
        print("  CONFLICT: " + e)
    sys.exit(1)

print("  No alternative duplicates the canonical_script")
PY
) && ALT_CHECK_RC=0 || ALT_CHECK_RC=$?
echo "$ALT_CHECK_OUTPUT"
[[ $ALT_CHECK_RC -eq 0 ]] && pass "No alternative path duplicates its canonical_script" || fail "An alternative path duplicates the canonical_script"

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "━━━ Canonical Entrypoint Map Validation Summary ━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}PASS${NC}  ${PASS}"
echo -e "  ${YELLOW}WARN${NC}  ${WARN}"
echo -e "  ${RED}FAIL${NC}  ${FAIL}"
echo ""

if [[ $FAIL -gt 0 ]]; then
  echo -e "${RED}RESULT: FAIL — ${FAIL} check(s) failed.${NC}"
  exit 1
else
  echo -e "${GREEN}RESULT: PASS — canonical entrypoint map is valid.${NC}"
  exit 0
fi
