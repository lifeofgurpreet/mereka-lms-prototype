#!/usr/bin/env bash
# @covers AC-ENTUI-001, AC-ENTUI-002, AC-ENTUI-003, AC-ENTUI-004, AC-ENTUI-005, AC-ENTUI-006, AC-ENTUI-007
# @spec: bead-115d13
# verify-enterprise-ui-review.sh
# Covers: AC-ENTUI-001 through AC-ENTUI-007 (Enterprise UI Review)
# Exit 0 = all checks pass
# Exit 1 = hard failure
# Exit 2 = indeterminate (authoritative truth is infra-owned or runtime-only)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0
INDET=0
LANE="local"
CONTRACT_YAML="$REPO_ROOT/docs/runtime-proof/enterprise-mfe-runtime-config-contract.v1.yaml"

pass() { echo -e "${GREEN}[PASS]${NC} $1"; PASS=$((PASS + 1)); }
fail() { echo -e "${RED}[FAIL]${NC} $1"; FAIL=$((FAIL + 1)); }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; WARN=$((WARN + 1)); }
indet() { echo -e "${YELLOW}[INDETERMINATE]${NC} $1"; INDET=$((INDET + 1)); }

usage() {
  cat <<EOF
Usage: $0 [--lane local|dev|staging|prod]
EOF
  exit 0
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lane) LANE="$2"; shift 2 ;;
    -h|--help) usage ;;
    *) echo "Unknown argument: $1" >&2; usage ;;
  esac
done

if [[ ! "$LANE" =~ ^(local|dev|staging|prod)$ ]]; then
  echo "Invalid --lane: $LANE (expected local|dev|staging|prod)" >&2
  exit 1
fi

ENTERPRISE_MFE_DIR="$REPO_ROOT/deploy/k8s/base/apps/enterprise/mfe"
MFE_ENV_JS="$ENTERPRISE_MFE_DIR/enterprise-mfe-env.js"
ADMIN_DEPLOY="$ENTERPRISE_MFE_DIR/admin-portal-deployment.yaml"
LEARNER_DEPLOY="$ENTERPRISE_MFE_DIR/learner-portal-deployment.yaml"
KUSTOMIZATION="$ENTERPRISE_MFE_DIR/kustomization.yaml"
BRAND_HTML="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/header/brand.html"
MFE_SCSS="$REPO_ROOT/infrastructure/tutor/themes/mereka/mfe/mereka.scss"

MEREKA_REGISTRY="ghcr.io/biji-biji-initiative/mereka-lms/"
contract_lane_result() {
  local klass="$1"
  python3 - "$CONTRACT_YAML" "$klass" "$LANE" <<'PY'
import sys, yaml
path, klass, lane = sys.argv[1:]
with open(path) as f:
    data = yaml.safe_load(f)
print(data["config_classes"][klass]["repo_only_result_by_lane"][lane])
PY
}

shell_bootstrap_repo_result="$(contract_lane_result shell_bootstrap)"
branding_repo_result="$(contract_lane_result branding_runtime_visible)"
lane_authoritative_env_available=false
if [[ "$LANE" == "local" ]]; then
  lane_authoritative_env_available=true
fi

echo "=== Enterprise UI Review Gate (AC-ENTUI-001..AC-ENTUI-007) ==="
echo "lane=$LANE"
echo ""

# ---------------------------------------------------------------------------
# AC-ENTUI-001: MFE env config references correct LMS/Studio URLs
# ---------------------------------------------------------------------------
echo "[AC-ENTUI-001] Verifying enterprise MFE env config URLs..."
if [[ ! -f "$MFE_ENV_JS" ]]; then
  fail "AC-ENTUI-001: enterprise-mfe-env.js not found at $MFE_ENV_JS"
elif [[ "$lane_authoritative_env_available" != "true" ]]; then
  indet "AC-ENTUI-001: authoritative ${LANE} env.config.js is infra-owned; repo-only result=${shell_bootstrap_repo_result}. Refusing to treat base defaults as lane truth."
else
  LMS_URL_LINE=$(grep "LMS_BASE_URL" "$MFE_ENV_JS" || echo "")
  STUDIO_URL_LINE=$(grep "STUDIO_BASE_URL" "$MFE_ENV_JS" || echo "")

  if echo "$LMS_URL_LINE" | grep -q "http://localhost"; then
    pass "AC-ENTUI-001: local base default LMS_BASE_URL is environment-neutral localhost"
  else
    fail "AC-ENTUI-001: local base default LMS_BASE_URL is not environment-neutral (got: $LMS_URL_LINE)"
  fi

  if echo "$STUDIO_URL_LINE" | grep -q "http://studio.localhost"; then
    pass "AC-ENTUI-001: local base default STUDIO_BASE_URL is environment-neutral localhost"
  else
    fail "AC-ENTUI-001: local base default STUDIO_BASE_URL is not environment-neutral (got: $STUDIO_URL_LINE)"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC-ENTUI-002: Enterprise MFE deployments use Mereka container registry
