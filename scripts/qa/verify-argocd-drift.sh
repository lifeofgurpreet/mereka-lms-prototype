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
#   ./scripts/qa/verify-argocd-drift.sh --app mereka-lms-staging --offline
#   ./scripts/qa/verify-argocd-drift.sh --app mereka-lms-prod --online
#   ./scripts/qa/verify-argocd-drift.sh --app mereka-lms-staging --online --offline
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
  [mereka-lms-staging]="apps/mereka-lms/overlays/staging"
  [mereka-lms-prod]="apps/mereka-lms/overlays/prod"
)
declare -A EXPECTED_REPO_URL=(
  [mereka-lms-dev]="https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git"
  [mereka-lms-staging]="https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git"
  [mereka-lms-prod]="https://github.com/Biji-Biji-Initiative/bbi-infrastructure.git"
)
declare -A EXPECTED_DEST_NAMESPACE=(
  [mereka-lms-dev]="mereka-lms-dev"
  [mereka-lms-staging]="stg-mereka-lms"
  [mereka-lms-prod]="mereka-lms"
)
declare -A EXPECTED_MANIFEST_PATH=(
  [mereka-lms-dev]="argocd/applicationsets/mereka-lms-dev.yaml"
  [mereka-lms-staging]="argocd/applications/mereka-lms-staging.yaml"
  [mereka-lms-prod]="argocd/applications/mereka-lms-prod.yaml"
)
declare -A EXPECTED_OWNER_KIND=(
  [mereka-lms-dev]="ApplicationSet"
  [mereka-lms-staging]="Application"
  [mereka-lms-prod]="Application"
)
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

read_manifest_contract() {
  local manifest_path="$1"
  local owner_kind="$2"

  python3 - "$manifest_path" "$owner_kind" <<'PY'
from __future__ import annotations

import json
from pathlib import Path
import sys

import yaml


path = Path(sys.argv[1])
owner_kind = sys.argv[2]
doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
spec = doc.get("spec") or {}
if owner_kind == "ApplicationSet":
    spec = (spec.get("template") or {}).get("spec") or {}

source = spec.get("source") or {}
destination = spec.get("destination") or {}
sync_policy = spec.get("syncPolicy") or {}
automated = sync_policy.get("automated") or {}
sync_options = sorted(sync_policy.get("syncOptions") or [])

print(source.get("path", ""))
print(source.get("repoURL", ""))
print(destination.get("namespace", ""))
print(str(automated.get("prune", "")).lower())
print(str(automated.get("selfHeal", "")).lower())
print(json.dumps(sync_options))
PY
}

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
    --app <name>    ArgoCD Application name (mereka-lms-dev, mereka-lms-staging, or mereka-lms-prod)
    --offline       Validate git manifests (no cluster access)
    --online        Live cluster checks via kubectl
    --help          Show this help

