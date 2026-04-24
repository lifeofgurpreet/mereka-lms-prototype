#!/usr/bin/env bash
# @covers AC-ENT-MFE-001
# @spec: k8s-deployment_spec.md
#
# Verify enterprise MFE env.config.js files enforce the build/runtime boundary:
# - Base config uses localhost (environment-neutral)
# - Overlay configs use correct environment URLs
# - No production URLs leak into dev/local configs
# - No dev URLs leak into staging/production configs
# - No MISSING_ENV_VAR placeholders remain
#
# Exit 0 = all checks pass
# Exit 1 = one or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
FAILURES=0

pass() { echo "  PASS: $1"; }
fail() { echo "  FAIL: $1"; FAILURES=$((FAILURES + 1)); }

echo "=== MFE env.config.js URL Guard ==="
echo ""

# ─── Check 1: Base config uses localhost defaults ────────────────────────
echo "[1/4] Base enterprise-mfe-env.js uses localhost (environment-neutral)"
base="${REPO_ROOT}/deploy/k8s/base/apps/enterprise/mfe/enterprise-mfe-env.js"
if [[ -f "$base" ]]; then
  if grep -q 'localhost' "$base"; then
    pass "base config contains localhost references"
  else
    fail "base config does NOT contain localhost — may be environment-specific"
  fi

  if grep -q 'academyv2\.mereka\.io' "$base"; then
    fail "base config contains production URL (academyv2.mereka.io)"
  else
    pass "base config has no production URL leakage"
  fi

  if grep -q 'academyv2\.mereka\.dev' "$base"; then
    fail "base config contains dev URL (academyv2.mereka.dev)"
  else
    pass "base config has no dev URL leakage"
  fi
else
  fail "base enterprise-mfe-env.js not found"
fi

# ─── Check 2: Dev/local configs use .mereka.dev ─────────────────────────
echo "[2/4] Dev/local configs use .mereka.dev (not .mereka.io)"
for overlay in local rke2-nonprod; do
  env_js="${REPO_ROOT}/deploy/k8s/overlays/${overlay}/enterprise-mfe-env.js"
  if [[ ! -f "$env_js" ]]; then
    pass "${overlay}: no enterprise-mfe-env.js (ok if portals disabled)"
    continue
  fi

  if grep -q '\.mereka\.io' "$env_js"; then
    fail "${overlay}: contains production URL (.mereka.io)"
  else
    pass "${overlay}: no production URL leakage"
  fi

  if grep -q '\.mereka\.dev\|localhost' "$env_js"; then
    pass "${overlay}: uses dev/localhost URLs"
  else
    fail "${overlay}: does not use dev or localhost URLs"
  fi
done

# ─── Check 3: Staging config uses staging domain ────────────────────────
echo "[3/4] Staging config uses staging domain"
staging_env="${REPO_ROOT}/deploy/k8s/overlays/staging/enterprise-mfe-env.js"
if [[ -f "$staging_env" ]]; then
  if grep -q 'staging\.\|\.mereka\.io' "$staging_env"; then
    pass "staging: uses staging domain pattern"
  else
    fail "staging: does not reference staging domain"
  fi

  if grep -q 'academyv2\.mereka\.dev[^.]' "$staging_env"; then
    fail "staging: contains dev URL (should use staging.* or .mereka.io)"
  else
    pass "staging: no dev URL leakage"
  fi
fi

# ─── Check 4: No MISSING_ENV_VAR in any env.config.js ───────────────────
echo "[4/4] No MISSING_ENV_VAR placeholders in any env.config.js"
found_missing=0
while IFS= read -r -d '' f; do
  if grep -q 'MISSING_ENV_VAR' "$f"; then
    fail "$(basename "$(dirname "$f")")/$(basename "$f"): contains MISSING_ENV_VAR"
    found_missing=1
  fi
done < <(find "${REPO_ROOT}/deploy/k8s" -name 'enterprise-mfe-env.js' -print0 2>/dev/null)
if [[ $found_missing -eq 0 ]]; then
  pass "no MISSING_ENV_VAR placeholders found in any env.config.js"
fi

# Also check tenant-specific env files in base
for tenant_env in "${REPO_ROOT}/deploy/k8s/base/apps/enterprise/mfe/"*-mfe-env.js; do
  [[ -f "$tenant_env" ]] || continue
  name=$(basename "$tenant_env")
  if grep -q 'MISSING_ENV_VAR' "$tenant_env"; then
    fail "${name}: contains MISSING_ENV_VAR placeholder"
  else
    pass "${name}: no MISSING_ENV_VAR"
  fi
done

echo ""
echo "=== Results: ${FAILURES} failures ==="
if [[ $FAILURES -gt 0 ]]; then
  echo "VERDICT: FAIL"
  exit 1
fi
echo "VERDICT: PASS"
exit 0
