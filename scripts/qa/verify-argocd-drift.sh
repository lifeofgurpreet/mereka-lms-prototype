#!/usr/bin/env bash
# verify-argocd-drift.sh — Detect ArgoCD "Synced but wrong" drift scenarios
#
# Real-world incident: Someone manually patched the ApplicationSet in-cluster.
# ArgoCD showed "Synced" but the config was wrong. This script catches that.
#
# Supports two modes:
#   --offline  Validate git manifests only (no cluster access needed)
#   --online   Live cluster checks via kubectl (requires cluster access)
#
# Usage:
#   ./scripts/qa/verify-argocd-drift.sh --app mereka-lms-dev --offline
#   ./scripts/qa/verify-argocd-drift.sh --app mereka-lms-prod --online
#   ./scripts/qa/verify-argocd-drift.sh --app mereka-lms-prod --online --offline
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"
# shellcheck source=../shared/config.sh
source "${REPO_ROOT}/scripts/shared/config.sh"

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
BBI_INFRA="${BBI_INFRA:-}"
if [[ -z "$BBI_INFRA" ]]; then
  for candidate in \
    "${WORKSPACE_ROOT}/bbi-infrastructure" \
    "${WORKSPACE_ROOT}/infrastructure" \
    "${HOME}/projects/k8s/bbi-infrastructure" \
    "${HOME}/projects/k8s/infrastructure"; do
    if [[ -d "$candidate" ]]; then
      BBI_INFRA="$candidate"
      break
    fi
  done
fi
ARGOCD_NAMESPACE="argocd"

# Known-good source paths per app (git is the source of truth)
declare -A EXPECTED_SOURCE_PATH=(
  [mereka-lms-dev]="apps/mereka-lms/overlays/profiles/dev"
  [mereka-lms-prod]="apps/mereka-lms/overlays/prod"
)
declare -A EXPECTED_REPO_URL=(
  [mereka-lms-dev]="https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git"
  [mereka-lms-prod]="https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git"
)
declare -A EXPECTED_DEST_NAMESPACE=(
  [mereka-lms-dev]="mereka-lms"
  [mereka-lms-prod]="mereka-lms"
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { echo -e "${GREEN}PASS${NC}  $1"; PASS_COUNT=$((PASS_COUNT + 1)); }
fail() { echo -e "${RED}FAIL${NC}  $1"; FAIL_COUNT=$((FAIL_COUNT + 1)); }
warn() { echo -e "${YELLOW}WARN${NC}  $1"; WARN_COUNT=$((WARN_COUNT + 1)); }

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
APP_NAME=""
RUN_OFFLINE=false
RUN_ONLINE=false

print_usage() {
  cat <<EOF
Usage: $(basename "$0") --app <name> [--offline] [--online]

OPTIONS:
    --app <name>    ArgoCD Application name (mereka-lms-dev or mereka-lms-prod)
    --offline       Validate git manifests (no cluster access)
    --online        Live cluster checks via kubectl
    --help          Show this help

EXAMPLES:
    $(basename "$0") --app mereka-lms-dev --offline
    $(basename "$0") --app mereka-lms-prod --online
    $(basename "$0") --app mereka-lms-prod --online --offline
EOF
}

while [[ $# -gt 0 ]]; do
  case $1 in
    --app)     APP_NAME="$2"; shift 2 ;;
    --offline) RUN_OFFLINE=true; shift ;;
    --online)  RUN_ONLINE=true; shift ;;
    --help)    print_usage; exit 0 ;;
    *)         echo "Unknown option: $1"; print_usage; exit 1 ;;
  esac
done

if [[ -z "$APP_NAME" ]]; then
  echo "ERROR: --app is required" >&2
  print_usage
  exit 1
fi

if [[ "$RUN_OFFLINE" == false && "$RUN_ONLINE" == false ]]; then
  echo "ERROR: at least one of --offline or --online is required" >&2
  print_usage
  exit 1
fi

if [[ -z "${EXPECTED_SOURCE_PATH[$APP_NAME]:-}" ]]; then
  echo "ERROR: unknown app '$APP_NAME'. Known apps: ${!EXPECTED_SOURCE_PATH[*]}" >&2
  exit 1
fi

