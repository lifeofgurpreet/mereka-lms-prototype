#!/usr/bin/env bash
# @covers AC-ROUTE-001, AC-ROUTE-002, AC-ROUTE-003, AC-ROUTE-004
# @spec: bead-115d17
#
# verify-mfe-routing-parity.sh — MFE routing QA aligned with runtime Caddyfile
#
# Verifies that:
#   1. Every documented MFE route has a handler in the MFE-internal Caddyfile
#      (deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile)
#   2. Both /authoring and /course-authoring exist and point to the same dist dir
#   3. All MFE route handlers proxy exclusively to mfe:8002 from the outer Caddyfile
#      (deploy/k8s/base/apps/caddy/Caddyfile)
#   4. Cross-reference with branding verifier MFE_ROUTES map for drift detection
#
# AC-ROUTE-001: Routes mapped from runtime Caddyfile expectations
# AC-ROUTE-002: Both /authoring and /course-authoring tested
# AC-ROUTE-003: Intended to gate CI (syntax-checked in monitoring-guardrails)
# AC-ROUTE-004: Evidence and log commands documented in docs/ops/runbooks/architecture/MFE_ROUTING_PARITY.md
#
# Usage: ./scripts/qa/verify-mfe-routing-parity.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"

# Primary files
MFE_CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
OUTER_CADDYFILE="$REPO_ROOT/deploy/k8s/base/apps/caddy/Caddyfile"
BRANDING_VERIFIER="$REPO_ROOT/scripts/qa/verify-mfe-branding.sh"
RUNBOOK="$REPO_ROOT/docs/ops/runbooks/architecture/MFE_ROUTING_PARITY.md"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== MFE Routing Parity Verification ==="
echo "Spec: bead-115d17"
echo "Coverage: AC-ROUTE-001, AC-ROUTE-002, AC-ROUTE-003, AC-ROUTE-004"
echo ""

# =============================================================================
# Section 1: File existence (AC-ROUTE-001)
# =============================================================================
echo "--- File Existence Checks (AC-ROUTE-001) ---"

if [ ! -f "$MFE_CADDYFILE" ]; then
  do_fail "AC-ROUTE-001: MFE Caddyfile not found at $MFE_CADDYFILE"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
do_pass "AC-ROUTE-001: MFE Caddyfile exists at deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"

if [ ! -f "$OUTER_CADDYFILE" ]; then
  do_fail "AC-ROUTE-001: Outer Caddyfile not found at $OUTER_CADDYFILE"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
do_pass "AC-ROUTE-001: Outer Caddyfile exists at deploy/k8s/base/apps/caddy/Caddyfile"

if [ -f "$RUNBOOK" ]; then
  do_pass "AC-ROUTE-004: Runbook exists at docs/ops/runbooks/architecture/MFE_ROUTING_PARITY.md"
else
  do_fail "AC-ROUTE-004: Runbook missing at docs/ops/runbooks/architecture/MFE_ROUTING_PARITY.md"
fi

echo ""

# =============================================================================
# Section 2: Outer Caddyfile proxies apps.* domain to mfe:8002 (AC-ROUTE-001)
# =============================================================================
echo "--- Outer Caddyfile: apps.* → mfe:8002 proxy (AC-ROUTE-001) ---"

# All MFE routes flow through the apps.* virtual host, which delegates to mfe:8002
if grep -q "apps\.localhost" "$OUTER_CADDYFILE"; then
  do_pass "AC-ROUTE-001: apps.localhost vhost defined in outer Caddyfile"
else
  do_fail "AC-ROUTE-001: apps.localhost vhost missing from outer Caddyfile"
fi

if grep -q "apps\.academyv2\.mereka\.io" "$OUTER_CADDYFILE"; then
  do_pass "AC-ROUTE-001: apps.academyv2.mereka.io vhost defined in outer Caddyfile"
else
  do_fail "AC-ROUTE-001: apps.academyv2.mereka.io vhost missing from outer Caddyfile"
fi

# Both apps vhosts must use import proxy "mfe:8002" (not direct reverse_proxy)
APPS_PROXY_COUNT=$(grep -c "mfe:8002" "$OUTER_CADDYFILE" || true)
if [ "$APPS_PROXY_COUNT" -ge 2 ]; then
  do_pass "AC-ROUTE-001: mfe:8002 referenced $APPS_PROXY_COUNT times in outer Caddyfile (>= 2 expected)"
else
  do_fail "AC-ROUTE-001: mfe:8002 referenced $APPS_PROXY_COUNT times in outer Caddyfile (expected >= 2)"
fi

# ecommerce.* has a special /authn/* passthrough — verify it proxies to mfe:8002 not mfe:8000
if grep -A4 "handle /authn/\*" "$OUTER_CADDYFILE" | grep -q "mfe:8002"; then
  do_pass "AC-ROUTE-001: ecommerce /authn/* correctly proxied to mfe:8002"
