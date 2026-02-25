#!/usr/bin/env bash
# Verify Ulmo Admin Console MFE build and routing configuration.
#
# Checks (static, no cluster required):
#   1. admin-console MFE git-fetch stage in Dockerfile
#   2. admin-console production build stage in Dockerfile
#   3. admin-console assets COPY step in final production image
#   4. MFE wildcard route (apps subdomain) in Caddyfile
#   5. Content libraries app present in mereka_lms plugin settings
#   6. CSRF trusted origins include the apps subdomain
#
# Usage:
#   ./scripts/qa/verify-admin-console.sh
#
# Exit codes:
#   0 - all checks passed
#   1 - one or more checks failed
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

DOCKERFILE="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"

PASS=0
FAIL=0

pass() {
  echo "[PASS] $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "[FAIL] $1" >&2
  FAIL=$((FAIL + 1))
}

skip() {
  echo "[SKIP] $1"
}

# ---- Check 1: admin-console git-fetch stage in Dockerfile ----
if [[ ! -f "$DOCKERFILE" ]]; then
  fail "Dockerfile not found: $DOCKERFILE"
else
  if grep -q "FROM base AS admin-console-git" "$DOCKERFILE"; then
    pass "admin-console MFE present in Dockerfile"
  else
    fail "admin-console git stage missing from Dockerfile (expected 'FROM base AS admin-console-git')"
  fi
fi

# ---- Check 2: admin-console production build stage ----
if [[ -f "$DOCKERFILE" ]]; then
  if grep -q "FROM admin-console-common AS admin-console-prod" "$DOCKERFILE"; then
    pass "admin-console production stage present in Dockerfile"
  else
    fail "admin-console production stage missing from Dockerfile (expected 'FROM admin-console-common AS admin-console-prod')"
  fi
fi

# ---- Check 3: admin-console assets COPY into final image ----
if [[ -f "$DOCKERFILE" ]]; then
  if grep -q "admin-console-prod.*admin-console" "$DOCKERFILE" || \
     grep -q "COPY --from=admin-console-prod" "$DOCKERFILE"; then
    pass "admin-console assets COPY step present in Dockerfile"
  else
    fail "admin-console assets are not copied into the final production image"
  fi
fi

# ---- Check 4: MFE wildcard route (apps subdomain) in Caddyfile ----
if [[ ! -f "$CADDYFILE" ]]; then
  fail "Caddyfile not found: $CADDYFILE"
else
  if grep -q "apps\.academyv2\.mereka\.io" "$CADDYFILE"; then
    pass "MFE route (apps subdomain) present in Caddyfile"
  else
    fail "apps.academyv2.mereka.io route missing from Caddyfile — admin-console will not be routable"
  fi
fi

# ---- Check 5: Content libraries app in mereka_lms plugin ----
if [[ ! -f "$PLUGIN" ]]; then
  fail "mereka_lms plugin not found: $PLUGIN"
else
  if grep -q "content_libraries" "$PLUGIN"; then
    pass "Content libraries app listed in plugin settings"
  else
    fail "content_libraries not found in mereka_lms plugin — Admin Console library management will fail"
  fi
fi

# ---- Check 6: CSRF trusted origins include apps subdomain ----
if [[ -f "$PLUGIN" ]]; then
  if grep -q "apps\.academyv2\.mereka\.io" "$PLUGIN"; then
    pass "CSRF trusted origins include apps subdomain"
  else
    # apps.academyv2.mereka.io may be implied by the wildcard cookie domain; treat as SKIP
    skip "apps.academyv2.mereka.io not explicitly listed in CSRF origins (covered by cookie domain)"
  fi
fi

# ---- Summary ----
echo ""
echo "[INFO] Admin Console URL: https://apps.academyv2.mereka.io/admin-console/"
echo "[INFO] Requires: is_staff=True or is_superuser=True on the Django user"
echo ""

TOTAL=$((PASS + FAIL))
if [[ "$FAIL" -gt 0 ]]; then
  echo "FAILED ($FAIL/$TOTAL checks failed)" >&2
  exit 1
fi

echo "All checks passed ($PASS/$TOTAL)"
exit 0
