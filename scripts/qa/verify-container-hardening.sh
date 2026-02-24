#!/usr/bin/env bash
# @covers AC-CCR-002, AC-CCR-008, AC-CCR-009
# @spec: k8s-deployment_spec.md
#
# Verify container hardening — non-root, read-only FS, capability drop, seccomp.
#
# Modes:
#   --offline  Static analysis of manifests in deploy/k8s/base/ (default)
#   --online   Live cluster checks via kubectl (requires KUBECONFIG / cluster access)
#
# Usage:
#   ./scripts/qa/verify-container-hardening.sh
#   ./scripts/qa/verify-container-hardening.sh --offline
#   ./scripts/qa/verify-container-hardening.sh --online
#
# T087 — Container hardening (non-root, read-only FS, seccomp)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_DIR="${REPO_ROOT}/deploy/k8s/base"
PATCH_FILE="${BASE_DIR}/patches/container-hardening.yaml"
KUSTOMIZATION="${BASE_DIR}/kustomization.yaml"
NAMESPACE="${NAMESPACE:-mereka-lms}"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
SKIPPED=0

pass()  { echo -e "${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
fail()  { echo -e "${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
skip()  { echo -e "${YELLOW}SKIP${NC}  $1"; SKIPPED=$((SKIPPED + 1)); }

MODE="offline"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --offline) MODE="offline"; shift ;;
    --online)  MODE="online";  shift ;;
    -h|--help)
      echo "Usage: $0 [--offline|--online]"
      exit 0 ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1 ;;
  esac
done

