#!/usr/bin/env bash
set -euo pipefail

# Deploy branded OpenEdX image to GKE
# Usage: ./scripts/branding/deploy-branded-image.sh [TAG]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TAG="${1:-mereka-brand}"
IMAGE_BASE="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"
NAMESPACE="mereka-lms"

echo "=== Deploying branded OpenEdX image ==="
echo "Tag: $TAG"
echo "Registry: $IMAGE_BASE"
echo "Namespace: $NAMESPACE"
echo ""

# Step 0: Verify branding health before pushing
echo "Step 0: Verifying branding health..."
"$REPO_ROOT/scripts/branding/verify-branding-health.sh"

# Step 1: Verify image exists locally
echo ""
echo "Step 1: Checking local image..."
if ! docker images | grep -q "tutor_local/openedx"; then
  echo "ERROR: Local image tutor_local/openedx not found. Run 'tutor images build openedx' first."
  exit 1
fi
echo "  Local image found."

# Step 2: Tag for Artifact Registry
echo ""
echo "Step 2: Tagging image for Artifact Registry..."
docker tag tutor_local/openedx:latest "${IMAGE_BASE}/openedx:${TAG}"
echo "  Tagged: ${IMAGE_BASE}/openedx:${TAG}"

# Step 3: Push to Artifact Registry
echo ""
echo "Step 3: Pushing to Artifact Registry..."
docker push "${IMAGE_BASE}/openedx:${TAG}"
echo "  Push complete."

# Step 4: Update K8s deployments
echo ""
echo "Step 4: Updating Kubernetes deployments..."

DEPLOYMENTS=("lms" "cms" "lms-worker" "cms-worker")
for DEPLOY in "${DEPLOYMENTS[@]}"; do
  echo "  Updating ${DEPLOY}..."
  kubectl set image "deployment/${DEPLOY}" \
    "${DEPLOY}=${IMAGE_BASE}/openedx:${TAG}" \
    -n "${NAMESPACE}"
done

# Step 5: Wait for rollouts
echo ""
echo "Step 5: Waiting for rollouts..."
for DEPLOY in "${DEPLOYMENTS[@]}"; do
  echo "  Waiting for ${DEPLOY}..."
  kubectl rollout status "deployment/${DEPLOY}" -n "${NAMESPACE}" --timeout=300s
done

# Step 6: Verify
echo ""
echo "Step 6: Verifying deployments..."
kubectl get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}' | grep openedx | head -10

echo ""
echo "=== Deployment complete ==="
echo ""
echo "Visual verification checklist:"
echo "- [ ] Visit https://academyv2.mereka.io"
echo "- [ ] Check logo: Mereka horizontal logo in header"
echo "- [ ] Check colors: Teal accents (#2d898b), blue links (#295cad)"
echo "- [ ] Check footer: Custom Mereka footer"
echo "- [ ] Check fonts: Lato headings, Poppins body"
echo ""
echo "Rollback command (if needed):"
echo "  kubectl set image deployment/lms lms=docker.io/overhangio/openedx:18.2.2-indigo -n ${NAMESPACE}"
