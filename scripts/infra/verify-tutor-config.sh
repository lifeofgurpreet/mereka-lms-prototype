#!/usr/bin/env bash
# @covers AC-TCR-004
# @spec: tutor-configuration-resilience_spec.md
# Verify that all required Tutor patches are present in generated files
# Exit 1 if any check fails, 0 if all pass
#
# Usage: ./scripts/infra/verify-tutor-config.sh

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get repository root
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUTOR_ENV="${TUTOR_ROOT:-${REPO_ROOT}/tutor_env}"

# Track failures
FAILURES=()
WARNINGS=()

# Print section header
print_section() {
  echo -e "\n${BLUE}=== $1 ===${NC}"
}

# Print check result
check_pass() {
  echo -e "${GREEN}✓${NC} $1"
}

check_fail() {
  echo -e "${RED}✗${NC} $1"
  FAILURES+=("$1")
}

check_warn() {
  echo -e "${YELLOW}⚠${NC} $1"
  WARNINGS+=("$1")
}

# Check if file exists
file_exists() {
  local file="$1"
  local description="$2"
  if [[ -f "$file" ]]; then
    check_pass "$description exists: $file"
    return 0
  else
    check_fail "$description missing: $file"
    return 1
  fi
}

# Check if pattern exists in file
pattern_in_file() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if [[ ! -f "$file" ]]; then
    check_fail "$description - file not found: $file"
    return 1
  fi

  if grep -qF "$pattern" "$file" 2>/dev/null; then
    check_pass "$description"
    return 0
  else
    check_fail "$description - pattern not found in $file"
    return 1
  fi
}

# Check if regex pattern exists in file
regex_in_file() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if [[ ! -f "$file" ]]; then
    check_fail "$description - file not found: $file"
    return 1
  fi

  if grep -qE "$pattern" "$file" 2>/dev/null; then
    check_pass "$description"
    return 0
  else
    check_fail "$description - pattern not found in $file"
    return 1
  fi
}

print_section "Checking Tutor Environment Structure"

if [[ ! -d "$TUTOR_ENV" ]]; then
  echo -e "${RED}ERROR: Tutor environment not found at $TUTOR_ENV${NC}"
  echo "Run 'tutor config save' first to initialize the environment."
  exit 1
fi

file_exists "$TUTOR_ENV/config.yml" "Tutor config file"
file_exists "$TUTOR_ENV/env/apps/caddy/Caddyfile" "Caddy config"
# Nginx was replaced by Caddy in Tutor v21 — check only if present
if [[ -d "$TUTOR_ENV/env/apps/nginx" ]]; then
  file_exists "$TUTOR_ENV/env/apps/nginx/lms.conf" "Nginx LMS config"
fi
file_exists "$TUTOR_ENV/env/apps/openedx/settings/lms/production.py" "LMS production settings"
file_exists "$TUTOR_ENV/env/build/openedx/Dockerfile" "OpenEdX Dockerfile"

print_section "Checking Multi-Site Domain Configuration"

# Check ALLOWED_HOSTS in LMS settings
LMS_SETTINGS="$TUTOR_ENV/env/apps/openedx/settings/lms/production.py"
if [[ -f "$LMS_SETTINGS" ]]; then
  pattern_in_file "academy.biji-biji.com" "$LMS_SETTINGS" "Biji-Biji domain in ALLOWED_HOSTS"
  pattern_in_file "skillourfuture.academy.mereka.io" "$LMS_SETTINGS" "SkillOurFuture domain in ALLOWED_HOSTS"
else
  check_fail "LMS settings file not found"
fi

# Check CSRF_TRUSTED_ORIGINS
pattern_in_file "https://academy.biji-biji.com" "$LMS_SETTINGS" "Biji-Biji domain in CSRF_TRUSTED_ORIGINS"
pattern_in_file "https://skillourfuture.academy.mereka.io" "$LMS_SETTINGS" "SkillOurFuture domain in CSRF_TRUSTED_ORIGINS"

# Check Caddyfile for extra domains
CADDYFILE="$TUTOR_ENV/env/apps/caddy/Caddyfile"
if [[ -f "$CADDYFILE" ]]; then
  pattern_in_file "academy.biji-biji.com" "$CADDYFILE" "Biji-Biji domain in Caddyfile"
  pattern_in_file "skillourfuture.academy.mereka.io" "$CADDYFILE" "SkillOurFuture domain in Caddyfile"
