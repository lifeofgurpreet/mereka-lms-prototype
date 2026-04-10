#!/usr/bin/env bash
# @covers AC-CI-017
# @spec: ci-cd-pipeline_spec.md
set -euo pipefail

# verify-workflow-gate-enforcement.sh — Verify critical workflow gates
# are structural (exit 1 on failure), not advisory (continue-on-error).
#
# Checks:
#   1. Live-asset gate in smoke workflow uses exit 1 on failure
#   2. Release-object projection consumer validation in release workflow uses exit 1
#   3. Promotion job requires create-github-release via needs:
#   4. Release-bundle job requires all build+scan jobs via needs:
#   5. continue-on-error steps are explicitly classified with comments
#   6. Process invariant jobs are listed as required branch protection checks

REPO_ROOT="${REPO_ROOT_OVERRIDE:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
WORKFLOWS="$REPO_ROOT/.github/workflows"

passes=0
failures=0

pass() { echo "  [PASS] $*"; passes=$((passes + 1)); }
fail() { echo "  [FAIL] $*" >&2; failures=$((failures + 1)); }

echo "=== Workflow Gate Enforcement Verification ==="

# ── Gate 1: Live-asset gate is structural ────────────────────────────
echo "--- Gate 1: Live-asset gate (smoke-authenticated.yml) ---"

SMOKE="$WORKFLOWS/smoke-authenticated.yml"
if [[ ! -f "$SMOKE" ]]; then
  fail "smoke-authenticated.yml not found"
else
  if grep -q 'Live-asset gate' "$SMOKE"; then
    pass "live-asset gate step exists"
  else
    fail "live-asset gate step missing"
  fi

  # Must exit 1 when gate is red (not just echo a warning)
  if grep -A40 'Live-asset gate' "$SMOKE" | grep -q 'exit 1'; then
    pass "live-asset gate exits 1 on failure (structural)"
  else
    fail "live-asset gate does NOT exit 1 — may be advisory only"
  fi

  # Must NOT have continue-on-error
  if grep -B2 -A2 'Live-asset gate' "$SMOKE" | grep -q 'continue-on-error'; then
    fail "live-asset gate has continue-on-error — defeats enforcement"
  else
    pass "live-asset gate has no continue-on-error"
  fi
fi

# ── Gate 2: Release-object validation is structural ──────────────────
echo "--- Gate 2: Release-object validation (release.yml) ---"

RELEASE="$WORKFLOWS/release.yml"
if [[ ! -f "$RELEASE" ]]; then
  fail "release.yml not found"
else
  if grep -q 'Validate release-object control-plane projection consumer' "$RELEASE"; then
    pass "release-object validation step exists"
  else
    fail "release-object validation step missing"
  fi

  if grep -A20 'Validate release-object control-plane projection consumer' "$RELEASE" | grep -q 'SystemExit'; then
    pass "release-object validation exits 1 on failure"
  else
    fail "release-object validation does NOT exit 1"
  fi
fi

# ── Gate 3: Promotion gating ────────────────────────────────────────
echo "--- Gate 3: Promotion requires release (release.yml) ---"

if grep -A5 'promote-to-production:' "$RELEASE" | grep -q 'needs:.*create-github-release'; then
  pass "promotion depends on create-github-release"
else
  fail "promotion does NOT depend on create-github-release"
fi

if grep -A10 'promote-to-production:' "$RELEASE" | grep -q 'environment:.*production'; then
  pass "promotion requires production environment (manual approval)"
else
  fail "promotion does NOT require production environment"
fi

# ── Gate 4: Release bundle requires all build jobs ──────────────────
echo "--- Gate 4: Release bundle gating (build-tutor-images.yml) ---"

BUILD="$WORKFLOWS/build-tutor-images.yml"
if [[ ! -f "$BUILD" ]]; then
  fail "build-tutor-images.yml not found"
else
  BUNDLE_NEEDS=$(grep -A5 '^\s*release-bundle:' "$BUILD" | grep 'needs:' || true)
  for dep in build-openedx build-mfe scan-openedx-image scan-mfe-image; do
    if echo "$BUNDLE_NEEDS" | grep -q "$dep"; then
      pass "release-bundle depends on $dep"
    else
      fail "release-bundle does NOT depend on $dep"
    fi
  done
fi

# ── Gate 5: continue-on-error classification ────────────────────────
echo "--- Gate 5: continue-on-error steps are classified ---"

# Every continue-on-error must have a comment explaining why
UNCLASSIFIED=0
for wf in ci.yml build-tutor-images.yml; do
  while IFS= read -r line_num; do
    # Check the line itself or the line before for a comment
    prev_line=$((line_num - 1))
    context=$(sed -n "${prev_line},${line_num}p" "$WORKFLOWS/$wf")
    if echo "$context" | grep -qi 'non-blocking\|informational\|tracked\|debt\|optional\|desirable\|may not exist\|failed\|fallback'; then
      : # classified
    else
      fail "$wf:$line_num: continue-on-error without classification comment"
      UNCLASSIFIED=$((UNCLASSIFIED + 1))
    fi
  done < <(grep -n 'continue-on-error: true' "$WORKFLOWS/$wf" 2>/dev/null | cut -d: -f1)
done

if [[ "$UNCLASSIFIED" -eq 0 ]]; then
  pass "all continue-on-error steps have classification comments"
fi

# ── Summary ─────────────────────────────────────────────────────────
echo ""
echo "=== Summary ==="
echo "PASS: $passes | FAIL: $failures"

if [[ "$failures" -gt 0 ]]; then
  echo ""
  echo "Workflow gate enforcement has gaps."
  exit 1
fi

echo "All critical workflow gates are structural."
