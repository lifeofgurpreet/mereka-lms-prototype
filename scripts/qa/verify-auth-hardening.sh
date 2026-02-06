#!/usr/bin/env bash
# One-shot "world-class" verification for auth + permissions hardening.
#
# This aggregates both public and internal checks:
# - Public checks: run without credentials
# - Internal checks: require kubectl (but no secrets)
#
# Usage:
#   ./scripts/qa/verify-auth-hardening.sh
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$REPO_ROOT/scripts/shared/config.sh"

log() { echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] $*"; }

log "Verifying public auth surfaces (prod)"
STRICT_ADMIN_LOGIN_REDIRECT=1 "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" prod

log "Verifying public auth surfaces (dev)"
STRICT_ADMIN_LOGIN_REDIRECT=1 "$REPO_ROOT/scripts/qa/verify-auth-surfaces.sh" dev

log "Verifying multisite config (prod)"
STRICT=1 "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" prod

log "Verifying multisite config (dev)"
STRICT=1 "$REPO_ROOT/scripts/qa/verify-multisite-config.sh" dev

log "Verifying platform admin permissions (prod + dev)"
"$REPO_ROOT/scripts/infra/ensure-platform-admins.sh" --verify

log "Verifying Authentik admin policy (prod)"
"$REPO_ROOT/scripts/infra/ensure-authentik-admin.sh" --verify

log "Verifying OIDC provider configs (prod + dev, kubectl required)"
"$REPO_ROOT/scripts/qa/verify-oidc-provider-configs.sh" --env auto

log "OK"

