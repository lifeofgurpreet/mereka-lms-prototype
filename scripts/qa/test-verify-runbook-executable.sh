#!/usr/bin/env bash
# test-verify-runbook-executable.sh — Self-test for
# scripts/governance/verify-runbook-executable.sh
#
# Bead: mereka-lms-q69f.3 (Phase 0 burn #3 — Doctrine Rule 3 verifier
# shipped without fixtures; closes that gap).
#
# Fixtures:
#   1. No-executable runbooks: a runbooks dir with only a status:active
#      runbook. Verifier must exit 0 with PASS=0 WARN=0 FAIL=0.
#   2. Executable runbook + NO evidence (default mode): verifier must exit 0
#      with WARN >= 1. Smoke-tests the grace-period contract.
#   3. Executable runbook + NO evidence (--strict mode): verifier must exit
#      non-zero with FAIL >= 1. Smoke-tests the CI-gate contract.
#   4. Executable runbook + FRESH evidence: verifier must exit 0 with
#      PASS >= 1 and no WARN/FAIL. Smoke-tests the happy path.
#   5. Executable runbook + STALE evidence (> MAX_AGE_DAYS): verifier under
#      --strict must exit non-zero. Tests age enforcement.
#
# All fixtures inject their runbooks/evidence dirs via --runbooks-dir and
# --evidence-dir, so the real repo state is never mutated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REAL_SCRIPT="${REPO_ROOT}/scripts/governance/verify-runbook-executable.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "${TMPD}"' EXIT

if [[ ! -x "${REAL_SCRIPT}" ]]; then
  echo "[FAIL] verify-runbook-executable.sh not found or not executable at ${REAL_SCRIPT}"
  exit 1
fi

PASS=0
FAIL=0

expect_pass() {
  local label="$1"; shift
  if "$@" >"${TMPD}/out" 2>&1; then
    echo "[PASS] ${label}"
    PASS=$((PASS + 1))
  else
    local rc=$?
    echo "[FAIL] ${label} (exit=${rc})"
    sed 's/^/  | /' "${TMPD}/out" | tail -15
    FAIL=$((FAIL + 1))
  fi
}

expect_fail() {
  local label="$1"; shift
  if "$@" >"${TMPD}/out" 2>&1; then
    echo "[FAIL] ${label} — expected non-zero exit, got 0"
    sed 's/^/  | /' "${TMPD}/out" | tail -10
    FAIL=$((FAIL + 1))
  else
    echo "[PASS] ${label}"
    PASS=$((PASS + 1))
  fi
}

make_runbook() {
  local path="$1" status="$2"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
---
title: Q69F.3 Test Runbook
status: ${status}
owner: q69f.3-test
---

# Test runbook for q69f.3 fixtures — ignore in production.
EOF
}

make_evidence() {
  local path="$1"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<'EOF'
---
title: Q69F.3 Test Evidence
---
# Evidence fixture for q69f.3 self-test.
EOF
}

# ── Fixture 1: no executable runbooks ────────────────────────────────────────
FX1_RB="${TMPD}/fx1/runbooks"
FX1_EV="${TMPD}/fx1/evidence"
make_runbook "${FX1_RB}/plain-active.md" "active"
expect_pass "fixture 1: no executable runbooks → exit 0" \
  bash "${REAL_SCRIPT}" --runbooks-dir "${FX1_RB}" --evidence-dir "${FX1_EV}"

# ── Fixture 2: executable + no evidence, default (WARN) mode ─────────────────
FX2_RB="${TMPD}/fx2/runbooks"
FX2_EV="${TMPD}/fx2/evidence"
make_runbook "${FX2_RB}/exec-no-evidence.md" "executable"
expect_pass "fixture 2: executable + no evidence (default) → WARN, exit 0" \
  bash "${REAL_SCRIPT}" --runbooks-dir "${FX2_RB}" --evidence-dir "${FX2_EV}"

# Verify the expected WARN line is in output
if grep -q '\[WARN\].*exec-no-evidence' "${TMPD}/out"; then
  echo "[PASS] fixture 2b: WARN line present in fixture 2 output"
  PASS=$((PASS + 1))
else
  echo "[FAIL] fixture 2b: expected WARN line for exec-no-evidence not found"
  FAIL=$((FAIL + 1))
fi

# ── Fixture 3: executable + no evidence, --strict mode ───────────────────────
expect_fail "fixture 3: executable + no evidence (--strict) → exit non-zero" \
  bash "${REAL_SCRIPT}" --strict --runbooks-dir "${FX2_RB}" --evidence-dir "${FX2_EV}"

# ── Fixture 4: executable + fresh evidence ───────────────────────────────────
FX4_RB="${TMPD}/fx4/runbooks"
FX4_EV="${TMPD}/fx4/evidence"
TODAY="$(date +%Y-%m-%d)"
make_runbook "${FX4_RB}/exec-with-evidence.md" "executable"
make_evidence "${FX4_EV}/exec-with-evidence-${TODAY}.md"
expect_pass "fixture 4: executable + fresh evidence → PASS, exit 0" \
  bash "${REAL_SCRIPT}" --strict --runbooks-dir "${FX4_RB}" --evidence-dir "${FX4_EV}"

# Verify no WARN/FAIL in output
if grep -qE '\[(WARN|FAIL)\]' "${TMPD}/out"; then
  echo "[FAIL] fixture 4b: unexpected WARN/FAIL for happy-path evidence"
  sed 's/^/  | /' "${TMPD}/out" | tail -6
  FAIL=$((FAIL + 1))
else
  echo "[PASS] fixture 4b: no WARN/FAIL in happy-path output"
  PASS=$((PASS + 1))
fi

# ── Fixture 5: executable + stale evidence (age enforcement) ─────────────────
# Evidence dated 200 days ago; --strict should FAIL because MAX_AGE_DAYS default
# is 90.
FX5_RB="${TMPD}/fx5/runbooks"
FX5_EV="${TMPD}/fx5/evidence"
STALE="$(date -d '-200 days' +%Y-%m-%d 2>/dev/null || date -v-200d +%Y-%m-%d 2>/dev/null || echo '2025-01-01')"
make_runbook "${FX5_RB}/exec-stale.md" "executable"
make_evidence "${FX5_EV}/exec-stale-${STALE}.md"
expect_fail "fixture 5: executable + stale evidence (--strict) → exit non-zero" \
  bash "${REAL_SCRIPT}" --strict --runbooks-dir "${FX5_RB}" --evidence-dir "${FX5_EV}"

echo ""
echo "=== test-verify-runbook-executable.sh summary ==="
echo "PASS=${PASS}  FAIL=${FAIL}"

if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
echo "OK"
