#!/usr/bin/env bash
# @covers AC-TCR-001, AC-TCR-002, AC-TCR-003
# @spec: tutor-configuration-resilience_spec.md
# Verification script for Mereka LMS Tutor plugin
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
source "$REPO_ROOT/infrastructure/tutor/tutor-env.sh"

echo "Mereka LMS Plugin Verification"
echo "==============================="
echo

# Check plugin is enabled
echo "1. Checking if plugin is enabled..."
if tutor plugins list 2>/dev/null | grep -q "mereka_lms"; then
    echo "   ✓ Plugin is enabled"
else
    echo "   ✗ Plugin is NOT enabled"
    echo "   Run: tutor plugins enable mereka_lms"
    exit 1
fi

# Check configuration
echo
echo "2. Checking plugin configuration..."
VERSION=$(tutor config printvalue MEREKA_LMS_VERSION 2>/dev/null || echo "not set")
if [ "$VERSION" != "not set" ]; then
    echo "   ✓ MEREKA_LMS_VERSION: $VERSION"
else
    echo "   ✗ MEREKA_LMS_VERSION not set"
    echo "   Run: tutor config save"
    exit 1
fi

# Check generated LMS settings
echo
echo "3. Checking generated LMS settings..."
LMS_SETTINGS="$REPO_ROOT/tutor_env/env/apps/openedx/settings/lms/production.py"
if [ -f "$LMS_SETTINGS" ]; then
    if grep -q "MEREKA_LMS_EXTRA_HOSTS" "$LMS_SETTINGS"; then
        echo "   ✓ LMS settings contain Mereka patches"
    else
        echo "   ⚠ LMS settings exist but don't contain Mereka patches"
        echo "   Run: tutor config save"
    fi
else
    echo "   ✗ LMS settings file not found"
    echo "   Run: tutor config save"
    exit 1
fi

# Check Dockerfile has custom apps
echo
echo "4. Checking Open edX Dockerfile..."
DOCKERFILE="$REPO_ROOT/tutor_env/env/build/openedx/Dockerfile"
if [ -f "$DOCKERFILE" ]; then
    if grep -q "mfe_oauth_fix" "$DOCKERFILE"; then
        echo "   ✓ Dockerfile contains custom app patches"
    else
        echo "   ⚠ Dockerfile exists but doesn't contain custom apps"
        echo "   Run: tutor config save"
    fi
else
    echo "   ✗ Dockerfile not found"
    echo "   Run: tutor config save"
    exit 1
fi

# Check MFE Dockerfile
echo
echo "5. Checking MFE Dockerfile..."
MFE_DOCKERFILE="$REPO_ROOT/tutor_env/env/plugins/mfe/build/mfe/Dockerfile"
if [ -f "$MFE_DOCKERFILE" ]; then
    if grep -q "NODE_OPTIONS" "$MFE_DOCKERFILE" || grep -q "g++" "$MFE_DOCKERFILE"; then
        echo "   ✓ MFE Dockerfile contains Mereka patches"
    else
        echo "   ⚠ MFE Dockerfile exists but may be missing patches"
    fi
else
    echo "   ℹ MFE Dockerfile not found (may not be using MFE plugin)"
fi

# Check custom apps exist
echo
echo "6. Checking custom apps..."
CUSTOM_APPS="$REPO_ROOT/infrastructure/tutor/custom-apps"
if [ -d "$CUSTOM_APPS/mfe_oauth_fix" ]; then
    echo "   ✓ mfe_oauth_fix app exists"
else
    echo "   ✗ mfe_oauth_fix app NOT found"
    exit 1
fi

if [ -d "$CUSTOM_APPS/openedx_prometheus" ]; then
    echo "   ✓ openedx_prometheus app exists"
else
    echo "   ✗ openedx_prometheus app NOT found"
    exit 1
fi

echo
echo "==============================="
echo "✓ Plugin verification passed"
echo
echo "Next steps:"
echo "  1. Build images: tutor images build openedx mfe"
echo "  2. Test locally: tutor local launch"
echo "  3. Verify services: curl -I http://localhost"