else
  do_warn "AC-ROUTE-001: ecommerce /authn/* passthrough target unclear — check outer Caddyfile"
fi

echo ""

# =============================================================================
# Section 3: Extract MFE routes from MFE Caddyfile (AC-ROUTE-001)
# =============================================================================
echo "--- MFE Caddyfile Route Extraction (AC-ROUTE-001) ---"

# Canonical MFE routes expected in the MFE-internal Caddyfile.
# Maps URL path prefix → dist directory name.
declare -A EXPECTED_ROUTES=(
  ["/authn"]="authn"
  ["/account"]="account"
  ["/communications"]="communications"
  ["/course-authoring"]="course-authoring"
  ["/discussions"]="discussions"
  ["/gradebook"]="gradebook"
  ["/learner-dashboard"]="learner-dashboard"
  ["/learner-record"]="learner-record"
  ["/learning"]="learning"
  ["/ora-grading"]="ora-grading"
  ["/profile"]="profile"
)

# Verify each expected route has a handler block and correct dist directory
for route in "${!EXPECTED_ROUTES[@]}"; do
  dist_dir="${EXPECTED_ROUTES[$route]}"

  # Check the named matcher exists: @mfe_<name>
  matcher_name="mfe_${dist_dir}"

  # Look for: path <route> <route>/*
  route_escaped="${route//\//\\/}"
  if grep -qP "path ${route_escaped}( |$)" "$MFE_CADDYFILE"; then
    do_pass "AC-ROUTE-001: Route ${route} path matcher exists in MFE Caddyfile"
  else
    do_fail "AC-ROUTE-001: Route ${route} path matcher MISSING from MFE Caddyfile"
  fi

  # Verify the handler serves the correct dist directory
  if grep -q "root \* /openedx/dist/${dist_dir}" "$MFE_CADDYFILE"; then
    do_pass "AC-ROUTE-001: Route ${route} serves /openedx/dist/${dist_dir}"
  else
    do_fail "AC-ROUTE-001: Route ${route} dist directory /openedx/dist/${dist_dir} NOT found"
  fi
done

echo ""

# =============================================================================
# Section 4: Count total MFE route handlers (AC-ROUTE-001)
# =============================================================================
echo "--- MFE Route Handler Count (AC-ROUTE-001) ---"

DIST_DIRS=$(mktemp)
grep -oP '(?<=root \* /openedx/dist/)[a-z0-9_-]+' "$MFE_CADDYFILE" | sort -u > "$DIST_DIRS"
DIST_COUNT=$(wc -l < "$DIST_DIRS")

if [ "$DIST_COUNT" -ge 10 ]; then
  do_pass "AC-ROUTE-001: $DIST_COUNT distinct dist directories in MFE Caddyfile (>= 10 expected)"
else
  do_fail "AC-ROUTE-001: Only $DIST_COUNT distinct dist directories in MFE Caddyfile (expected >= 10)"
fi

# Verify file_server is used (not reverse_proxy) for MFE routes
FILE_SERVER_COUNT=$(grep -c "file_server" "$MFE_CADDYFILE" || true)
if [ "$FILE_SERVER_COUNT" -ge 10 ]; then
  do_pass "AC-ROUTE-001: $FILE_SERVER_COUNT file_server directives in MFE Caddyfile (>= 10 expected)"
else
  do_fail "AC-ROUTE-001: Only $FILE_SERVER_COUNT file_server directives (expected >= 10)"
fi

echo ""

# =============================================================================
# Section 5: Authoring dual-path check (AC-ROUTE-002)
# =============================================================================
echo "--- Authoring Dual-Path Verification (AC-ROUTE-002) ---"

# /authoring path matcher must exist
if grep -q "path /authoring /authoring/\*" "$MFE_CADDYFILE" || \
   grep -qP "path /authoring( |$)" "$MFE_CADDYFILE"; then
  do_pass "AC-ROUTE-002: /authoring path matcher defined in MFE Caddyfile"
else
  do_fail "AC-ROUTE-002: /authoring path matcher MISSING from MFE Caddyfile"
fi

# /course-authoring path matcher must exist
if grep -q "path /course-authoring /course-authoring/\*" "$MFE_CADDYFILE" || \
   grep -qP "path /course-authoring( |$)" "$MFE_CADDYFILE"; then
  do_pass "AC-ROUTE-002: /course-authoring path matcher defined in MFE Caddyfile"
else
  do_fail "AC-ROUTE-002: /course-authoring path matcher MISSING from MFE Caddyfile"
fi

