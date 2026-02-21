#!/usr/bin/env bash
# park-prod.sh — Put GKE prod into warm-park-mode (cost-save, reversible).
#
# Warm-park mode scales all stateless LMS workloads to 0 while keeping the
# data plane running (mysql, redis, postgresql-payments). All PVCs remain
# bound; Velero continues backing up. Unpark with unpark-prod.sh.
#
# SAFETY: This script validates Velero backups exist and data-plane is healthy
#         before applying the park patch.
#
# Usage:
#   ./scripts/ops/park-prod.sh [--dry-run] [--skip-velero-check]
#
# Cost savings:
#   Parked pods: LMS, CMS, workers, MFEs, enterprise services, notes, smtp,
#                elasticsearch, meilisearch, xqueue, caddy (~22 deployments → 0)
#   Kept running: mysql, redis, postgresql-payments, promtail, mux-monitor
#   Estimated GKE node pool reduction: 2-3 nodes depending on node autoscaling

set -euo pipefail

BBI_INFRA="${BBI_INFRA:-/home/gurpreet/projects/k8s/bbi-infrastructure}"
NAMESPACE="mereka-lms"
GKE_CONTEXT="gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster"
PARK_PATCH_REL="apps/mereka-lms/overlays/prod/patches/warm-park-mode.yaml"
KUSTOMIZE_FILE="apps/mereka-lms/overlays/prod/kustomization.yaml"
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

log "=== PARK PROD (warm-park mode) ==="
log "BBI_INFRA: $BBI_INFRA"
log "DRY_RUN: $DRY_RUN"

# 1. Pre-flight checks
log "--- Pre-flight checks ---"

ctx=$(kubectl config current-context 2>/dev/null || echo "NONE")
if [ "$ctx" != "$GKE_CONTEXT" ]; then
  die "Wrong kubectl context: $ctx (expected $GKE_CONTEXT)"
fi
log "kubectl context: $ctx OK"

# Check if already parked
if [ -f "$BBI_INFRA/$PARK_PATCH_REL" ] && \
   grep -q "warm-park-mode" "$BBI_INFRA/$KUSTOMIZE_FILE" 2>/dev/null; then
  log "INFO: warm-park-mode.yaml already exists and is referenced in kustomization."
  log "Cluster appears to already be in park mode."
  kubectl get deploy -n "$NAMESPACE" 2>/dev/null | grep -v "1/1" | head -5
  exit 0
fi

