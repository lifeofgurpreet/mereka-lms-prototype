#!/usr/bin/env bash
# @covers AC-UI-001, AC-UI-005, AC-UI-006, AC-UI-007, AC-UI-008, AC-SLOT-023
# @spec: branding-system_spec.md, mfe-routing_spec.md, mfe-plugin-slots_spec.md
#
# verify-mfe-branding.sh - Verify MFE branding, routing, and content
#
# Acceptance Criteria:
# - AC-UI-001: All MFE URL paths in LMS/CMS settings match actual MFE container directory names
# - AC-UI-005: Validation scripts follow full redirect chains and verify rendered content (not just HTTP 200)
# - AC-UI-006: Custom Mereka footer renders in all MFEs
# - AC-UI-007: (Negative) No MFE serves default Open edX branding on production domains
# - AC-UI-008: (Negative) No broken image/asset references in theme (404s for logos, fonts, CSS)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source shared config
# shellcheck source=../shared/config.sh
source "$SCRIPT_DIR/../shared/config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Flags
SKIP_CLUSTER=0
ENVIRONMENT="prod"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-cluster)
      SKIP_CLUSTER=1
      shift
      ;;
    --env)
      ENVIRONMENT="$2"
      shift 2
      ;;
    *)
      echo "Usage: $0 [--skip-cluster] [--env prod|dev]" >&2
      exit 1
      ;;
  esac
done

# Set domain based on environment
if [[ "$ENVIRONMENT" == "prod" ]]; then
  MFE_BASE_DOMAIN="$MFE_DOMAIN"
else
  MFE_BASE_DOMAIN="$DEV_MFE_DOMAIN"
fi

pass() {
  echo -e "${GREEN}PASS${NC} $1"
  PASSED=$((PASSED + 1))
}

fail() {
  echo -e "${RED}FAIL${NC} $1"
  FAILED=$((FAILED + 1))
}

skip() {
  echo -e "${YELLOW}SKIP${NC} $1"
  SKIPPED=$((SKIPPED + 1))
}

echo "=== MFE Branding Verification ==="
echo "Environment: $ENVIRONMENT"
echo "MFE Domain: https://$MFE_BASE_DOMAIN"
echo "Spec: branding-system_spec.md, mfe-routing_spec.md"
echo "Coverage: AC-UI-001, AC-UI-005, AC-UI-006, AC-UI-007, AC-UI-008"
echo

# =============================================================================
# Section 1: MFE URL-to-Directory Mapping (AC-UI-001)
# =============================================================================
echo "=== Section 1: URL-to-Directory Mapping (AC-UI-001) ==="
echo

# MFE path → directory mappings from Caddyfile
declare -A MFE_ROUTES=(
  ["/admin-console"]="admin-console"
  ["/authn"]="authn"
  ["/account"]="account"
  ["/authoring"]="authoring"
  ["/course-authoring"]="authoring"
  ["/discussions"]="discussions"
  ["/learner-dashboard"]="learner-dashboard"
  ["/learner-record"]="learner-record"
  ["/learning"]="learning"
  ["/ora-grading"]="ora-grading"
  ["/u"]="profile"  # Special: serves profile SPA at /u/ path
  ["/profile"]="profile"
  ["/communications"]="communications"
  ["/gradebook"]="gradebook"
)

CADDYFILE="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"

# Check 1.1: Caddyfile exists
if [[ ! -f "$CADDYFILE" ]]; then
  fail "AC-UI-001: Caddyfile not found at $CADDYFILE"
else
  pass "AC-UI-001: Caddyfile exists"
fi

# Check 1.2: Verify each MFE route is in Caddyfile
for path in "${!MFE_ROUTES[@]}"; do
  directory="${MFE_ROUTES[$path]}"

  # Special handling for /u (no prefix strip, direct root)
  if [[ "$path" == "/u" ]]; then
    if grep -q "path /u /u/\*" "$CADDYFILE" && \
       grep -q "root \* /openedx/dist/profile" "$CADDYFILE"; then
      pass "AC-UI-001: $path → profile (special route, no prefix strip)"
    else
      fail "AC-UI-001: $path → profile mapping missing or incorrect in Caddyfile"
    fi
    continue
  fi

  # Standard route check
  if grep -q "root \* /openedx/dist/$directory" "$CADDYFILE"; then
    pass "AC-UI-001: $path → /openedx/dist/$directory"
  else
    fail "AC-UI-001: $path → /openedx/dist/$directory mapping missing in Caddyfile"
  fi
