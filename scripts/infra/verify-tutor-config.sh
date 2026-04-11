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
APPLY_PATCH_SCRIPT="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
MFE_PATCH_MODULE="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/mfe_dockerfile.py"
PLUGIN_SRC_DIR="$REPO_ROOT/infrastructure/tutor/plugins"
PLUGIN_DIR="${TUTOR_PLUGINS_DIR:-$HOME/.local/share/tutor-plugins}"

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

fixed_pattern_count() {
  local pattern="$1"
  local file="$2"

  if [[ ! -f "$file" ]]; then
    echo ""
    return 1
  fi

  python3 - "$pattern" "$file" <<'PY'
from pathlib import Path
import sys

pattern = sys.argv[1]
path = Path(sys.argv[2])
text = path.read_text()
print(text.count(pattern))
PY
}

fixed_pattern_count_equals() {
  local pattern="$1"
  local expected="$2"
  local file="$3"
  local description="$4"

  if [[ ! -f "$file" ]]; then
    check_fail "$description - file not found: $file"
    return 1
  fi

  local count
  count="$(fixed_pattern_count "$pattern" "$file")"
  if [[ "$count" == "$expected" ]]; then
    check_pass "$description"
    return 0
  fi

  check_fail "$description - expected $expected occurrences of '$pattern' in $file, found $count"
  return 1
}

regex_pattern_count() {
  local pattern="$1"
  local file="$2"

  if [[ ! -f "$file" ]]; then
    echo ""
    return 1
  fi

  python3 - "$pattern" "$file" <<'PY'
from pathlib import Path
import re
import sys

pattern = re.compile(sys.argv[1], re.MULTILINE)
path = Path(sys.argv[2])
text = path.read_text()
print(len(pattern.findall(text)))
PY
}

regex_pattern_count_equals() {
  local pattern="$1"
  local expected="$2"
  local file="$3"
  local description="$4"

  if [[ ! -f "$file" ]]; then
    check_fail "$description - file not found: $file"
    return 1
  fi

  local count
  count="$(regex_pattern_count "$pattern" "$file")"
  if [[ "$count" == "$expected" ]]; then
    check_pass "$description"
    return 0
  fi

  check_fail "$description - expected $expected matches for /$pattern/ in $file, found $count"
  return 1
}

pattern_not_in_file() {
  local pattern="$1"
  local file="$2"
  local description="$3"

  if [[ ! -f "$file" ]]; then
    check_fail "$description - file not found: $file"
    return 1
  fi

  if grep -qF "$pattern" "$file" 2>/dev/null; then
    check_fail "$description - unexpected pattern found in $file"
    return 1
  fi

  check_pass "$description"
  return 0
}

files_match() {
  local src="$1"
  local dst="$2"
  local description="$3"

  if [[ ! -f "$src" ]]; then
    check_fail "$description - source not found: $src"
    return 1
  fi
  if [[ ! -f "$dst" ]]; then
    check_fail "$description - mirror not found: $dst"
    return 1
  fi
  if cmp -s "$src" "$dst"; then
    check_pass "$description"
    return 0
  fi

  check_fail "$description - mirror is stale"
  return 1
}

dirs_match() {
  local src="$1"
  local dst="$2"
  local description="$3"

  if [[ ! -d "$src" ]]; then
    check_fail "$description - source dir not found: $src"
    return 1
  fi
  if [[ ! -d "$dst" ]]; then
    check_fail "$description - mirror dir not found: $dst"
    return 1
  fi

  if command -v rsync >/dev/null 2>&1; then
    local drift
    drift="$(rsync -rcn --delete --exclude='__pycache__/' --exclude='*.pyc' --out-format='%n' "$src/" "$dst/" 2>/dev/null || true)"
    if [[ -z "$drift" ]]; then
      check_pass "$description"
      return 0
    fi
  else
    if diff -qr "$src" "$dst" >/dev/null 2>&1; then
      check_pass "$description"
      return 0
    fi
  fi

  check_fail "$description - mirror is stale"
  return 1
}

