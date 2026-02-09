#!/usr/bin/env bash
# Verify Sentry CLI auth + org/project contract using observability standards.
#
# Usage:
#   ./scripts/qa/verify-sentry-cli-contract.sh
#   SENTRY_ORG=biji-biji-non-profits SENTRY_PROJECTS="mereka-lms-web" ./scripts/qa/verify-sentry-cli-contract.sh
set -euo pipefail

SENTRY_ORG="${SENTRY_ORG:-biji-biji-non-profits}"
SENTRY_PROJECTS="${SENTRY_PROJECTS:-mereka-lms-web}"
JSON_OUT=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/verify-sentry-cli-contract.sh [--json]
Env:
  SENTRY_ORG=biji-biji-non-profits
  SENTRY_PROJECTS="mereka-lms-web"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --json) JSON_OUT=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

ok_cmd=0
ok_auth=0
ok_org=0
ok_projects=1
missing_projects=()

if command -v sentry-cli >/dev/null 2>&1; then
  ok_cmd=1
fi

if [[ "$ok_cmd" -eq 1 ]] && sentry-cli info >/dev/null 2>&1; then
  ok_auth=1
fi

if [[ "$ok_auth" -eq 1 ]] && sentry-cli organizations list | rg -Fq -- "$SENTRY_ORG"; then
  ok_org=1
fi

if [[ "$ok_org" -eq 1 ]]; then
  projects_table="$(sentry-cli projects list --org "$SENTRY_ORG")"
  for p in $SENTRY_PROJECTS; do
    if ! rg -Fq -- "$p" <<<"$projects_table"; then
      ok_projects=0
      missing_projects+=("$p")
    fi
  done
else
  ok_projects=0
  for p in $SENTRY_PROJECTS; do
    missing_projects+=("$p")
  done
fi

if [[ "$JSON_OUT" -eq 1 ]]; then
  printf "{"
  printf "\"sentry_cli_installed\":%s," "$ok_cmd"
  printf "\"sentry_cli_authenticated\":%s," "$ok_auth"
  printf "\"org_present\":%s," "$ok_org"
  printf "\"projects_present\":%s," "$ok_projects"
  printf "\"org\":\"%s\"," "$SENTRY_ORG"
  printf "\"required_projects\":["
  first=1
  for p in $SENTRY_PROJECTS; do
    [[ "$first" -eq 0 ]] && printf ","
    first=0
    printf "\"%s\"" "$p"
  done
  printf "],"
  printf "\"missing_projects\":["
  first=1
  for p in "${missing_projects[@]}"; do
    [[ "$first" -eq 0 ]] && printf ","
    first=0
    printf "\"%s\"" "$p"
  done
  printf "]"
  printf "}\n"
else
  echo "Verify: Sentry CLI contract"
  echo "  org: $SENTRY_ORG"
  echo "  required projects: $SENTRY_PROJECTS"
  echo
  [[ "$ok_cmd" -eq 1 ]] && echo "OK   sentry-cli installed" || echo "FAIL sentry-cli not installed"
  [[ "$ok_auth" -eq 1 ]] && echo "OK   sentry-cli authenticated" || echo "FAIL sentry-cli not authenticated"
  [[ "$ok_org" -eq 1 ]] && echo "OK   org exists: $SENTRY_ORG" || echo "FAIL org missing: $SENTRY_ORG"
  if [[ "$ok_projects" -eq 1 ]]; then
    echo "OK   required projects exist"
  else
    echo "FAIL missing projects: ${missing_projects[*]}"
  fi
fi

[[ "$ok_cmd" -eq 1 && "$ok_auth" -eq 1 && "$ok_org" -eq 1 && "$ok_projects" -eq 1 ]]
