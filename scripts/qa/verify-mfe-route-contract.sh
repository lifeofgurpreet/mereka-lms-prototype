#!/usr/bin/env bash
# @covers AC-MFERT-001, AC-MFERT-002, AC-MFERT-003
# @spec: mfe-branding-customization_spec.md
#
# verify-mfe-route-contract.sh — MFE route-to-dist contract verifier
#
# Ensures 3-layer routing consistency:
#   1. Caddy routes (Caddyfile)
#   2. LMS URL settings (production.py)
#   3. Branding verifier hardcoded map (verify-mfe-branding.sh)
#
# This is MORE comprehensive than verify-mfe-route-drift.sh because it adds
# the LMS settings layer cross-check.
#
# Usage: ./scripts/qa/verify-mfe-route-contract.sh

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
PRODUCTION_PY="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
BRANDING_VERIFIER="$REPO_ROOT/scripts/qa/verify-mfe-branding.sh"
CONTRACT_DOC="$REPO_ROOT/docs/architecture/MFE_ROUTE_TO_DIST_CONTRACT.md"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== MFE Route-to-Dist Contract Verification ==="
echo "Spec: mfe-branding-customization_spec.md"
echo "Coverage: AC-MFERT-001, AC-MFERT-002, AC-MFERT-003"
echo ""

# =============================================================================
# Section 1: Contract Document Exists (AC-MFERT-001)
# =============================================================================
echo "--- Contract Documentation (AC-MFERT-001) ---"

if [ ! -f "$CONTRACT_DOC" ]; then
  do_fail "AC-MFERT-001: Contract document missing at $CONTRACT_DOC"
else
  do_pass "AC-MFERT-001: Contract document exists"

  # Check for required sections
  if grep -q "## Route Mapping Table" "$CONTRACT_DOC"; then
    do_pass "AC-MFERT-001: Contract has route mapping table"
  else
    do_fail "AC-MFERT-001: Contract missing route mapping table"
  fi

  if grep -q "## Drift Risks" "$CONTRACT_DOC"; then
    do_pass "AC-MFERT-001: Contract documents drift risks"
  else
    do_fail "AC-MFERT-001: Contract missing drift risks section"
  fi

  if grep -q "## Adding a New MFE" "$CONTRACT_DOC"; then
    do_pass "AC-MFERT-001: Contract has migration guide"
  else
    do_fail "AC-MFERT-001: Contract missing migration guide"
  fi
fi

echo ""

# =============================================================================
# Section 2: File Existence Checks
# =============================================================================
echo "--- File Existence Checks ---"

if [ ! -f "$CADDYFILE" ]; then
  do_fail "Caddyfile not found at $CADDYFILE"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
do_pass "Caddyfile exists"

if [ ! -f "$PRODUCTION_PY" ]; then
  do_fail "production.py not found at $PRODUCTION_PY"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
do_pass "production.py exists"

if [ ! -f "$BRANDING_VERIFIER" ]; then
  do_fail "Branding verifier not found at $BRANDING_VERIFIER"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
do_pass "Branding verifier exists"

echo ""

# =============================================================================
# Section 3: Extract Routes from Caddyfile (Layer 1)
# =============================================================================
echo "--- Layer 1: Caddyfile Routes ---"

CADDY_DIRS=$(mktemp)
CADDY_PATHS=$(mktemp)

# Extract directories: root * /openedx/dist/<dir>
grep -oP '(?<=root \* /openedx/dist/)[a-z0-9_-]+' "$CADDYFILE" | sort -u > "$CADDY_DIRS"
CADDY_DIR_COUNT=$(wc -l < "$CADDY_DIRS")

if [ "$CADDY_DIR_COUNT" -ge 10 ]; then
  do_pass "Found $CADDY_DIR_COUNT MFE directories in Caddyfile (>= 10 expected)"
else
  do_fail "Only $CADDY_DIR_COUNT MFE directories in Caddyfile (expected >= 10)"
fi

# Extract path prefixes: path /name /name/*
grep -oP '(?<=path )/[a-z0-9_-]+(?= )' "$CADDYFILE" | sort -u > "$CADDY_PATHS"
CADDY_PATH_COUNT=$(wc -l < "$CADDY_PATHS")

if [ "$CADDY_PATH_COUNT" -ge 11 ]; then
  do_pass "Found $CADDY_PATH_COUNT URL path prefixes in Caddyfile (>= 11 expected)"
