#!/usr/bin/env bash
# verify-ulmo-parity.sh
#
# Verify that app-owned Ulmo / Indigo contracts remain truthful for dev/staging
# reference overlays without over-claiming lane-realized GitOps parity.
#
# Checks (offline unless --online is passed):
#   - Base image versions reference Tutor v21 / Ulmo images
#   - MFE Dockerfile uses release/ulmo.1 source refs
#   - MFE Dockerfile uses release/ulmo for Atlas translations
#   - Design Tokens pipeline files exist (tokens.css + _tokens.scss)
#   - rke2-nonprod overlay has domain-env patch
#   - rke2-nonprod overlay has ExternalSecrets infisical patch
#   - Reference overlays pin concrete GHCR tags where this repo still carries them
#   - Caddy config routes environment-specific hosts via overlay-injected env vars
#   - config.example.yml documents Tutor version
#
# Usage:
#   ./scripts/qa/verify-ulmo-parity.sh [--online]
#
# Exit codes:
#   0  — no FAIL checks
#   1  — one or more FAIL checks
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

KUSTOMIZATION_BASE="${REPO_ROOT}/deploy/k8s/base/kustomization.yaml"
KUSTOMIZATION_PROD="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"
KUSTOMIZATION_RKE2="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod/kustomization.yaml"
MFE_DOCKERFILE="${REPO_ROOT}/infrastructure/tutor/mfe-build/Dockerfile"
CADDYFILE="${REPO_ROOT}/deploy/k8s/base/apps/caddy/Caddyfile"
MFE_CADDYFILE="${REPO_ROOT}/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
TOKENS_CSS="${REPO_ROOT}/assets/branding/tokens.css"
TOKENS_SCSS="${REPO_ROOT}/infrastructure/tutor/themes/mereka/scss/_tokens.scss"
CONFIG_EXAMPLE="${REPO_ROOT}/infrastructure/tutor/config.example.yml"
DOMAIN_ENV_PATCH="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod/patches/domain-env.yaml"
INFISICAL_PATCH="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod/patches/externalsecrets-infisical.yaml"
LMS_ENV_YML="${REPO_ROOT}/deploy/k8s/base/apps/openedx/config/lms.env.yml"
CMS_ENV_YML="${REPO_ROOT}/deploy/k8s/base/apps/openedx/config/cms.env.yml"
RKE2_LMS_ENV_YML="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod/config/lms.env.yml"
RKE2_CMS_ENV_YML="${REPO_ROOT}/deploy/k8s/overlays/rke2-nonprod/config/cms.env.yml"
CI_WORKFLOW="${REPO_ROOT}/.github/workflows/ci.yml"
NAMESPACE="${NAMESPACE:-mereka-lms}"
LMS_DEPLOYMENT="${REPO_ROOT}/deploy/k8s/base/apps/lms/deployment.yaml"
CMS_DEPLOYMENT="${REPO_ROOT}/deploy/k8s/base/apps/cms/deployment.yaml"
MFE_DEPLOYMENT="${REPO_ROOT}/deploy/k8s/base/apps/mfe/deployment.yaml"
DISCOVERY_DEPLOYMENT="${REPO_ROOT}/deploy/k8s/base/apps/discovery/deployment.yaml"

PASS=0
FAIL=0
SKIP=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
skip() { SKIP=$((SKIP + 1)); echo "  SKIP: $1"; }

# Extract the first newTag for an image name in a kustomization file.
extract_image_tag() {
  local file="$1"
  local image_name="$2"
  awk -v name="$image_name" '
    $1 == "-" && $2 == "name:" && $3 == name { in_block = 1; next }
    in_block && $1 == "newTag:" { print $2; exit }
    in_block && $1 == "-" && $2 == "name:" { in_block = 0 }
  ' "$file"
}

MODE="offline"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --online) MODE="online"; shift ;;
    --offline) MODE="offline"; shift ;;
    -h|--help)
      echo "Usage: $0 [--online|--offline]"
      echo "  Default mode is offline (static checks only)."
      exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

echo "========================================"
echo "Ulmo Dev Parity Verification ($MODE)"
echo "========================================"
echo ""

# ---------------------------------------------------------------------------
# Section 1: Base image versions (Ulmo / 21.x)
# ---------------------------------------------------------------------------
echo "--- Section 1: Base deployment image versions (Ulmo 21.x) ---"