dir_has_files() {
  local pattern="$1"
  local description="$2"

  if compgen -G "$pattern" >/dev/null 2>&1; then
    check_pass "$description"
  else
    check_warn "$description"
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

print_section "Checking Tutor Plugin Source of Truth"

files_match "$PLUGIN_SRC_DIR/mereka_lms.py" "$PLUGIN_DIR/mereka_lms.py" "Tutor plugin entrypoint mirror is fresh"
files_match "$PLUGIN_SRC_DIR/mereka_lms_mfe_slots.py" "$PLUGIN_DIR/mereka_lms_mfe_slots.py" "Tutor MFE slots module mirror is fresh"
dirs_match "$PLUGIN_SRC_DIR/_mereka_lms" "$PLUGIN_DIR/_mereka_lms" "Tutor _mereka_lms package mirror is fresh"

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

print_section "Checking MFE Build Authority"

MFE_DOCKERFILE="$TUTOR_ENV/env/plugins/mfe/build/mfe/Dockerfile"
MFE_ENV_CONFIG="$TUTOR_ENV/env/plugins/mfe/build/mfe/env.config.jsx"
MFE_INDIGO_ENV_CONFIG="$TUTOR_ENV/env/plugins/mfe/build/mfe/indigo/env.config.jsx"
MFE_THEME_DIR="$TUTOR_ENV/env/plugins/mfe/build/mfe/indigo/mereka"
MFE_BRAND_DIR="$TUTOR_ENV/env/plugins/mfe/build/mfe/indigo/brand-mereka"
if [[ -f "$MFE_DOCKERFILE" ]]; then
  check_pass "Rendered MFE Dockerfile exists: $MFE_DOCKERFILE"
  if [[ -L "$MFE_DOCKERFILE" ]]; then
    check_fail "Rendered MFE Dockerfile must not be a symlink: $MFE_DOCKERFILE -> $(readlink "$MFE_DOCKERFILE")"
  else
    check_pass "Rendered MFE Dockerfile is a regular file"
  fi
else
  check_warn "MFE Dockerfile not found (ok if MFE plugin not installed)"
fi

if [[ -L "$MFE_DOCKERFILE" ]]; then
  check_fail "Rendered MFE Dockerfile must not be a symlink: $MFE_DOCKERFILE -> $(readlink "$MFE_DOCKERFILE")"
elif [[ -f "$MFE_DOCKERFILE" ]]; then
  check_pass "Rendered MFE Dockerfile is a regular file"
fi

if [[ -f "$APPLY_PATCH_SCRIPT" ]]; then
  if grep -q 'mfe-node.sh' "$APPLY_PATCH_SCRIPT" 2>/dev/null; then
    check_fail "apply-patches.sh still references removed mfe-node.sh"
  else
    check_pass "apply-patches.sh does not reference removed mfe-node.sh"
  fi
else
  check_fail "apply-patches.sh missing: $APPLY_PATCH_SCRIPT"
fi

if [[ -f "$MFE_PATCH_MODULE" ]]; then
  pattern_in_file "mfe-dockerfile-pre-npm-install" "$MFE_PATCH_MODULE" "MFE plugin defines pre-npm-install hook"
  pattern_in_file "mfe-dockerfile-post-npm-install" "$MFE_PATCH_MODULE" "MFE plugin defines post-npm-install hook"
  pattern_in_file "@edx/brand@file:./brand-mereka" "$MFE_PATCH_MODULE" "MFE plugin installs local brand package"
  pattern_in_file "frontend-plugin-framework@^1.8.0" "$MFE_PATCH_MODULE" "MFE plugin installs frontend-plugin-framework"
else
  check_fail "MFE Dockerfile patch module missing: $MFE_PATCH_MODULE"
fi

if [[ -f "$MFE_DOCKERFILE" ]]; then
  regex_in_file "(docker.io/)?node:(18|20|24)[-a-z0-9.]*" "$MFE_DOCKERFILE" "Rendered MFE Dockerfile uses supported Node image"
  pattern_in_file "frontend-plugin-framework@^1.8.0" "$MFE_DOCKERFILE" "Rendered MFE Dockerfile contains frontend-plugin-framework install"
  pattern_in_file "@edx/brand@file:./brand-mereka" "$MFE_DOCKERFILE" "Rendered MFE Dockerfile contains local brand package install"
fi
else
  check_fail "apply-patches.sh missing: $APPLY_PATCH_SCRIPT"
fi

if [[ -f "$MFE_PATCH_MODULE" ]]; then
  pattern_in_file "mfe-dockerfile-pre-npm-install" "$MFE_PATCH_MODULE" "MFE plugin defines pre-npm-install hook"
  pattern_in_file "mfe-dockerfile-post-npm-install" "$MFE_PATCH_MODULE" "MFE plugin defines post-npm-install hook"
  pattern_in_file "@edx/brand@file:./brand-mereka" "$MFE_PATCH_MODULE" "MFE plugin installs local brand package"
  pattern_in_file "frontend-plugin-framework@^1.8.0" "$MFE_PATCH_MODULE" "MFE plugin installs frontend-plugin-framework"
else
  check_fail "MFE Dockerfile patch module missing: $MFE_PATCH_MODULE"
fi

if [[ -f "$MFE_DOCKERFILE" ]]; then
  regex_in_file "(docker.io/)?node:(18|20|24)[-a-z0-9.]*" "$MFE_DOCKERFILE" "Rendered MFE Dockerfile uses supported Node image"
  pattern_in_file "frontend-plugin-framework@^1.8.0" "$MFE_DOCKERFILE" "Rendered MFE Dockerfile contains frontend-plugin-framework install"
  pattern_in_file "@edx/brand@file:./brand-mereka" "$MFE_DOCKERFILE" "Rendered MFE Dockerfile contains local brand package install"
fi

if [[ -f "$MFE_ENV_CONFIG" ]]; then
  check_pass "Rendered MFE env.config.jsx exists: $MFE_ENV_CONFIG"
else
  check_warn "Rendered MFE env.config.jsx not found: $MFE_ENV_CONFIG"
fi

if [[ -f "$MFE_INDIGO_ENV_CONFIG" ]]; then
  check_pass "Rendered Indigo env.config.jsx exists: $MFE_INDIGO_ENV_CONFIG"
  pattern_in_file "mereka/mereka.scss" "$MFE_INDIGO_ENV_CONFIG" "MFE custom theme import"
  pattern_in_file "const MerekaFooter" "$MFE_INDIGO_ENV_CONFIG" "Custom Mereka footer component"
  pattern_in_file "RenderWidget: MerekaFooter" "$MFE_INDIGO_ENV_CONFIG" "Mereka footer rendered"
else
  check_warn "Rendered Indigo env.config.jsx not found: $MFE_INDIGO_ENV_CONFIG"
fi

if [[ -d "$MFE_THEME_DIR" ]]; then
  check_pass "Rendered Indigo theme directory exists: $MFE_THEME_DIR"
else
  check_warn "Rendered Indigo theme directory not found: $MFE_THEME_DIR"
fi

if [[ -d "$MFE_BRAND_DIR" ]]; then
  check_pass "Rendered Indigo brand package exists: $MFE_BRAND_DIR"
else
  check_warn "Rendered Indigo brand package not found: $MFE_BRAND_DIR"
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
OPENEDX_NOTIFICATIONS_DIR="$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_notifications"
OPENEDX_NOTIFICATIONS_ACE_CHANNEL="$OPENEDX_NOTIFICATIONS_DIR/ace_channel.py"
OPENEDX_NOTIFICATIONS_MODELS="$OPENEDX_NOTIFICATIONS_DIR/models.py"
OPENEDX_NOTIFICATIONS_MIGRATION="$OPENEDX_NOTIFICATIONS_DIR/migrations/0001_initial.py"
if [[ -f "$OPENEDX_DOCKERFILE" ]]; then
  pattern_in_file "mfe_oauth_fix" "$OPENEDX_DOCKERFILE" "MFE OAuth fix app copied"
  pattern_in_file "openedx_prometheus" "$OPENEDX_DOCKERFILE" "Prometheus metrics app copied"
  pattern_in_file 'RUN $PIP_COMMAND install -e /openedx/mfe_oauth_fix' "$OPENEDX_DOCKERFILE" "MFE OAuth fix installed"
  pattern_in_file 'RUN $PIP_COMMAND install -e /openedx/openedx_prometheus' "$OPENEDX_DOCKERFILE" "Prometheus metrics installed"
  pattern_in_file "django-prometheus" "$OPENEDX_DOCKERFILE" "django-prometheus installed"
  pattern_in_file "django-cors-headers==4.3.1" "$OPENEDX_DOCKERFILE" "django-cors-headers installed"
  fixed_pattern_count_equals "pkgconfig==1.5.5" "1" "$OPENEDX_DOCKERFILE" "pkgconfig toolchain pin is not duplicated"
  pattern_in_file "path==16.16.0" "$OPENEDX_DOCKERFILE" "legacy path provider installed"
  pattern_in_file "defusedxml==0.7.1" "$OPENEDX_DOCKERFILE" "defusedxml installed"
  pattern_in_file "edx-enterprise==6.6.9" "$OPENEDX_DOCKERFILE" "edx-enterprise installed"
  pattern_in_file "lazy==1.6" "$OPENEDX_DOCKERFILE" "lazy installed"
  pattern_in_file "lxml_html_clean==0.4.4" "$OPENEDX_DOCKERFILE" "lxml_html_clean installed"
  regex_in_file 'pymongo\[srv\]|dnspython' "$OPENEDX_DOCKERFILE" "pymongo[srv] installed (for Atlas)"
  fixed_pattern_count_equals "translation settings import preflight ok" "1" "$OPENEDX_DOCKERFILE" "Translation preflight block is not duplicated"
fi

if [[ -f "$LMS_SETTINGS" ]]; then
  pattern_in_file "mfe_oauth_fix" "$LMS_SETTINGS" "MFE OAuth fix in INSTALLED_APPS"
  pattern_in_file "openedx_prometheus" "$LMS_SETTINGS" "Prometheus metrics in INSTALLED_APPS"
  pattern_in_file "django_prometheus" "$LMS_SETTINGS" "django_prometheus in INSTALLED_APPS"
  pattern_in_file "PrometheusBeforeMiddleware" "$LMS_SETTINGS" "Prometheus middleware (before)"
  pattern_in_file "PrometheusAfterMiddleware" "$LMS_SETTINGS" "Prometheus middleware (after)"
  regex_pattern_count_equals "INSTALLED_APPS\\.append\\([\"']mfe_oauth_fix[\"']\\)" "1" "$LMS_SETTINGS" "Exactly one mfe_oauth_fix app registration"
  regex_pattern_count_equals "INSTALLED_APPS\\.append\\([\"']openedx_prometheus[\"']\\)" "1" "$LMS_SETTINGS" "Exactly one openedx_prometheus app registration"
  regex_pattern_count_equals "(_safe_add_app\\([\"']mereka_tenancy[\"']\\)|INSTALLED_APPS\\.append\\([\"']mereka_tenancy[\"']\\))" "1" "$LMS_SETTINGS" "Exactly one mereka_tenancy app registration path"
  regex_pattern_count_equals "(_safe_add_app\\([\"']openedx_notifications[\"']\\)|INSTALLED_APPS\\.append\\([\"']openedx_notifications[\"']\\))" "1" "$LMS_SETTINGS" "Exactly one openedx_notifications app registration path"
  if grep -q 'MFE_CONFIG\["ORDER_HISTORY_URL"\] = ORDER_HISTORY_MICROFRONTEND_URL' "$LMS_SETTINGS" 2>/dev/null \
    || grep -q 'MFE_CONFIG\["ORDER_HISTORY_URL"\].*/orders' "$LMS_SETTINGS" 2>/dev/null; then
    check_pass "MFE ORDER_HISTORY_URL is defined in rendered LMS settings"
  else
    check_fail "MFE ORDER_HISTORY_URL is defined in rendered LMS settings - pattern not found in $LMS_SETTINGS"
  fi
  pattern_in_file 'f"https://{host}" for host in' "$LMS_SETTINGS" "Tenant extra-host CSP tuple is defined"
  pattern_in_file 'f"https://apps.{host}" for host in' "$LMS_SETTINGS" "Tenant extra-host MFE CSP tuple is defined"
  pattern_in_file "academy.biji-biji.com" "$LMS_SETTINGS" "Non-primary tenant hosts are present in rendered LMS settings"
  pattern_in_file "skillourfuture.academy.mereka.io" "$LMS_SETTINGS" "SOF tenant host is present in rendered LMS settings"
fi

if [[ -f "$OPENEDX_NOTIFICATIONS_ACE_CHANNEL" ]]; then
  pattern_in_file 'getattr(ChannelType, "IN_APP", "in_app")' "$OPENEDX_NOTIFICATIONS_ACE_CHANNEL" "openedx_notifications ACE channel uses runtime-safe IN_APP fallback"
  pattern_not_in_file "channel_type = ChannelType.IN_APP" "$OPENEDX_NOTIFICATIONS_ACE_CHANNEL" "No hard dependency on ChannelType.IN_APP enum member"
fi

if [[ -f "$OPENEDX_NOTIFICATIONS_MODELS" ]]; then
  pattern_in_file "related_name='openedx_in_app_notifications'" "$OPENEDX_NOTIFICATIONS_MODELS" "openedx_notifications model uses non-conflicting reverse accessor"
  pattern_not_in_file "related_name='notifications'" "$OPENEDX_NOTIFICATIONS_MODELS" "openedx_notifications model does not reuse upstream notifications reverse accessor"
fi

if [[ -f "$OPENEDX_NOTIFICATIONS_MIGRATION" ]]; then
  pattern_in_file "related_name='openedx_in_app_notifications'" "$OPENEDX_NOTIFICATIONS_MIGRATION" "openedx_notifications migration keeps non-conflicting reverse accessor"
  pattern_not_in_file "related_name='notifications'" "$OPENEDX_NOTIFICATIONS_MIGRATION" "openedx_notifications migration does not reintroduce upstream reverse accessor collision"
fi

CONFIG_DEFAULTS_FILE="$REPO_ROOT/infrastructure/tutor/plugins/_mereka_lms/config_defaults.py"
if [[ -f "$CONFIG_DEFAULTS_FILE" ]]; then
  pattern_in_file "MEREKA_PREVIEW_LMS_BASE" "$CONFIG_DEFAULTS_FILE" "Mereka Tutor config defaults define preview LMS base contract"
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
  elif grep -qE "npm install --no-audit --package-lock=false --registry=" "$OPENEDX_DOCKERFILE" 2>/dev/null; then
    check_pass "Resilient npm install command (package-lock tolerance)"
  else
    check_fail "NPM install command with lockfile tolerance not found in $OPENEDX_DOCKERFILE"
  fi

  if grep -qE '\$PIP_COMMAND install --no-build-isolation -r /openedx/edx-platform/requirements/edx/base.txt -r /openedx/edx-platform/requirements/edx/assets.txt' "$OPENEDX_DOCKERFILE" 2>/dev/null; then
    check_pass "uv-compatible requirements install command"
  elif grep -qE '\$PIP_COMMAND install --no-build-isolation -r /tmp/base-filtered.txt -r /tmp/assets.txt' "$OPENEDX_DOCKERFILE" 2>/dev/null; then
    check_pass "uv-compatible requirements install command (/tmp filtered requirements)"
  else
    check_fail "Python requirements install command with lockfile handling not found in $OPENEDX_DOCKERFILE"
  fi

  pattern_in_file "translation settings import preflight ok" "$OPENEDX_DOCKERFILE" "Translation settings import preflight"
  fixed_pattern_count_equals "Stripped google font imports from {changed} scss files" "1" "$OPENEDX_DOCKERFILE" "Brand compile block is not duplicated"
  pattern_not_in_file "webpack skipped (prebuilt bundles)" "$OPENEDX_DOCKERFILE" "Proof lane does not use conditional webpack skip"
  pattern_not_in_file "RUN uv pip install -e /openedx/mfe_oauth_fix" "$OPENEDX_DOCKERFILE" "No duplicate production-stage custom app reinstalls remain"
  pattern_in_file 'RUN $PIP_COMMAND install django-prometheus==2.3.1' "$OPENEDX_DOCKERFILE" "django-prometheus install uses uv-compatible production installer"
  pattern_not_in_file "RUN pip install -e /openedx/mfe_oauth_fix" "$OPENEDX_DOCKERFILE" "No legacy pip editable custom-app install remains in production stage"
  pattern_in_file "COPY --from=python-requirements --chown=app:app /openedx/mfe_oauth_fix /openedx/mfe_oauth_fix" "$OPENEDX_DOCKERFILE" "Final runtime carries mfe_oauth_fix from python-requirements"
  pattern_in_file "COPY --from=python-requirements --chown=app:app /openedx/openedx_prometheus /openedx/openedx_prometheus" "$OPENEDX_DOCKERFILE" "Final runtime carries openedx_prometheus from python-requirements"
  pattern_in_file "COPY --from=python-requirements --chown=app:app /openedx/plugins/mereka_tenancy /openedx/plugins/mereka_tenancy" "$OPENEDX_DOCKERFILE" "Final runtime carries mereka_tenancy from python-requirements"
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

  if [[ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates" && -d "$THEME_BUILD_DIR/lms/templates" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates" "$THEME_BUILD_DIR/lms/templates" "Rendered LMS theme templates mirror source"
  fi
  if [[ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates" && -d "$THEME_BUILD_DIR/common/templates" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates" "$THEME_BUILD_DIR/common/templates" "Rendered common theme templates mirror source"
  fi
  if [[ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css" && -d "$THEME_BUILD_DIR/lms/static/css" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/css" "$THEME_BUILD_DIR/lms/static/css" "Rendered LMS theme CSS mirrors source"
  fi
  if [[ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css" && -d "$THEME_BUILD_DIR/common/static/css" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/static/css" "$THEME_BUILD_DIR/common/static/css" "Rendered common theme CSS mirrors source"
  fi
  if [[ -d "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates" && -d "$THEME_BUILD_DIR/cms/templates" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates" "$THEME_BUILD_DIR/cms/templates" "Rendered CMS theme templates mirror source"
  fi

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
  dir_has_files "$THEME_BUILD_DIR/lms/static/fonts/*.woff2" "LMS font files present"
  dir_has_files "$THEME_BUILD_DIR/cms/static/fonts/*.woff2" "CMS font files present"
else
  check_warn "Theme build directory not found (run apply-patches.sh)"
fi

print_section "Checking Rendered Custom App Build Context"

OPENEDX_BUILD_ROOT="$TUTOR_ENV/env/build/openedx"
if [[ -d "$OPENEDX_BUILD_ROOT" ]]; then
  if [[ -d "$REPO_ROOT/infrastructure/tutor/custom-apps/mfe_oauth_fix" && -d "$OPENEDX_BUILD_ROOT/infrastructure/tutor/custom-apps/mfe_oauth_fix" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/custom-apps/mfe_oauth_fix" "$OPENEDX_BUILD_ROOT/infrastructure/tutor/custom-apps/mfe_oauth_fix" "Rendered mfe_oauth_fix mirrors source"
  fi
  if [[ -d "$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus" && -d "$OPENEDX_BUILD_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus" "$OPENEDX_BUILD_ROOT/infrastructure/tutor/custom-apps/openedx_prometheus" "Rendered openedx_prometheus mirrors source"
  fi
  if [[ -d "$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy" && -d "$OPENEDX_BUILD_ROOT/infrastructure/tutor/plugins/multi-tenancy" ]]; then
    dirs_match "$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy" "$OPENEDX_BUILD_ROOT/infrastructure/tutor/plugins/multi-tenancy" "Rendered multi-tenancy plugin mirrors source"
  fi
else
  check_warn "Rendered Open edX build root not found: $OPENEDX_BUILD_ROOT"
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
