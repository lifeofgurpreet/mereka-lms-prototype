#!/usr/bin/env bash
# verify-mfe-route-drift.sh — Guard against MFE route mapping drift
#
# Ensures the Caddyfile route definitions stay in sync with:
#   1. The branding verifier's hardcoded MFE_ROUTES map
#   2. Expected MFE directory names
#
# Usage: ./scripts/qa/verify-mfe-route-drift.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
BRANDING_VERIFIER="$REPO_ROOT/scripts/qa/verify-mfe-branding.sh"
SCOPE_MODE="${VERIFY_MFE_ROUTE_DRIFT_SCOPE:-}"
CHANGED_FILES_RAW="${VERIFY_MFE_ROUTE_DRIFT_CHANGED_FILES:-${CI_CHANGED_FILES:-}}"

should_skip_scope() {
  [[ "$SCOPE_MODE" == "changed" ]] || return 1
  [[ -n "$CHANGED_FILES_RAW" ]] || return 1

  while IFS= read -r path; do
    [[ -n "$path" ]] || continue
    case "$path" in
      .github/workflows/ci.yml|\
      scripts/qa/verify-mfe-route-drift.sh|\
      scripts/qa/verify-mfe-branding.sh|\
      deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile)
        return 1
        ;;
    esac
  done <<< "$CHANGED_FILES_RAW"

  return 0
}

if should_skip_scope; then
  echo "PASS verify-mfe-route-drift (scope skip: no MFE route authority changes)"
  exit 0
fi

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== MFE Route Mapping Drift Guard ==="
echo ""

# 1. Verify Caddyfile exists
echo "--- Caddyfile structural checks ---"
if [ ! -f "$CADDYFILE" ]; then
  do_fail "Caddyfile not found at $CADDYFILE"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi
do_pass "Caddyfile exists"

# 2. Extract all MFE routes from Caddyfile (path directives → directory mappings)
echo ""
echo "--- Extracting Caddyfile routes ---"
CADDY_ROUTES=$(mktemp)

# Extract "root * /openedx/dist/<dir>" lines and their preceding path blocks
# Pattern: look for path directives followed by root directives
while IFS= read -r line; do
  # Match: root * /openedx/dist/<directory>
  if echo "$line" | grep -qP 'root \* /openedx/dist/'; then
    dir=$(echo "$line" | grep -oP '(?<=/openedx/dist/)[a-z0-9_-]+')
    [ -n "$dir" ] && echo "$dir" >> "$CADDY_ROUTES"
  fi
done < "$CADDYFILE"

sort -u "$CADDY_ROUTES" -o "$CADDY_ROUTES"
CADDY_COUNT=$(wc -l < "$CADDY_ROUTES")
echo "  Found $CADDY_COUNT unique MFE directories in Caddyfile"

# 3. Extract path prefixes from Caddyfile
CADDY_PATHS=$(mktemp)
grep -oP '(?<=path )/[a-z0-9_-]+(?= )' "$CADDYFILE" | sort -u > "$CADDY_PATHS"
PATH_COUNT=$(wc -l < "$CADDY_PATHS")
echo "  Found $PATH_COUNT URL path prefixes in Caddyfile"

# 4. Verify branding verifier exists and extract its route map
echo ""
echo "--- Branding verifier route map checks ---"
if [ ! -f "$BRANDING_VERIFIER" ]; then
  do_fail "Branding verifier not found at $BRANDING_VERIFIER"
