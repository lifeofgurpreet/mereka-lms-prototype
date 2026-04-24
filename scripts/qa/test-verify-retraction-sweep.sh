#!/usr/bin/env bash
# test-verify-retraction-sweep.sh — Self-test for
# scripts/governance/verify-retraction-sweep.sh
#
# Bead: mereka-lms-q69f.3 (second half — follow-up to #1842).
#
# Fixtures:
#   1. No terms provided → usage error, exit 2
#   2. Term absent from scope → PASS, exit 0
#   3. Term present AND annotated within context window → PASS, exit 0
#   4. Term present AND unannotated (default WARN mode) → WARN, exit 0
#   5. Term present AND unannotated (--strict mode) → FAIL, exit non-zero
#   6. Term present AND annotated BUT annotation is outside context window →
#      WARN/FAIL (context-boundary test — catches off-by-N in the annotation
#      lookback)
#
# All fixtures inject their scope via --scope, so the real repo state is
# never mutated.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REAL_SCRIPT="${REPO_ROOT}/scripts/governance/verify-retraction-sweep.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "${TMPD}"' EXIT

if [[ ! -x "${REAL_SCRIPT}" ]]; then
  echo "[FAIL] verify-retraction-sweep.sh not found or not executable at ${REAL_SCRIPT}"
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
    sed 's/^/  | /' "${TMPD}/out" | tail -12
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

# ── Fixture 1: no terms provided → usage error ────────────────────────────────
expect_fail "fixture 1: no --term provided → usage error exit 2" \
  bash "${REAL_SCRIPT}"

# ── Fixture 2: term absent from scope → PASS ──────────────────────────────────
FX2="${TMPD}/fx2"
mkdir -p "$FX2"
echo "This file contains nothing of interest." > "$FX2/clean.md"
expect_pass "fixture 2: term absent from scope → PASS, exit 0" \
  bash "${REAL_SCRIPT}" --term "q69f3b-stale-invariant" --scope "$FX2"

# ── Fixture 3: term + annotation within window → PASS ─────────────────────────
FX3="${TMPD}/fx3"
mkdir -p "$FX3"
cat > "$FX3/annotated.md" <<'EOF'
# Historical notes

> **Retracted**: the following hypothesis was disproven on 2026-04-18.

The old theory claimed q69f3b-stale-invariant was load-bearing.
EOF
expect_pass "fixture 3: annotated term → PASS, exit 0" \
  bash "${REAL_SCRIPT}" --strict --term "q69f3b-stale-invariant" --scope "$FX3"

# ── Fixture 4: term + NO annotation, default mode → WARN, exit 0 ──────────────
FX4="${TMPD}/fx4"
mkdir -p "$FX4"
cat > "$FX4/unannotated.md" <<'EOF'
# Some doc that still references the old theory

The platform uses q69f3b-stale-invariant as its primary invariant.
EOF
expect_pass "fixture 4: unannotated term (default) → WARN, exit 0" \
  bash "${REAL_SCRIPT}" --term "q69f3b-stale-invariant" --scope "$FX4"

if grep -qE '\[WARN\]|WARN:' "${TMPD}/out"; then
  echo "[PASS] fixture 4b: WARN line present in fixture 4 output"
  PASS=$((PASS + 1))
else
  echo "[FAIL] fixture 4b: expected WARN marker not found"
  sed 's/^/  | /' "${TMPD}/out" | tail -8
  FAIL=$((FAIL + 1))
fi

# ── Fixture 5: term + NO annotation, --strict mode → FAIL ─────────────────────
expect_fail "fixture 5: unannotated term (--strict) → exit non-zero" \
  bash "${REAL_SCRIPT}" --strict --term "q69f3b-stale-invariant" --scope "$FX4"

# ── Fixture 6: annotation OUTSIDE the context window → should NOT count ───────
# Put the "retracted" marker 20 lines above the term, with --context-lines=5
# so the marker is outside the lookback window. Verifier should flag the term
# as unannotated.
FX6="${TMPD}/fx6"
mkdir -p "$FX6"
{
  echo "> **Retracted**: this line is far above the term."
  for i in $(seq 1 20); do echo "(filler line $i)"; done
  echo "Here is the q69f3b-stale-invariant surviving unannotated-within-window."
} > "$FX6/far-annotation.md"
expect_fail "fixture 6: annotation outside --context-lines window (--strict) → exit non-zero" \
  bash "${REAL_SCRIPT}" --strict --context-lines 5 \
    --term "q69f3b-stale-invariant" --scope "$FX6"

echo ""
echo "=== test-verify-retraction-sweep.sh summary ==="
echo "PASS=${PASS}  FAIL=${FAIL}"

if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
echo "OK"
