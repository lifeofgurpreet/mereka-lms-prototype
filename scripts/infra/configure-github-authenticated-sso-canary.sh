#!/usr/bin/env bash
# Configure GitHub secrets/variable for authenticated SSO canary enforcement.
#
# This script never prints secret values. Provide secrets via environment variables.
#
# Usage:
#   SSO_CANARY_EMAIL_PROD='user@example.com' \
#   SSO_CANARY_PASSWORD_PROD='***' \
#   ./scripts/infra/configure-github-authenticated-sso-canary.sh --enable-runtime-gate
#
# Optional dev wiring:
#   SSO_CANARY_EMAIL_DEV='user-dev@example.com' \
#   SSO_CANARY_PASSWORD_DEV='***' \
#   ./scripts/infra/configure-github-authenticated-sso-canary.sh --enable-runtime-gate
set -euo pipefail

REPO_SLUG="${REPO_SLUG:-Biji-Biji-Initiative/mereka-lms}"
REQUIRE_DEV="${REQUIRE_DEV:-0}"
REQUIRE_STUDIO="${REQUIRE_STUDIO:-0}"
ENABLE_RUNTIME_GATE=0

usage() {
  cat <<EOF_USAGE
Usage: $0 [--repo owner/repo] [--require-dev] [--enable-runtime-gate]

Env inputs (required for prod):
  SSO_CANARY_EMAIL_PROD
  SSO_CANARY_PASSWORD_PROD

Optional prod inputs (recommended for Studio staff canary):
  SSO_CANARY_STUDIO_EMAIL_PROD
  SSO_CANARY_STUDIO_PASSWORD_PROD

Optional dev inputs:
  SSO_CANARY_EMAIL_DEV
  SSO_CANARY_PASSWORD_DEV

Optional dev inputs (recommended for Studio staff canary):
  SSO_CANARY_STUDIO_EMAIL_DEV
  SSO_CANARY_STUDIO_PASSWORD_DEV

Options:
  --repo owner/repo      GitHub repo slug (default: $REPO_SLUG)
  --require-dev          Require dev secrets too (or set REQUIRE_DEV=1)
  --require-studio       Require Studio staff canary secrets too (or set REQUIRE_STUDIO=1)
  --enable-runtime-gate  Set repo variable RUN_AUTHENTICATED_SSO_CANARY=true
  -h, --help             Show help
EOF_USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_SLUG="${2:-}"; shift 2 ;;
    --require-dev)
      REQUIRE_DEV=1; shift ;;
    --require-studio)
      REQUIRE_STUDIO=1; shift ;;
    --enable-runtime-gate)
      ENABLE_RUNTIME_GATE=1; shift ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ -z "$REPO_SLUG" ]]; then
  echo "Repository slug is required" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

gh auth status >/dev/null 2>&1 || {
  echo "gh auth is required (run: gh auth login)" >&2
  exit 1
}

require_var() {
  local key="$1"
  if [[ -z "${!key:-}" ]]; then
    echo "Missing required env var: $key" >&2
    exit 1
  fi
}

set_secret_if_present() {
  local key="$1"
  local value="${!key:-}"
  if [[ -z "$value" ]]; then
    return 1
  fi
  gh secret set "$key" --repo "$REPO_SLUG" --body "$value" >/dev/null
  return 0
}

require_var "SSO_CANARY_EMAIL_PROD"
require_var "SSO_CANARY_PASSWORD_PROD"

set_secret_if_present "SSO_CANARY_EMAIL_PROD"
set_secret_if_present "SSO_CANARY_PASSWORD_PROD"
studio_prod_email_set=0
studio_prod_password_set=0
if set_secret_if_present "SSO_CANARY_STUDIO_EMAIL_PROD"; then
  studio_prod_email_set=1
fi
if set_secret_if_present "SSO_CANARY_STUDIO_PASSWORD_PROD"; then
  studio_prod_password_set=1
fi

dev_email_set=0
dev_password_set=0
dev_studio_email_set=0
dev_studio_password_set=0
if set_secret_if_present "SSO_CANARY_EMAIL_DEV"; then
  dev_email_set=1
fi
if set_secret_if_present "SSO_CANARY_PASSWORD_DEV"; then
  dev_password_set=1
fi
if set_secret_if_present "SSO_CANARY_STUDIO_EMAIL_DEV"; then
  dev_studio_email_set=1
fi
if set_secret_if_present "SSO_CANARY_STUDIO_PASSWORD_DEV"; then
  dev_studio_password_set=1
fi

if [[ "$REQUIRE_DEV" == "1" ]]; then
  if [[ "$dev_email_set" != "1" || "$dev_password_set" != "1" || "$dev_studio_email_set" != "1" || "$dev_studio_password_set" != "1" ]]; then
    echo "REQUIRE_DEV=1 but dev canary secrets are missing" >&2
    exit 1
  fi
fi

if [[ "$REQUIRE_STUDIO" == "1" ]]; then
  if [[ "$studio_prod_email_set" != "1" || "$studio_prod_password_set" != "1" ]]; then
    echo "REQUIRE_STUDIO=1 but prod Studio canary secrets are missing" >&2
    exit 1
  fi
fi

if [[ "$ENABLE_RUNTIME_GATE" == "1" ]]; then
  gh variable set RUN_AUTHENTICATED_SSO_CANARY --repo "$REPO_SLUG" --body "true" >/dev/null
fi

echo "Configured GitHub authenticated SSO canary wiring for $REPO_SLUG"
echo "  prod secrets: set"
if [[ "$studio_prod_email_set" == "1" && "$studio_prod_password_set" == "1" ]]; then
  echo "  prod studio secrets: set"
else
  echo "  prod studio secrets: not set (optional unless --require-studio)"
fi
if [[ "$dev_email_set" == "1" && "$dev_password_set" == "1" && "$dev_studio_email_set" == "1" && "$dev_studio_password_set" == "1" ]]; then
  echo "  dev secrets: set"
else
  echo "  dev secrets: not fully set (optional unless --require-dev)"
fi
echo "  runtime gate variable: $([[ "$ENABLE_RUNTIME_GATE" == "1" ]] && echo "set to true" || echo "unchanged")"