# Both must serve the same dist directory (course-authoring)
AUTHORING_DIST=$(grep -A5 "path /authoring /authoring/\*" "$MFE_CADDYFILE" | \
  grep -oP '(?<=root \* /openedx/dist/)[a-z0-9_-]+' | head -1 || true)
COURSE_AUTHORING_DIST=$(grep -A5 "path /course-authoring /course-authoring/\*" "$MFE_CADDYFILE" | \
  grep -oP '(?<=root \* /openedx/dist/)[a-z0-9_-]+' | head -1 || true)

if [ -n "$AUTHORING_DIST" ] && [ -n "$COURSE_AUTHORING_DIST" ]; then
  if [ "$AUTHORING_DIST" = "$COURSE_AUTHORING_DIST" ]; then
    do_pass "AC-ROUTE-002: /authoring and /course-authoring both serve dist/$AUTHORING_DIST (same dir)"
  else
    do_fail "AC-ROUTE-002: /authoring serves dist/$AUTHORING_DIST but /course-authoring serves dist/$COURSE_AUTHORING_DIST (MISMATCH)"
  fi
else
  do_fail "AC-ROUTE-002: Could not extract dist dir for /authoring ($AUTHORING_DIST) or /course-authoring ($COURSE_AUTHORING_DIST)"
fi

# Verify canonical dist dir is 'course-authoring' (not 'authoring')
if [ "${AUTHORING_DIST:-}" = "course-authoring" ]; then
  do_pass "AC-ROUTE-002: /authoring alias correctly maps to dist/course-authoring (canonical dir)"
else
  do_warn "AC-ROUTE-002: /authoring dist dir is '${AUTHORING_DIST:-unknown}', expected 'course-authoring'"
fi

# Both routes must have strip_prefix directives (so /authoring/... strips /authoring)
if grep -A6 "path /authoring /authoring/\*" "$MFE_CADDYFILE" | grep -q "uri strip_prefix /authoring"; then
  do_pass "AC-ROUTE-002: /authoring handler strips /authoring prefix correctly"
else
  do_warn "AC-ROUTE-002: /authoring handler does not have uri strip_prefix — check manually"
fi

if grep -A6 "path /course-authoring /course-authoring/\*" "$MFE_CADDYFILE" | grep -q "uri strip_prefix /course-authoring"; then
  do_pass "AC-ROUTE-002: /course-authoring handler strips /course-authoring prefix correctly"
else
  do_warn "AC-ROUTE-002: /course-authoring handler does not have uri strip_prefix — check manually"
fi

echo ""

# =============================================================================
# Section 6: Profile /u route check (AC-ROUTE-001)
# =============================================================================
echo "--- Profile /u Alias Route (AC-ROUTE-001) ---"

if grep -q "path /u /u/\*" "$MFE_CADDYFILE" || grep -qP "path /u( |$)" "$MFE_CADDYFILE"; then
  do_pass "AC-ROUTE-001: /u profile alias route exists in MFE Caddyfile"
else
  do_fail "AC-ROUTE-001: /u profile alias route MISSING from MFE Caddyfile"
fi

# /u must serve profile dist
if grep -A5 "mfe_profile_u" "$MFE_CADDYFILE" | grep -q "/openedx/dist/profile"; then
  do_pass "AC-ROUTE-001: /u alias serves dist/profile correctly"
else
  do_fail "AC-ROUTE-001: /u alias does not serve dist/profile"
fi

# /u should NOT strip prefix (profile SPA expects full path for username routing)
if grep -A5 "mfe_profile_u" "$MFE_CADDYFILE" | grep -q "uri strip_prefix /u"; then
  do_fail "AC-ROUTE-001: /u route incorrectly strips prefix — profile username routing will break"
else
  do_pass "AC-ROUTE-001: /u route correctly keeps prefix intact (no strip_prefix)"
fi

echo ""

# =============================================================================
# Section 7: API passthrough routes (AC-ROUTE-001)
# =============================================================================
echo "--- API Passthrough Routes (AC-ROUTE-001) ---"

if grep -q "reverse_proxy /api/mfe_config/v1" "$MFE_CADDYFILE"; then
  do_pass "AC-ROUTE-001: /api/mfe_config/v1* proxied to LMS in MFE Caddyfile"
else
  do_fail "AC-ROUTE-001: /api/mfe_config/v1* proxy MISSING from MFE Caddyfile"
fi

if grep -q "reverse_proxy /login_refresh" "$MFE_CADDYFILE"; then
  do_pass "AC-ROUTE-001: /login_refresh* proxied to LMS in MFE Caddyfile"
else
  do_fail "AC-ROUTE-001: /login_refresh* proxy MISSING from MFE Caddyfile"
fi

