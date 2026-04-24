#!/usr/bin/env bash
# test-validate-registry.sh — Self-test for scripts/governance/validate-registry.sh
#
# Bead: mereka-lms-q69f.1 (Phase 0 burn #1 — validate-registry.sh had 2/5
# first-class score because of no self-test; closes that gap).
#
# Fixtures:
#   1. Happy-path: validator exits 0 on the actual in-repo registry.
#   2. Seeded fail: registry injected via REGISTRY_OVERRIDE points at a
#      nonexistent script — validator must exit non-zero.
#   3. Seeded fail: registry injected via REGISTRY_OVERRIDE points at a
#      real-but-non-executable file — validator must exit non-zero.
#
# Any fixture regression fails this test. Intended to be wired into CI as a
# registered scripts/qa/test-* helper via the standard governance path.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REAL_SCRIPT="${REPO_ROOT}/scripts/governance/validate-registry.sh"
TMPD="$(mktemp -d)"
trap 'rm -rf "${TMPD}"' EXIT

if [[ ! -x "${REAL_SCRIPT}" ]]; then
  echo "[FAIL] validate-registry.sh not found or not executable at ${REAL_SCRIPT}"
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
    sed 's/^/  | /' "${TMPD}/out" | tail -20
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

# ── Fixture 1: happy-path on real repo ─────────────────────────────────────────
expect_pass "fixture 1: happy-path on real in-repo registry" \
  bash "${REAL_SCRIPT}"

# ── Fixture 2: seeded nonexistent registered script ───────────────────────────
cat > "${TMPD}/registry-nonexistent.yaml" <<'YAML'
version: 1
scripts:
  critical:
    - path: scripts/qa/__fixture_nonexistent_never_created__.sh
      description: q69f.1 fixture — path intentionally missing
ci_static_inventory:
  shard_files: []
  precheck_files: []
  entries: []
ci_runtime_inventory:
  entries: []
YAML

# Ambient CI env hoists VALIDATE_REGISTRY_SCOPE=changed + CI_CHANGED_FILES.
# When the PR under test doesn't change scripts/*, the validator early-exits
# with "scope skip" → exit 0 → fixture 2/3 false-pass. Strip those env vars
# from the fixture runs so the validator executes its real checks.
expect_fail "fixture 2: seeded nonexistent registered script" \
  env -u VALIDATE_REGISTRY_SCOPE -u CI_CHANGED_FILES \
      -u VALIDATE_REGISTRY_CHANGED_FILES \
      REGISTRY_OVERRIDE="${TMPD}/registry-nonexistent.yaml" WARN_UNREGISTERED=0 \
  bash "${REAL_SCRIPT}"

# ── Fixture 3: seeded non-executable registered script ───────────────────────
# Pick a known-to-exist non-script file in the repo (README.md) that is not
# executable. The validator must flag this as "not executable".
cat > "${TMPD}/registry-nonexec.yaml" <<'YAML'
version: 1
scripts:
  critical:
    - path: README.md
      description: q69f.1 fixture — real file but not executable
ci_static_inventory:
  shard_files: []
  precheck_files: []
  entries: []
ci_runtime_inventory:
  entries: []
YAML

expect_fail "fixture 3: seeded non-executable registered script" \
  env -u VALIDATE_REGISTRY_SCOPE -u CI_CHANGED_FILES \
      -u VALIDATE_REGISTRY_CHANGED_FILES \
      REGISTRY_OVERRIDE="${TMPD}/registry-nonexec.yaml" WARN_UNREGISTERED=0 \
  bash "${REAL_SCRIPT}"

echo ""
echo "=== test-validate-registry.sh summary ==="
echo "PASS=${PASS}  FAIL=${FAIL}"

if [[ "${FAIL}" -ne 0 ]]; then
  exit 1
fi
echo "OK"