EXAMPLES:
    $(basename "$0") --app mereka-lms-dev --offline
    $(basename "$0") --app mereka-lms-staging --offline
    $(basename "$0") --app mereka-lms-prod --online
    $(basename "$0") --app mereka-lms-staging --online --offline
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
  app_manifest="${BBI_INFRA}/${EXPECTED_MANIFEST_PATH[$APP_NAME]}"
  owner_kind="${EXPECTED_OWNER_KIND[$APP_NAME]}"
  if [[ -f "$app_manifest" ]]; then
    pass "${owner_kind} manifest exists: ${app_manifest}"

    mapfile -t manifest_contract < <(read_manifest_contract "$app_manifest" "$owner_kind")
    manifest_path="${manifest_contract[0]:-}"
    manifest_repo="${manifest_contract[1]:-}"
    manifest_namespace="${manifest_contract[2]:-}"
    manifest_prune="${manifest_contract[3]:-}"
    manifest_selfheal="${manifest_contract[4]:-}"
    manifest_sync_options_json="${manifest_contract[5]:-[]}"

    if [[ "$manifest_path" == "$expected_path" ]]; then
      pass "manifest source.path matches expected: ${expected_path}"
    else
      fail "manifest source.path '${manifest_path}' != expected '${expected_path}'"
    fi

    if [[ "$manifest_repo" == "$expected_repo" ]]; then
      pass "manifest source.repoURL matches expected"
    else
      fail "manifest source.repoURL '${manifest_repo}' != expected '${expected_repo}'"
    fi

    if [[ "$manifest_namespace" == "${EXPECTED_DEST_NAMESPACE[$APP_NAME]}" ]]; then
      pass "manifest destination.namespace matches expected: ${EXPECTED_DEST_NAMESPACE[$APP_NAME]}"
    else
      fail "manifest destination.namespace '${manifest_namespace}' != expected '${EXPECTED_DEST_NAMESPACE[$APP_NAME]}'"
    fi

    if [[ "$manifest_prune" == "true" || "$manifest_prune" == "false" ]]; then
      pass "manifest automated prune declared: ${manifest_prune}"
    else
      fail "manifest automated prune missing or invalid"
    fi

    if [[ "$manifest_selfheal" == "true" || "$manifest_selfheal" == "false" ]]; then
      pass "manifest automated selfHeal declared: ${manifest_selfheal}"
    else
      fail "manifest automated selfHeal missing or invalid"
    fi

    if [[ "$manifest_sync_options_json" == "[]" ]]; then
      warn "manifest syncOptions list is empty"
    else
      pass "manifest syncOptions declared"
    fi
  else
    fail "${owner_kind} manifest not found: ${app_manifest}"
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

      # 5. ApplicationSet drift detection (dev only, generated from a dedicated ApplicationSet)
      if [[ "$APP_NAME" == "mereka-lms-dev" ]]; then
        echo ""
        echo "--- ApplicationSet drift detection ---"

        appset_json=$(kubectl get applicationset mereka-lms-dev -n "$ARGOCD_NAMESPACE" -o json 2>/dev/null || echo "")
        if [[ -z "$appset_json" ]]; then
          warn "ApplicationSet 'mereka-lms-dev' not found (may not be deployed to this cluster)"
        else
          pass "ApplicationSet 'mereka-lms-dev' found in cluster"

          # Compare the in-cluster ApplicationSet template path
          live_template_path=$(echo "$appset_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
tmpl = d.get('spec',{}).get('template',{}).get('spec',{}).get('source',{})
print(tmpl.get('path',''))
" 2>/dev/null || echo "")

          if [[ "$live_template_path" == "${EXPECTED_SOURCE_PATH[$APP_NAME]}" ]]; then
            pass "ApplicationSet template path matches git: ${live_template_path}"
          else
            fail "ApplicationSet template path unexpected: ${live_template_path}"
          fi

          live_template_ns=$(echo "$appset_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
tmpl = d.get('spec',{}).get('template',{}).get('spec',{}).get('destination',{})
print(tmpl.get('namespace',''))
" 2>/dev/null || echo "")

          if [[ "$live_template_ns" == "${EXPECTED_DEST_NAMESPACE[$APP_NAME]}" ]]; then
            pass "ApplicationSet template namespace matches git: ${live_template_ns}"
          else
            fail "ApplicationSet template namespace unexpected: ${live_template_ns}"
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
      app_manifest="${BBI_INFRA}/${EXPECTED_MANIFEST_PATH[$APP_NAME]}"
      owner_kind="${EXPECTED_OWNER_KIND[$APP_NAME]}"
      if [[ ! -f "$app_manifest" ]]; then
        warn "cannot compare sync policy to git: manifest missing at ${app_manifest}"
      else
        mapfile -t manifest_contract < <(read_manifest_contract "$app_manifest" "$owner_kind")
        manifest_prune="${manifest_contract[3]:-}"
        manifest_selfheal="${manifest_contract[4]:-}"
        manifest_sync_options_json="${manifest_contract[5]:-[]}"

        automated_prune=$(echo "$app_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
sp = d.get('spec',{}).get('syncPolicy',{}).get('automated',{})
prune = sp.get('prune', False)
selfHeal = sp.get('selfHeal', False)
print(f'{str(prune).lower()},{str(selfHeal).lower()}')
" 2>/dev/null || echo "False,False")

        live_sync_options_json=$(echo "$app_json" | python3 -c "
import sys,json
d=json.load(sys.stdin)
sync_options = sorted(d.get('spec',{}).get('syncPolicy',{}).get('syncOptions',[]))
print(json.dumps(sync_options))
" 2>/dev/null || echo "[]")

        prune_val="${automated_prune%%,*}"
        selfheal_val="${automated_prune##*,}"

        if [[ "$prune_val" == "$manifest_prune" ]]; then
          pass "automated prune matches git: ${manifest_prune}"
        else
          fail "DRIFT: automated prune '${prune_val}' != git '${manifest_prune}'"
        fi

        if [[ "$selfheal_val" == "$manifest_selfheal" ]]; then
          pass "automated selfHeal matches git: ${manifest_selfheal}"
        else
          fail "DRIFT: automated selfHeal '${selfheal_val}' != git '${manifest_selfheal}'"
        fi

        if [[ "$live_sync_options_json" == "$manifest_sync_options_json" ]]; then
          pass "syncOptions match git"
        else
          fail "DRIFT: syncOptions ${live_sync_options_json} != git ${manifest_sync_options_json}"
        fi
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
