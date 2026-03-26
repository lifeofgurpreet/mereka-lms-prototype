#!/usr/bin/env bash
# @covers AC-045
# @spec: auth-sso-enterprise_spec.md
# Audit authenticated SSO canary wiring (workflow contract + GitHub secret/variable presence).
#
# Usage:
#   ./scripts/qa/audit-authenticated-sso-canary-wiring.sh
#   STRICT=1 ./scripts/qa/audit-authenticated-sso-canary-wiring.sh --repo Biji-Biji-Initiative/mereka-lms
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKFLOW_FILE="$REPO_ROOT/.github/workflows/operations-gates-runtime.yml"
# The SSO canary job lives in smoke-authenticated.yml (merged from authenticated-sso-canary.yml)
CANARY_WORKFLOW_FILE="$REPO_ROOT/.github/workflows/smoke-authenticated.yml"
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

case "$STRICT" in
  0|1) ;;
  *)
    echo "Invalid STRICT='$STRICT' (expected 0 or 1)" >&2
    exit 1
    ;;
esac

check_workflow_pattern() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if rg -q --fixed-strings "$pattern" "$file"; then
    echo "OK workflow: $label"
  else
    echo "FAIL workflow: missing $label" >&2
    failures=$((failures + 1))
  fi
}

check_workflow_regex() {
  local file="$1"
  local pattern="$2"
  local label="$3"
  if rg -q "$pattern" "$file"; then
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

check_workflow_pattern "$WORKFLOW_FILE" "run_authenticated_sso_canary:" "dispatch input run_authenticated_sso_canary"
check_workflow_pattern "$WORKFLOW_FILE" "RUN_AUTHENTICATED_SSO_CANARY=1" "runtime gate enable export"
check_workflow_pattern "$WORKFLOW_FILE" "AUTHENTICATED_SSO_CANARY_REQUIRE_SECRETS=1" "strict secret requirement export"
check_workflow_pattern "$WORKFLOW_FILE" "OPERATIONS_GATES_RUNTIME_ENV_SCOPE" "runtime workflow env-scope variable wiring"
check_workflow_regex "$WORKFLOW_FILE" '^[[:space:]]+- staging$' "dispatch input includes staging scope"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_EMAIL_PROD" "prod canary email secret wiring"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_PASSWORD_PROD" "prod canary password secret wiring"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_EMAIL_DEV" "dev canary email secret wiring"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_PASSWORD_DEV" "dev canary password secret wiring"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_EMAIL_STAGING" "staging canary email secret wiring"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_PASSWORD_STAGING" "staging canary password secret wiring"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_STUDIO_EMAIL_STAGING" "staging Studio canary email secret wiring"
check_workflow_pattern "$WORKFLOW_FILE" "SSO_CANARY_STUDIO_PASSWORD_STAGING" "staging Studio canary password secret wiring"

if [[ ! -f "$CANARY_WORKFLOW_FILE" ]]; then
  echo "FAIL canary workflow file not found: $CANARY_WORKFLOW_FILE" >&2
  echo "  (SSO canary is in the sso-canary job inside smoke-authenticated.yml)" >&2
  exit 1
fi

check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_EMAIL_PROD" "canary workflow prod canary email wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_PASSWORD_PROD" "canary workflow prod canary password wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_EMAIL_DEV" "canary workflow dev canary email wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_PASSWORD_DEV" "canary workflow dev canary password wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_EMAIL_STAGING" "canary workflow staging canary email wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_PASSWORD_STAGING" "canary workflow staging canary password wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_STUDIO_EMAIL_PROD" "canary workflow prod studio canary email wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_STUDIO_PASSWORD_PROD" "canary workflow prod studio canary password wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_STUDIO_EMAIL_DEV" "canary workflow dev studio canary email wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_STUDIO_PASSWORD_DEV" "canary workflow dev studio canary password wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_STUDIO_EMAIL_STAGING" "canary workflow staging studio canary email wiring"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "SSO_CANARY_STUDIO_PASSWORD_STAGING" "canary workflow staging studio canary password wiring"
check_workflow_regex "$CANARY_WORKFLOW_FILE" '^[[:space:]]+- staging$' "canary workflow dispatch includes staging scope"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "REQUIRE_STUDIO_CANARY" "canary workflow REQUIRE_STUDIO_CANARY flag present"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "sso-canary" "canary workflow sso-canary job defined"
check_workflow_pattern "$CANARY_WORKFLOW_FILE" "verify-authenticated-sso-canary.sh" "canary workflow invokes canary script"

if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
  secret_names="$(gh secret list --repo "$REPO_SLUG" | awk '{print $1}')"
  variable_rows="$(gh variable list --repo "$REPO_SLUG" || true)"

  for key in \
    SSO_CANARY_EMAIL_PROD \
    SSO_CANARY_PASSWORD_PROD \
    SSO_CANARY_STUDIO_EMAIL_PROD \
    SSO_CANARY_STUDIO_PASSWORD_PROD \
    SSO_CANARY_EMAIL_DEV \
    SSO_CANARY_PASSWORD_DEV \
    SSO_CANARY_STUDIO_EMAIL_DEV \
    SSO_CANARY_STUDIO_PASSWORD_DEV \
    SSO_CANARY_EMAIL_STAGING \
    SSO_CANARY_PASSWORD_STAGING \
    SSO_CANARY_STUDIO_EMAIL_STAGING \
    SSO_CANARY_STUDIO_PASSWORD_STAGING; do
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

  run_canary_value="$(awk '$1=="RUN_AUTHENTICATED_SSO_CANARY"{print tolower($2); exit}' <<<"$variable_rows")"
  if [[ "$run_canary_value" == "true" ]]; then
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

  runtime_scope_value="$(awk '$1=="OPERATIONS_GATES_RUNTIME_ENV_SCOPE"{print tolower($2); exit}' <<<"$variable_rows")"
  if [[ -n "$runtime_scope_value" ]]; then
    echo "OK github variable OPERATIONS_GATES_RUNTIME_ENV_SCOPE=$runtime_scope_value"
  else
    echo "WARN github variable OPERATIONS_GATES_RUNTIME_ENV_SCOPE is not set (workflow falls back to 'both')"
    warnings=$((warnings + 1))
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
