#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TUTOR_ROOT="${TUTOR_ROOT:-$REPO_ROOT/tutor_env}"
MYSQL_CONTAINER="${MYSQL_CONTAINER:-tutor_local-mysql-1}"
LMS_CONTAINER="${LMS_CONTAINER:-tutor_local-lms-1}"
CADDY_CONTAINER="${CADDY_CONTAINER:-tutor_local-caddy-1}"
TARGET_THEME="${TARGET_THEME:-mereka}"
HTTP_TIMEOUT="${HTTP_TIMEOUT:-15}"
HTTP_ROUTE_ATTEMPTS="${HTTP_ROUTE_ATTEMPTS:-12}"
HTTP_ROUTE_SLEEP_SECONDS="${HTTP_ROUTE_SLEEP_SECONDS:-5}"
LMS_URL="${LMS_URL:-http://localhost}"
STUDIO_URL="${STUDIO_URL:-http://studio.localhost}"
MFE_AUTHN_URL="${MFE_AUTHN_URL:-http://apps.localhost/authn/login}"
DISCOVERY_URL="${DISCOVERY_URL:-http://discovery.localhost}"

if [ -f "$REPO_ROOT/infrastructure/tutor/tutor-env.sh" ]; then
  # shellcheck source=/dev/null
  source "$REPO_ROOT/infrastructure/tutor/tutor-env.sh" >/dev/null 2>&1 || true
fi

FAILURES=()

pass() {
  printf 'PASS: %s\n' "$1"
}

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  FAILURES+=("$1")
}

require_running_container() {
  local name="$1"
  local label="$2"
  local running
  running="$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)"
  if [ "$running" = "true" ]; then
    pass "$label container is running ($name)"
  else
    fail "$label container is not running ($name)"
  fi
}

mysql_scalar() {
  local sql="$1"
  local escaped
  escaped="$(printf '%q' "$sql")"
  docker exec "$MYSQL_CONTAINER" sh -lc "mysql -uroot -p\"\$MYSQL_ROOT_PASSWORD\" -Nse $escaped"
}

lms_shell() {
  local code="$1"
  local escaped
  escaped="$(printf '%q' "$code")"
  docker exec "$LMS_CONTAINER" sh -lc "cd /openedx/edx-platform && python manage.py lms shell -c $escaped"
}

check_http_route() {
  local url="$1"
  local label="$2"
  local allowed="$3"
  local attempt status

  for ((attempt = 1; attempt <= HTTP_ROUTE_ATTEMPTS; attempt++)); do
    status="$(curl -sS -o /dev/null -w '%{http_code}' --max-time "$HTTP_TIMEOUT" "$url" 2>/dev/null || true)"
    status="${status:-000}"
    if [[ " $allowed " == *" $status "* ]]; then
      pass "$label route returns HTTP $status ($url)"
      return 0
    fi
    if (( attempt < HTTP_ROUTE_ATTEMPTS )); then
      sleep "$HTTP_ROUTE_SLEEP_SECONDS"
    fi
  done

  fail "$label route returned HTTP ${status:-000} after ${HTTP_ROUTE_ATTEMPTS} attempts; expected one of: $allowed ($url)"
}

check_mysql_ready() {
  local result
  if result="$(mysql_scalar 'SELECT 1;' 2>/dev/null)" && [ "$result" = "1" ]; then
    pass "MySQL root access is healthy"
  else
    fail "MySQL root access is not healthy"
  fi
}

check_openedx_user() {
  local result
  if result="$(mysql_scalar "SELECT COUNT(*) FROM mysql.user WHERE user = 'openedx';" 2>/dev/null)" && [ "${result:-0}" -ge 1 ]; then
    pass "openedx MySQL user exists"
  else
    fail "openedx MySQL user is missing"
  fi
}

check_schema_tables() {
  local result
  if result="$(mysql_scalar "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'openedx' AND table_name IN ('django_migrations','django_site');" 2>/dev/null)" && [ "${result:-0}" -eq 2 ]; then
    pass "openedx schema contains core Django tables"
  else
    fail "openedx schema is missing core Django tables"
  fi
}

check_local_site_rows() {
  local result
  if result="$(mysql_scalar "SELECT COUNT(*) FROM openedx.django_site WHERE domain IN ('localhost','localhost:8000','studio.localhost','studio.localhost:8001','apps.localhost');" 2>/dev/null)" && [ "${result:-0}" -eq 5 ]; then
    pass "local Django site rows exist"
  else
    fail "local Django site rows are incomplete"
  fi
}

check_local_theme_convergence() {
  local result
  result="$(mysql_scalar "
SELECT GROUP_CONCAT(CONCAT(s.domain, ':', t.theme_dir_name) ORDER BY s.domain SEPARATOR '\n')
FROM openedx.theming_sitetheme t
JOIN openedx.django_site s ON s.id = t.site_id
WHERE s.domain IN ('localhost','localhost:8000','studio.localhost','studio.localhost:8001','apps.localhost')
  AND t.theme_dir_name <> '$TARGET_THEME';
" 2>/dev/null || true)"
  if [ -z "$result" ] || [ "$result" = "NULL" ]; then
    pass "localhost SiteTheme rows converge to $TARGET_THEME"
  else
    fail "localhost SiteTheme rows are not converged to $TARGET_THEME${result:+ ($result)}"
  fi
}

main() {
  require_running_container "$MYSQL_CONTAINER" "mysql"
  require_running_container "$LMS_CONTAINER" "lms"
  require_running_container "$CADDY_CONTAINER" "caddy"

  check_mysql_ready
  check_openedx_user
  check_schema_tables
  check_local_site_rows
  check_local_theme_convergence
  check_http_route "$LMS_URL" "LMS" "200 302"
  check_http_route "$STUDIO_URL" "Studio" "200 302"
  check_http_route "$MFE_AUTHN_URL" "MFE authn" "200 302"
  check_http_route "$DISCOVERY_URL" "Discovery" "200 302"

  if [ "${#FAILURES[@]}" -gt 0 ]; then
    printf '\nBootstrap readiness is not established. These are local initialized-state failures, not source/render/image proof.\n' >&2
    exit 1
  fi

  printf '\nPASS: local bootstrap readiness baseline is established under %s\n' "$TUTOR_ROOT"
}

main "$@"