# ---------------------------------------------------------------------------
echo "[AC-ENTUI-002] Verifying enterprise MFE deployment image registry..."
for DEPLOY_FILE in "$ADMIN_DEPLOY" "$LEARNER_DEPLOY"; do
  DEPLOY_NAME="$(basename "$DEPLOY_FILE")"
  if [[ ! -f "$DEPLOY_FILE" ]]; then
    fail "AC-ENTUI-002: Deployment manifest not found: $DEPLOY_FILE"
    continue
  fi
  IMAGE_LINE=$(grep "image:" "$DEPLOY_FILE" | head -1 || echo "")
  if echo "$IMAGE_LINE" | grep -q "$MEREKA_REGISTRY"; then
    pass "AC-ENTUI-002: $DEPLOY_NAME uses Mereka registry ($MEREKA_REGISTRY)"
  else
    fail "AC-ENTUI-002: $DEPLOY_NAME image does not use Mereka registry (got: $IMAGE_LINE)"
  fi
done
echo ""

# ---------------------------------------------------------------------------
# AC-ENTUI-003: Enterprise portal Caddy configs exist in kustomization
# ---------------------------------------------------------------------------
echo "[AC-ENTUI-003] Verifying enterprise Caddy configmap entries in kustomization..."
if [[ ! -f "$KUSTOMIZATION" ]]; then
  fail "AC-ENTUI-003: enterprise MFE kustomization.yaml not found"
else
  if grep -q "enterprise-admin-portal-caddy-config" "$KUSTOMIZATION"; then
    pass "AC-ENTUI-003: admin-portal Caddy configmap declared in kustomization"
  else
    fail "AC-ENTUI-003: enterprise-admin-portal-caddy-config missing from kustomization"
  fi

  if grep -q "enterprise-learner-portal-caddy-config" "$KUSTOMIZATION"; then
    pass "AC-ENTUI-003: learner-portal Caddy configmap declared in kustomization"
  else
    fail "AC-ENTUI-003: enterprise-learner-portal-caddy-config missing from kustomization"
  fi

  # Verify the Caddyfile sources are referenced
  if grep -q "Caddyfile=admin-portal-Caddyfile" "$KUSTOMIZATION"; then
    pass "AC-ENTUI-003: admin-portal-Caddyfile source referenced"
  else
    fail "AC-ENTUI-003: admin-portal-Caddyfile source not found in kustomization"
  fi

  if grep -q "Caddyfile=learner-portal-Caddyfile" "$KUSTOMIZATION"; then
    pass "AC-ENTUI-003: learner-portal-Caddyfile source referenced"
  else
    fail "AC-ENTUI-003: learner-portal-Caddyfile source not found in kustomization"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC-ENTUI-004: LMS brand.html enterprise tagline uses site_configuration helper
# ---------------------------------------------------------------------------
echo "[AC-ENTUI-004] Verifying brand.html enterprise tagline uses configuration_helpers..."
if [[ ! -f "$BRAND_HTML" ]]; then
  fail "AC-ENTUI-004: brand.html not found at $BRAND_HTML"
else
  if grep -q "configuration_helpers.get_value" "$BRAND_HTML"; then
    pass "AC-ENTUI-004: brand.html uses configuration_helpers.get_value"
  else
    fail "AC-ENTUI-004: brand.html does not use configuration_helpers.get_value for enterprise tagline"
  fi

  if grep -q "ENTERPRISE_TAGLINE" "$BRAND_HTML"; then
    pass "AC-ENTUI-004: brand.html references ENTERPRISE_TAGLINE via site_configuration"
  else
    fail "AC-ENTUI-004: brand.html missing ENTERPRISE_TAGLINE reference"
  fi

  # Ensure enterprise tagline block is conditional (not always rendered)
  if grep -q "enable_enterprise_sidebar" "$BRAND_HTML"; then
    pass "AC-ENTUI-004: enterprise tagline block is conditional (enable_enterprise_sidebar guard)"
  else
    warn "AC-ENTUI-004: enterprise tagline guard variable not found — check rendering logic"
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# AC-ENTUI-005: No hardcoded brand strings in enterprise K8s manifests
# ---------------------------------------------------------------------------
echo "[AC-ENTUI-005] Checking for hardcoded brand strings in enterprise K8s manifests..."
ENTERPRISE_MANIFEST_DIR="$REPO_ROOT/deploy/k8s/base/apps/enterprise"
HARDCODED_BRANDS=('"Mereka Academy"' '"Biji-Biji"' '"mereka academy"')

HARDCODED_FOUND=false
for BRAND in "${HARDCODED_BRANDS[@]}"; do
  # Search YAML manifests only, not JS config
  HITS=$(grep -r "$BRAND" "$ENTERPRISE_MANIFEST_DIR" --include="*.yaml" --include="*.yml" -l 2>/dev/null || echo "")
  if [[ -n "$HITS" ]]; then
    fail "AC-ENTUI-005: Hardcoded brand string $BRAND found in: $HITS"
    HARDCODED_FOUND=true
  fi
done

