#!/usr/bin/env bash
# test-score-tier-a-scripts.sh — Self-test for
# scripts/governance/score-tier-a-scripts.py
#
# Bead: mereka-lms-q69f.4
#
# Fixtures:
#   1. JSON mode emits valid JSON with expected structure.
#   2. Table mode emits a readable summary with AGGREGATE line.
#   3. Threshold mode exits non-zero when any script falls below threshold.
#   4. Threshold mode exits 0 when threshold is permissive (0.0).
#   5. JSON records cover all 10 Phase 1 tier-A scripts.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REAL_SCRIPT="${REPO_ROOT}/scripts/governance/score-tier-a-scripts.py"
TMPD="$(mktemp -d)"
trap 'rm -rf "${TMPD}"' EXIT

if [[ ! -x "${REAL_SCRIPT}" ]]; then
  echo "[FAIL] score-tier-a-scripts.py not found or not executable at ${REAL_SCRIPT}"
  exit 1
fi

PASS=0
FAIL=0

# ── Fixture 1: JSON mode emits valid JSON ─────────────────────────────────────
if python3 "${REAL_SCRIPT}" --json > "${TMPD}/out.json" 2>&1; then
  if python3 -c "
import json, sys
d = json.load(open('${TMPD}/out.json'))
assert d.get('phase') == 1, f'phase mismatch: {d.get(\"phase\")}'
assert 'records' in d and isinstance(d['records'], list), 'records missing'
assert d.get('max_score') == 5.0, f'max_score mismatch'
print('OK', len(d['records']))
" > "${TMPD}/check1.out" 2>&1; then
    echo "[PASS] fixture 1: JSON mode emits valid JSON ($(cat ${TMPD}/check1.out))"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] fixture 1: JSON validation failed"
    sed 's/^/  | /' "${TMPD}/check1.out" | tail -10
    FAIL=$((FAIL + 1))
  fi
else
  echo "[FAIL] fixture 1: --json mode exited non-zero"
  sed 's/^/  | /' "${TMPD}/out.json" | tail -5
  FAIL=$((FAIL + 1))
fi

# ── Fixture 2: Table mode emits AGGREGATE summary ─────────────────────────────
if python3 "${REAL_SCRIPT}" > "${TMPD}/out.table" 2>&1; then
  if grep -q "^AGGREGATE:" "${TMPD}/out.table"; then
    echo "[PASS] fixture 2: table mode emits AGGREGATE summary"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] fixture 2: AGGREGATE line missing from table output"
    FAIL=$((FAIL + 1))
  fi
else
  echo "[FAIL] fixture 2: table mode exited non-zero"
  FAIL=$((FAIL + 1))
fi

# ── Fixture 3: Threshold mode fails on unmet threshold ────────────────────────
if python3 "${REAL_SCRIPT}" --threshold 5.0 > "${TMPD}/out.t5" 2>&1; then
  echo "[FAIL] fixture 3: expected non-zero exit with threshold=5.0 (nothing scores 5/5 yet)"
  FAIL=$((FAIL + 1))
else
  echo "[PASS] fixture 3: threshold=5.0 triggers non-zero exit"
  PASS=$((PASS + 1))
fi

# ── Fixture 4: Threshold mode passes at threshold=0 ───────────────────────────
if python3 "${REAL_SCRIPT}" --threshold 0.0 > "${TMPD}/out.t0" 2>&1; then
  echo "[PASS] fixture 4: threshold=0.0 exits 0"
  PASS=$((PASS + 1))
else
  echo "[FAIL] fixture 4: threshold=0.0 unexpectedly failed"
  FAIL=$((FAIL + 1))
fi

# ── Fixture 5: JSON record count matches Phase 1 hardcode ─────────────────────
EXPECTED_N=10
ACTUAL_N=$(python3 -c "import json; print(len(json.load(open('${TMPD}/out.json'))['records']))")
if [[ "${ACTUAL_N}" == "${EXPECTED_N}" ]]; then
  echo "[PASS] fixture 5: JSON contains ${EXPECTED_N} records"
  PASS=$((PASS + 1))
else
  echo "[FAIL] fixture 5: expected ${EXPECTED_N} records, got ${ACTUAL_N}"
  FAIL=$((FAIL + 1))
fi

# ── Fixture 6: --auto-discover mode (Phase 2) ─────────────────────────────────
if python3 "${REAL_SCRIPT}" --auto-discover --json > "${TMPD}/out.auto.json" 2>"${TMPD}/auto.err"; then
  if python3 -c "
import json
d = json.load(open('${TMPD}/out.auto.json'))
assert d.get('phase') == 2, f'expected phase 2, got {d.get(\"phase\")}'
assert d.get('discovery_mode') == 'auto', f'discovery_mode mismatch'
# Auto-discover should find at least 10 scripts (sanity floor)
assert len(d['records']) >= 10, f'auto-discover returned too few: {len(d[\"records\"])}'
print('OK', len(d['records']))
" > "${TMPD}/check6.out" 2>&1; then
    echo "[PASS] fixture 6: --auto-discover emits valid phase-2 JSON ($(cat ${TMPD}/check6.out))"
    PASS=$((PASS + 1))
  else
    echo "[FAIL] fixture 6: auto-discover JSON validation failed"
    sed 's/^/  | /' "${TMPD}/check6.out" | tail -6
    FAIL=$((FAIL + 1))
  fi
else
  echo "[FAIL] fixture 6: --auto-discover exited non-zero"
  sed 's/^/  | /' "${TMPD}/auto.err" | tail -5
  FAIL=$((FAIL + 1))
fi

echo ""
echo "=== test-score-tier-a-scripts.sh summary ==="
echo "PASS=${PASS}  FAIL=${FAIL}"

if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
echo "OK"
