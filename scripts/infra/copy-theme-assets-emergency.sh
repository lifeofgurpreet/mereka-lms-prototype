#!/usr/bin/env bash
# Emergency script to copy theme assets to running pods
# USE ONLY when logo files return 404 and image rebuild is not immediately possible
#
# IMPORTANT: This is a TEMPORARY fix. Files will be lost on pod restart.
# Permanent fix requires rebuilding the OpenedX Docker image.

set -euo pipefail

NAMESPACE="mereka-lms"

echo "=========================================="
echo "EMERGENCY THEME ASSETS COPY"
echo "=========================================="
echo
echo "⚠️  WARNING: This is a TEMPORARY fix!"
echo "    Files will be lost on pod restart."
echo "    Permanent fix requires image rebuild."
echo
read -p "Continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 1
fi

echo
echo "Copying logo assets to LMS pod..."
echo

# Copy to primary images path
echo "1. Copying to /openedx/staticfiles/images/"
kubectl exec -n "$NAMESPACE" deployment/lms -- bash -c \
  "cp /openedx/themes/mereka/common/static/images/logo-*.png /openedx/staticfiles/images/ && \
   cp /openedx/themes/mereka/common/static/images/logo-*.svg /openedx/staticfiles/images/ && \
   chmod 644 /openedx/staticfiles/images/logo-*"

# Copy to mereka subdirectory path
echo "2. Copying to /openedx/staticfiles/mereka/images/"
kubectl exec -n "$NAMESPACE" deployment/lms -- bash -c \
  "mkdir -p /openedx/staticfiles/mereka/images && \
   cp /openedx/themes/mereka/common/static/images/logo-*.png /openedx/staticfiles/mereka/images/ && \
   cp /openedx/themes/mereka/common/static/images/logo-*.svg /openedx/staticfiles/mereka/images/ && \
   chmod 644 /openedx/staticfiles/mereka/images/logo-*"

echo
echo "Verifying files..."
echo

kubectl exec -n "$NAMESPACE" deployment/lms -- bash -c \
  "ls -lh /openedx/staticfiles/images/logo-*.png"

echo
echo "=========================================="
echo "✅ Emergency fix applied successfully"
echo "=========================================="
echo
echo "Next steps:"
echo "  1. Test logo URLs return HTTP 200"
echo "  2. Schedule Docker image rebuild for permanent fix"
echo "  3. See reports/2026/closures/LOGO-404-EMERGENCY-FIX.md"
echo
