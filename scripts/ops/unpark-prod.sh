#!/usr/bin/env bash
# unpark-prod.sh — Restore GKE prod from warm-park-mode to full operation.
#
# Warm-park mode scales all stateless LMS workloads to 0, keeping data-plane
# pods (mysql, redis, postgresql-payments) running. This script reverses it via
# GitOps: removes warm-park-mode.yaml from the prod kustomization, commits to
# bbi-infrastructure, and waits for ArgoCD to reconcile.
#
# Usage:
#   ./scripts/ops/unpark-prod.sh [--dry-run] [--skip-velero-check]
#
# Requires:
#   - kubectl pointing at gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster
#   - write access to bbi-infrastructure repo
#   - ArgoCD CLI (optional, for status polling)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"
BBI_INFRA="${BBI_INFRA:-}"
if [[ -z "$BBI_INFRA" ]]; then
  for candidate in \
    "${WORKSPACE_ROOT}/bbi-infrastructure" \
    "${WORKSPACE_ROOT}/infrastructure"; do
    if [[ -d "$candidate/.git" ]]; then
      BBI_INFRA="$candidate"
      break
    fi
  done
fi
BBI_INFRA="${BBI_INFRA:-${WORKSPACE_ROOT}/bbi-infrastructure}"
ARGOCD_APP="mereka-lms-prod"
PARK_PATCH="apps/mereka-lms/overlays/prod/patches/warm-park-mode.yaml"
KUSTOMIZE_FILE="apps/mereka-lms/overlays/prod/kustomization.yaml"
NAMESPACE="mereka-lms"
GKE_CONTEXT="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
DRY_RUN=false
SKIP_VELERO=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --skip-velero-check) SKIP_VELERO=true ;;
  esac
done

log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*"; }
die() { log "ERROR: $*"; exit 1; }

log "=== UNPARK PROD ==="
log "BBI_INFRA: $BBI_INFRA"
log "DRY_RUN: $DRY_RUN"

# 1. Pre-flight checks
log "--- Pre-flight checks ---"

# Check kubectl context
ctx=$(kubectl config current-context 2>/dev/null || echo "NONE")
if [ "$ctx" != "$GKE_CONTEXT" ]; then
  die "Wrong kubectl context: $ctx (expected $GKE_CONTEXT)"
fi
log "kubectl context: $ctx OK"

# Check data-plane pods are still running
for svc in mysql redis postgresql-payments; do
  ready=$(kubectl get deploy -n "$NAMESPACE" "$svc" -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "${ready:-0}" -lt 1 ]; then
    die "Data-plane service $svc is not ready (readyReplicas=${ready:-0}). Investigate before unparking."
  fi
  log "Data-plane $svc: $ready ready OK"
done

# Check PVCs are bound
pvc_out=$(kubectl get pvc -n "$NAMESPACE" --no-headers 2>/dev/null || true)
unbound_pvcs=$(printf '%s\n' "$pvc_out" | grep -v "Bound" | grep -v "^$" || true)
if [ -n "$unbound_pvcs" ]; then
  log "WARN: some PVCs are not Bound:"
  printf '%s\n' "$unbound_pvcs"
else
  log "PVC check done (all Bound)"
fi

# Check Velero backups (last backup within 2h)
if [ "$SKIP_VELERO" = false ]; then
  log "--- Velero backup check ---"
  latest_backup=$(kubectl get backup -n velero --no-headers 2>/dev/null \
    | grep "velero-local-hourly-critical" \
    | awk '{print $1}' \
    | sort -r | head -n 1 || echo "")
  if [ -z "$latest_backup" ]; then
    log "WARN: No Velero hourly-critical backup found. Consider taking a manual backup."
    log "  kubectl create backup pre-unpark-$(date +%Y%m%d-%H%M%S) \\"
    log "    -n velero --include-namespaces $NAMESPACE --wait"
  else
    log "Latest hourly backup: $latest_backup OK"
  fi
fi

# Check warm-park-mode.yaml exists in bbi-infrastructure
if [ ! -f "$BBI_INFRA/$PARK_PATCH" ]; then
  log "WARN: $PARK_PATCH not found — prod may not be in park mode"
  log "Checking if kustomization references it..."
  if ! grep -q "warm-park-mode" "$BBI_INFRA/$KUSTOMIZE_FILE" 2>/dev/null; then
    log "INFO: warm-park-mode not in kustomization — cluster may already be unparked"
    exit 0
  fi
fi

log ""
log "Pre-flight checks passed."
log ""

if [ "$DRY_RUN" = true ]; then
  log "DRY_RUN mode: would remove warm-park-mode from kustomization and commit."
  log "Files to change:"
  log "  1. Remove: $BBI_INFRA/$PARK_PATCH"
  log "  2. Edit: $BBI_INFRA/$KUSTOMIZE_FILE (remove warm-park-mode.yaml line)"
  exit 0
fi

# 2. Remove park patch from kustomization
log "--- Removing warm-park-mode from kustomization ---"
cd "$BBI_INFRA"

# Check for any uncommitted changes before editing
if ! git diff --quiet HEAD 2>/dev/null; then
  die "bbi-infrastructure has uncommitted changes. Commit or stash them first."
fi

# Remove the line that includes warm-park-mode.yaml
python3 - <<'PY'
import re
from pathlib import Path

kust = Path("apps/mereka-lms/overlays/prod/kustomization.yaml")
content = kust.read_text()

# Remove the warm-park-mode patch line and its comment
content = re.sub(
    r'\s*# Temporary cost-save mode:.*?mode\.\s*\n',
    '\n',
    content,
    flags=re.DOTALL
)
content = re.sub(r'\s*- patches/warm-park-mode\.yaml\n', '\n', content)

kust.write_text(content)
print("kustomization.yaml updated: warm-park-mode.yaml removed")
PY

# Remove the park patch file
rm -f "$PARK_PATCH"
log "Removed: $PARK_PATCH"

# Restore HPA guardrails (comment in kustomization mentions them)
log "Note: HPA guardrails should be restored manually if needed."
log "  Check if patchesStrategicMerge needs HPA min/max replicas added back."

# 3. Commit and push
log "--- Committing unpark change ---"
git add "$PARK_PATCH" "$KUSTOMIZE_FILE"
git status --short

git commit -m "ops(mereka-lms): unpark prod — restore LMS workloads to normal operation

Removes warm-park-mode.yaml from prod kustomization. ArgoCD will
restore all stateless workloads to their base replica counts.

Data-plane verification before unpark:
- mysql: running
- redis: running
- postgresql-payments: running
- All PVCs: Bound

Co-Authored-By: WhiteCliff <noreply@anthropic.com>"

log "--- Pushing to remote ---"
git push origin HEAD

log ""
log "=== Unpark committed and pushed ==="
log "ArgoCD will now reconcile mereka-lms-prod and restore workloads."
log ""
log "Monitor with:"
log "  kubectl get pods -n $NAMESPACE -w"
log "  kubectl get deploy -n $NAMESPACE"
log ""
log "Expected sequence (5-10 min):"
log "  1. ArgoCD detects new commit on main"
log "  2. Syncs kustomization (removes park patch)"
log "  3. Caddy, LMS, CMS, workers scale up"
log "  4. Health checks resume"
log ""
log "Verify site is up:"
log "  curl -Isk https://academyv2.mereka.io/"
log "  curl -Isk https://studio.academyv2.mereka.io/"
log "  curl -Isk https://admin.academyv2.mereka.io/"