if [[ ! -f "$LMS_DEPLOYMENT" || ! -f "$CMS_DEPLOYMENT" || ! -f "$MFE_DEPLOYMENT" || ! -f "$DISCOVERY_DEPLOYMENT" ]]; then
  fail "One or more split base deployment manifests are missing"
else
  OPENEDX_TAG=$(grep "image: .*overhangio/openedx:" "$LMS_DEPLOYMENT" "$CMS_DEPLOYMENT" 2>/dev/null | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+-.*" | head -1 || true)
  if [[ -z "$OPENEDX_TAG" ]]; then
    fail "Cannot determine openedx image tag from split base deployments"
  elif echo "$OPENEDX_TAG" | grep -qE "^21\."; then
    pass "LMS/CMS base image is Ulmo-era (21.x): $OPENEDX_TAG"
  else
    fail "LMS/CMS base image is NOT Ulmo-era: $OPENEDX_TAG (expected 21.x)"
  fi

  # MFE
  MFE_BASE_TAG=$(grep "image: .*overhangio/openedx-mfe:" "$MFE_DEPLOYMENT" 2>/dev/null | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+-.*" | head -1 || true)
  if [[ -z "$MFE_BASE_TAG" ]]; then
    fail "Cannot determine openedx-mfe image tag from apps/mfe/deployment.yaml"
  elif echo "$MFE_BASE_TAG" | grep -qE "^21\."; then
    pass "MFE base image is Ulmo-era (21.x): $MFE_BASE_TAG"
  else
    fail "MFE base image is NOT Ulmo-era: $MFE_BASE_TAG (expected 21.x)"
  fi

  # Discovery
  DISCOVERY_TAG=$(grep "image: .*overhangio/openedx-discovery:" "$DISCOVERY_DEPLOYMENT" 2>/dev/null | head -1 | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1 || true)
  if echo "$DISCOVERY_TAG" | grep -qE "^21\."; then
    pass "Discovery base image is Ulmo-era (21.x): $DISCOVERY_TAG"
  else
    fail "Discovery base image is NOT Ulmo-era: $DISCOVERY_TAG (expected 21.x)"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 2: Base kustomization — Mereka custom image override
# ---------------------------------------------------------------------------
echo "--- Section 2: Base kustomization custom image override ---"

if [[ ! -f "$KUSTOMIZATION_BASE" ]]; then
  fail "Base kustomization.yaml not found: $KUSTOMIZATION_BASE"
else
  if grep -q "ghcr.io/biji-biji-initiative/mereka-lms/openedx" "$KUSTOMIZATION_BASE"; then
    pass "Base kustomization overrides openedx image to mereka-lms registry"
  else
    fail "Base kustomization does not redirect openedx to mereka-lms registry"
  fi

  MEREKA_TAG=$(grep -A3 "ghcr.io/biji-biji-initiative/mereka-lms/openedx" "$KUSTOMIZATION_BASE" \
    | grep "newTag:" | awk '{print $2}' | head -1 || true)
  if [[ -n "$MEREKA_TAG" && "$MEREKA_TAG" != "latest" && "$MEREKA_TAG" != "nightly" ]]; then
    pass "Base kustomization pins openedx to non-latest tag: $MEREKA_TAG"
  elif [[ "$MEREKA_TAG" == "latest" || "$MEREKA_TAG" == "nightly" ]]; then
    fail "Base kustomization pins openedx to unpinned tag: $MEREKA_TAG"
  else
    skip "Could not read openedx newTag from base kustomization"
  fi

  BASE_APP_VERSION=$(grep -A2 "commonAnnotations:" "$KUSTOMIZATION_BASE" | grep "app.kubernetes.io/version:" | awk '{print $2}' | head -1 || true)
  if [[ "$BASE_APP_VERSION" == "21.0.0" ]]; then
    pass "Base kustomization app.kubernetes.io/version is 21.0.0"
  elif [[ -n "$BASE_APP_VERSION" ]]; then
    fail "Base kustomization app.kubernetes.io/version is stale: $BASE_APP_VERSION (expected 21.0.0)"
  else
    skip "Base kustomization app.kubernetes.io/version annotation not found"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 3: Production overlay — MFE and enterprise MFE tags are pinned
# ---------------------------------------------------------------------------
echo "--- Section 3: Production overlay image tags ---"

if [[ ! -f "$KUSTOMIZATION_PROD" ]]; then
  fail "Production kustomization.yaml not found: $KUSTOMIZATION_PROD"
else
  PROD_MFE_TAG=$(grep -A4 "openedx-mfe" "$KUSTOMIZATION_PROD" | grep "newTag:" | head -1 | awk '{print $2}' || true)
  if [[ -z "$PROD_MFE_TAG" ]]; then
    fail "Production overlay: openedx-mfe newTag not found"
  elif [[ "$PROD_MFE_TAG" == "latest" || "$PROD_MFE_TAG" == "nightly" ]]; then
    fail "Production overlay: MFE tag is not pinned: $PROD_MFE_TAG"
  else
    pass "Production overlay: MFE tag is pinned: $PROD_MFE_TAG"
  fi

  if grep -q "enterprise-admin-portal" "$KUSTOMIZATION_PROD"; then
    ADMIN_TAG=$(grep -A3 "enterprise-admin-portal" "$KUSTOMIZATION_PROD" | grep "newTag:" | head -1 | awk '{print $2}' || true)
    if [[ -n "$ADMIN_TAG" && "$ADMIN_TAG" != "latest" && "$ADMIN_TAG" != "nightly" ]]; then
      pass "Production overlay: enterprise-admin-portal tag pinned: $ADMIN_TAG"
    else
      fail "Production overlay: enterprise-admin-portal tag not pinned or missing"
    fi
  else
    skip "enterprise-admin-portal not in production overlay"
  fi

  if grep -q "enterprise-learner-portal" "$KUSTOMIZATION_PROD"; then
    LEARNER_TAG=$(grep -A3 "enterprise-learner-portal" "$KUSTOMIZATION_PROD" | grep "newTag:" | head -1 | awk '{print $2}' || true)
    if [[ -n "$LEARNER_TAG" && "$LEARNER_TAG" != "latest" && "$LEARNER_TAG" != "nightly" ]]; then
      pass "Production overlay: enterprise-learner-portal tag pinned: $LEARNER_TAG"
    else
      fail "Production overlay: enterprise-learner-portal tag not pinned or missing"
    fi
  else
    skip "enterprise-learner-portal not in production overlay"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 4: rke2-nonprod overlay correctness
# ---------------------------------------------------------------------------
echo "--- Section 4: rke2-nonprod overlay ---"

if [[ ! -f "$KUSTOMIZATION_RKE2" ]]; then
  fail "rke2-nonprod kustomization.yaml not found: $KUSTOMIZATION_RKE2"
else
  pass "rke2-nonprod kustomization.yaml exists"

  # Domain-env patch referenced
  if grep -q "domain-env.yaml" "$KUSTOMIZATION_RKE2"; then
    pass "rke2-nonprod kustomization references domain-env.yaml patch"
  else
    fail "rke2-nonprod kustomization does not reference domain-env.yaml"
  fi

  # ExternalSecrets infisical patch referenced
  if grep -q "externalsecrets-infisical.yaml" "$KUSTOMIZATION_RKE2"; then
    pass "rke2-nonprod kustomization references externalsecrets-infisical.yaml patch"
  else
    fail "rke2-nonprod kustomization does not reference externalsecrets-infisical.yaml"
  fi

  # Caddy rollout strategy truth: Recreate is defined in the base deployment now.
  if grep -q "type: Recreate" "$REPO_ROOT/deploy/k8s/base/apps/caddy/deployment.yaml" 2>/dev/null; then
    pass "base Caddy deployment uses Recreate strategy for RWO safety"
  else
    fail "base Caddy deployment missing Recreate strategy"
  fi

  # Reference overlay should carry explicit non-placeholder pins even though
  # final lane-realized dev/staging tags are infra-owned in bbi-infrastructure.
  if grep -q "images:" "$KUSTOMIZATION_RKE2"; then
    pass "rke2-nonprod reference overlay has images: block"
  else
    fail "rke2-nonprod reference overlay has no images: block"
  fi

  PROD_MFE_CANONICAL_TAG=$(extract_image_tag "$KUSTOMIZATION_PROD" "docker.io/overhangio/openedx-mfe")
  PROD_MFE_TRANSFORMED_TAG=$(extract_image_tag "$KUSTOMIZATION_PROD" "ghcr.io/biji-biji-initiative/mereka-lms/mfe")
  RKE2_MFE_CANONICAL_TAG=$(extract_image_tag "$KUSTOMIZATION_RKE2" "docker.io/overhangio/openedx-mfe")
  RKE2_MFE_TRANSFORMED_TAG=$(extract_image_tag "$KUSTOMIZATION_RKE2" "ghcr.io/biji-biji-initiative/mereka-lms/mfe")

  if [[ -n "$RKE2_MFE_CANONICAL_TAG" && -n "$RKE2_MFE_TRANSFORMED_TAG" ]]; then
    pass "rke2-nonprod pins both canonical and transformed openedx-mfe image names"
  else
    fail "rke2-nonprod must pin both canonical and transformed openedx-mfe image names"
  fi

  if [[ -n "$RKE2_MFE_CANONICAL_TAG" && "$RKE2_MFE_CANONICAL_TAG" != "latest" && "$RKE2_MFE_CANONICAL_TAG" != "pin-required" ]]; then
    pass "rke2-nonprod canonical openedx-mfe tag is concretely pinned: $RKE2_MFE_CANONICAL_TAG"
  else
    fail "rke2-nonprod canonical openedx-mfe tag is missing or unpinned: $RKE2_MFE_CANONICAL_TAG"
  fi

  if [[ -n "$RKE2_MFE_TRANSFORMED_TAG" && "$RKE2_MFE_TRANSFORMED_TAG" != "latest" && "$RKE2_MFE_TRANSFORMED_TAG" != "pin-required" ]]; then
    pass "rke2-nonprod transformed openedx-mfe tag is concretely pinned: $RKE2_MFE_TRANSFORMED_TAG"
  else
    fail "rke2-nonprod transformed openedx-mfe tag is missing or unpinned: $RKE2_MFE_TRANSFORMED_TAG"
  fi

  if [[ -n "$RKE2_MFE_CANONICAL_TAG" && -n "$RKE2_MFE_TRANSFORMED_TAG" && "$RKE2_MFE_CANONICAL_TAG" == "$RKE2_MFE_TRANSFORMED_TAG" ]]; then
    pass "rke2-nonprod canonical and transformed openedx-mfe tags are internally aligned"
  else
    fail "rke2-nonprod canonical/transformed openedx-mfe tags diverge"
  fi

  PROD_ENTERPRISE_ADMIN_TAG=$(extract_image_tag "$KUSTOMIZATION_PROD" "ghcr.io/biji-biji-initiative/mereka-lms/enterprise-admin-portal")
  PROD_ENTERPRISE_LEARNER_TAG=$(extract_image_tag "$KUSTOMIZATION_PROD" "ghcr.io/biji-biji-initiative/mereka-lms/enterprise-learner-portal")
  RKE2_ENTERPRISE_ADMIN_TAG=$(extract_image_tag "$KUSTOMIZATION_RKE2" "ghcr.io/biji-biji-initiative/mereka-lms/enterprise-admin-portal")
  RKE2_ENTERPRISE_LEARNER_TAG=$(extract_image_tag "$KUSTOMIZATION_RKE2" "ghcr.io/biji-biji-initiative/mereka-lms/enterprise-learner-portal")

  if [[ -n "$RKE2_ENTERPRISE_ADMIN_TAG" && "$RKE2_ENTERPRISE_ADMIN_TAG" != "latest" && "$RKE2_ENTERPRISE_ADMIN_TAG" != "pin-required" ]]; then
    pass "rke2-nonprod enterprise-admin-portal tag is concretely pinned: $RKE2_ENTERPRISE_ADMIN_TAG"
  else
    fail "rke2-nonprod enterprise-admin-portal tag is missing or unpinned: $RKE2_ENTERPRISE_ADMIN_TAG"
  fi

  if [[ -n "$RKE2_ENTERPRISE_LEARNER_TAG" && "$RKE2_ENTERPRISE_LEARNER_TAG" != "latest" && "$RKE2_ENTERPRISE_LEARNER_TAG" != "pin-required" ]]; then
    pass "rke2-nonprod enterprise-learner-portal tag is concretely pinned: $RKE2_ENTERPRISE_LEARNER_TAG"
  else
    fail "rke2-nonprod enterprise-learner-portal tag is missing or unpinned: $RKE2_ENTERPRISE_LEARNER_TAG"
  fi

  if [[ -n "$PROD_MFE_CANONICAL_TAG" && -n "$RKE2_MFE_CANONICAL_TAG" && "$RKE2_MFE_CANONICAL_TAG" != "$PROD_MFE_CANONICAL_TAG" ]]; then
    skip "Production vs rke2 MFE tag drift observed (prod=$PROD_MFE_CANONICAL_TAG, ref-rke2=$RKE2_MFE_CANONICAL_TAG); final lane parity is infra-owned"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 5: Domain-env patch content
# ---------------------------------------------------------------------------
echo "--- Section 5: domain-env.yaml patch content ---"

if [[ ! -f "$DOMAIN_ENV_PATCH" ]]; then
  fail "domain-env.yaml patch not found: $DOMAIN_ENV_PATCH"
else
  if grep -q "academyv2.mereka.dev" "$DOMAIN_ENV_PATCH"; then
    pass "domain-env.yaml references academyv2.mereka.dev"
  else
    fail "domain-env.yaml does not reference academyv2.mereka.dev"
  fi

  if grep -q "LMS_BASE_URL" "$DOMAIN_ENV_PATCH"; then
    pass "domain-env.yaml patches LMS_BASE_URL"
  else
    fail "domain-env.yaml does not patch LMS_BASE_URL"
  fi

  if grep -q "MFE_BASE_URL" "$DOMAIN_ENV_PATCH"; then
    pass "domain-env.yaml patches MFE_BASE_URL"
  else
    fail "domain-env.yaml does not patch MFE_BASE_URL"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 6: openedx-config env override for rke2-nonprod (Gap 1)
# ---------------------------------------------------------------------------
echo "--- Section 6: openedx-config domain override for rke2-nonprod (Gap 1) ---"

if [[ ! -f "$LMS_ENV_YML" ]]; then
  skip "Base lms.env.yml not found — cannot validate openedx-config override"
else
  if grep -q "academyv2.mereka.io" "$LMS_ENV_YML"; then
    pass "Base lms.env.yml is production-scoped (expected); overlay must provide rke2-nonprod override"
  else
    skip "Base lms.env.yml does not contain academyv2.mereka.io; checking overlay override anyway"
  fi

  if [[ ! -f "$RKE2_LMS_ENV_YML" || ! -f "$RKE2_CMS_ENV_YML" ]]; then
    fail "rke2-nonprod openedx-config override files missing (expected: overlays/rke2-nonprod/config/{lms,cms}.env.yml)"
  else
    pass "rke2-nonprod openedx-config override files exist"
  fi

  if grep -A4 "name: openedx-config" "$KUSTOMIZATION_RKE2" | grep -q "behavior: merge"; then
    pass "rke2-nonprod kustomization merges openedx-config via configMapGenerator"
  else
    fail "rke2-nonprod kustomization missing openedx-config merge behavior"
  fi

  if grep -q "config/lms.env.yml" "$KUSTOMIZATION_RKE2" && grep -q "config/cms.env.yml" "$KUSTOMIZATION_RKE2"; then
    pass "rke2-nonprod kustomization references overlay lms/cms env config files"
  else
    fail "rke2-nonprod kustomization does not reference overlay lms/cms env config files"
  fi

  if [[ -f "$RKE2_LMS_ENV_YML" ]]; then
    if grep -q "academyv2.mereka.dev" "$RKE2_LMS_ENV_YML"; then
      pass "rke2 lms.env.yml targets academyv2.mereka.dev"
    else
      fail "rke2 lms.env.yml does not target academyv2.mereka.dev"
    fi
    if grep -q 'SESSION_COOKIE_DOMAIN: ".academyv2.mereka.dev"' "$RKE2_LMS_ENV_YML"; then
      pass "rke2 lms.env.yml sets SESSION_COOKIE_DOMAIN=.academyv2.mereka.dev"
    else
      fail "rke2 lms.env.yml has incorrect SESSION_COOKIE_DOMAIN"
    fi
    if grep -q 'OAUTH_OIDC_ISSUER: "https://academyv2.mereka.dev/oauth2"' "$RKE2_LMS_ENV_YML"; then
      pass "rke2 lms.env.yml sets OAUTH_OIDC_ISSUER to .dev domain"
    else
      fail "rke2 lms.env.yml has incorrect OAUTH_OIDC_ISSUER"
    fi
  fi

  if [[ -f "$RKE2_CMS_ENV_YML" ]]; then
    if grep -q "studio.academyv2.mereka.dev" "$RKE2_CMS_ENV_YML"; then
      pass "rke2 cms.env.yml targets studio.academyv2.mereka.dev"
    else
      fail "rke2 cms.env.yml does not target studio.academyv2.mereka.dev"
    fi
  fi

  if [[ -f "$CMS_ENV_YML" ]]; then
    if grep -q 'SESSION_COOKIE_DOMAIN: ".academyv2.mereka.io"' "$CMS_ENV_YML"; then
      pass "Base cms.env.yml remains production-scoped; overlay handles nonprod override"
    else
      skip "Base cms.env.yml is not production-scoped; overlay validation still enforced"
    fi
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 7: MFE Dockerfile — Ulmo source refs
# ---------------------------------------------------------------------------
echo "--- Section 7: MFE Dockerfile Ulmo source refs ---"

if [[ ! -f "$MFE_DOCKERFILE" ]]; then
  fail "MFE Dockerfile not found: $MFE_DOCKERFILE"
else
  pass "MFE Dockerfile exists"

  ULMO_REFS=$(grep -c "frontend-app.*\.git#release/ulmo" "$MFE_DOCKERFILE" || true)
  if [[ "$ULMO_REFS" -ge 11 ]]; then
    pass "MFE Dockerfile: $ULMO_REFS ulmo.1 source refs (expected >=11)"
  elif [[ "$ULMO_REFS" -ge 1 ]]; then
    fail "MFE Dockerfile: only $ULMO_REFS ulmo source refs (expected >=11)"
  else
    fail "MFE Dockerfile: no release/ulmo refs found"
  fi

  REDWOOD_REFS=$(grep -c "frontend-app.*open-release/redwood" "$MFE_DOCKERFILE" || true)
  if [[ "$REDWOOD_REFS" -eq 0 ]]; then
    pass "MFE Dockerfile: no stale redwood source refs"
  else
    fail "MFE Dockerfile: $REDWOOD_REFS stale redwood source ref(s) present"
  fi

  ATLAS_OPEN_ULMO=$(grep -c "revision=open-release/ulmo" "$MFE_DOCKERFILE" || true)
  if [[ "$ATLAS_OPEN_ULMO" -eq 0 ]]; then
    pass "MFE Dockerfile: no legacy open-release/ulmo atlas translation refs"
  else
    fail "MFE Dockerfile: $ATLAS_OPEN_ULMO legacy open-release/ulmo atlas translation ref(s) present"
  fi

  ATLAS_ULMO=$(grep -cE "revision=release/ulmo(\\.1)?" "$MFE_DOCKERFILE" || true)
  if [[ "$ATLAS_ULMO" -ge 11 ]]; then
    pass "MFE Dockerfile: $ATLAS_ULMO Atlas translation pulls use release/ulmo"
  elif [[ "$ATLAS_ULMO" -ge 1 ]]; then
    fail "MFE Dockerfile: only $ATLAS_ULMO Atlas ulmo refs (expected >=11)"
  else
    fail "MFE Dockerfile: no release/ulmo Atlas translation refs"
  fi

  NODE_BASE=$(grep -E "^FROM (docker\.io/)?node:" "$MFE_DOCKERFILE" | head -1 || true)
  if echo "$NODE_BASE" | grep -qE "node:(18|20|22|24)"; then
    pass "MFE Dockerfile base image uses Node 18+: $NODE_BASE"
  elif [[ -n "$NODE_BASE" ]]; then
    fail "MFE Dockerfile base image may be pre-Node 18: $NODE_BASE"
  else
    skip "Cannot determine Node version from MFE Dockerfile"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 8: Design Tokens pipeline
# ---------------------------------------------------------------------------
echo "--- Section 8: Design Tokens pipeline ---"

if [[ -f "$TOKENS_CSS" ]]; then
  pass "tokens.css exists: $TOKENS_CSS"
else
  fail "tokens.css missing: $TOKENS_CSS (canonical design token source)"
fi

if [[ -f "$TOKENS_SCSS" ]]; then
  pass "_tokens.scss exists: $TOKENS_SCSS"
else
  fail "_tokens.scss missing: $TOKENS_SCSS (generated SCSS bridge for Mereka theme)"
fi

if [[ -f "$TOKENS_CSS" && -f "$TOKENS_SCSS" ]]; then
  # Spot-check: _tokens.scss should contain GENERATED comment
  if grep -q "BEGIN GENERATED" "$TOKENS_SCSS"; then
    pass "_tokens.scss contains GENERATED marker (generated file, not hand-edited)"
  else
    skip "_tokens.scss: GENERATED marker not found — may be hand-maintained"
  fi

  # Spot-check: at least one color variable from tokens.css should appear in _tokens.scss
  # tokens.css uses custom property syntax (--...), _tokens.scss translates to SCSS ($...)
  TOKEN_COUNT=$(grep -c "^\\\$color-" "$TOKENS_SCSS" || true)
  if [[ "$TOKEN_COUNT" -ge 5 ]]; then
    pass "_tokens.scss: $TOKEN_COUNT color token variables found"
  else
    fail "_tokens.scss: fewer than 5 color token variables found ($TOKEN_COUNT) — may be out of sync"
  fi
fi

if [[ -f "$CI_WORKFLOW" ]]; then
  if grep -q "design-token-validation" "$CI_WORKFLOW"; then
    pass "CI workflow defines design-token-validation job"
  else
    fail "CI workflow missing design-token-validation job"
  fi

  if grep -q "generate-tokens-from-canonical.sh --check" "$CI_WORKFLOW"; then
    pass "CI workflow enforces generate-tokens-from-canonical.sh --check"
  else
    fail "CI workflow missing generate-tokens-from-canonical.sh --check gate"
  fi
else
  skip "CI workflow file not found: $CI_WORKFLOW"
fi

echo ""

# ---------------------------------------------------------------------------
# Section 9: Caddy config hosts for mereka.dev
# ---------------------------------------------------------------------------
echo "--- Section 9: Caddy config uses env-driven host routing ---"

if [[ ! -f "$CADDYFILE" ]]; then
  fail "Caddyfile not found: $CADDYFILE"
else
  if grep -q 'http://{$LMS_HOST}' "$CADDYFILE"; then
    pass "Caddyfile routes LMS traffic via \$LMS_HOST"
  else
    fail "Caddyfile missing env-driven LMS host route"
  fi

  if grep -q 'http://{$STUDIO_HOST}' "$CADDYFILE"; then
    pass "Caddyfile routes Studio traffic via \$STUDIO_HOST"
  else
    fail "Caddyfile missing env-driven Studio host route"
  fi

  if grep -q 'http://{$MFE_HOST}' "$CADDYFILE"; then
    pass "Caddyfile routes MFE traffic via \$MFE_HOST"
  else
    fail "Caddyfile missing env-driven MFE host route"
  fi

  if [[ -f "$DOMAIN_ENV_PATCH" ]] && grep -q 'academyv2.mereka.dev' "$DOMAIN_ENV_PATCH"; then
    pass "rke2 domain-env patch injects mereka.dev hostnames into Caddy env vars"
  else
    fail "rke2 domain-env patch does not inject mereka.dev hostnames"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 10: MFE Caddyfile exists
# ---------------------------------------------------------------------------
echo "--- Section 10: MFE internal Caddyfile ---"

if [[ -f "$MFE_CADDYFILE" ]]; then
  pass "MFE Caddyfile exists: $MFE_CADDYFILE"
  if grep -q "8002" "$MFE_CADDYFILE"; then
    pass "MFE Caddyfile listens on port 8002"
  else
    fail "MFE Caddyfile does not reference port 8002"
  fi
else
  fail "MFE Caddyfile not found: $MFE_CADDYFILE"
fi

echo ""

# ---------------------------------------------------------------------------
# Section 11: config.example.yml Tutor version reference
# ---------------------------------------------------------------------------
echo "--- Section 11: config.example.yml Tutor version ---"

if [[ ! -f "$CONFIG_EXAMPLE" ]]; then
  skip "config.example.yml not found — skipping"
else
  OPENEDX_VER=$(grep "OPENEDX_COMMON_VERSION" "$CONFIG_EXAMPLE" | head -1 | awk '{print $2}' || true)
  if [[ -z "$OPENEDX_VER" ]]; then
    skip "OPENEDX_COMMON_VERSION not found in config.example.yml"
  elif echo "$OPENEDX_VER" | grep -q "ulmo"; then
    pass "config.example.yml OPENEDX_COMMON_VERSION references ulmo: $OPENEDX_VER"
  elif echo "$OPENEDX_VER" | grep -q "redwood"; then
    fail "config.example.yml OPENEDX_COMMON_VERSION is stale redwood value: $OPENEDX_VER (Gap 7)"
  else
    skip "config.example.yml OPENEDX_COMMON_VERSION: $OPENEDX_VER — cannot determine era"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Section 12: ExternalSecrets infisical patch content
# ---------------------------------------------------------------------------
echo "--- Section 12: ExternalSecrets infisical patch ---"

if [[ ! -f "$INFISICAL_PATCH" ]]; then
  fail "externalsecrets-infisical.yaml not found: $INFISICAL_PATCH"
else
  if grep -q "infisical-secret-store-dev" "$INFISICAL_PATCH"; then
    pass "externalsecrets-infisical.yaml references infisical-secret-store-dev"
  else
    fail "externalsecrets-infisical.yaml does not reference infisical-secret-store-dev"
  fi
fi

echo ""

# ---------------------------------------------------------------------------
# Online checks
# ---------------------------------------------------------------------------
if [[ "$MODE" == "online" ]]; then
  echo "--- Online: live cluster checks (rke2-nonprod) ---"

  KUBE_CONTEXT="${KUBE_CONTEXT:-rke2-nonprod}"

  if ! command -v kubectl &>/dev/null; then
    skip "kubectl not found — all online checks skipped"
  elif ! kubectl --context="$KUBE_CONTEXT" get namespace "$NAMESPACE" &>/dev/null 2>&1; then
    skip "Namespace $NAMESPACE not accessible on context $KUBE_CONTEXT — online checks skipped"
  else
    pass "kubectl accessible, namespace $NAMESPACE found on context $KUBE_CONTEXT"

    # Secret store
    SECRET_STORE_STATUS=$(kubectl --context="$KUBE_CONTEXT" get clustersecretstore infisical-secret-store-dev \
      -o jsonpath='{.status.conditions[0].reason}' 2>/dev/null || echo "")
    if [[ "$SECRET_STORE_STATUS" == "Valid" ]]; then
      pass "infisical-secret-store-dev ClusterSecretStore is Valid"
    elif [[ -n "$SECRET_STORE_STATUS" ]]; then
      fail "infisical-secret-store-dev status: $SECRET_STORE_STATUS (expected Valid)"
    else
      fail "infisical-secret-store-dev ClusterSecretStore not found on rke2-nonprod"
    fi

    # imagePullSecret
    PULL_SECRET=$(kubectl --context="$KUBE_CONTEXT" get secret ghcr-registry \
      -n "$NAMESPACE" -o name 2>/dev/null || echo "")
    if [[ -n "$PULL_SECRET" ]]; then
      pass "ghcr-registry secret exists in namespace $NAMESPACE"
    else
      fail "ghcr-registry secret not found in namespace $NAMESPACE (pods will fail to pull from GHCR)"
    fi

    # LMS pod image
    LMS_POD=$(kubectl --context="$KUBE_CONTEXT" get pods -n "$NAMESPACE" \
      -l "app.kubernetes.io/name=lms" \
      --field-selector=status.phase=Running \
      -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || true)

    if [[ -z "$LMS_POD" ]]; then
      skip "No running LMS pod on rke2-nonprod — image check skipped"
    else
      LMS_IMAGE=$(kubectl --context="$KUBE_CONTEXT" get pod "$LMS_POD" -n "$NAMESPACE" \
        -o jsonpath='{.spec.containers[0].image}' 2>/dev/null || true)
      if echo "$LMS_IMAGE" | grep -q "ghcr.io/biji-biji-initiative/mereka-lms/openedx:"; then
        pass "LMS pod running Mereka-branded image: $LMS_IMAGE"
      else
        fail "LMS pod NOT running Mereka-branded image: $LMS_IMAGE"
      fi
    fi

    # MFE route smoke test
    MFE_HOST="${MFE_HOST:-apps.academyv2.mereka.dev}"
    HTTP_CODE=$(curl -so /dev/null -w '%{http_code}' --max-time 10 \
      "https://${MFE_HOST}/authn/login" 2>/dev/null || echo "")
    if [[ "$HTTP_CODE" == "200" || "$HTTP_CODE" == "304" || "$HTTP_CODE" == "302" || "$HTTP_CODE" == "301" ]]; then
      pass "MFE /authn/login responds HTTP $HTTP_CODE on $MFE_HOST"
    elif [[ -n "$HTTP_CODE" && "$HTTP_CODE" != "000" ]]; then
      fail "MFE /authn/login returned HTTP $HTTP_CODE on $MFE_HOST"
    else
      skip "Could not reach $MFE_HOST — check DNS and VPN"
    fi
  fi

  echo ""
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "========================================"
echo "Ulmo Parity ($MODE): $PASS PASS / $FAIL FAIL / $SKIP SKIP"
echo "========================================"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "See docs/status/active/ULMO_DEV_STAGING_PARITY.md for remediation steps."
fi

exit $((FAIL > 0 ? 1 : 0))
