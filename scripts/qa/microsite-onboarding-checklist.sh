#!/usr/bin/env bash
# Microsite/hostname onboarding checklist runner.
#
# Intended workflow:
# 1) Edit scripts/shared/config.sh (and relevant deployment configs)
# 2) Deploy
# 3) Run this script to verify the ecosystem is consistent
#
# By default this is verify-only. You can optionally apply the Authentik redirect URI allowlist
# update (safe, idempotent) if you intentionally added a new LMS hostname.
#
# Usage:
#   ./scripts/qa/microsite-onboarding-checklist.sh
#   ./scripts/qa/microsite-onboarding-checklist.sh --env prod
#   ./scripts/qa/microsite-onboarding-checklist.sh --apply-authentik
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

ENV_SCOPE="both"
APPLY_AUTHENTIK=0

usage() {
  cat <<'EOF' >&2
Usage: ./scripts/qa/microsite-onboarding-checklist.sh [--env prod|dev|both] [--apply-authentik]
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --env)
      ENV_SCOPE="${2:-}"; shift 2 ;;
    --apply-authentik)
      APPLY_AUTHENTIK=1; shift ;;
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

echo "Microsite/hostname onboarding checklist"
echo "  env: $ENV_SCOPE"
echo ""

echo "[1/3] Regenerate canonical hostname registry doc"
./scripts/gen/update-openedx-hostnames-doc.sh
echo ""

if [[ "$APPLY_AUTHENTIK" -eq 1 ]]; then
  echo "[2/3] Apply Authentik OIDC redirect URI allowlist (intentional change)"
  ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --apply
else
  echo "[2/3] Verify Authentik OIDC redirect URI allowlist"
  ./scripts/infra/ensure-authentik-oidc-redirect-uris.sh --verify
fi
echo ""

echo "[3/3] Run full auth/access audit"
./scripts/qa/audit-auth-access.sh --env "$ENV_SCOPE"