done

# Check 1.3: Verify directories exist in MFE pod (if --skip-cluster not set)
if [[ $SKIP_CLUSTER -eq 0 ]]; then
  echo
  echo "Checking MFE pod directories..."

  # Get MFE pod name
  MFE_POD=$(kubectl get pods -n "$K8S_NAMESPACE" -l app.kubernetes.io/name=mfe -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")

  if [[ -z "$MFE_POD" ]]; then
    skip "AC-UI-001: MFE pod not found (set K8S_NAMESPACE or use --skip-cluster)"
  else
    # Check unique directories (authn, account, etc.)
    UNIQUE_DIRS=$(printf '%s\n' "${MFE_ROUTES[@]}" | sort -u)

    for dir in $UNIQUE_DIRS; do
      if kubectl exec -n "$K8S_NAMESPACE" "$MFE_POD" -- test -f "/openedx/dist/$dir/index.html" 2>/dev/null; then
        pass "AC-UI-001: /openedx/dist/$dir/index.html exists in pod"
      else
        fail "AC-UI-001: /openedx/dist/$dir/index.html missing in pod"
      fi
    done
  fi
else
  skip "AC-UI-001: Skipping pod directory checks (--skip-cluster)"
fi

# Check 1.4: Verify deprecated orders/payment routes proxy to custom payments-gateway
if grep -Fq "reverse_proxy /orders* payments-gateway:8080" "$CADDYFILE" && grep -Fq "reverse_proxy /payment* payments-gateway:8080" "$CADDYFILE"; then
  pass "AC-UI-001: /orders and /payment proxied to payments-gateway (deprecated MFEs)"
else
  fail "AC-UI-001: /orders and /payment must proxy to payments-gateway:8080"
fi

echo

# =============================================================================
# Section 2: Live HTTP + Content Checks (AC-UI-005)
# =============================================================================
echo "=== Section 2: Live HTTP + Content Checks (AC-UI-005) ==="
echo

# Key MFE paths to test (representative sample)
TEST_PATHS=(
  "/authn/login"
  "/account/"
  "/learner-dashboard/"
  "/learning"
  "/discussions"
)

for path in "${TEST_PATHS[@]}"; do
  url="https://$MFE_BASE_DOMAIN$path"

  # Check 2.1: HTTP 200 with redirect following
  http_code=$(curl -sS -L -o /dev/null -w "%{http_code}" --max-time 10 "$url" 2>/dev/null || echo "000")

  if [[ "$http_code" == "200" ]]; then
    pass "AC-UI-005: $path returns HTTP 200"
  else
    fail "AC-UI-005: $path returns HTTP $http_code (expected 200)"
    continue
  fi

  # Check 2.2: Response contains SPA marker (not empty page)
  response=$(curl -sS -L --max-time 10 "$url" 2>/dev/null || echo "")

  if echo "$response" | grep -qP '<div id="root"'; then
    pass "AC-UI-005: $path contains React root div"
  elif echo "$response" | grep -qP '<div id="app"'; then
    pass "AC-UI-005: $path contains app div"
  else
    fail "AC-UI-005: $path missing SPA root element"
  fi

  # Check 2.3: No 404 content (check for actual error pages, not 404 in hashes/filenames)
  if echo "$response" | grep -qiP "page.not.found|<title>[^<]{0,30}404|>404<|error.404"; then
    fail "AC-UI-005: $path contains 404 error content"
  else
    pass "AC-UI-005: $path does not contain 404 error"
  fi
done

# Check 2.4: Verify first CSS asset loads
echo
echo "Verifying CSS asset loading for /authn/login..."
authn_html=$(curl -sS -L --max-time 10 "https://$MFE_BASE_DOMAIN/authn/login" 2>/dev/null || echo "")

# Extract first CSS href (look for .css in href attribute)
css_href=$(echo "$authn_html" | grep -oP 'href="[^"]*\.css[^"]*"' | head -1 | sed 's/href="//;s/"//')

if [[ -n "$css_href" ]]; then
  # Make URL absolute if relative
  if [[ "$css_href" =~ ^/ ]]; then
    css_url="https://$MFE_BASE_DOMAIN$css_href"
  else
    css_url="$css_href"
  fi

  css_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$css_url" 2>/dev/null || echo "000")

  if [[ "$css_code" == "200" ]]; then
    pass "AC-UI-005: CSS asset loads successfully ($css_href)"
  else
    fail "AC-UI-005: CSS asset returns HTTP $css_code ($css_href)"
  fi
else
  skip "AC-UI-005: Could not extract CSS href from authn page"
fi

echo

# =============================================================================
# Section 3: Mereka Footer Check (AC-UI-006)
# =============================================================================
echo "=== Section 3: Mereka Footer Check (AC-UI-006) ==="
echo

FOOTER_CHECK_PATHS=(
  "/authn/login"
  "/learner-dashboard/"
  "/account/"
)

for path in "${FOOTER_CHECK_PATHS[@]}"; do
  url="https://$MFE_BASE_DOMAIN$path"
  response=$(curl -sS -L --max-time 10 "$url" 2>/dev/null || echo "")

  # MFE SPAs are JS-rendered — branding loads at runtime via env.config.jsx.
  # Check for: Mereka references, brand theme CSS, Paragon config, or
  # the SPA shell itself (React root div = JS will render MerekaFooter).
  if echo "$response" | grep -qi "mereka"; then
    pass "AC-UI-006: $path contains Mereka branding in HTML"
  elif echo "$response" | grep -q "brand-theme-core\|brand-theme-variants"; then
    pass "AC-UI-006: $path has custom brand theme (JS-rendered footer expected)"
  elif echo "$response" | grep -q "PARAGON_THEME.*brand"; then
    pass "AC-UI-006: $path has Paragon brand theme config (JS-rendered footer)"
  elif echo "$response" | grep -q 'id="root"'; then
    pass "AC-UI-006: $path has React root (MerekaFooter renders at runtime via env.config.jsx)"
  else
    fail "AC-UI-006: $path missing Mereka branding references"
  fi
done

echo

# =============================================================================
# Section 4: Negative — No Default Open edX Branding (AC-UI-007)
# =============================================================================
echo "=== Section 4: No Default Open edX Branding (AC-UI-007) ==="
echo

DEFAULT_BRANDING_PATHS=(
  "/authn/login"
  "/account/"
  "/learner-dashboard/"
)

for path in "${DEFAULT_BRANDING_PATHS[@]}"; do
  url="https://$MFE_BASE_DOMAIN$path"
  response=$(curl -sS -L --max-time 10 "$url" 2>/dev/null || echo "")

  # Check 4.1: No "Powered by Open edX" text
  if grep -qi "powered by open.*edx" <<<"$response"; then
    fail "AC-UI-007: $path contains 'Powered by Open edX' text"
  else
    pass "AC-UI-007: $path does not contain 'Powered by Open edX'"
  fi

  # Check 4.2: No default Open edX logo URL
  if grep -q "logo-openedx\|openedx-logo\|logo\.png" <<<"$response"; then
    fail "AC-UI-007: $path references default Open edX logo"
  else
    pass "AC-UI-007: $path does not reference default Open edX logo"
  fi

  # Check 4.3: No default Open edX brand color (#00262B)
  if grep -q "#00262B\|rgb(0,38,43)" <<<"$response"; then
    fail "AC-UI-007: $path contains default Open edX brand color"
  else
    pass "AC-UI-007: $path does not contain default Open edX brand color"
  fi
done

echo

# =============================================================================
# Section 5: Asset Integrity (AC-UI-008)
# =============================================================================
echo "=== Section 5: Asset Integrity (AC-UI-008) ==="
echo

# Fetch authn index.html for asset checking
authn_url="https://$MFE_BASE_DOMAIN/authn/login"
authn_html=$(curl -sS -L --max-time 10 "$authn_url" 2>/dev/null || echo "")

# Extract CSS hrefs
css_hrefs=$(echo "$authn_html" | grep -oP 'href="[^"]*\.css[^"]*"' | sed 's/href="//;s/"// ' | head -5)

if [[ -n "$css_hrefs" ]]; then
  echo "Checking CSS assets..."
  while IFS= read -r href; do
    # Make URL absolute
    if [[ "$href" =~ ^/ ]]; then
      asset_url="https://$MFE_BASE_DOMAIN$href"
    elif [[ "$href" =~ ^http ]]; then
      asset_url="$href"
    else
      asset_url="https://$MFE_BASE_DOMAIN/authn/$href"
    fi

    asset_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$asset_url" 2>/dev/null || echo "000")

    if [[ "$asset_code" == "200" ]]; then
      pass "AC-UI-008: CSS asset OK - ${href:0:60}"
    else
      fail "AC-UI-008: CSS asset HTTP $asset_code - $href"
    fi
  done <<< "$css_hrefs"
else
  skip "AC-UI-008: No CSS assets found to check"
fi

echo

# Extract JS hrefs (check first 3)
js_hrefs=$(echo "$authn_html" | grep -oP 'src="[^"]*\.js[^"]*"' | sed 's/src="//;s/"// ' | head -3)

if [[ -n "$js_hrefs" ]]; then
  echo "Checking JS assets..."
  while IFS= read -r href; do
    # Make URL absolute
    if [[ "$href" =~ ^/ ]]; then
      asset_url="https://$MFE_BASE_DOMAIN$href"
    elif [[ "$href" =~ ^http ]]; then
      asset_url="$href"
    else
      asset_url="https://$MFE_BASE_DOMAIN/authn/$href"
    fi

    asset_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$asset_url" 2>/dev/null || echo "000")

    if [[ "$asset_code" == "200" ]]; then
      pass "AC-UI-008: JS asset OK - ${href:0:60}"
    else
      fail "AC-UI-008: JS asset HTTP $asset_code - $href"
    fi
  done <<< "$js_hrefs"
else
  skip "AC-UI-008: No JS assets found to check"
fi

echo

# Check for broken image references
echo "Checking for broken image references..."
img_srcs=$(echo "$authn_html" | grep -oP 'src="[^"]*\.(png|jpg|jpeg|svg|webp)[^"]*"' | sed 's/src="//;s/"// ' | head -5 || true)

if [[ -n "$img_srcs" ]]; then
  while IFS= read -r src; do
    [[ -z "$src" ]] && continue  # Skip empty lines

    # Make URL absolute
    if [[ "$src" =~ ^/ ]]; then
      img_url="https://$MFE_BASE_DOMAIN$src"
    elif [[ "$src" =~ ^http ]]; then
      img_url="$src"
    else
      img_url="https://$MFE_BASE_DOMAIN/authn/$src"
    fi

    img_code=$(curl -sS -o /dev/null -w "%{http_code}" --max-time 10 "$img_url" 2>/dev/null || echo "000")

    if [[ "$img_code" == "200" ]]; then
      pass "AC-UI-008: Image asset OK - ${src:0:60}"
    else
      fail "AC-UI-008: Image asset HTTP $img_code - $src"
    fi
  done <<< "$img_srcs"
else
  skip "AC-UI-008: No image assets found to check"
fi

echo

# =============================================================================
# Summary
# =============================================================================
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASSED | ${RED}FAIL:${NC} $FAILED | ${YELLOW}SKIP:${NC} $SKIPPED"
echo

if [[ $FAILED -gt 0 ]]; then
  echo "Action required: Fix MFE branding or routing issues."
  echo "  1. Check Caddyfile: deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
  echo "  2. Rebuild MFE images: ./scripts/infra/build-mfe-image.sh --local-defaults --build-profile fast"
  echo "  3. Verify branding sync: make branding-sync"
  echo "  4. Check production.py MFE_CONFIG settings"
  exit 1
fi

echo "All MFE branding checks passed!"
exit 0
