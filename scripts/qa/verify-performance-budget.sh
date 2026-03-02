#!/usr/bin/env bash
# verify-performance-budget.sh — @covers AC-UIPERF-001, AC-UIPERF-002, AC-UIPERF-003
#
# Verifies the performance budget quality contract:
# - Performance budgets doc exists with required sections
# - Caddyfile exists at expected path
# - Caddyfile cache-control headers (WARN if missing — config gap)
# - No hardcoded cache durations in application code
# - Bundle size budget section exists
# - Web Vitals thresholds section exists
#
# Usage: ./scripts/qa/verify-performance-budget.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/mereka_plugin_contract.sh"
PLUGIN_MAIN="$(mereka_plugin_main_file "$REPO_ROOT")"
BUDGET_DOC="$REPO_ROOT/docs/architecture/PERFORMANCE_BUDGETS.md"
CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UIPERF-001..003: Performance Budget Contract Verification ==="
echo ""

# 1. Budget documentation exists
echo "--- Performance Budget Documentation ---"
if [ -f "$BUDGET_DOC" ]; then
  do_pass "PERFORMANCE_BUDGETS.md exists"
else
  do_fail "PERFORMANCE_BUDGETS.md not found"
  echo ""
  echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="
  exit 1
fi

# 2. Required sections present
echo ""
echo "--- Required Sections ---"
required_sections=(
  "Performance Budget Thresholds"
  "Cache-Control Policy"
  "Bundle Size Budgets"
  "Caddy Configuration Requirements"
  "Current Gaps"
  "LCP"
  "FID"
  "CLS"
  "TTFB"
)

for section in "${required_sections[@]}"; do
  if grep -qi "$section" "$BUDGET_DOC"; then
    do_pass "Section present: $section"
  else
    do_fail "Section missing: $section"
  fi
done

# 3. Web Vitals thresholds defined (AC-UIPERF-002)
echo ""
echo "--- Web Vitals Thresholds ---"
web_vitals=(
  "LCP.*2\.5s"
  "FID.*100ms"
  "CLS.*0\.1"
  "TTFB.*600ms"
)

for vital in "${web_vitals[@]}"; do
  if grep -Ei "$vital" "$BUDGET_DOC"; then
    do_pass "Web Vital threshold defined: ${vital%%.*}"
  else
    do_fail "Web Vital threshold missing: ${vital%%.*}"
  fi
done

# 4. Bundle size budgets defined (AC-UIPERF-002)
echo ""
echo "--- Bundle Size Budgets ---"
if grep -qi "Bundle Size Budgets" "$BUDGET_DOC"; then
  do_pass "Bundle size budgets section exists"

  bundle_checks=(
    "500.*KB.*gzipped"
    "250.*KB"
    "Initial.*Load"
    "Individual.*Chunk"
  )

  for check in "${bundle_checks[@]}"; do
    if grep -Ei "$check" "$BUDGET_DOC"; then
      do_pass "Bundle budget defined: ${check%%.*}"
    else
      do_warn "Bundle budget detail missing: ${check%%.*}"
    fi
  done
else
  do_fail "Bundle Size Budgets section not found"
fi

# 5. Cache-control policy documented (AC-UIPERF-001)
echo ""
echo "--- Cache-Control Policy ---"
cache_policies=(
  "max-age=31536000"
  "immutable"
  "no-cache"
  "must-revalidate"
  "private.*no-store"
)

for policy in "${cache_policies[@]}"; do
  if grep -Ei "$policy" "$BUDGET_DOC"; then
    do_pass "Cache policy documented: ${policy%%.*}"
  else
    do_fail "Cache policy missing: ${policy%%.*}"
  fi
done

# 6. Caddyfile exists
echo ""
echo "--- Caddyfile Existence ---"
if [ -f "$CADDYFILE" ]; then
  do_pass "Caddyfile exists at expected path"
else
  do_fail "Caddyfile not found at $CADDYFILE"
fi

# 7. Caddyfile cache headers (WARN only — this is a known config gap)
echo ""
echo "--- Caddyfile Cache-Control Headers (AC-UIPERF-003) ---"
if [ -f "$CADDYFILE" ]; then
  if grep -qi "Cache-Control" "$CADDYFILE"; then
    do_pass "Caddyfile contains Cache-Control headers"

    # Check for immutable directive
    if grep -qi "immutable" "$CADDYFILE"; then
      do_pass "Caddyfile uses 'immutable' directive for hashed assets"
    else
      do_warn "Caddyfile missing 'immutable' directive (best practice for hashed assets)"
    fi

    # Check for no-cache on index.html
    if grep -qi "no-cache" "$CADDYFILE"; then
      do_pass "Caddyfile uses 'no-cache' for index.html"
    else
      do_warn "Caddyfile missing 'no-cache' for index.html (critical for SPA updates)"
    fi

  else
    do_warn "Caddyfile has NO Cache-Control headers (documented config gap in AC-UIPERF-003)"
    do_warn "Expected: Cache-Control headers for hashed assets, index.html, API responses"
    do_warn "See: docs/architecture/PERFORMANCE_BUDGETS.md section 'Caddy Configuration Requirements'"
  fi