else
  do_warn "Only $CADDY_PATH_COUNT URL path prefixes in Caddyfile (expected >= 11)"
fi

echo ""

# =============================================================================
# Section 4: Extract MFE URLs from LMS Settings (Layer 2) — NEW CHECK
# =============================================================================
echo "--- Layer 2: LMS Settings ---"

LMS_MFE_URLS=$(mktemp)

# Extract *_MICROFRONTEND_URL assignments
# Pattern: AUTHN_MICROFRONTEND_URL = f"{...}/authn"
grep -oP '[A-Z_]+_MICROFRONTEND_URL(?= =)' "$PRODUCTION_PY" | sort -u > "$LMS_MFE_URLS"
LMS_URL_COUNT=$(wc -l < "$LMS_MFE_URLS")

if [ "$LMS_URL_COUNT" -ge 8 ]; then
  do_pass "Found $LMS_URL_COUNT *_MICROFRONTEND_URL settings in production.py (>= 8 expected)"
else
  do_fail "Only $LMS_URL_COUNT *_MICROFRONTEND_URL settings in production.py (expected >= 8)"
fi

# Check MFE_CONFIG_API_URLS dictionary exists
if grep -q "MFE_CONFIG_API_URLS = {" "$PRODUCTION_PY"; then
  do_pass "MFE_CONFIG_API_URLS dictionary defined in production.py"
else
  do_fail "MFE_CONFIG_API_URLS dictionary missing from production.py"
fi

# Extract MFE names from MFE_CONFIG_API_URLS
LMS_API_URLS=$(mktemp)
awk '/MFE_CONFIG_API_URLS = \{/,/^\}/' "$PRODUCTION_PY" | \
  grep -oP "'\K[a-z0-9_-]+(?=':\s*f)" | sort -u > "$LMS_API_URLS"
LMS_API_COUNT=$(wc -l < "$LMS_API_URLS")

if [ "$LMS_API_COUNT" -ge 10 ]; then
  do_pass "Found $LMS_API_COUNT MFE entries in MFE_CONFIG_API_URLS (>= 10 expected)"
else
  do_warn "Only $LMS_API_COUNT MFE entries in MFE_CONFIG_API_URLS (expected >= 10)"
fi

echo ""

# =============================================================================
# Section 5: Cross-Check Caddy ↔ LMS Settings (AC-MFERT-002) — NEW CHECK
# =============================================================================
echo "--- Cross-Check: Caddy ↔ LMS Settings (AC-MFERT-002) ---"

# For each Caddy directory, check if there's a corresponding LMS URL setting
while IFS= read -r dir; do
  # Special cases
  if [ "$dir" = "course-authoring" ]; then
    # Check for COURSE_AUTHORING_MICROFRONTEND_URL in MFE_CONFIG
    if grep -q "COURSE_AUTHORING_MICROFRONTEND_URL" "$PRODUCTION_PY"; then
      do_pass "AC-MFERT-002: Caddy dir '$dir' has LMS setting (COURSE_AUTHORING in MFE_CONFIG)"
    else
      do_fail "AC-MFERT-002: Caddy dir '$dir' has no LMS setting"
    fi
    continue
  fi

  # Convert directory name to likely setting name
  # authn → AUTHN, learner-dashboard → LEARNER_HOME, etc.
  case "$dir" in
    authn)
      setting="AUTHN_MICROFRONTEND_URL"
      ;;
    account)
      setting="ACCOUNT_MICROFRONTEND_URL"
      ;;
    communications)
      setting="COMMUNICATIONS_MICROFRONTEND_URL"
      ;;
    discussions)
      setting="DISCUSSIONS_MICROFRONTEND_URL"
      ;;
    gradebook)
      setting="WRITABLE_GRADEBOOK_URL"
      ;;
    learner-dashboard)
      setting="LEARNER_HOME_MICROFRONTEND_URL"
      ;;
    learning)
      setting="LEARNING_MICROFRONTEND_URL"
      ;;
    ora-grading)
      setting="ORA_GRADING_MICROFRONTEND_URL"
      ;;
    profile)
      setting="PROFILE_MICROFRONTEND_URL"
      ;;
    *)
      # Unknown — check MFE_CONFIG_API_URLS
      if grep -q "'$dir':" "$PRODUCTION_PY"; then
        do_pass "AC-MFERT-002: Caddy dir '$dir' in MFE_CONFIG_API_URLS"
      else
        do_warn "AC-MFERT-002: Caddy dir '$dir' not found in known LMS settings"
      fi
      continue
      ;;
  esac

  # Check if setting exists in production.py
  if grep -q "^$setting\s*=" "$PRODUCTION_PY"; then
    do_pass "AC-MFERT-002: Caddy dir '$dir' has LMS setting $setting"
  else
    do_fail "AC-MFERT-002: Caddy dir '$dir' has no LMS setting $setting"
  fi
