#!/usr/bin/env bash
# Auto-generate k8s override file for resource requests
# This script creates the override.yml file that sets memory requests to 512Mi
# for core Open edX deployments.
#
# Usage:
#   ./scripts/infra/setup-k8s-overrides.sh
#
# Reference: TUTOR_K8S_OVERRIDE_GUIDE.md

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OVERRIDE_FILE="$REPO_ROOT/tutor_env/env/k8s/override.yml"
KUSTOMIZATION_FILE="$REPO_ROOT/tutor_env/env/kustomization.yml"

echo "=== Setting up Tutor k8s-override configuration ==="
echo ""

# Check if tutor_env exists
if [ ! -d "$REPO_ROOT/tutor_env/env/k8s" ]; then
  echo "❌ ERROR: tutor_env/env/k8s directory not found"
  echo "   Please run 'tutor config save' first to initialize Tutor environment"
  exit 1
fi

# Create override.yml
echo "Creating override.yml with 512Mi memory requests..."
cat > "$OVERRIDE_FILE" <<'EOF'
---
# Tutor k8s-override: Set memory requests to 512Mi for core deployments
# This file persists resource configurations across `tutor config save` operations
# Created: 2025-11-21
# Reference: https://docs.tutor.edly.io/k8s.html

# CMS deployment - reduce memory from 2Gi to 512Mi
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cms
spec:
  template:
    spec:
      containers:
        - name: cms
          resources:
            requests:
              memory: 512Mi

---
# CMS worker deployment - set memory to 512Mi
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cms-worker
spec:
  template:
    spec:
      containers:
        - name: cms-worker
          resources:
            requests:
              memory: 512Mi

---
# LMS deployment - reduce memory from 2Gi to 512Mi
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lms
spec:
  template:
    spec:
      containers:
        - name: lms
          resources:
            requests:
              memory: 512Mi

---
# LMS worker deployment - set memory to 512Mi
apiVersion: apps/v1
kind: Deployment
metadata:
  name: lms-worker
spec:
  template:
    spec:
      containers:
        - name: lms-worker
          resources:
            requests:
              memory: 512Mi

---
# MFE deployment - set memory to 512Mi
apiVersion: apps/v1
kind: Deployment
metadata:
  name: mfe
spec:
  template:
    spec:
      containers:
        - name: mfe
          resources:
            requests:
              memory: 512Mi
EOF

echo "✅ Created $OVERRIDE_FILE"

# Update kustomization.yml to include the override
if grep -q "patchesStrategicMerge" "$KUSTOMIZATION_FILE"; then
  if grep -q "k8s/override.yml" "$KUSTOMIZATION_FILE"; then
    echo "✅ kustomization.yml already references override.yml"
  else
    echo "⚠️  WARNING: kustomization.yml has patchesStrategicMerge but doesn't include override.yml"
    echo "   You may need to manually add 'k8s/override.yml' to patchesStrategicMerge"
  fi
else
  echo "⚠️  WARNING: kustomization.yml doesn't have patchesStrategicMerge section"
  echo "   This may have been regenerated. The override needs to be added to kustomization.yml"
  echo ""
  echo "   Add this section after 'resources:' in $KUSTOMIZATION_FILE:"
  echo ""
  echo "   # Strategic merge patches for resource overrides"
  echo "   patchesStrategicMerge:"
  echo "   - k8s/override.yml"
fi

echo ""
echo "Next steps:"
echo "  1. Verify configuration: ./scripts/infra/verify-k8s-overrides.sh"
echo "  2. Apply to cluster: tutor k8s start"
echo "  3. Verify in cluster: kubectl get deployments -n openedx -o custom-columns=NAME:.metadata.name,MEMORY:.spec.template.spec.containers[0].resources.requests.memory"
echo ""
echo "See TUTOR_K8S_OVERRIDE_GUIDE.md for detailed documentation"