fi

# Check nginx for extra domains
NGINX_CONF="$TUTOR_ENV/env/apps/nginx/lms.conf"
if [[ -f "$NGINX_CONF" ]]; then
  pattern_in_file "academy.biji-biji.com" "$NGINX_CONF" "Biji-Biji domain in nginx"
  pattern_in_file "skillourfuture.academy.mereka.io" "$NGINX_CONF" "SkillOurFuture domain in nginx"
fi

print_section "Checking MySQL Authentication Fix"

DOCKER_COMPOSE="$TUTOR_ENV/env/local/docker-compose.yml"
if [[ -f "$DOCKER_COMPOSE" ]]; then
  pattern_in_file "default-authentication-plugin=mysql_native_password" "$DOCKER_COMPOSE" "MySQL native password plugin"
  pattern_in_file "MYSQL_ROOT_HOST" "$DOCKER_COMPOSE" "MySQL remote root access"
else
  check_warn "Docker Compose file not found (ok if using K8s only)"
fi

print_section "Checking MFE Configuration"

MFE_DOCKERFILE="$TUTOR_ENV/env/plugins/mfe/build/mfe/Dockerfile"
if [[ -f "$MFE_DOCKERFILE" ]]; then
  pattern_in_file "docker.io/node:24.11.0-bullseye-slim" "$MFE_DOCKERFILE" "MFE Node 24 base image"
  regex_in_file "gcc g\+\+ git" "$MFE_DOCKERFILE" "MFE build toolchain (g++)"
  pattern_in_file "python3" "$MFE_DOCKERFILE" "MFE Python 3 dependency"
  pattern_in_file "SESSION_COOKIE_DOMAIN" "$MFE_DOCKERFILE" "MFE cookie domain config"
  pattern_in_file "CSRF_COOKIE_DOMAIN" "$MFE_DOCKERFILE" "MFE CSRF cookie config"
else
  check_warn "MFE Dockerfile not found (ok if MFE plugin not installed)"
fi

# Check MFE theme integration
MFE_ENV_CONFIG="$TUTOR_ENV/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
if [[ -f "$MFE_ENV_CONFIG" ]]; then
  pattern_in_file "mereka/mereka.scss" "$MFE_ENV_CONFIG" "MFE custom theme import"
  pattern_in_file "const MerekaFooter" "$MFE_ENV_CONFIG" "Custom Mereka footer component"
  pattern_in_file "<MerekaFooter />" "$MFE_ENV_CONFIG" "Mereka footer rendered"
else
  check_warn "MFE env.config.jsx not found (ok if MFE plugin not installed)"
fi

print_section "Checking Forum Configuration (MongoDB Atlas)"

if [[ -f "$LMS_SETTINGS" ]]; then
  # Forum v2 is integrated into LMS in Tutor v19+, check for discussion service
  regex_in_file 'FEATURES\["ENABLE_DISCUSSION_SERVICE"\]' "$LMS_SETTINGS" "Discussion service enabled"
  # Check for MFE discussions config
  pattern_in_file "DISCUSSIONS_MFE_ENABLED" "$LMS_SETTINGS" "MFE discussions enabled"
  pattern_in_file "ENABLE_DISCUSSION_HOME_PANEL" "$LMS_SETTINGS" "Legacy discussion panel disabled"
fi

# MongoDB connection is in config.yml, check for Atlas SRV format
if [[ -f "$TUTOR_ENV/config.yml" ]]; then
  if grep -q "mongodb+srv://" "$TUTOR_ENV/config.yml" 2>/dev/null; then
    check_pass "MongoDB Atlas SRV connection string"
  elif grep -q "mongodb.mereka-lms.svc.cluster.local" "$TUTOR_ENV/config.yml" 2>/dev/null; then
    check_warn "Local MongoDB reference found (should be Atlas SRV for production)"
  fi
fi

print_section "Checking Custom Apps Integration"