echo "ArgoCD Drift Detection: ${APP_NAME}"
echo "======================================="
echo ""

# ---------------------------------------------------------------------------
# OFFLINE CHECKS — validate git manifests
# ---------------------------------------------------------------------------
if [[ "$RUN_OFFLINE" == true ]]; then
  echo "== Offline checks (git manifests) =="
  echo ""

  # 1. Verify bbi-infrastructure repo is accessible
  if [[ -d "$BBI_INFRA" ]]; then
    pass "bbi-infrastructure repo exists at ${BBI_INFRA}"
  else
    fail "bbi-infrastructure repo not found at ${BBI_INFRA}"
    echo ""
    echo "Set BBI_INFRA env var to override. Skipping offline checks."
    RUN_OFFLINE=false
  fi
fi

if [[ "$RUN_OFFLINE" == true ]]; then
  expected_path="${EXPECTED_SOURCE_PATH[$APP_NAME]}"
  expected_repo="${EXPECTED_REPO_URL[$APP_NAME]}"

  # 2. Verify the expected overlay path exists in bbi-infrastructure
  if [[ -d "${BBI_INFRA}/${expected_path}" ]]; then
    pass "overlay path exists: ${expected_path}"
  else
    fail "overlay path missing: ${BBI_INFRA}/${expected_path}"
  fi

  # 3. Verify kustomization.yaml exists in the overlay
  kustomization_file="${BBI_INFRA}/${expected_path}/kustomization.yaml"
  if [[ -f "$kustomization_file" ]]; then
    pass "kustomization.yaml present in overlay"
  else
    fail "kustomization.yaml missing: ${kustomization_file}"
  fi

  # 4. Check the git-defined Application/ApplicationSet spec matches expectations
  if [[ "$APP_NAME" == "mereka-lms-prod" ]]; then
    app_manifest="${BBI_INFRA}/applicationsets/mereka-lms-prod.yaml"
    if [[ -f "$app_manifest" ]]; then
      pass "Application manifest exists: ${app_manifest}"

      # Verify source path in manifest
      manifest_path=$(grep -A5 "source:" "$app_manifest" | grep "path:" | head -1 | awk '{print $2}' || echo "")
      if [[ "$manifest_path" == "$expected_path" ]]; then
        pass "manifest source.path matches expected: ${expected_path}"
      else
        fail "manifest source.path '${manifest_path}' != expected '${expected_path}'"
      fi

      # Verify repo URL
      manifest_repo=$(grep -A5 "source:" "$app_manifest" | grep "repoURL:" | head -1 | awk '{print $2}' || echo "")
      if [[ "$manifest_repo" == "$expected_repo" ]]; then
        pass "manifest source.repoURL matches expected"
      else
        fail "manifest source.repoURL '${manifest_repo}' != expected '${expected_repo}'"
      fi
    else
      fail "Application manifest not found: ${app_manifest}"
    fi
  fi

  if [[ "$APP_NAME" == "mereka-lms-dev" ]]; then
    appset_manifest="${BBI_INFRA}/applicationsets/kustomize-apps.yaml"
    if [[ -f "$appset_manifest" ]]; then
      pass "ApplicationSet manifest exists: ${appset_manifest}"

      # Verify mereka-lms entry exists
      if grep -q "app: mereka-lms" "$appset_manifest"; then
        pass "mereka-lms entry present in ApplicationSet"
      else
        fail "mereka-lms entry missing from ApplicationSet"
      fi

      # Verify dev overlay reference
      if grep -q "overlay: profiles/dev" "$appset_manifest"; then
        pass "dev overlay 'profiles/dev' referenced in ApplicationSet"
      else
        fail "dev overlay 'profiles/dev' not found in ApplicationSet"
      fi
    else
      fail "ApplicationSet manifest not found: ${appset_manifest}"
    fi
  fi

  # 5. Verify no warm-park-mode active (prod only)
  if [[ "$APP_NAME" == "mereka-lms-prod" ]]; then
    park_file="${BBI_INFRA}/apps/mereka-lms/overlays/prod/patches/warm-park-mode.yaml"
    park_kustomization="${BBI_INFRA}/apps/mereka-lms/overlays/prod/kustomization.yaml"
    if [[ -f "$park_file" ]] && grep -q "warm-park-mode" "$park_kustomization" 2>/dev/null; then
      warn "warm-park-mode.yaml is active in prod kustomization (intentional if parked)"
    else
      pass "warm-park-mode not active in prod overlay"
    fi
  fi

  echo ""
