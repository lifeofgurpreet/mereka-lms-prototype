#!/usr/bin/env bash
# Verify k8s-override patches are correctly applied to deployments
# This script checks that memory requests are set to 512Mi for core deployments
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEPLOYMENTS_FILE="$REPO_ROOT/tutor_env/env/k8s/deployments.yml"
OVERRIDE_FILE="$REPO_ROOT/tutor_env/env/k8s/override.yml"
KUSTOMIZATION_FILE="$REPO_ROOT/tutor_env/env/kustomization.yml"

echo "=== Verifying Tutor k8s-override Configuration ==="
echo ""

# Check if override file exists
if [ ! -f "$OVERRIDE_FILE" ]; then
  echo "❌ ERROR: override.yml not found at $OVERRIDE_FILE"
  exit 1
fi
echo "✅ override.yml exists"

# Check if kustomization includes the override
if ! grep -q "patchesStrategicMerge" "$KUSTOMIZATION_FILE"; then
  echo "❌ ERROR: kustomization.yml does not include patchesStrategicMerge"
  exit 1
fi
if ! grep -q "k8s/override.yml" "$KUSTOMIZATION_FILE"; then
  echo "❌ ERROR: kustomization.yml does not reference k8s/override.yml"
  exit 1
fi
echo "✅ kustomization.yml includes override.yml in patchesStrategicMerge"

# Verify each deployment in override file
DEPLOYMENTS=("cms" "cms-worker" "lms" "lms-worker" "mfe")
echo ""
echo "Checking override.yml contains patches for:"
for deployment in "${DEPLOYMENTS[@]}"; do
  if grep -q "name: $deployment" "$OVERRIDE_FILE"; then
    echo "  ✅ $deployment"
  else
    echo "  ❌ $deployment (missing)"
  fi
done

# Show current memory settings in deployments.yml
echo ""
echo "Current memory requests in deployments.yml:"
for deployment in "${DEPLOYMENTS[@]}"; do
  # Extract memory value for this deployment
  memory=$(awk -v dep="$deployment" '
    $0 ~ "name: " dep "$" { found=1 }
    found && /memory:/ { print $2; exit }
  ' "$DEPLOYMENTS_FILE")

  if [ -n "$memory" ]; then
    echo "  $deployment: $memory"
  else
    echo "  $deployment: (no memory request set)"
  fi
done

echo ""
echo "Expected memory after override applies: 512Mi for all deployments"
echo ""
echo "To apply these overrides to your cluster:"
echo "  1. Run: tutor k8s start"
echo "  2. Or: kubectl apply -k tutor_env/env"
echo ""
echo "To verify applied resources in cluster:"
echo "  kubectl get deployment -n openedx cms -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}'"
echo "  kubectl get deployment -n openedx lms -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}'"
echo "  kubectl get deployment -n openedx mfe -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}'"