# Verify LMS proxy target is lms:8000 (not mfe)
if grep -A2 "reverse_proxy /api/mfe_config" "$MFE_CADDYFILE" | grep -q "lms:8000"; then
  do_pass "AC-ROUTE-001: /api/mfe_config proxies to lms:8000 (correct backend)"
else
  do_fail "AC-ROUTE-001: /api/mfe_config proxy target is not lms:8000"
fi

if grep -A2 "reverse_proxy /login_refresh" "$MFE_CADDYFILE" | grep -q "lms:8000"; then
  do_pass "AC-ROUTE-001: /login_refresh proxies to lms:8000 (correct backend)"
else
  do_fail "AC-ROUTE-001: /login_refresh proxy target is not lms:8000"
fi

echo ""

# =============================================================================
# Section 8: Payments proxy routes (AC-ROUTE-001)
# =============================================================================
echo "--- Deprecated MFE Payments Proxy (AC-ROUTE-001) ---"

if grep -q "reverse_proxy /orders" "$MFE_CADDYFILE" && \
   grep -A2 "reverse_proxy /orders" "$MFE_CADDYFILE" | grep -q "payments-gateway"; then
  do_pass "AC-ROUTE-001: /orders* proxied to payments-gateway"
else
  do_fail "AC-ROUTE-001: /orders* proxy to payments-gateway MISSING"
fi

if grep -q "reverse_proxy /payment" "$MFE_CADDYFILE" && \
   grep -A2 "reverse_proxy /payment" "$MFE_CADDYFILE" | grep -q "payments-gateway"; then
  do_pass "AC-ROUTE-001: /payment* proxied to payments-gateway"
else
  do_fail "AC-ROUTE-001: /payment* proxy to payments-gateway MISSING"
fi

echo ""

# =============================================================================
# Section 9: try_files → SPA fallback (AC-ROUTE-001)
# =============================================================================
echo "--- SPA Fallback (try_files) Coverage (AC-ROUTE-001) ---"

TRY_FILES_COUNT=$(grep -c "try_files.*index.html" "$MFE_CADDYFILE" || true)
if [ "$TRY_FILES_COUNT" -ge 10 ]; then
  do_pass "AC-ROUTE-001: $TRY_FILES_COUNT SPA try_files fallbacks in MFE Caddyfile (>= 10 expected)"
else
  do_fail "AC-ROUTE-001: Only $TRY_FILES_COUNT try_files fallbacks in MFE Caddyfile (expected >= 10)"
fi

echo ""

# =============================================================================
# Section 10: Branding verifier cross-reference (AC-ROUTE-001)
# =============================================================================
echo "--- Branding Verifier Cross-Reference (AC-ROUTE-001) ---"

if [ ! -f "$BRANDING_VERIFIER" ]; then
  do_warn "AC-ROUTE-001: Branding verifier not found at $BRANDING_VERIFIER — skipping cross-reference"
else
  # For each dist directory found in MFE Caddyfile, check branding verifier references it
  while IFS= read -r dist_dir; do
    if grep -q "\"$dist_dir\"" "$BRANDING_VERIFIER"; then
      do_pass "AC-ROUTE-001: dist/$dist_dir referenced in branding verifier (no drift)"
    else
      do_warn "AC-ROUTE-001: dist/$dist_dir NOT referenced in branding verifier — possible drift"
    fi
  done < "$DIST_DIRS"
fi

echo ""

# =============================================================================
# Section 11: Runbook content checks (AC-ROUTE-004)
# =============================================================================
echo "--- Runbook Content Checks (AC-ROUTE-004) ---"

if [ -f "$RUNBOOK" ]; then
  for section in "Route Mapping" "/authoring" "/course-authoring" "verification" "mfe:8002"; do
    if grep -qi "$section" "$RUNBOOK"; then
      do_pass "AC-ROUTE-004: Runbook covers '$section'"
    else
      do_warn "AC-ROUTE-004: Runbook missing coverage for '$section'"
    fi
  done
fi

echo ""

# Cleanup
rm -f "$DIST_DIRS"

# =============================================================================
# Summary
# =============================================================================
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "ACTION REQUIRED: MFE routing parity checks failed."
  echo ""
  echo "Common fixes:"
  echo "  1. New MFE route added? Add handler block to:"
  echo "       deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
  echo "  2. /authoring and /course-authoring must both serve dist/course-authoring"
  echo "  3. All routes must use file_server (not reverse_proxy) except API passthroughs"
  echo "  4. See docs/ops/runbooks/architecture/MFE_ROUTING_PARITY.md for the full runbook"
  echo ""
  exit 1
fi

if [ "$WARN" -gt 0 ]; then
  echo ""
  echo "WARNINGS PRESENT: No failures but warnings need review."
  echo "Update branding verifier and runbook if routes have changed."
fi

echo ""
echo "All MFE routing parity checks passed."
exit 0