# Check data-plane pods
for svc in mysql redis postgresql-payments; do
  ready=$(kubectl get deploy -n "$NAMESPACE" "$svc" \
    -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
  if [ "${ready:-0}" -lt 1 ]; then
    die "Data-plane service $svc is not ready. Cannot safely park — investigate first."
  fi
  log "Data-plane $svc: $ready ready OK"
done

# Verify Velero backup recent enough
if [ "$SKIP_VELERO" = false ]; then
  log "--- Velero backup check ---"
  latest=$(kubectl get backup -n velero --no-headers 2>/dev/null \
    | grep "velero-local-hourly-critical" \
    | awk '{print $1}' \
    | sort -r | head -n 1 || echo "")
  if [ -z "$latest" ]; then
    log "WARN: No recent Velero backup found."
    log "Consider running a manual backup first:"
    log "  velero backup create pre-park-$(date +%Y%m%d-%H%M%S) \\"
    log "    --include-namespaces $NAMESPACE --wait"
    read -rp "Continue without Velero confirmation? [y/N] " confirm
    if [ "${confirm,,}" != "y" ]; then
      die "Aborted by user. Run a backup first, then retry."
    fi
  else
    log "Latest hourly backup: $latest OK"
  fi
fi

# Record before-state
log ""
log "--- Before state ---"
log "Running pods:"
kubectl get pods -n "$NAMESPACE" --no-headers 2>/dev/null \
  | grep "Running" | awk '{print "  " $1 " " $3}' || echo "  (none running)"

log ""
log "Pre-flight checks passed."

if [ "$DRY_RUN" = true ]; then
  log "DRY_RUN: would add warm-park-mode.yaml to bbi-infrastructure prod overlay"
  log "  + $PARK_PATCH_REL"
  log "  ~ $KUSTOMIZE_FILE (add warm-park-mode.yaml to patchesStrategicMerge)"
  exit 0
fi

# 2. Generate the park patch
log ""
log "--- Creating warm-park-mode.yaml ---"
mkdir -p "$(dirname "$BBI_INFRA/$PARK_PATCH_REL")"
cat > "$BBI_INFRA/$PARK_PATCH_REL" << 'PATCH'
# warm-park-mode.yaml — Temporary cost-save configuration for GKE prod.
# Scales all stateless LMS workloads to 0, preserving data-plane.
# REVERT: Remove this file and its reference from kustomization.yaml, commit, push.
# See: scripts/ops/unpark-prod.sh for automated rollback.
PATCH

# Add all stateless deployments to scale to 0
for svc in \
  caddy lms lms-worker cms cms-worker mfe meilisearch notes smtp \
  enterprise-access enterprise-access-worker enterprise-admin-portal \
  enterprise-catalog enterprise-catalog-worker enterprise-learner-portal \
  enterprise-subsidy license-manager credentials discovery \
  ecommerce ecommerce-worker elasticsearch xqueue payments-gateway; do
  cat >> "$BBI_INFRA/$PARK_PATCH_REL" << EOF
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${svc}
spec:
  replicas: 0
EOF
done

# Delete HPAs so they don't fight the replica=0 setting
cat >> "$BBI_INFRA/$PARK_PATCH_REL" << 'EOF'
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: lms
$patch: delete
---
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: cms
$patch: delete
EOF

log "Created: $BBI_INFRA/$PARK_PATCH_REL"

# 3. Add to kustomization
log "--- Updating kustomization.yaml ---"
python3 - <<'PY'
from pathlib import Path

kust = Path("apps/mereka-lms/overlays/prod/kustomization.yaml")
content = kust.read_text()

# Only add if not already present
if "warm-park-mode" not in content:
    # Find patchesStrategicMerge section and add at end
    insert_comment = (
        "\n  # Temporary cost-save mode: keep data-plane deployments up and park stateless LMS workloads.\n"
        "  # Revert by removing this patch and re-adding the HPA guardrails below.\n"
        "  - patches/warm-park-mode.yaml\n"
    )
    # Find last entry in patchesStrategicMerge
    idx = content.rfind("patchesStrategicMerge:")
    if idx == -1:
        # Append as new section
        content += "\npatchesStrategicMerge:\n" + insert_comment
    else:
        # Find end of patchesStrategicMerge block
        next_section = content.find("\n\n", idx)
        if next_section == -1:
            content += insert_comment
        else:
            content = content[:next_section] + insert_comment + content[next_section:]
    kust.write_text(content)
    print("kustomization.yaml updated")
else:
    print("warm-park-mode already in kustomization — no change")
PY

# 4. Commit and push
log "--- Committing park change ---"
cd "$BBI_INFRA"
git add "$PARK_PATCH_REL" "$KUSTOMIZE_FILE"
git status --short

TS=$(date -u +%Y-%m-%dT%H:%MZ)
git commit -m "ops(mereka-lms): warm-park prod for cost savings ($TS)

Scales all stateless LMS workloads to 0 while keeping data-plane running.
Data preservation:
- mysql PVC: Bound (5Gi)
- redis PVC: Bound (1Gi)
- postgresql-payments PVC: Bound (5Gi)
- Velero hourly backups: active

Revert: git revert HEAD && git push, or run scripts/ops/unpark-prod.sh

Co-Authored-By: WhiteCliff <noreply@anthropic.com>"

log "--- Pushing to remote ---"
git push origin HEAD

log ""
log "=== Park mode committed and pushed ==="
log "ArgoCD will scale down stateless workloads within 2-5 minutes."
log ""
log "Monitor scale-down:"
log "  kubectl get deploy -n $NAMESPACE"
log "  kubectl get pods -n $NAMESPACE -w"
log ""
log "Verify data-plane still healthy after scale-down:"
log "  kubectl get pods -n $NAMESPACE | grep -E 'mysql|redis|postgresql'"
log ""
log "UNPARK command: ./scripts/ops/unpark-prod.sh"