done < "$CADDY_DIRS"

echo ""

# =============================================================================
# Section 6: Cross-Check LMS Settings → Caddy (AC-MFERT-002) — NEW CHECK
# =============================================================================
echo "--- Cross-Check: LMS Settings → Caddy (AC-MFERT-002) ---"

# Check each LMS MFE URL has a Caddy route
# Mapping of setting → expected Caddy directory
declare -A SETTING_TO_DIR=(
  ["AUTHN_MICROFRONTEND_URL"]="authn"
  ["ACCOUNT_MICROFRONTEND_URL"]="account"
  ["COMMUNICATIONS_MICROFRONTEND_URL"]="communications"
  ["DISCUSSIONS_MICROFRONTEND_URL"]="discussions"
  ["WRITABLE_GRADEBOOK_URL"]="gradebook"
  ["LEARNER_HOME_MICROFRONTEND_URL"]="learner-dashboard"
  ["LEARNING_MICROFRONTEND_URL"]="learning"
  ["ORA_GRADING_MICROFRONTEND_URL"]="ora-grading"
  ["PROFILE_MICROFRONTEND_URL"]="profile"
  ["ORDER_HISTORY_MICROFRONTEND_URL"]="__orders_proxy__"
)

while IFS= read -r setting; do
  # Check if key exists in associative array (bash 4.3+)
  if [[ ! -v SETTING_TO_DIR[$setting] ]]; then
    do_warn "AC-MFERT-002: LMS setting $setting has no known Caddy mapping"
    continue
  fi

  expected_dir="${SETTING_TO_DIR[$setting]}"

  if [[ "$expected_dir" == "__orders_proxy__" ]]; then
    if grep -Fq "reverse_proxy /orders* payments-gateway:8080" "$CADDYFILE"; then
      do_pass "AC-MFERT-002: LMS setting $setting has Caddy proxy /orders* → payments-gateway"
    else
      do_fail "AC-MFERT-002: LMS setting $setting missing Caddy proxy /orders* → payments-gateway"
    fi
  elif grep -q "/openedx/dist/$expected_dir" "$CADDYFILE"; then
    do_pass "AC-MFERT-002: LMS setting $setting has Caddy route to $expected_dir"
  else
    do_fail "AC-MFERT-002: LMS setting $setting has no Caddy route to $expected_dir"
  fi
done < "$LMS_MFE_URLS"

echo ""

# =============================================================================
# Section 7: Cross-Check Caddy ↔ Branding Verifier (AC-MFERT-002)
# =============================================================================
echo "--- Cross-Check: Caddy ↔ Branding Verifier (AC-MFERT-002) ---"

VERIFIER_ROUTES=$(mktemp)

# Extract MFE_ROUTES entries: ["/path"]="directory"
grep -oP '\["/[a-z0-9_-]+"\]="[a-z0-9_-]+"' "$BRANDING_VERIFIER" > "$VERIFIER_ROUTES"
VERIFIER_COUNT=$(wc -l < "$VERIFIER_ROUTES")

if [ "$VERIFIER_COUNT" -ge 11 ]; then
  do_pass "AC-MFERT-002: Branding verifier has $VERIFIER_COUNT route mappings (>= 11 expected)"
else
  do_fail "AC-MFERT-002: Branding verifier only has $VERIFIER_COUNT route mappings (expected >= 11)"
fi

# Check each Caddyfile directory is referenced in branding verifier
while IFS= read -r dir; do
  if grep -q "\"$dir\"" "$BRANDING_VERIFIER"; then
    do_pass "AC-MFERT-002: Caddy dir '$dir' referenced in branding verifier"
  else
    do_fail "AC-MFERT-002: Caddy dir '$dir' NOT in branding verifier (drift!)"
  fi
done < "$CADDY_DIRS"

echo ""

# =============================================================================
# Section 8: Authoring Dual-Path Check (AC-MFERT-002)
# =============================================================================
echo "--- Authoring Dual-Path Check (AC-MFERT-002) ---"