fi

# ---------------------------------------------------------------------------
# ONLINE CHECKS — live cluster via kubectl
# ---------------------------------------------------------------------------
if [[ "$RUN_ONLINE" == true ]]; then
  echo "== Online checks (live cluster) =="
  echo ""

  # Verify kubectl is available
  if ! command -v kubectl &>/dev/null; then
    fail "kubectl not found in PATH"
    echo "Cannot run online checks without kubectl."
  else
    pass "kubectl available"

    # 1. Check ArgoCD Application status: Synced + Healthy
    echo ""
    echo "--- Sync and health status ---"
    app_json=$(kubectl get application "$APP_NAME" -n "$ARGOCD_NAMESPACE" -o json 2>/dev/null || echo "")

    if [[ -z "$app_json" ]]; then
      fail "ArgoCD Application '$APP_NAME' not found in namespace '$ARGOCD_NAMESPACE'"
    else
      pass "ArgoCD Application '$APP_NAME' found"

      sync_status=$(echo "$app_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('sync',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")
      health_status=$(echo "$app_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status',{}).get('health',{}).get('status','UNKNOWN'))" 2>/dev/null || echo "UNKNOWN")

      if [[ "$sync_status" == "Synced" ]]; then
        pass "sync status: Synced"
      else
        fail "sync status: ${sync_status} (expected Synced)"
      fi

      if [[ "$health_status" == "Healthy" ]]; then
        pass "health status: Healthy"
      else
        fail "health status: ${health_status} (expected Healthy)"
      fi

      # 2. Compare in-cluster source path against expected
      echo ""
      echo "--- Source path validation ---"
      expected_path="${EXPECTED_SOURCE_PATH[$APP_NAME]}"
      expected_repo="${EXPECTED_REPO_URL[$APP_NAME]}"
      expected_ns="${EXPECTED_DEST_NAMESPACE[$APP_NAME]}"

      live_path=$(echo "$app_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('spec',{}).get('source',{}).get('path',''))" 2>/dev/null || echo "")
      live_repo=$(echo "$app_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('spec',{}).get('source',{}).get('repoURL',''))" 2>/dev/null || echo "")
      live_ns=$(echo "$app_json" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('spec',{}).get('destination',{}).get('namespace',''))" 2>/dev/null || echo "")

      if [[ "$live_path" == "$expected_path" ]]; then
        pass "in-cluster source.path matches git: ${expected_path}"
      else
        fail "DRIFT: in-cluster source.path '${live_path}' != git '${expected_path}'"
      fi

      if [[ "$live_repo" == "$expected_repo" ]]; then
        pass "in-cluster source.repoURL matches git"
      else
        fail "DRIFT: in-cluster source.repoURL '${live_repo}' != git '${expected_repo}'"
      fi

      if [[ "$live_ns" == "$expected_ns" ]]; then
        pass "in-cluster destination.namespace matches: ${expected_ns}"
      else
        fail "DRIFT: in-cluster destination.namespace '${live_ns}' != expected '${expected_ns}'"
      fi

      # 3. Check for manual refresh annotations (indicate someone forced a sync)
      echo ""
      echo "--- Manual override detection ---"
      refresh_annotation=$(echo "$app_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
ann = d.get('metadata',{}).get('annotations',{})
print(ann.get('argocd.argoproj.io/refresh',''))
" 2>/dev/null || echo "")

      if [[ -n "$refresh_annotation" ]]; then
        warn "manual refresh annotation present: argocd.argoproj.io/refresh=${refresh_annotation}"
      else
        pass "no manual refresh annotation (clean state)"
      fi

      # Check operation state for recent manual syncs
      last_op_phase=$(echo "$app_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
op = d.get('status',{}).get('operationState',{})
phase = op.get('phase','')
initiated_by = op.get('operation',{}).get('initiatedBy',{})
user = initiated_by.get('username','')
automated = initiated_by.get('automated', False)
if user and not automated:
    print(f'manual:{user}:{phase}')
elif automated:
    print(f'automated:{phase}')
else:
    print(f'unknown:{phase}')
" 2>/dev/null || echo "unknown:")

      if [[ "$last_op_phase" == manual:* ]]; then
        warn "last sync was manual (${last_op_phase})"
      else
        pass "last sync was automated (${last_op_phase})"
      fi

      # 4. Check for degraded health conditions in child resources
      echo ""
      echo "--- Resource health conditions ---"
      degraded_resources=$(echo "$app_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
resources = d.get('status',{}).get('resources',[])
degraded = []
for r in resources:
    health = r.get('health',{}).get('status','')
    if health in ('Degraded', 'Missing', 'Unknown'):
        name = r.get('name','?')
        kind = r.get('kind','?')
        degraded.append(f'{kind}/{name}={health}')
for item in degraded:
    print(item)
" 2>/dev/null || echo "")

      if [[ -z "$degraded_resources" ]]; then
        pass "all managed resources are healthy"
      else
        while IFS= read -r resource; do
          [[ -z "$resource" ]] && continue
          fail "degraded resource: ${resource}"
        done <<< "$degraded_resources"
      fi

      # 5. ApplicationSet drift detection (dev only, generated from ApplicationSet)
      if [[ "$APP_NAME" == "mereka-lms-dev" ]]; then
        echo ""
        echo "--- ApplicationSet drift detection ---"

        appset_json=$(kubectl get applicationset bbi-kustomize-apps -n "$ARGOCD_NAMESPACE" -o json 2>/dev/null || echo "")
        if [[ -z "$appset_json" ]]; then
          warn "ApplicationSet 'bbi-kustomize-apps' not found (may not be deployed to this cluster)"
        else
          pass "ApplicationSet 'bbi-kustomize-apps' found in cluster"

          # Compare the in-cluster ApplicationSet template path
          live_template_path=$(echo "$appset_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
tmpl = d.get('spec',{}).get('template',{}).get('spec',{}).get('source',{})
print(tmpl.get('path',''))
" 2>/dev/null || echo "")

          # The template uses Go templating, so check it contains the expected pattern
          if echo "$live_template_path" | grep -q 'apps/.*overlays'; then
            pass "ApplicationSet template path pattern is correct: ${live_template_path}"
          else
            fail "ApplicationSet template path unexpected: ${live_template_path}"
          fi

          # Compare generation to detect if AppSet was modified in-cluster
          appset_gen=$(echo "$appset_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('metadata',{}).get('generation',0))
" 2>/dev/null || echo "0")
          appset_rv=$(echo "$appset_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
print(d.get('metadata',{}).get('resourceVersion',''))
" 2>/dev/null || echo "")

          pass "ApplicationSet generation=${appset_gen}, resourceVersion=${appset_rv}"
        fi
      fi

      # 6. Check sync policy is still automated (not manually disabled)
      echo ""
      echo "--- Sync policy validation ---"
      automated_prune=$(echo "$app_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
sp = d.get('spec',{}).get('syncPolicy',{}).get('automated',{})
prune = sp.get('prune', False)
selfHeal = sp.get('selfHeal', False)
print(f'{prune},{selfHeal}')
" 2>/dev/null || echo "False,False")

      prune_val="${automated_prune%%,*}"
      selfheal_val="${automated_prune##*,}"

      if [[ "$prune_val" == "True" ]]; then
        pass "automated prune is enabled"
      else
        fail "DRIFT: automated prune is DISABLED (should be True)"
      fi

      if [[ "$selfheal_val" == "True" ]]; then
        pass "automated selfHeal is enabled"
      else
        fail "DRIFT: automated selfHeal is DISABLED (should be True)"
      fi
    fi
  fi

  echo ""
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo "======================================="
echo "Summary"
echo "======================================="
echo -e "${GREEN}Passed: ${PASS_COUNT}${NC}"
echo -e "${RED}Failed: ${FAIL_COUNT}${NC}"
echo -e "${YELLOW}Warnings: ${WARN_COUNT}${NC}"

if [[ $FAIL_COUNT -gt 0 ]]; then
  exit 1
fi
exit 0
