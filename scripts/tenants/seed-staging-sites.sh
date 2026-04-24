#!/usr/bin/env bash
# seed-staging-sites.sh — Idempotent seed/repair for Django Site + SiteConfiguration
#                         rows across all staging tenants.
#
# Creates or updates Site and SiteConfiguration for each staging tenant.
# Safe to re-run: uses get_or_create / update_or_create throughout.
#
# Usage:
#   scripts/tenants/seed-staging-sites.sh [--namespace NS] [--dry-run]
#
# Requires: kubectl, python3
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

DRY_RUN=false

# ── Arg parsing ───────────────────────────────────────────────────────────────
# Note: --namespace may override the env file default; parse before sourcing.
_NS_OVERRIDE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --namespace) _NS_OVERRIDE="${2:?--namespace requires a value}"; shift 2 ;;
    --dry-run)   DRY_RUN=true; shift ;;
    -h|--help)   echo "Usage: $0 [--namespace NS] [--dry-run]"; exit 0 ;;
    *)           echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# ── Load environment constants ────────────────────────────────────────────────
# shellcheck source=env/staging.env
source "${SCRIPT_DIR}/env/staging.env"
[[ -n "$_NS_OVERRIDE" ]] && NAMESPACE="$_NS_OVERRIDE"

command -v kubectl &>/dev/null || { echo "ERROR: kubectl required" >&2; exit 1; }

# ── Discover LMS pod ─────────────────────────────────────────────────────────
_POD_LIST=$(kubectl get pods -n "$NAMESPACE" \
  -l app.kubernetes.io/name=lms \
  --field-selector=status.phase=Running \
  -o jsonpath='{range .items[*]}{.metadata.name} {.status.containerStatuses[0].ready}{"\n"}{end}' 2>/dev/null || true)
LMS_POD=$(echo "$_POD_LIST" | awk '$2 == "true" { print $1; exit }')
[[ -z "$LMS_POD" ]] && { echo "ERROR: no ready LMS pod in namespace $NAMESPACE" >&2; exit 1; }

echo "=== seed-staging-sites: namespace=$NAMESPACE lms=$LMS_POD ==="
[[ "$DRY_RUN" == "true" ]] && echo "=== DRY RUN — no writes will be made ==="
echo ""

# ── Run seed ──────────────────────────────────────────────────────────────────
# shellcheck source=lib/site-reconcile-common.sh
source "${SCRIPT_DIR}/lib/site-reconcile-common.sh"
run_seed