OPENEDX_DOCKERFILE="$TUTOR_ENV/env/build/openedx/Dockerfile"
if [[ -f "$OPENEDX_DOCKERFILE" ]]; then
  pattern_in_file "mfe_oauth_fix" "$OPENEDX_DOCKERFILE" "MFE OAuth fix app copied"
  pattern_in_file "openedx_prometheus" "$OPENEDX_DOCKERFILE" "Prometheus metrics app copied"
  pattern_in_file "pip install -e /openedx/mfe_oauth_fix" "$OPENEDX_DOCKERFILE" "MFE OAuth fix installed"
  pattern_in_file "pip install -e /openedx/openedx_prometheus" "$OPENEDX_DOCKERFILE" "Prometheus metrics installed"
  pattern_in_file "django-prometheus" "$OPENEDX_DOCKERFILE" "django-prometheus installed"
  regex_in_file 'pymongo\[srv\]|dnspython' "$OPENEDX_DOCKERFILE" "pymongo[srv] installed (for Atlas)"
fi

if [[ -f "$LMS_SETTINGS" ]]; then
  pattern_in_file "mfe_oauth_fix" "$LMS_SETTINGS" "MFE OAuth fix in INSTALLED_APPS"
  pattern_in_file "openedx_prometheus" "$LMS_SETTINGS" "Prometheus metrics in INSTALLED_APPS"
  pattern_in_file "django_prometheus" "$LMS_SETTINGS" "django_prometheus in INSTALLED_APPS"
  pattern_in_file "PrometheusBeforeMiddleware" "$LMS_SETTINGS" "Prometheus middleware (before)"
  pattern_in_file "PrometheusAfterMiddleware" "$LMS_SETTINGS" "Prometheus middleware (after)"
fi

print_section "Checking Build Optimizations"

if [[ -f "$OPENEDX_DOCKERFILE" ]]; then
  pattern_in_file "ENV NODE_OPTIONS=\"--max-old-space-size=6144\"" "$OPENEDX_DOCKERFILE" "Node memory limit increased"
  pattern_in_file "ENV PYTHONPATH=/openedx/edx-platform" "$OPENEDX_DOCKERFILE" "PYTHONPATH set"

  # Check for npm/pip install resilience strategy.
  # Upstream patches evolved over time from explicit retry loops to
  # direct install commands in recent Tutor/Open edX branches.
  if grep -qE "for attempt in 1 2 3.*npm clean-install" "$OPENEDX_DOCKERFILE" 2>/dev/null; then
    check_pass "Resilient npm install with retries"
  elif grep -qE "npm clean-install --no-audit --registry=" "$OPENEDX_DOCKERFILE" 2>/dev/null; then
    check_pass "Resilient npm install command (single-run)"
  else
    check_fail "NPM install command with lockfile tolerance not found in $OPENEDX_DOCKERFILE"
  fi

  if grep -qE "for attempt in 1 2 3.*pip install" "$OPENEDX_DOCKERFILE" 2>/dev/null; then
    check_pass "Resilient pip install with retries"
  elif grep -qE "pip install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt -r /openedx/edx-platform/requirements/edx/assets.txt" "$OPENEDX_DOCKERFILE" 2>/dev/null; then
    check_pass "Fallback pip install command"
  else
    check_fail "Python requirements install command with lockfile handling not found in $OPENEDX_DOCKERFILE"
  fi
fi

# Check webpack config for optimization
WEBPACK_CONFIG="$TUTOR_ENV/env/build/openedx/edx-platform/webpack.prod.config.js"
if [[ -f "$WEBPACK_CONFIG" ]]; then
  regex_in_file "TerserPlugin.*parallel.*false" "$WEBPACK_CONFIG" "Webpack Terser plugin parallelism disabled (memory)"
else
  check_warn "Webpack config not found (ok if not built yet)"
fi

print_section "Checking Asset Build Fixes"

# Check for collectstatic SuspiciousFileOperation fix
LMS_ASSETS="$TUTOR_ENV/env/build/openedx/settings/lms/assets.py"
if [[ -f "$LMS_ASSETS" ]]; then
  pattern_in_file "_build_safe_join" "$LMS_ASSETS" "LMS collectstatic safe_join patch"
fi

CMS_ASSETS="$TUTOR_ENV/env/build/openedx/settings/cms/assets.py"
if [[ -f "$CMS_ASSETS" ]]; then
  pattern_in_file "_build_safe_join" "$CMS_ASSETS" "CMS collectstatic safe_join patch"
fi

# Check for theme asset compilation
if [[ -f "$OPENEDX_DOCKERFILE" ]]; then
  pattern_in_file "npm run compile-sass -- --skip-default --theme-dir /openedx/themes --theme mereka" "$OPENEDX_DOCKERFILE" "Theme SASS compilation"
  pattern_in_file "Stripped google font imports from {changed} scss files" "$OPENEDX_DOCKERFILE" "Google fonts stripping"
