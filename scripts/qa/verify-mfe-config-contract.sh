#!/usr/bin/env bash
# @covers AC-005
# @spec: multi-site-domains_spec.md
# Verify `/api/mfe_config/v1` contract on the public MFE host.
#
# Why:
# - Many auth regressions show up first as missing/incorrect MFE config keys.
# - This is a public, non-credentialed check that complements the credentialed
#   SSO canary (`verify-authenticated-sso-canary.sh`).
#
# Usage:
#   ./scripts/qa/verify-mfe-config-contract.sh --env prod
#   ./scripts/qa/verify-mfe-config-contract.sh --env dev
#   ./scripts/qa/verify-mfe-config-contract.sh --env staging
#   ./scripts/qa/verify-mfe-config-contract.sh --env all
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

ENV_SCOPE="prod" # prod|dev|staging|both|all

usage() {
  cat <<EOF
Usage: $0 [--env prod|dev|staging|both|all]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "staging" && "$ENV_SCOPE" != "both" && "$ENV_SCOPE" != "all" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

failures=0

run_env() {
  local env_name="$1"
  local lms_domain studio_domain mfe_domain expected_authn_url expected_authn_domain expected_authn_domain_legacy

  if [[ "$env_name" == "prod" ]]; then
    lms_domain="$LMS_DOMAIN"
    studio_domain="$STUDIO_DOMAIN"
    mfe_domain="$MFE_DOMAIN"
  elif [[ "$env_name" == "staging" ]]; then
    lms_domain="$STAGING_LMS_DOMAIN"
    studio_domain="$STAGING_STUDIO_DOMAIN"
    mfe_domain="$STAGING_MFE_DOMAIN"
  else
    lms_domain="$DEV_LMS_DOMAIN"
    studio_domain="$DEV_STUDIO_DOMAIN"
    mfe_domain="$DEV_MFE_DOMAIN"
  fi

  expected_authn_url="https://${mfe_domain}/authn"
  expected_authn_domain="${mfe_domain}"
  expected_authn_domain_legacy="${expected_authn_url}"

  echo "Environment: ${env_name}"
  echo "Checking: https://${mfe_domain}/api/mfe_config/v1?mfe=authn"

  if ! python3 - "$env_name" "$lms_domain" "$studio_domain" "$expected_authn_url" "$expected_authn_domain" "$expected_authn_domain_legacy" "$mfe_domain" <<'PY'
import json
import sys
import urllib.request

env_name, lms_domain, studio_domain, expected_authn_url, expected_authn_domain, expected_authn_domain_legacy, mfe_domain = sys.argv[1:8]

def fail(msg: str) -> None:
    print(f"[{env_name}] FAIL {msg}", file=sys.stderr)
    raise SystemExit(1)

url = f"https://{mfe_domain}/api/mfe_config/v1?mfe=authn"
try:
    with urllib.request.urlopen(url, timeout=30) as resp:
        raw = resp.read()
except Exception as exc:
    fail(f"failed to fetch {url}: {exc}")

try:
    data = json.loads(raw.decode("utf-8"))
except Exception as exc:
    sample = raw[:200].decode("utf-8", errors="replace")
    fail(f"invalid JSON response: {exc}; sample={sample!r}")

def require_eq(key: str, expected) -> None:
    actual = data.get(key)
    if actual != expected:
        fail(f"{key}={actual!r} (expected {expected!r})")

def require_truthy(key: str) -> None:
    actual = data.get(key)
    if not actual:
        fail(f"{key} is missing/empty (got {actual!r})")

def require_one_of(key: str, expected_values) -> None:
    actual = data.get(key)
    if actual not in expected_values:
        fail(f"{key}={actual!r} (expected one of {expected_values!r})")

# Hard requirements: must align with the currently deployed public surface.
require_eq("LMS_BASE_URL", f"https://{lms_domain}")
require_eq("STUDIO_BASE_URL", f"https://{studio_domain}")
# IMPORTANT: expose login_refresh on the MFE origin to avoid cross-origin cookie drops
# (many browser clients default to credentials='same-origin').
refresh = data.get("REFRESH_ACCESS_TOKEN_ENDPOINT")
if refresh not in (f"https://{mfe_domain}/login_refresh", "/login_refresh"):
    fail(
        f"REFRESH_ACCESS_TOKEN_ENDPOINT={refresh!r} "
        f"(expected {('https://'+mfe_domain+'/login_refresh')!r} OR '/login_refresh')"
    )
require_eq("DISABLE_ENTERPRISE_LOGIN", True)

# Authn wiring SHOULD be present; missing values are a common signal that a
# stale configmap/image is running (or tutor settings drifted). The current
# runtime contract uses the bare apps host for AUTHN_MICROFRONTEND_DOMAIN,
# but older bootstrap paths may still emit the full authn URL, so accept both.
require_eq("AUTHN_MICROFRONTEND_URL", expected_authn_url)
require_one_of("AUTHN_MICROFRONTEND_DOMAIN", [expected_authn_domain, expected_authn_domain_legacy])

# Cookie posture SHOULD be explicit for cross-site SSO flows.
require_eq("SESSION_COOKIE_SAMESITE", "None")
require_eq("CSRF_COOKIE_SAMESITE", "None")

# Learner-facing MFE URLs must stay complete. A partial SiteConfiguration.MFE_CONFIG
# can shadow otherwise-correct LMS settings and silently route users back to
# legacy LMS surfaces after login.
expected_urls = {
    "ACCOUNT_MICROFRONTEND_URL": f"https://{mfe_domain}/account/",
    "ACCOUNT_SETTINGS_URL": f"https://{mfe_domain}/account/",
    "DISCUSSIONS_MICROFRONTEND_URL": f"https://{mfe_domain}/discussions",
    "DISCUSSIONS_MFE_BASE_URL": f"https://{mfe_domain}/discussions",
    "WRITABLE_GRADEBOOK_URL": f"https://{mfe_domain}/gradebook",
    "LEARNER_HOME_MICROFRONTEND_URL": f"https://{mfe_domain}/learner-dashboard/",
    "LEARNER_RECORD_MICROFRONTEND_URL": f"https://{mfe_domain}/learner-record",
    "LEARNING_MICROFRONTEND_URL": f"https://{mfe_domain}/learning",
    "LEARNING_BASE_URL": f"https://{mfe_domain}/learning",
    "ORA_GRADING_MICROFRONTEND_URL": f"https://{mfe_domain}/ora-grading",
    "PROFILE_MICROFRONTEND_URL": f"https://{mfe_domain}/u/",
    "ACCOUNT_PROFILE_URL": f"https://{mfe_domain}/u/",
    "COMMUNICATIONS_MICROFRONTEND_URL": f"https://{mfe_domain}/communications",
}
for key, expected in expected_urls.items():
    require_eq(key, expected)

require_eq("LOGIN_REDIRECT_URL", f"https://{mfe_domain}/learner-dashboard/")

# Sanity markers
require_truthy("ACCESS_TOKEN_COOKIE_NAME")
require_truthy("USER_INFO_COOKIE_NAME")

print(f"[{env_name}] OK")
PY
  then
    failures=$((failures + 1))
  fi
}

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  run_env "prod"
fi
if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" || "$ENV_SCOPE" == "all" ]]; then
  run_env "dev"
fi
if [[ "$ENV_SCOPE" == "staging" || "$ENV_SCOPE" == "all" ]]; then
  run_env "staging"
fi

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