if [[ "$HARDCODED_FOUND" == "false" ]]; then
  pass "AC-ENTUI-005: No hardcoded brand strings found in enterprise K8s manifests"
fi
echo ""

# ---------------------------------------------------------------------------
# AC-ENTUI-006: Enterprise MFE env config includes all required auth/session fields
# ---------------------------------------------------------------------------
echo "[AC-ENTUI-006] Verifying required auth fields in enterprise MFE env config..."
REQUIRED_FIELDS=(
  "LMS_BASE_URL"
  "STUDIO_BASE_URL"
  "LOGIN_URL"
  "LOGOUT_URL"
  "REFRESH_ACCESS_TOKEN_ENDPOINT"
  "ACCESS_TOKEN_COOKIE_NAME"
  "CSRF_TOKEN_API_PATH"
)

if [[ ! -f "$MFE_ENV_JS" ]]; then
  fail "AC-ENTUI-006: enterprise-mfe-env.js not found"
else
  for FIELD in "${REQUIRED_FIELDS[@]}"; do
    if grep -q "$FIELD" "$MFE_ENV_JS"; then
      pass "AC-ENTUI-006: Required field present: $FIELD"
    else
      fail "AC-ENTUI-006: Missing required field: $FIELD"
    fi
  done
fi
echo ""

# ---------------------------------------------------------------------------
# AC-ENTUI-007: Copy consistency — no mixed brand names (edX/Open edX) in enterprise configs
# ---------------------------------------------------------------------------
echo "[AC-ENTUI-007] Checking copy consistency — no mixed upstream brand names..."
BANNED_STRINGS=("Open edX" "openedx.org" "edx.org" "edX Inc")

COPY_ISSUES=false

# Check enterprise-mfe-env.js
if [[ -f "$MFE_ENV_JS" ]]; then
  for BANNED in "${BANNED_STRINGS[@]}"; do
    if grep -qi "$BANNED" "$MFE_ENV_JS" 2>/dev/null; then
      fail "AC-ENTUI-007: Banned brand string '$BANNED' found in enterprise-mfe-env.js"
      COPY_ISSUES=true
    fi
  done
fi

# Check brand.html for hardcoded upstream brand strings in customer-facing output
if [[ -f "$BRAND_HTML" ]]; then
  for BANNED in "${BANNED_STRINGS[@]}"; do
    # Exclude comments and import lines
    if grep -v "^#\|^//" "$BRAND_HTML" | grep -qi "$BANNED" 2>/dev/null; then
      fail "AC-ENTUI-007: Banned brand string '$BANNED' found in brand.html"
      COPY_ISSUES=true
    fi
  done
fi

# Check enterprise K8s manifest literals (not comments)
if [[ -d "$ENTERPRISE_MANIFEST_DIR" ]]; then
  for BANNED in "${BANNED_STRINGS[@]}"; do
    HITS=$(grep -rl "$BANNED" "$ENTERPRISE_MANIFEST_DIR" --include="*.yaml" --include="*.yml" 2>/dev/null || echo "")
    if [[ -n "$HITS" ]]; then
      fail "AC-ENTUI-007: Banned brand string '$BANNED' found in K8s manifests: $HITS"
      COPY_ISSUES=true
    fi
  done
fi

if [[ "$COPY_ISSUES" == "false" ]]; then
  pass "AC-ENTUI-007: No mixed upstream brand names found in enterprise configs"
fi

# Advisory: warn if no enterprise-specific SCSS exists (informational)
if ! grep -qi "enterprise" "$MFE_SCSS" 2>/dev/null; then
  warn "AC-ENTUI-007: No enterprise-specific SCSS selectors in mereka.scss (portals inherit Paragon defaults)"
fi

echo ""
echo "[TRUTH-CONTRACT] Verifying lane/result semantics..."
if [[ ! -f "$CONTRACT_YAML" ]]; then
  fail "TRUTH-CONTRACT: Missing contract fixture at $CONTRACT_YAML"
else
  pass "TRUTH-CONTRACT: Contract fixture present at $CONTRACT_YAML"
  if [[ "$LANE" != "local" ]]; then
    indet "TRUTH-CONTRACT: ${LANE} branding/runtime-visible result is ${branding_repo_result}; live /api/mfe_config/v1 and SiteConfiguration truth are not repo-provable."
  fi
fi
echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASS"
echo -e "${YELLOW}WARN:${NC} $WARN"
echo -e "${YELLOW}INDETERMINATE:${NC} $INDET"
echo -e "${RED}FAIL:${NC} $FAIL"
echo ""
if [[ $FAIL -eq 0 && $INDET -eq 0 ]]; then
  echo -e "${GREEN}Enterprise UI review gate PASSED${NC}"
  exit 0
fi
if [[ $FAIL -eq 0 && $INDET -gt 0 ]]; then
  echo -e "${YELLOW}Enterprise UI review gate INDETERMINATE${NC}"
  exit 2
fi
echo -e "${RED}Enterprise UI review gate FAILED ($FAIL failure(s))${NC}"
exit 1