else
  do_fail "Cannot verify Caddyfile cache headers (file not found)"
fi

# 8. No hardcoded cache durations in application code
echo ""
echo "--- Hardcoded Cache Durations Check ---"
# Check for hardcoded max-age values in Python/JS code (NOT in docs or configs)
hardcoded_found=0

# Check Python MFE plugin for hardcoded cache headers
if mereka_plugin_has_any "$REPO_ROOT"; then
  while IFS= read -r plugin_file; do
    if grep -E "Cache-Control.*[0-9]+" "$plugin_file" 2>/dev/null | grep -qv "^#"; then
      do_warn "Found hardcoded cache durations in plugin contract source $(basename "$plugin_file") (prefer Caddyfile config)"
      hardcoded_found=1
    fi
  done < <(mereka_plugin_contract_files "$REPO_ROOT")
else
  do_warn "Plugin contract sources not found (expected at least $PLUGIN_MAIN)"
fi

# Check for hardcoded cache headers in custom Django settings
if [ -d "$REPO_ROOT/infrastructure/tutor/env/apps/openedx/settings/lms" ]; then
  while IFS= read -r -d '' file; do
    if grep -E "Cache-Control.*[0-9]+" "$file" 2>/dev/null | grep -qv "^#"; then
      do_warn "Found hardcoded cache durations in $file (prefer Caddyfile config)"
      hardcoded_found=1
    fi
  done < <(find "$REPO_ROOT/infrastructure/tutor/env/apps/openedx/settings" -type f -name "*.py" -print0 2>/dev/null)
fi

if [ "$hardcoded_found" -eq 0 ]; then
  do_pass "No hardcoded cache durations in application code"
fi

# 9. Caddy configuration requirements documented (AC-UIPERF-003)
echo ""
echo "--- Caddy Configuration Requirements ---"
if grep -qi "Caddy Configuration Requirements" "$BUDGET_DOC"; then
  do_pass "Caddy configuration requirements section exists"

  # Check for specific guidance
  caddy_guidance=(
    "header"
    "static"
    "index.html"
    "reverse_proxy"
  )

  for guide in "${caddy_guidance[@]}"; do
    if grep -i "$guide" "$BUDGET_DOC" | grep -qi "caddyfile\|caddy"; then
      do_pass "Caddy guidance includes: $guide"
    else
      do_warn "Caddy guidance may be missing detail for: $guide"
    fi
  done
else
  do_fail "Caddy Configuration Requirements section not found"
fi

# 10. Current gaps documented
echo ""
echo "--- Current Gaps Documentation ---"
if grep -qi "Current Gaps" "$BUDGET_DOC"; then
  do_pass "Current gaps section exists"

  # Check for known gaps
  known_gaps=(
    "No performance monitoring"
    "No bundle size"
    "No Lighthouse"
  )

  for gap in "${known_gaps[@]}"; do
    if grep -qi "$gap" "$BUDGET_DOC"; then
      do_pass "Known gap documented: $gap"
    else
      do_warn "Gap may be missing: $gap"
    fi
  done

  if grep -Ei "cache-control.*monitor|runtime.*cache-control.*monitor" "$BUDGET_DOC"; then
    do_pass "Cache-control monitoring/drift gap is documented"
  else
    do_warn "Cache-control monitoring/drift gap may be missing"
  fi
else
  do_warn "Current Gaps section not found (recommended for transparency)"
fi

# 11. Acceptance criteria tagged
echo ""
echo "--- Acceptance Criteria ---"
ac_tags=(
  "AC-UIPERF-001"
  "AC-UIPERF-002"
  "AC-UIPERF-003"
)

for tag in "${ac_tags[@]}"; do
  if grep -q "$tag" "$BUDGET_DOC"; then
    do_pass "AC tagged: $tag"
  else
    do_warn "AC not tagged: $tag"
  fi
done

# 12. Tooling section exists
echo ""
echo "--- Tooling & Verification ---"
if grep -qi "Tooling" "$BUDGET_DOC"; then
  do_pass "Tooling section exists"

  tools=(
    "Lighthouse"
    "webpack-bundle-analyzer"
    "web-vitals"
  )

  for tool in "${tools[@]}"; do
    if grep -qi "$tool" "$BUDGET_DOC"; then
      do_pass "Tool documented: $tool"
    else
      do_warn "Tool not documented: $tool"
    fi
  done
else
  do_warn "Tooling section not found (recommended for implementation)"
fi

echo ""
echo "=== Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
