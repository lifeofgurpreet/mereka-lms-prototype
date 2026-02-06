#!/usr/bin/env bash
# Audit branding coverage across public surfaces (does not fail by default).
#
# This is a gap-finder: it helps answer "which surface is still default?"
# without turning the whole CI red while prod/dev deployments are catching up.
#
# Usage:
#   ./scripts/qa/audit-branding-surfaces.sh prod
#   ./scripts/qa/audit-branding-surfaces.sh dev
#   ./scripts/qa/audit-branding-surfaces.sh prod --strict
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shared/config.sh"

ENVIRONMENT="${1:-prod}"
STRICT=0

shift || true
while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict) STRICT=1; shift ;;
    -h|--help)
      echo "Usage: $0 [prod|dev] [--strict]" >&2
      exit 0
      ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "dev" ]]; then
  echo "Usage: $0 [prod|dev] [--strict]" >&2
  exit 1
fi

gaps=0

ok() { printf "✓ %s\n" "$1"; }
gap() { printf "✗ %s\n" "$1" >&2; gaps=$((gaps + 1)); }

fetch() {
  local url=$1
  curl -sS -L --connect-timeout 10 --max-time 30 "$url" 2>/dev/null || true
}

extract_first() {
  local re=$1
  rg -o "$re" | head -n 1 || true
}

check_lms_overrides() {
  local host=$1
  local label=$2
  local html css_path css

  html="$(fetch "https://${host}/?nocache=$(date +%s)")"
  if [[ -z "${html:-}" ]]; then
    gap "${label}: host unreachable or returned empty response"
    return
  fi
  css_path="$(printf '%s' "$html" | extract_first '/static/mereka/css/mereka-overrides[^"]*\.css')"
  if [[ -z "${css_path:-}" ]]; then
    gap "${label}: missing mereka-overrides.css link"
    return
  fi

  css="$(fetch "https://${host}${css_path}")"
  if [[ -z "${css:-}" ]]; then
    gap "${label}: could not fetch override CSS (${css_path})"
    return
  fi
  if printf '%s' "$css" | grep -Eq 'font-family:[[:space:]]*"Poppins"' \
    && printf '%s' "$css" | grep -Eq 'font-family:[[:space:]]*"Lato"'; then
    ok "${label}: override CSS includes local fonts"
  else
    gap "${label}: override CSS missing local font-face wiring"
  fi

  if printf '%s' "$css" | grep -Eq '\.courses-listing' \
    && printf '%s' "$css" | grep -Eq '\.courseware' \
    && printf '%s' "$css" | grep -Eq '\.sequence-nav' \
    && printf '%s' "$css" | grep -Eq '\.xblock'; then
    ok "${label}: deep selectors present in override CSS"
  else
    gap "${label}: deep selectors missing (likely older openedx image deployed)"
  fi
}

check_studio_css() {
  local host=$1
  local label=$2
  local html css_path css

  html="$(fetch "https://${host}/?nocache=$(date +%s)")"
  if [[ -z "${html:-}" ]]; then
    gap "${label}: host unreachable or returned empty response"
    return
  fi
  css_path="$(printf '%s' "$html" | extract_first '/static/studio/mereka/css/studio-main-v1\.[a-z0-9]+\.css')"
  if [[ -z "${css_path:-}" ]]; then
    gap "${label}: could not locate studio-main-v1 CSS link"
    return
  fi

  css="$(fetch "https://${host}${css_path}")"
  if [[ -z "${css:-}" ]]; then
    gap "${label}: could not fetch studio CSS (${css_path})"
    return
  fi

  if printf '%s' "$css" | grep -Eq -- '--mereka-color-teal'; then
    ok "${label}: studio CSS exports brand tokens"
  else
    gap "${label}: studio CSS missing brand token exports (likely older openedx image deployed)"
  fi

  if printf '%s' "$css" | grep -Eq 'Poppins-Regular[^"]*\.woff2' \
    && printf '%s' "$css" | grep -Eq 'Lato-Regular[^"]*\.woff2'; then
    ok "${label}: studio CSS references local brand fonts"
  else
    gap "${label}: studio CSS not referencing local brand fonts"
  fi

  if printf '%s' "$css" | grep -Eq 'fonts\.googleapis\.com'; then
    gap "${label}: studio CSS still imports Google fonts (override planned)"
  else
    ok "${label}: studio CSS has no Google font imports"
  fi
}

check_forum() {
  local host=$1
  local code
  code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 "https://${host}/heartbeat" || echo "000")"
  if [[ "$code" == "200" ]]; then
    ok "Forum heartbeat reachable (200)"
  else
    gap "Forum heartbeat not OK (${code})"
  fi
}

check_credentials() {
  local host=$1
  local health body admin_code
  health="https://${host}/health/"
  admin_code="$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 10 --max-time 20 "https://${host}/admin/login/" || echo "000")"
  if [[ "$admin_code" =~ ^[23][0-9][0-9]$ ]]; then
    ok "Credentials admin login reachable (${admin_code})"
  else
    gap "Credentials admin login not reachable (${admin_code})"
  fi

  body="$(fetch "$health")"
  if [[ -z "${body:-}" ]]; then
    gap "Credentials health endpoint empty/unreachable"
    return
  fi
  if printf '%s' "$body" | rg -F -q '"overall_status"' \
    && printf '%s' "$body" | rg -F -q '"database_status"'; then
    ok "Credentials health payload shape OK"
  else
    gap "Credentials health payload missing expected status fields"
  fi
}

if [[ "$ENVIRONMENT" == "prod" ]]; then
  check_lms_overrides "$LMS_DOMAIN" "LMS (${LMS_DOMAIN})"
  check_lms_overrides "$BIJI_DOMAIN" "Microsite (${BIJI_DOMAIN})"
  check_lms_overrides "$SKILLOURFUTURE_DOMAIN" "Microsite (${SKILLOURFUTURE_DOMAIN})"
  check_studio_css "$STUDIO_DOMAIN" "Studio (${STUDIO_DOMAIN})"
  check_credentials "credentials.${LMS_DOMAIN}"
  check_forum "$FORUM_DOMAIN"
else
  check_lms_overrides "$DEV_LMS_DOMAIN" "LMS (${DEV_LMS_DOMAIN})"
  check_studio_css "$DEV_STUDIO_DOMAIN" "Studio (${DEV_STUDIO_DOMAIN})"
  check_credentials "credentials.${DEV_LMS_DOMAIN}"
  check_forum "$DEV_FORUM_DOMAIN"
fi

echo ""
echo "Branding surface audit: gaps=${gaps} strict=${STRICT}"

if [[ "$STRICT" == "1" && "$gaps" -gt 0 ]]; then
  exit 1
fi

exit 0
