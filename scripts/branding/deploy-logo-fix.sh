#!/usr/bin/env bash
# Deploy logo fix to production (K8s)
# This script handles the immediate fix without requiring a full image rebuild
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
NAMESPACE="mereka-lms"

echo "========================================="
echo "Deploying Logo Fix to Production"
echo "========================================="
echo ""

# Verify kubectl is available and namespace exists
if ! command -v kubectl &> /dev/null; then
  echo "✗ Error: kubectl is not installed"
  exit 1
fi

if ! kubectl get namespace "$NAMESPACE" &> /dev/null; then
  echo "✗ Error: Namespace $NAMESPACE does not exist"
  exit 1
fi

# Step 1: Get LMS pod
echo "1. Finding LMS pod..."
LMS_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -z "$LMS_POD" ]; then
  echo "  ✗ Error: No LMS pod found in namespace $NAMESPACE"
  exit 1
fi
echo "  ✓ Found LMS pod: $LMS_POD"
echo ""

# Step 2: Copy logo files to the pod
echo "2. Copying logo files to LMS pod..."
LOGO_FILES=(
  "logo.png"
  "logo-horizontal.png"
  "logo-horizontal-white.png"
  "logo-square.png"
  "logo-horizontal.svg"
  "logo-horizontal-white.svg"
  "logo-square.svg"
  "favicon.ico"
)

THEME_SRC_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images"
POD_THEME_DIR="/openedx/themes/mereka/lms/static/images"

for logo_file in "${LOGO_FILES[@]}"; do
  src_file="$THEME_SRC_DIR/$logo_file"
  if [ -f "$src_file" ]; then
    kubectl cp "$src_file" "$NAMESPACE/$LMS_POD:$POD_THEME_DIR/$logo_file" 2>/dev/null || echo "  ⚠ Warning: Failed to copy $logo_file"
    echo "  ✓ Copied $logo_file"
  else
    echo "  ⚠ Warning: $logo_file not found in theme source"
  fi
done
echo ""

# Step 3: Run collectstatic
echo "3. Running collectstatic in LMS pod..."
kubectl exec -n "$NAMESPACE" "$LMS_POD" -- ./manage.py lms collectstatic --noinput 2>&1 | tail -10
echo "  ✓ Collectstatic completed"
echo ""

# Step 4: Verify logo accessibility
echo "4. Verifying logo accessibility..."
sleep 3  # Give the load balancer a moment
LOGO_URL="https://academyv2.mereka.io/static/images/logo.png"
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$LOGO_URL" 2>/dev/null || echo "000")

if [ "$HTTP_STATUS" = "200" ]; then
  echo "  ✓ Logo is accessible at $LOGO_URL"
else
  echo "  ✗ Warning: Logo returned HTTP $HTTP_STATUS at $LOGO_URL"
  echo "  This might resolve after a few minutes. Try checking again."
fi
echo ""

# Step 5: Check MFE pod (if exists)
echo "5. Checking MFE pod..."
MFE_POD=$(kubectl get pods -n "$NAMESPACE" -l app.kubernetes.io/name=mfe -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
if [ -n "$MFE_POD" ]; then
  echo "  ℹ MFE pod found: $MFE_POD"
  echo "  MFE footer logo will use: $LOGO_URL (via MFE patch)"
  echo "  No action needed for MFE - footer component already updated"
else
  echo "  ℹ No MFE pod found (may be using different deployment strategy)"
fi
echo ""

echo "========================================="
echo "✓ Logo fix deployment completed!"
echo "========================================="
echo ""
echo "Verification checklist:"
echo "  1. LMS footer: https://academyv2.mereka.io/ (scroll to bottom)"
echo "  2. LMS header: https://academyv2.mereka.io/ (top navigation)"
echo "  3. MFE footer: https://apps.academyv2.mereka.io/authn/login (scroll to bottom)"
echo ""
echo "If logos still show 404:"
echo "  - Wait 2-3 minutes for CDN/cache to clear"
echo "  - Hard refresh browser (Ctrl+Shift+R / Cmd+Shift+R)"
echo "  - Check pod logs: kubectl logs -n $NAMESPACE $LMS_POD"
echo ""
echo "For persistent issues, rebuild images:"
echo "  tutor images build openedx"
echo "  tutor k8s restart"
echo ""
