#!/usr/bin/env bash
# @covers AC-001
# @spec: multi-site-domains_spec.md
# Unified multisite governance gate for domain/site config + org ownership.
#
# Usage:
#   ./scripts/qa/run-multisite-governance-gates.sh
#   ./scripts/qa/run-multisite-governance-gates.sh --env prod
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENV_SCOPE="${ENV_SCOPE:-both}"
STRICT="${STRICT:-1}"
CHECK_TIMEOUT_SECONDS="${CHECK_TIMEOUT_SECONDS:-900}"
STAMP="$(date -u +%Y%m%d-%H%M%S)"
ARTIFACT_DIR="${ARTIFACT_DIR:-var/multisite-governance-gates/${STAMP}}"
mkdir -p "$ARTIFACT_DIR"

usage() {
  cat <<'EOF'
Usage: ./scripts/qa/run-multisite-governance-gates.sh [--env prod|dev|both]
Env:
  STRICT=1                  Enforce strict validation mode
  CHECK_TIMEOUT_SECONDS=900 Per-check timeout in seconds
  ARTIFACT_DIR=var/...      Directory for per-check logs
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    -h|--help)
      usage; exit 0 ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1 ;;
  esac
done

if [[ "$ENV_SCOPE" != "prod" && "$ENV_SCOPE" != "dev" && "$ENV_SCOPE" != "both" ]]; then
  echo "Invalid --env: $ENV_SCOPE" >&2
  usage
  exit 1
fi

failures=0

run_check() {
  local name="$1"; shift
  local out_file rc out slug timed_out
  slug="$(echo "$name" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
  out_file="${ARTIFACT_DIR}/${slug}.log"
  timed_out=0

  set +e
  if command -v timeout >/dev/null 2>&1; then
    timeout "${CHECK_TIMEOUT_SECONDS}s" "$@" >"$out_file" 2>&1
  else
    "$@" >"$out_file" 2>&1
  fi
  rc=$?
  set -e
  out="$(cat "$out_file")"

  if [[ "$rc" -eq 124 ]]; then
    timed_out=1
  fi

  if [[ "$rc" -eq 0 ]]; then
    echo "OK   $name"
  else
    failures=$((failures + 1))
    if [[ "$timed_out" -eq 1 ]]; then
      echo "FAIL $name (timed out after ${CHECK_TIMEOUT_SECONDS}s)"
    else
      echo "FAIL $name"
    fi
    if [[ -n "$out" ]]; then
      echo "$out" | sed 's/^/  /'
    fi
    echo "  log: $out_file"
  fi
}

echo "Multisite governance gates"
echo "  env: $ENV_SCOPE"
echo "  strict: $STRICT"
echo "  check_timeout_seconds: $CHECK_TIMEOUT_SECONDS"
echo "  artifact_dir: $ARTIFACT_DIR"
echo ""

if [[ "$ENV_SCOPE" == "prod" || "$ENV_SCOPE" == "both" ]]; then
  run_check "multisite config (prod)" \
    env STRICT="$STRICT" ./scripts/qa/verify-multisite-config.sh prod
  run_check "org role ownership (prod)" \
    env STRICT="$STRICT" ./scripts/qa/verify-org-role-ownership.sh prod
  run_check "auth surfaces (prod)" \
    ./scripts/qa/verify-auth-surfaces.sh prod
fi

if [[ "$ENV_SCOPE" == "dev" || "$ENV_SCOPE" == "both" ]]; then
  run_check "multisite config (dev)" \
    env STRICT="$STRICT" ./scripts/qa/verify-multisite-config.sh dev
  run_check "org role ownership (dev)" \
    env STRICT="$STRICT" ./scripts/qa/verify-org-role-ownership.sh dev
  run_check "auth surfaces (dev)" \
    ./scripts/qa/verify-auth-surfaces.sh dev
fi

run_check "hostname registry drift ($ENV_SCOPE)" \
  ./scripts/qa/list-openedx-hostnames.sh --env "$ENV_SCOPE"

echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "OK"
else
  echo "FAILED ($failures checks failed)"
fi
echo "Logs: $ARTIFACT_DIR"

[[ "$failures" -eq 0 ]]
