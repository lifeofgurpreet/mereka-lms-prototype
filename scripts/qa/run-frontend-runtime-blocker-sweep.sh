#!/usr/bin/env bash
# run-frontend-runtime-blocker-sweep.sh — Canonical auth/credentials runtime blocker sweep.
#
# Purpose:
#   Run the two high-signal runtime checks that currently define frontend auth/session
#   stability in dev:
#     1) verify-auth-surfaces.sh
#     2) verify-credentials-readiness.sh --cluster
#
# Usage:
#   ./scripts/qa/run-frontend-runtime-blocker-sweep.sh [--env dev|prod]
#
# Notes:
#   - Default env is dev.
#   - credentials-readiness cluster check is scoped to dev because current blocker
#     triage is dev-runtime specific.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENVIRONMENT="dev"

usage() {
  cat <<'USAGE'
Usage: run-frontend-runtime-blocker-sweep.sh [--env dev|prod]

Options:
  --env <dev|prod>   Target environment for auth-surfaces check (default: dev)
  -h, --help         Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENVIRONMENT="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" ]]; then
  echo "ERROR: --env must be dev or prod" >&2
  exit 2
fi

mkdir -p "$REPO_ROOT/var/qa"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
auth_log="$REPO_ROOT/var/qa/frontend-runtime-blocker-auth-surfaces-${ENVIRONMENT}-${ts}.log"
cred_log="$REPO_ROOT/var/qa/frontend-runtime-blocker-credentials-${ENVIRONMENT}-${ts}.log"
summary_log="$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-${ENVIRONMENT}-${ts}.summary.log"

pass=0
fail=0
skip=0

run_check() {
  local label="$1"
  local log_file="$2"
  shift 2

  echo "=== $label ===" | tee -a "$summary_log"
  if "$@" 2>&1 | tee "$log_file"; then
    echo "PASS: $label" | tee -a "$summary_log"
    pass=$((pass + 1))
  else
    echo "FAIL: $label" | tee -a "$summary_log"
    fail=$((fail + 1))
  fi
}

: >"$summary_log"
echo "Frontend runtime blocker sweep (${ENVIRONMENT}) @ ${ts}" | tee -a "$summary_log"

run_check \
  "auth-surfaces:${ENVIRONMENT}" \
  "$auth_log" \
  "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" \
  "$ENVIRONMENT"

if [[ "$ENVIRONMENT" == "dev" ]]; then
  run_check \
    "credentials-readiness:dev:cluster" \
    "$cred_log" \
    "$REPO_ROOT/scripts/qa/verify-credentials-readiness.sh" \
    "--cluster"
else
  echo "SKIP: credentials-readiness cluster sweep is dev-only" | tee -a "$summary_log"
  skip=$((skip + 1))
fi

echo "" | tee -a "$summary_log"
echo "Summary: PASS=${pass} FAIL=${fail} SKIP=${skip}" | tee -a "$summary_log"
echo "Auth log: $auth_log" | tee -a "$summary_log"
if [[ "$ENVIRONMENT" == "dev" ]]; then
  echo "Credentials log: $cred_log" | tee -a "$summary_log"
fi
echo "Summary log: $summary_log" | tee -a "$summary_log"

[[ "$fail" -eq 0 ]]
