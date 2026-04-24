#!/usr/bin/env bash
# run-a11y-runtime-lane.sh — canonical wrapper for accessibility verification lanes.
#
# Examples:
#   ./scripts/qa/run-a11y-runtime-lane.sh --env prod --mode offline
#   ./scripts/qa/run-a11y-runtime-lane.sh --env dev --mode online --allow-missing-reports
#   ./scripts/qa/run-a11y-runtime-lane.sh --env prod --mode hybrid --routes "/authn/login,/dashboard"
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
VERIFY_SCRIPT="$REPO_ROOT/scripts/qa/verify-accessibility.sh"

ENVIRONMENT="prod"
MODE="offline"
TARGET_URL=""
ROUTES=""
ALLOW_MISSING_REPORTS=0

usage() {
  cat <<'EOF'
Usage: run-a11y-runtime-lane.sh [options]

Options:
  --env <prod|dev>           Target environment (default: prod)
  --mode <offline|online|hybrid>
                             Accessibility mode (default: offline)
  --target-url <url>         Target URL (default: apps domain derived from --env)
  --routes <csv>             Optional CSV route list for online scans
  --allow-missing-reports    Downgrade missing online reports to SKIP
  -h, --help                 Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      [[ $# -lt 2 ]] && { echo "ERROR: --env requires a value" >&2; exit 2; }
      ENVIRONMENT="$2"
      shift 2
      ;;
    --mode)
      [[ $# -lt 2 ]] && { echo "ERROR: --mode requires a value" >&2; exit 2; }
      MODE="$2"
      shift 2
      ;;
    --target-url)
      [[ $# -lt 2 ]] && { echo "ERROR: --target-url requires a value" >&2; exit 2; }
      TARGET_URL="$2"
      shift 2
      ;;
    --routes)
      [[ $# -lt 2 ]] && { echo "ERROR: --routes requires a value" >&2; exit 2; }
      ROUTES="$2"
      shift 2
      ;;
    --allow-missing-reports)
      ALLOW_MISSING_REPORTS=1
      shift
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

case "$ENVIRONMENT" in
  prod|dev) ;;
  *)
    echo "ERROR: --env must be prod or dev (got: $ENVIRONMENT)" >&2
    exit 2
    ;;
esac

case "$MODE" in
  offline|online|hybrid) ;;
  *)
    echo "ERROR: --mode must be offline, online, or hybrid (got: $MODE)" >&2
    exit 2
    ;;
esac

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "ERROR: Missing executable verifier: ${VERIFY_SCRIPT#$REPO_ROOT/}" >&2
  exit 1
fi

if [[ -z "$TARGET_URL" ]]; then
  if [[ "$ENVIRONMENT" == "prod" ]]; then
    TARGET_URL="https://apps.academyv2.mereka.io"
  else
    TARGET_URL="https://apps.academyv2.mereka.dev"
  fi
fi

args=()
case "$MODE" in
  offline)
    args+=(--offline)
    ;;
  online)
    args+=(--online --target "$TARGET_URL")
    ;;
  hybrid)
    args+=(--offline --online --target "$TARGET_URL")
    ;;
esac

if [[ -n "$ROUTES" ]]; then
  args+=(--routes "$ROUTES")
fi
if [[ "$ALLOW_MISSING_REPORTS" == "1" ]]; then
  args+=(--allow-missing-reports)
fi

exec "$VERIFY_SCRIPT" "${args[@]}"
