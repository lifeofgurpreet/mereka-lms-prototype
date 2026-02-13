#!/usr/bin/env bash
# Verify fixes for beads mereka-lms-3f8g, mereka-lms-2pne, mereka-lms-dcd
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

echo "Verifying bead fixes..."
echo ""

# Color codes for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass_count=0
fail_count=0
warn_count=0

check_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((pass_count++))
}

check_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    ((fail_count++))
}

check_warn() {
    echo -e "${YELLOW}⚠ WARN${NC}: $1"
    ((warn_count++))
}

echo "=== Bead 1: mereka-lms-3f8g - Course Authoring Directory Fix ==="
echo ""

# Check if patch function exists in apply-patches.sh
if grep -q "def ensure_mfe_course_authoring_directory_fix" infrastructure/tutor/apply-patches.sh; then
    check_pass "Patch function ensure_mfe_course_authoring_directory_fix exists"
else
    check_fail "Patch function ensure_mfe_course_authoring_directory_fix not found"
fi

# Check if patch is called
if grep -q "updated = ensure_mfe_course_authoring_directory_fix(updated)" infrastructure/tutor/apply-patches.sh; then
    check_pass "Patch function is called in apply-patches.sh"
else
    check_fail "Patch function is not called in apply-patches.sh"
fi

# Check if patch is documented in manifest
if grep -q "mfe-course-authoring-directory" infrastructure/tutor/patch-manifest.yml; then
    check_pass "Patch documented in patch-manifest.yml"
else
    check_fail "Patch not documented in patch-manifest.yml"
fi

# Check if patch was applied (only if tutor_env exists)
if [ -f "tutor_env/env/plugins/mfe/build/mfe/Dockerfile" ]; then
    if grep -q "ln -sf /openedx/app/frontend-app-course-authoring /openedx/app/course-authoring" tutor_env/env/plugins/mfe/build/mfe/Dockerfile; then
        check_pass "Symlink patch applied to MFE Dockerfile"
    else
        check_warn "Symlink not found in MFE Dockerfile (run 'tutor config save && ./infrastructure/tutor/apply-patches.sh')"
    fi
else
    check_warn "tutor_env not initialized (run 'tutor config save' first)"
fi

echo ""
echo "=== Bead 2: mereka-lms-2pne - MFE Cache Headers ==="
echo ""

# Check if cache headers patch function exists
if grep -q "def ensure_mfe_cache_headers" infrastructure/tutor/apply-patches.sh; then
    check_pass "Patch function ensure_mfe_cache_headers exists"
else
    check_fail "Patch function ensure_mfe_cache_headers not found"
fi

# Check if patch is called
if grep -q "updated = ensure_mfe_cache_headers(updated)" infrastructure/tutor/apply-patches.sh; then
    check_pass "Patch function is called in apply-patches.sh"
else
    check_fail "Patch function is not called in apply-patches.sh"
fi

# Check if patches are documented
if grep -q "mfe-cache-headers-html" infrastructure/tutor/patch-manifest.yml && \
   grep -q "mfe-cache-headers-static" infrastructure/tutor/patch-manifest.yml; then
    check_pass "Cache header patches documented in patch-manifest.yml"
else
    check_fail "Cache header patches not fully documented in patch-manifest.yml"
fi

# Check if patch was applied (only if tutor_env exists)
if [ -f "tutor_env/env/apps/caddy/Caddyfile" ]; then
    if grep -q "Cache-Control" tutor_env/env/apps/caddy/Caddyfile && \
       grep -q "no-cache" tutor_env/env/apps/caddy/Caddyfile; then
        check_pass "Cache headers applied to Caddyfile"
    else
        check_warn "Cache headers not found in Caddyfile (run 'tutor config save && ./infrastructure/tutor/apply-patches.sh')"
    fi
else
    check_warn "tutor_env not initialized (run 'tutor config save' first)"
fi

echo ""
echo "=== Bead 3: mereka-lms-dcd - ArgoCD ConfigMap Ignore ==="
echo ""

# Check if patch file exists
if [ -f "deploy/k8s/patches/argocd-configmap-ignore.yaml" ]; then
    check_pass "ArgoCD patch file exists"
else
    check_fail "ArgoCD patch file not found"
fi

# Check if README exists
if [ -f "deploy/k8s/patches/README.md" ]; then
    check_pass "Patches README.md exists"
else
    check_fail "Patches README.md not found"
fi

# Check if patch is documented
if grep -q "argocd-configmap-ignore" infrastructure/tutor/patch-manifest.yml; then
    check_pass "ArgoCD patch documented in patch-manifest.yml"
else
    check_fail "ArgoCD patch not documented in patch-manifest.yml"
fi

# Check if patch has required labels
if grep -q "app.kubernetes.io/name" deploy/k8s/patches/argocd-configmap-ignore.yaml; then
    check_pass "ArgoCD patch has required labels"
else
    check_fail "ArgoCD patch missing app.kubernetes.io/name label"
fi

# Check if ignoreDifferences section exists
if grep -q "ignoreDifferences" deploy/k8s/patches/argocd-configmap-ignore.yaml && \
   grep -q "openedx-overrides-runtime-css" deploy/k8s/patches/argocd-configmap-ignore.yaml; then
    check_pass "ArgoCD patch includes ignoreDifferences configuration"
else
    check_fail "ArgoCD patch missing ignoreDifferences configuration"
fi

echo ""
echo "=== Summary ==="
echo ""
echo -e "${GREEN}Passed:${NC} $pass_count"
echo -e "${YELLOW}Warnings:${NC} $warn_count"
echo -e "${RED}Failed:${NC} $fail_count"
echo ""

if [ $fail_count -eq 0 ]; then
    echo -e "${GREEN}All critical checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Apply patches: tutor config save && ./infrastructure/tutor/apply-patches.sh"
    echo "2. Test locally: make qa-smoke"
    echo "3. Apply ArgoCD patch: kubectl patch application mereka-lms -n argocd --type=merge --patch-file=deploy/k8s/patches/argocd-configmap-ignore.yaml"
    echo "4. Monitor pod stability: kubectl get pods -n mereka-lms -w"
    exit 0
else
    echo -e "${RED}Some checks failed. Please review the output above.${NC}"
    exit 1
fi