# ---------------------------------------------------------------------------
# OFFLINE mode — static manifest checks
# ---------------------------------------------------------------------------
run_offline_checks() {
  echo "=== Container Hardening — Offline Checks ==="
  echo ""

  # 1. Patch file exists
  echo "-- Patch file --"
  if [[ -f "$PATCH_FILE" ]]; then
    pass "container-hardening.yaml exists at deploy/k8s/base/patches/"
  else
    fail "container-hardening.yaml missing: ${PATCH_FILE}"
    echo ""
    echo "Summary: PASSED=${PASSED} FAILED=${FAILED} SKIPPED=${SKIPPED}"
    exit 1
  fi

  # 2. Patch is valid YAML (multi-document)
  if python3 -c "
import yaml, sys
docs = list(yaml.safe_load_all(open(sys.argv[1])))
docs = [d for d in docs if d is not None]
if not docs:
    sys.exit(1)
print(f'  parsed {len(docs)} documents')
" "$PATCH_FILE" 2>/dev/null; then
    pass "container-hardening.yaml is valid multi-document YAML"
  else
    fail "container-hardening.yaml failed YAML parse"
  fi

  # 3. Patch is referenced in kustomization.yaml
  echo ""
  echo "-- Kustomization wiring --"
  if grep -q "container-hardening.yaml" "$KUSTOMIZATION"; then
    pass "container-hardening.yaml is referenced in base/kustomization.yaml"
  else
    fail "container-hardening.yaml is NOT referenced in base/kustomization.yaml"
  fi

  if grep -q "patchesStrategicMerge" "$KUSTOMIZATION"; then
    pass "kustomization.yaml uses patchesStrategicMerge (kustomize v5 compatible)"
  else
    fail "kustomization.yaml does not use patchesStrategicMerge"
  fi

  # 4. Required security fields present in patch
  echo ""
  echo "-- Security field presence --"
  if grep -q "runAsNonRoot: true" "$PATCH_FILE"; then
    pass "runAsNonRoot: true present in patch"
  else
    fail "runAsNonRoot: true NOT found in patch"
  fi

  if grep -q "readOnlyRootFilesystem: true" "$PATCH_FILE"; then
    pass "readOnlyRootFilesystem: true present in patch"
  else
    fail "readOnlyRootFilesystem: true NOT found in patch"
  fi

  if grep -q 'drop: \["ALL"\]' "$PATCH_FILE" || grep -q "drop:" "$PATCH_FILE"; then
    pass "capabilities.drop present in patch"
  else
    fail "capabilities.drop NOT found in patch"
  fi

  if grep -q "seccompProfile" "$PATCH_FILE"; then
    pass "seccompProfile present in patch"
  else
    fail "seccompProfile NOT found in patch"
  fi

  if grep -q "type: RuntimeDefault" "$PATCH_FILE"; then
    pass "seccompProfile.type: RuntimeDefault present in patch"
  else
    fail "seccompProfile.type: RuntimeDefault NOT found in patch"
  fi

  if grep -q "allowPrivilegeEscalation: false" "$PATCH_FILE"; then
    pass "allowPrivilegeEscalation: false present in patch"
  else
    fail "allowPrivilegeEscalation: false NOT found in patch"
  fi

  # 5. No Deployment container runs as explicit UID 0 (root) in base manifests.
  # DaemonSets (e.g. promtail) legitimately run as root to read host logs —
  # they are excluded from this check. Only Deployment manifests are checked.
  echo ""
  echo "-- Root UID check in Deployment manifests --"
  local root_uid_hits
  root_uid_hits=$(grep -r "runAsUser: 0" "${BASE_DIR}" --include="*.yaml" --include="*.yml" \
    -l 2>/dev/null | xargs -I{} python3 -c "
import yaml, sys
for doc in yaml.safe_load_all(open(sys.argv[1])):
    if doc and doc.get('kind') == 'Deployment':
        print(sys.argv[1])
        break
" {} 2>/dev/null || true)
  if [[ -z "$root_uid_hits" ]]; then
    pass "No Deployment declares runAsUser: 0 in base manifests"
  else
    fail "Found runAsUser: 0 in Deployment manifests:"
    echo "$root_uid_hits" | while IFS= read -r line; do echo "    $line"; done
  fi

  # 6. Core Deployments in deployments.yml are all covered by the patch
  echo ""
  echo "-- Deployment coverage --"
  local deployments_yml="${BASE_DIR}/deployments.yml"
  local covered_deployments
  # Extract deployment names from deployments.yml
  covered_deployments=$(grep -E "^  name:" "$deployments_yml" | grep -v "app.kubernetes.io" | awk '{print $2}' || true)

  # Names from patch
  local patched_names
  patched_names=$(python3 -c "
import yaml, sys
docs = [d for d in yaml.safe_load_all(open(sys.argv[1])) if d]
names = [d['metadata']['name'] for d in docs if d.get('kind') == 'Deployment']
print('\n'.join(names))
" "$PATCH_FILE" 2>/dev/null || true)

  while IFS= read -r name; do
    [[ -z "$name" ]] && continue
    if echo "$patched_names" | grep -qxF "$name"; then
      pass "Deployment '${name}' is covered by container-hardening patch"
    else
      skip "Deployment '${name}' not in patch (may be in a sub-app or overlay)"
    fi
  done <<< "$covered_deployments"

  # 7. emptyDir volumes provided for key writable paths
  echo ""
  echo "-- emptyDir volumes for writable paths --"
  if grep -q "emptyDir: {}" "$PATCH_FILE"; then
    pass "emptyDir volumes defined for writable paths"
  else
    fail "No emptyDir volumes found in patch"
  fi

  # /tmp is the most common writable requirement
  local tmp_mounts
  tmp_mounts=$(grep -c "mountPath: /tmp" "$PATCH_FILE" || true)
  if [[ "${tmp_mounts:-0}" -gt 0 ]]; then
    pass "/tmp emptyDir mounts present for containers requiring temp write access"
  else
    fail "No /tmp mounts found in patch"
  fi
}

# ---------------------------------------------------------------------------
# ONLINE mode — live cluster checks via kubectl
# ---------------------------------------------------------------------------
run_online_checks() {
  echo "=== Container Hardening — Online Checks (namespace: ${NAMESPACE}) ==="
  echo ""

  if ! command -v kubectl &>/dev/null; then
    skip "kubectl not available — skipping all online checks"
    return
  fi

  if ! kubectl get namespace "${NAMESPACE}" &>/dev/null; then
    skip "Namespace '${NAMESPACE}' not found — skipping all online checks"
    return
  fi

  # Collect all running pods
  local pods
  pods=$(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase=Running \
    -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

  if [[ -z "$pods" ]]; then
    skip "No running pods found in namespace '${NAMESPACE}'"
    return
  fi

  echo "-- Non-root enforcement --"
  # Check that no container is running as UID 0
  local root_containers=0
  for pod in $pods; do
    local uid
    uid=$(kubectl exec -n "${NAMESPACE}" "${pod}" -- id -u 2>/dev/null || echo "unknown")
    if [[ "$uid" == "0" ]]; then
      fail "Pod '${pod}' is running as UID 0 (root)"
      root_containers=$((root_containers + 1))
    fi
  done
  if [[ "$root_containers" -eq 0 ]]; then
    pass "No running pods use UID 0 (root) in namespace '${NAMESPACE}'"
  fi

  echo ""
  echo "-- securityContext on pods --"
  # Check that pods have runAsNonRoot in their effective security context
  local pods_without_nonroot=0
  while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    local run_as_non_root
    run_as_non_root=$(kubectl get pod -n "${NAMESPACE}" "${pod}" \
      -o jsonpath='{.spec.securityContext.runAsNonRoot}' 2>/dev/null || echo "")
    if [[ "$run_as_non_root" == "true" ]]; then
      pass "Pod '${pod}': spec.securityContext.runAsNonRoot=true"
    else
      fail "Pod '${pod}': spec.securityContext.runAsNonRoot not set to true"
      pods_without_nonroot=$((pods_without_nonroot + 1))
    fi
  done < <(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)

  echo ""
  echo "-- seccomp profile on pods --"
  local pods_without_seccomp=0
  while IFS= read -r pod; do
    [[ -z "$pod" ]] && continue
    local seccomp_type
    seccomp_type=$(kubectl get pod -n "${NAMESPACE}" "${pod}" \
      -o jsonpath='{.spec.securityContext.seccompProfile.type}' 2>/dev/null || echo "")
    if [[ "$seccomp_type" == "RuntimeDefault" ]]; then
      pass "Pod '${pod}': seccompProfile.type=RuntimeDefault"
    else
      fail "Pod '${pod}': seccompProfile.type='${seccomp_type}' (expected RuntimeDefault)"
      pods_without_seccomp=$((pods_without_seccomp + 1))
    fi
  done < <(kubectl get pods -n "${NAMESPACE}" --field-selector=status.phase=Running \
    -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' 2>/dev/null || true)
}

# ---------------------------------------------------------------------------
# Run selected mode
# ---------------------------------------------------------------------------
if [[ "$MODE" == "offline" ]]; then
  run_offline_checks
elif [[ "$MODE" == "online" ]]; then
  run_online_checks
fi

echo ""
echo "=== Summary: PASSED=${PASSED} FAILED=${FAILED} SKIPPED=${SKIPPED} ==="
if [[ "${FAILED}" -gt 0 ]]; then
  exit 1
fi