if grep -q "path /authoring /authoring/\*" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /authoring path defined in Caddyfile"
else
  do_fail "AC-MFERT-002: /authoring path missing from Caddyfile"
fi

if grep -q "path /course-authoring /course-authoring/\*" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /course-authoring path defined in Caddyfile"
else
  do_fail "AC-MFERT-002: /course-authoring path missing from Caddyfile"
fi

# Both should point to same directory
AUTHORING_DIR=$(grep -A5 "path /authoring /authoring/\*" "$CADDYFILE" | grep -oP '(?<=/openedx/dist/)[a-z0-9_-]+' | head -1 || true)
COURSE_AUTHORING_DIR=$(grep -A5 "path /course-authoring /course-authoring/\*" "$CADDYFILE" | grep -oP '(?<=/openedx/dist/)[a-z0-9_-]+' | head -1 || true)

if [ "$AUTHORING_DIR" = "$COURSE_AUTHORING_DIR" ] && [ -n "$AUTHORING_DIR" ]; then
  do_pass "AC-MFERT-002: /authoring and /course-authoring both serve '$AUTHORING_DIR'"
else
  do_fail "AC-MFERT-002: /authoring ($AUTHORING_DIR) and /course-authoring ($COURSE_AUTHORING_DIR) serve different dirs"
fi

echo ""

# =============================================================================
# Section 9: Profile /u Route Check (AC-MFERT-002)
# =============================================================================
echo "--- Profile /u Route Check (AC-MFERT-002) ---"

if grep -q "path /u /u/\*" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /u profile route defined in Caddyfile"
else
  do_fail "AC-MFERT-002: /u profile route missing from Caddyfile"
fi

if grep -A3 "path /u /u/\*" "$CADDYFILE" | grep -q "/openedx/dist/profile"; then
  do_pass "AC-MFERT-002: /u route serves profile directory"
else
  do_fail "AC-MFERT-002: /u route does not serve profile directory"
fi

# Check /u route doesn't strip prefix (special handling)
if grep -A3 "path /u /u/\*" "$CADDYFILE" | grep -q "uri strip_prefix /u"; then
  do_fail "AC-MFERT-002: /u route incorrectly strips prefix (should NOT strip)"
else
  do_pass "AC-MFERT-002: /u route correctly keeps prefix (no uri strip_prefix)"
fi

echo ""

# =============================================================================
# Section 10: Deprecated MFE Proxy Routes (AC-MFERT-002)
# =============================================================================
echo "--- Deprecated MFE Proxy Routes (AC-MFERT-002) ---"

if grep -q "reverse_proxy /orders\* payments-gateway" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /orders proxied to payments-gateway"
else
  do_fail "AC-MFERT-002: /orders proxy to payments-gateway missing"
fi

if grep -q "reverse_proxy /payment\* payments-gateway" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /payment proxied to payments-gateway"
else
  do_fail "AC-MFERT-002: /payment proxy to payments-gateway missing"
fi

echo ""

# =============================================================================
# Section 11: MFE Config API Route (AC-MFERT-002)
# =============================================================================
echo "--- MFE Config API Route (AC-MFERT-002) ---"

if grep -q "reverse_proxy /api/mfe_config/v1\* lms" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /api/mfe_config/v1 proxied to LMS"
else
  do_fail "AC-MFERT-002: /api/mfe_config/v1 proxy missing (MFEs need this!)"
fi

if grep -q "reverse_proxy /login_refresh\* lms" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /login_refresh proxied to LMS"
else
  do_fail "AC-MFERT-002: /login_refresh proxy missing (JWT refresh needed!)"
fi

echo ""

# =============================================================================
# Section 12: Account Settings Redirect (AC-MFERT-002)
# =============================================================================
echo "--- Account Settings Redirect (AC-MFERT-002) ---"

if grep -q "path /account/settings" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /account/settings redirect matcher defined"
else
  do_fail "AC-MFERT-002: /account/settings redirect matcher missing"
fi

if grep -q "redir.*@account_settings_compat /account/ 302" "$CADDYFILE"; then
  do_pass "AC-MFERT-002: /account/settings redirects to /account/"
else
  do_fail "AC-MFERT-002: /account/settings redirect target incorrect or missing"
fi

echo ""

