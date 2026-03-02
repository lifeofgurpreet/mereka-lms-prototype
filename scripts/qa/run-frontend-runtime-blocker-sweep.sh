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
#   ./scripts/qa/run-frontend-runtime-blocker-sweep.sh [--env dev|prod|both]
#
# Notes:
#   - Default env is both.
#   - credentials-readiness cluster check is scoped to dev because current blocker
#     triage is dev-runtime specific.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

ENVIRONMENT="both"

usage() {
  cat <<'USAGE'
Usage: run-frontend-runtime-blocker-sweep.sh [--env dev|prod|both]

Options:
  --env <dev|prod|both>   Target environment set for checks (default: both)
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

if [[ "$ENVIRONMENT" != "dev" && "$ENVIRONMENT" != "prod" && "$ENVIRONMENT" != "both" ]]; then
  echo "ERROR: --env must be dev, prod, or both" >&2
  exit 2
fi

mkdir -p "$REPO_ROOT/var/qa"
ts="$(date -u +%Y%m%dT%H%M%SZ)"
auth_log_dev="$REPO_ROOT/var/qa/frontend-runtime-blocker-auth-surfaces-dev-${ts}.log"
auth_log_prod="$REPO_ROOT/var/qa/frontend-runtime-blocker-auth-surfaces-prod-${ts}.log"
cred_log="$REPO_ROOT/var/qa/frontend-runtime-blocker-credentials-dev-${ts}.log"
summary_log="$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-${ENVIRONMENT}-${ts}.summary.log"
summary_json="$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-${ENVIRONMENT}-${ts}.summary.json"
records_file="$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-${ENVIRONMENT}-${ts}.records.tsv"
diagnostics_file="$REPO_ROOT/var/qa/frontend-runtime-blocker-sweep-${ENVIRONMENT}-${ts}.diagnostics.tsv"

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
    printf "%s\t%s\t%s\n" "$label" "pass" "$log_file" >>"$records_file"
  else
    echo "FAIL: $label" | tee -a "$summary_log"
    fail=$((fail + 1))
    printf "%s\t%s\t%s\n" "$label" "fail" "$log_file" >>"$records_file"
  fi
}

emit_diagnostics() {
  local label="$1"
  local status="$2"
  local log_file="$3"
  local diagnosis="none"

  if [[ "$status" == "pass" || "$status" == "skip" || -z "$log_file" || ! -f "$log_file" ]]; then
    printf "%s\t%s\t%s\t%s\n" "$label" "$status" "$diagnosis" "$log_file" >>"$diagnostics_file"
    return 0
  fi

  case "$label" in
    auth-surfaces:dev)
      if rg -q "credentials: /login SSO entrypoint.*got code=500|credentials: /login/edx-oauth2.*got code=500" "$log_file"; then
        diagnosis="credentials_dev_login_500"
      else
        diagnosis="auth_surfaces_dev_failure_other"
      fi
      ;;
    credentials-readiness:dev:cluster)
      if rg -q "ZoneInfoNotFoundError|No module named 'tzdata'|cannot resolve ZoneInfo\\('UTC'\\)" "$log_file"; then
        diagnosis="credentials_timezone_tzdata_missing"
      else
        diagnosis="credentials_cluster_failure_other"
      fi
      ;;
    auth-surfaces:prod)
      diagnosis="auth_surfaces_prod_failure_other"
      ;;
    *)
      diagnosis="unknown_failure"
      ;;
  esac

  printf "%s\t%s\t%s\t%s\n" "$label" "$status" "$diagnosis" "$log_file" >>"$diagnostics_file"
}

: >"$summary_log"
: >"$records_file"
: >"$diagnostics_file"
echo "Frontend runtime blocker sweep (${ENVIRONMENT}) @ ${ts}" | tee -a "$summary_log"

if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "both" ]]; then
  run_check \
    "auth-surfaces:prod" \
    "$auth_log_prod" \
    "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" \
    "prod"
else
  skip=$((skip + 1))
  printf "%s\t%s\t%s\n" "auth-surfaces:prod" "skip" "" >>"$records_file"
fi

if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "both" ]]; then
  run_check \
    "auth-surfaces:dev" \
    "$auth_log_dev" \
    "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" \
    "dev"
else
  skip=$((skip + 1))
  printf "%s\t%s\t%s\n" "auth-surfaces:dev" "skip" "" >>"$records_file"
fi

if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "both" ]]; then
  run_check \
    "credentials-readiness:dev:cluster" \
    "$cred_log" \
    "$REPO_ROOT/scripts/qa/verify-credentials-readiness.sh" \
    "--cluster"
else
  echo "SKIP: credentials-readiness cluster sweep is dev-only" | tee -a "$summary_log"
  skip=$((skip + 1))
  printf "%s\t%s\t%s\n" "credentials-readiness:dev:cluster" "skip" "" >>"$records_file"
fi

while IFS=$'\t' read -r rec_label rec_status rec_log; do
  [[ -z "${rec_label:-}" ]] && continue
  emit_diagnostics "$rec_label" "$rec_status" "$rec_log"
done <"$records_file"

echo "" | tee -a "$summary_log"
echo "Summary: PASS=${pass} FAIL=${fail} SKIP=${skip}" | tee -a "$summary_log"
if [[ "$ENVIRONMENT" == "prod" || "$ENVIRONMENT" == "both" ]]; then
  echo "Auth log (prod): $auth_log_prod" | tee -a "$summary_log"
fi
if [[ "$ENVIRONMENT" == "dev" || "$ENVIRONMENT" == "both" ]]; then
  echo "Auth log (dev): $auth_log_dev" | tee -a "$summary_log"
  echo "Credentials log: $cred_log" | tee -a "$summary_log"
fi
echo "Summary log: $summary_log" | tee -a "$summary_log"
echo "Summary json: $summary_json" | tee -a "$summary_log"
echo "Diagnostics tsv: $diagnostics_file" | tee -a "$summary_log"

python3 - "$ENVIRONMENT" "$ts" "$pass" "$fail" "$skip" "$summary_log" "$summary_json" "$records_file" "$diagnostics_file" <<'PY'
import json
import sys
from pathlib import Path

environment, ts, pass_count, fail_count, skip_count, summary_log, summary_json, records_file, diagnostics_file = sys.argv[1:10]
checks = []
for line in Path(records_file).read_text().splitlines():
    if not line.strip():
        continue
    label, status, log_path = (line.split("\t") + ["", ""])[:3]
    checks.append(
        {
            "label": label,
            "status": status,
            "log": log_path or None,
        }
    )

diagnostics = []
for line in Path(diagnostics_file).read_text().splitlines():
    if not line.strip():
        continue
    label, status, diagnosis, log_path = (line.split("\t") + ["", "", "", ""])[:4]
    diagnostics.append(
        {
            "label": label,
            "status": status,
            "diagnosis": diagnosis,
            "log": log_path or None,
        }
    )

payload = {
    "environment": environment,
    "timestamp": ts,
    "summary": {
        "pass": int(pass_count),
        "fail": int(fail_count),
        "skip": int(skip_count),
    },
    "artifacts": {
        "summary_log": summary_log,
        "checks": checks,
        "diagnostics_tsv": diagnostics_file,
        "diagnostics": diagnostics,
    },
}

Path(summary_json).write_text(json.dumps(payload, indent=2) + "\n")
PY

[[ "$fail" -eq 0 ]]
