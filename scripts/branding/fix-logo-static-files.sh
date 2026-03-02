#!/usr/bin/env bash
# Emergency fix script for logo 404 issues
# This script syncs logo files and runs collectstatic without needing a full rebuild
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

echo "========================================="
echo "Mereka Academy Logo Static Files Fix"
echo "========================================="
echo ""

# Step 1: Sync logo files to build directory
echo "1. Syncing logo files to build directory..."
THEME_BUILD_DIR="$REPO_ROOT/tutor_env/env/build/openedx/themes/mereka"
if [ ! -d "$THEME_BUILD_DIR" ]; then
  echo "  ✗ Error: Theme build directory not found at $THEME_BUILD_DIR"
  echo "  Run 'tutor config save' first to generate the build directory."
  exit 1
fi

# Copy all logo variants to LMS
mkdir -p "$THEME_BUILD_DIR/lms/static/images"
COPIED_COUNT=0
for logo_file in logo.png logo-horizontal.png logo-horizontal-white.png logo-square.png \
                 logo-horizontal.svg logo-horizontal-white.svg logo-square.svg \
                 favicon.ico; do
  src_file="$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/static/images/$logo_file"
  if [ -f "$src_file" ]; then
    cp "$src_file" "$THEME_BUILD_DIR/lms/static/images/$logo_file"
    echo "  ✓ Copied $logo_file to LMS theme"
    ((COPIED_COUNT++))
  else
    echo "  ⚠ Warning: $logo_file not found in theme source"
  fi
done

# Copy to CMS if it exists
if [ -d "$THEME_BUILD_DIR/cms" ]; then
  mkdir -p "$THEME_BUILD_DIR/cms/static/images"
  for logo_file in logo.png logo-horizontal.png logo-horizontal-white.png logo-square.png \
                   logo-horizontal.svg logo-horizontal-white.svg logo-square.svg \
                   favicon.ico; do
    src_file="$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/static/images/$logo_file"
    if [ -f "$src_file" ]; then
      cp "$src_file" "$THEME_BUILD_DIR/cms/static/images/$logo_file"
      echo "  ✓ Copied $logo_file to CMS theme"
      ((COPIED_COUNT++))
    fi
  done
fi

echo "  Total files copied: $COPIED_COUNT"
echo ""

# Step 2: Check if we should run collectstatic
echo "2. Running collectstatic..."
cd "$REPO_ROOT"

# Check if running locally or on K8s
if command -v tutor &> /dev/null; then
  # Check if local environment is running
  if docker ps --filter "name=tutor_local-lms-1" --format "{{.Names}}" | grep -q "tutor_local-lms-1"; then
    echo "  Running collectstatic in local environment..."
    export TUTOR_ROOT="$REPO_ROOT/tutor_env"
    tutor local run lms ./manage.py lms collectstatic --noinput 2>&1 | tail -10
    echo "  ✓ Collectstatic completed for local environment"
  else
    echo "  ⚠ Local environment is not running. Skipping collectstatic."
    echo "  To run collectstatic manually:"
    echo "    tutor local run lms ./manage.py lms collectstatic --noinput"
  fi
fi

# Check if K8s is available
if command -v kubectl &> /dev/null; then
  if kubectl get namespace mereka-lms &> /dev/null; then
    echo "  Running collectstatic in K8s..."
    LMS_POD=$(kubectl get pods -n mereka-lms -l app.kubernetes.io/name=lms -o jsonpath='{.items[0].metadata.name}' 2>/dev/null || echo "")
    if [ -n "$LMS_POD" ]; then
      kubectl exec -n mereka-lms "$LMS_POD" -- ./manage.py lms collectstatic --noinput 2>&1 | tail -10
      echo "  ✓ Collectstatic completed for K8s"
    else
      echo "  ⚠ No LMS pod found in K8s. Skipping collectstatic."
      echo "  To run collectstatic manually:"
      echo "    kubectl exec -n mereka-lms <lms-pod-name> -- ./manage.py lms collectstatic --noinput"
    fi
  fi
fi

echo ""
echo "========================================="
echo "✓ Logo static files fix completed!"
echo "========================================="
echo ""
echo "Verification steps:"
echo "1. Check that logo files are in build directory:"
echo "   ls -la $THEME_BUILD_DIR/lms/static/images/logo*.png"
echo ""
echo "2. Verify logo is accessible (production):"
echo "   curl -I https://academyv2.mereka.io/static/images/logo.png"
echo ""
echo "3. If issues persist, rebuild and redeploy:"
echo "   tutor images build openedx"
echo "   tutor local restart (or kubectl rollout restart)"
echo ""