# =============================================================================
# Section 13: Contract Document Route Mapping Table (AC-MFERT-001)
# =============================================================================
echo "--- Contract Route Mapping Table (AC-MFERT-001) ---"

if [ -f "$CONTRACT_DOC" ]; then
  # Check if contract documents all active Caddy routes
  while IFS= read -r dir; do
    if grep -q "$dir" "$CONTRACT_DOC"; then
      do_pass "AC-MFERT-001: Contract documents Caddy dir '$dir'"
    else
      do_warn "AC-MFERT-001: Contract missing documentation for '$dir'"
    fi
  done < "$CADDY_DIRS"
fi

echo ""

# =============================================================================
# Section 4: Live Dist Directory Validation (8jao.6)
# =============================================================================
echo "--- Live Dist Directory Validation (8jao.6) ---"

CADDYFILE_LOCAL="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
if [[ -f "$CADDYFILE_LOCAL" ]]; then
  # Extract dist directory names from Caddyfile
  DIST_DIRS=$(grep -oP '(?<=root \* /openedx/dist/)[a-z0-9_-]+' "$CADDYFILE_LOCAL" | sort -u)

  if [[ -z "$DIST_DIRS" ]]; then
    do_warn "8jao.6: No dist directories found in Caddyfile"
  else
    DIST_DIR_COUNT=$(echo "$DIST_DIRS" | wc -l)
    do_pass "8jao.6: Parsed $DIST_DIR_COUNT dist directories from Caddyfile"

    # Try to validate against live MFE pod
    MFE_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=mfe -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

    if [[ -z "$MFE_POD" ]]; then
      do_warn "8jao.6: MFE pod not found — skipping live dist validation"
    else
      for dir in $DIST_DIRS; do
        if kubectl exec -n mereka-lms "$MFE_POD" -- test -d "/openedx/dist/$dir" 2>/dev/null; then
          do_pass "8jao.6: /openedx/dist/$dir exists in MFE pod"
        else
          do_warn "8jao.6: /openedx/dist/$dir MISSING in MFE pod (Caddyfile expects it)"
        fi
      done
    fi
  fi
else
  do_fail "8jao.6: Caddyfile not found at $CADDYFILE_LOCAL"
fi
echo ""

# =============================================================================
# Section 5: Selector Override Expiry Check (8jao.8)
# =============================================================================
echo "--- Selector Override Expiry Check (8jao.8) ---"

DECISION_LOG="$REPO_ROOT/docs/architecture/MFE_SELECTOR_DECISION_LOG.md"
if [[ -f "$DECISION_LOG" ]]; then
  do_pass "8jao.8: Selector decision log exists"

  # Check for expired entries
  TODAY=$(date +%Y-%m-%d)
  EXPIRED=0
  while IFS='|' read -r _ id selector file approved expiry owner target status _; do
    expiry=$(echo "$expiry" | xargs)
    if [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] && [[ "$expiry" < "$TODAY" ]]; then
      do_warn "8jao.8: Selector override $id expired on $expiry — needs migration"
      EXPIRED=$((EXPIRED + 1))
    fi
  done < <(grep "^| SEL-" "$DECISION_LOG")

  if [[ "$EXPIRED" -eq 0 ]]; then
    do_pass "8jao.8: No expired selector overrides"
  fi
else
  do_warn "8jao.8: Selector decision log not found — create docs/architecture/MFE_SELECTOR_DECISION_LOG.md"
fi
echo ""

# Cleanup
rm -f "$CADDY_DIRS" "$CADDY_PATHS" "$LMS_MFE_URLS" "$LMS_API_URLS" "$VERIFIER_ROUTES"

# =============================================================================
# Summary
# =============================================================================
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

if [ "$FAIL" -gt 0 ]; then
  echo ""
  echo "ACTION REQUIRED: Route mapping drift detected!"
  echo ""
  echo "Common fixes:"
  echo "  1. Added MFE in Caddyfile? Add to production.py and verify-mfe-branding.sh"
  echo "  2. Added setting in production.py? Add route to Caddyfile"
  echo "  3. See docs/architecture/MFE_ROUTE_TO_DIST_CONTRACT.md for full guide"
  echo ""
  exit 1
fi

if [ "$WARN" -gt 0 ]; then
  echo ""
  echo "WARNINGS PRESENT: Contract has warnings but no failures."
  echo "Review warnings above and update documentation if needed."
  echo ""
fi

echo "All MFE route-to-dist contract checks passed!"
exit 0