else
  do_pass "Branding verifier script exists"

  # Extract MFE_ROUTES entries: ["/path"]="directory"
  VERIFIER_ROUTES=$(mktemp)
  grep -oP '\["/[a-z0-9_-]+"\]="[a-z0-9_-]+"' "$BRANDING_VERIFIER" > "$VERIFIER_ROUTES" || true
  VERIFIER_COUNT=$(wc -l < "$VERIFIER_ROUTES")

  if [ "$VERIFIER_COUNT" -ge 8 ]; then
    do_pass "Branding verifier has $VERIFIER_COUNT route mappings (>= 8 required)"
  else
    do_fail "Branding verifier only has $VERIFIER_COUNT route mappings (expected >= 8)"
  fi

  # 5. Cross-check: every Caddyfile directory should be in verifier
  echo ""
  echo "--- Cross-referencing routes ---"

  # Check each Caddyfile directory is referenced in verifier
  while IFS= read -r dir; do
    if grep -q "\"$dir\"" "$BRANDING_VERIFIER"; then
      do_pass "Caddyfile dir '$dir' referenced in branding verifier"
    else
      do_fail "Caddyfile dir '$dir' NOT in branding verifier (drift!)"
    fi
  done < "$CADDY_ROUTES"

  # Check each verifier route has a Caddyfile mapping
  while IFS= read -r entry; do
    path=$(echo "$entry" | grep -oP '(?<=/)[a-z0-9_-]+(?="\])')
    dir=$(echo "$entry" | grep -oP '(?<==")[a-z0-9_-]+(?=")')
    [ -z "$path" ] || [ -z "$dir" ] && continue

    # Check the directory exists in Caddyfile
    if grep -qF "/openedx/dist/$dir" "$CADDYFILE"; then
      do_pass "Verifier route /$path → $dir exists in Caddyfile"
    else
      do_fail "Verifier route /$path → $dir NOT in Caddyfile (drift!)"
    fi
  done < "$VERIFIER_ROUTES"

  rm -f "$VERIFIER_ROUTES"
fi

# 6. Check authoring ↔ course-authoring dual-path (critical for mereka-lms-18ik)
echo ""
echo "--- Authoring dual-path check ---"
if grep -q "path /authoring /authoring/\*" "$CADDYFILE"; then
  do_pass "/authoring path defined in Caddyfile"
else
  do_fail "/authoring path missing from Caddyfile"
fi

if grep -q "path /course-authoring /course-authoring/\*" "$CADDYFILE"; then
  do_pass "/course-authoring path defined in Caddyfile"
else
  do_fail "/course-authoring path missing from Caddyfile"
fi

# Both should point to same directory
AUTHORING_DIR=$(grep -A5 "path /authoring /authoring/\*" "$CADDYFILE" | grep -oP '(?<=/openedx/dist/)[a-z0-9_-]+' | head -1 || true)
COURSE_AUTHORING_DIR=$(grep -A5 "path /course-authoring /course-authoring/\*" "$CADDYFILE" | grep -oP '(?<=/openedx/dist/)[a-z0-9_-]+' | head -1 || true)

if [ "$AUTHORING_DIR" = "$COURSE_AUTHORING_DIR" ] && [ -n "$AUTHORING_DIR" ]; then
  do_pass "/authoring and /course-authoring both serve $AUTHORING_DIR"
else
  do_fail "/authoring ($AUTHORING_DIR) and /course-authoring ($COURSE_AUTHORING_DIR) serve different dirs"
fi

# 7. Check profile /u route (special: no prefix strip)
echo ""
echo "--- Profile /u route check ---"
if grep -q "path /u /u/\*" "$CADDYFILE"; then
  do_pass "/u profile route defined in Caddyfile"
else
  do_fail "/u profile route missing from Caddyfile"
fi

if grep -A3 "path /u /u/\*" "$CADDYFILE" | grep -q "/openedx/dist/profile"; then
  do_pass "/u route serves profile directory"
else
  do_fail "/u route does not serve profile directory"
fi

# 8. Check deprecated compat routes stay absent from inner MFE Caddyfile
echo ""
echo "--- Deprecated compat route absence checks ---"
if grep -q "reverse_proxy /orders\*" "$CADDYFILE" || grep -q "reverse_proxy /payment\*" "$CADDYFILE"; then
  do_fail "stale /orders or /payment proxy route still present"
else
  do_pass "stale /orders and /payment proxy routes absent"
fi

# Cleanup
rm -f "$CADDY_ROUTES" "$CADDY_PATHS"

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
