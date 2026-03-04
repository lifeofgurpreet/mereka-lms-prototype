#!/usr/bin/env bash
# @covers AC-007
# @spec: branding-system_spec.md
set -euo pipefail

# Deploy branded OpenEdX image to GKE
# Usage: ./scripts/branding/deploy-branded-image.sh [TAG]

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

TAG="${1:-mereka-brand}"
IMAGE_BASE="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"
NAMESPACE="${NAMESPACE:-mereka-lms}"
KUBECTL_CONTEXT="${KUBECTL_CONTEXT:-}"

DEST_IMAGE="${IMAGE_BASE}/openedx:${TAG}"
SOURCE_IMAGE="${SOURCE_IMAGE:-}"

KUBECTL_ARGS=()
if [[ -n "$KUBECTL_CONTEXT" ]]; then
  KUBECTL_ARGS+=(--context "$KUBECTL_CONTEXT")
fi

echo "=== Deploying branded OpenEdX image ==="
echo "Tag: $TAG"
echo "Registry: $IMAGE_BASE"
echo "Namespace: $NAMESPACE"
echo "Destination image: $DEST_IMAGE"
if [[ -n "$KUBECTL_CONTEXT" ]]; then
  echo "Kubernetes context: $KUBECTL_CONTEXT"
fi
echo ""

# Step 0: Verify branding health before pushing
echo "Step 0: Verifying branding health..."
"$REPO_ROOT/scripts/branding/verify-branding-health.sh"

# Step 1: Verify image exists locally
echo ""
echo "Step 1: Checking local image..."
if [[ -z "$SOURCE_IMAGE" ]]; then
  if docker image inspect "$DEST_IMAGE" >/dev/null 2>&1; then
    SOURCE_IMAGE="$DEST_IMAGE"
  elif docker image inspect "tutor_local/openedx:latest" >/dev/null 2>&1; then
    SOURCE_IMAGE="tutor_local/openedx:latest"
  else
    echo "ERROR: No local Open edX image found."
    echo "  Looked for: $DEST_IMAGE and tutor_local/openedx:latest"
    echo "  Run: tutor images build openedx"
    exit 1
  fi
fi
echo "  Using source image: $SOURCE_IMAGE"

# Step 2: Tag for Artifact Registry
echo ""
echo "Step 2: Tagging image for Artifact Registry..."
if [[ "$SOURCE_IMAGE" != "$DEST_IMAGE" ]]; then
  docker tag "$SOURCE_IMAGE" "$DEST_IMAGE"
fi
echo "  Tagged: $DEST_IMAGE"

# Step 3: Push to Artifact Registry
echo ""
echo "Step 3: Pushing to Artifact Registry..."
docker push "$DEST_IMAGE"
echo "  Push complete."

# Step 4: Update K8s deployments
echo ""
echo "Step 4: Updating Kubernetes deployments..."

DEPLOYMENTS=("lms" "cms" "lms-worker" "cms-worker")
for DEPLOY in "${DEPLOYMENTS[@]}"; do
  echo "  Updating ${DEPLOY}..."
  kubectl "${KUBECTL_ARGS[@]}" set image "deployment/${DEPLOY}" \
    "${DEPLOY}=${DEST_IMAGE}" \
    -n "${NAMESPACE}"
done

# Step 5: Wait for rollouts
echo ""
echo "Step 5: Waiting for rollouts..."
for DEPLOY in "${DEPLOYMENTS[@]}"; do
  echo "  Waiting for ${DEPLOY}..."
  kubectl "${KUBECTL_ARGS[@]}" rollout status "deployment/${DEPLOY}" -n "${NAMESPACE}" --timeout=300s
done

# Step 6: Verify
echo ""
echo "Step 6: Verifying deployments..."
kubectl "${KUBECTL_ARGS[@]}" get pods -n "${NAMESPACE}" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}' | grep openedx | head -10

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
echo "  kubectl set image deployment/lms lms=\${PREVIOUS_IMAGE} -n ${NAMESPACE}"