fi

print_section "Checking Enterprise Features"

if [[ -f "$LMS_SETTINGS" ]]; then
  # Check for content libraries, bookmarks, discussions apps
  pattern_in_file "content_libraries" "$LMS_SETTINGS" "Content Libraries app enabled"
  pattern_in_file "bookmarks" "$LMS_SETTINGS" "Bookmarks app enabled"
  pattern_in_file "discussions" "$LMS_SETTINGS" "Discussions app enabled"
  pattern_in_file "theming" "$LMS_SETTINGS" "Theming app enabled"
fi

print_section "Checking Health Endpoints"

if [[ -f "$NGINX_CONF" ]]; then
  pattern_in_file "location = /health" "$NGINX_CONF" "Health check endpoint in nginx"
  pattern_in_file "location = /metrics" "$NGINX_CONF" "Prometheus metrics endpoint in nginx"
fi

if [[ -f "$CADDYFILE" ]]; then
  # Caddy might have different health check config
  if grep -q "/health" "$CADDYFILE" 2>/dev/null; then
    check_pass "Health check endpoint referenced in Caddy"
  else
    check_warn "Health check endpoint not found in Caddy"
  fi
fi

print_section "Checking Theme Assets"

THEME_BUILD_DIR="$TUTOR_ENV/env/build/openedx/themes/mereka"
if [[ -d "$THEME_BUILD_DIR" ]]; then
  check_pass "Theme build directory exists"

  # Check for key logo files
  if [[ -f "$THEME_BUILD_DIR/lms/static/images/logo.png" ]]; then
    check_pass "LMS logo.png"
  else
    check_warn "LMS logo.png not found"
  fi

  if [[ -f "$THEME_BUILD_DIR/lms/static/images/favicon.ico" ]]; then
    check_pass "LMS favicon.ico"
  else
    check_warn "LMS favicon.ico not found"
  fi

  # Check for fonts
  if compgen -G "$THEME_BUILD_DIR/lms/static/fonts/*.woff2" >/dev/null 2>&1; then
    check_pass "LMS font files present"
  else
    check_warn "LMS font files not found"
  fi
else
  check_warn "Theme build directory not found (run apply-patches.sh)"
fi

# Check for MFE theme assets
MFE_THEME_DIR="$TUTOR_ENV/env/plugins/mfe/build/mfe/indigo/mereka"
if [[ -d "$MFE_THEME_DIR" ]]; then
  check_pass "MFE theme directory exists"

  if [[ -f "$MFE_THEME_DIR/mereka.scss" ]]; then
    check_pass "MFE mereka.scss"
  else
    check_warn "MFE mereka.scss not found"
  fi

  if [[ -d "$MFE_THEME_DIR/scss" ]]; then
    check_pass "MFE SCSS directory"
  else
    check_warn "MFE SCSS directory not found"
  fi

  if [[ -d "$MFE_THEME_DIR/fonts" ]]; then
    check_pass "MFE fonts directory"
  else
    check_warn "MFE fonts directory not found"
  fi
else
  check_warn "MFE theme directory not found (ok if MFE plugin not installed)"
fi

# ============================================================================
# Summary
# ============================================================================

echo ""
echo -e "${BLUE}=== Verification Summary ===${NC}"
echo ""

if [[ ${#FAILURES[@]} -eq 0 ]]; then
  echo -e "${GREEN}✓ All required patches verified successfully!${NC}"

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Warnings (${#WARNINGS[@]}):${NC}"
    for warning in "${WARNINGS[@]}"; do
      echo "  - $warning"
    done
  fi

  exit 0
else
  echo -e "${RED}✗ Verification failed with ${#FAILURES[@]} error(s):${NC}"
  echo ""
  for failure in "${FAILURES[@]}"; do
    echo "  - $failure"
  done

  if [[ ${#WARNINGS[@]} -gt 0 ]]; then
    echo ""
    echo -e "${YELLOW}Additionally, ${#WARNINGS[@]} warning(s):${NC}"
    for warning in "${WARNINGS[@]}"; do
      echo "  - $warning"
    done
  fi

  echo ""
  echo -e "${YELLOW}Fix by running:${NC}"
  echo "  ./scripts/infra/prepare-tutor-build-context.sh --target all"
  echo ""

  exit 1
fi
