#!/usr/bin/env bash
# Audit authenticated SSO canary wiring (workflow contract + GitHub secret/variable presence).
#
# Usage:
#   ./scripts/qa/audit-authenticated-sso-canary-wiring.sh
#   STRICT=1 ./scripts/qa/audit-authenticated-sso-canary-wiring.sh --repo Biji-Biji-Initiative/mereka-lms
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/operations-gates-runtime.yml"
REPO_SLUG="${REPO_SLUG:-Biji-Biji-Initiative/mereka-lms}"
STRICT="${STRICT:-0}"

failures=0
warnings=0

usage() {
  cat <<EOF_USAGE
Usage: $0 [--repo owner/repo]

Env:
  STRICT=1   Fail when GitHub canary secrets/variable are missing
EOF_USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO_SLUG="${2:-}"; shift 2 ;;
    -h|--help)
      usage
      exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

check_workflow_pattern() {
  local pattern="$1"
  local label="$2"
  if rg -q --fixed-strings "$pattern" "$WORKFLOW_FILE"; then
    echo "OK workflow: $label"
  else
    echo "FAIL workflow: missing $label" >&2
    failures=$((failures + 1))
  fi
}

if [[ ! -f "$WORKFLOW_FILE" ]]; then
  echo "FAIL workflow file not found: $WORKFLOW_FILE" >&2
  exit 1
fi

check_workflow_pattern "run_authenticated_sso_canary:" "dispatch input run_authenticated_sso_canary"
check_workflow_pattern "RUN_AUTHENTICATED_SSO_CANARY=1" "runtime gate enable export"
check_workflow_pattern "AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1" "strict secret requirement export"
check_workflow_pattern "SSO_CANARY_EMAIL_PROD" "prod canary email secret wiring"
check_workflow_pattern "SSO_CANARY_PASSWORD_PROD" "prod canary password secret wiring"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  secret_names="$(gh secret list --repo "$REPO_SLUG" | awk '{print $1}')"
  variable_rows="$(gh variable list --repo "$REPO_SLUG" || true)"

  for key in SSO_CANARY_EMAIL_PROD SSO_CANARY_PASSWORD_PROD; do
    if grep -qx "$key" <<<"$secret_names"; then
      echo "OK github secret present: $key"
    else
      if [[ "$STRICT" == "1" ]]; then
        echo "FAIL github secret missing: $key" >&2
        failures=$((failures + 1))
      else
        echo "WARN github secret missing: $key (non-strict warning)"
        warnings=$((warnings + 1))
      fi
    fi
  done

  if grep -q '^RUN_AUTHENTICATED_SSO_CANARY[[:space:]]\+true$' <<<"$variable_rows"; then
    echo "OK github variable RUN_AUTHENTICATED_SSO_CANARY=true"
  else
    if [[ "$STRICT" == "1" ]]; then
      echo "FAIL github variable RUN_AUTHENTICATED_SSO_CANARY=true is not set" >&2
      failures=$((failures + 1))
    else
      echo "WARN github variable RUN_AUTHENTICATED_SSO_CANARY=true is not set (non-strict warning)"
      warnings=$((warnings + 1))
    fi
  fi
else
  if [[ "$STRICT" == "1" ]]; then
    echo "FAIL gh CLI/auth unavailable; cannot verify GitHub secret/variable presence in STRICT=1" >&2
    failures=$((failures + 1))
  else
    echo "WARN gh CLI/auth unavailable; skipped GitHub secret/variable presence checks"
    warnings=$((warnings + 1))
  fi
fi

if [[ "$failures" -gt 0 ]]; then
  echo "FAILED ($failures failures, $warnings warnings)" >&2
  exit 1
fi

echo "OK ($warnings warnings)"
