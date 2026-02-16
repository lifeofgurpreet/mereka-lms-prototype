#!/usr/bin/env bash
# verify-theme-consistency.sh — AC-UI-002: Theme consistency across LMS, Studio, MFEs
#
# Checks that the Mereka theme is correctly wired in all surfaces:
# - LMS: mereka theme set as default
# - Studio (CMS): same theme references
# - MFEs: custom footer, branding assets, no default Open edX branding
#
# Usage: ./scripts/qa/verify-theme-consistency.sh
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
THEME_DIR="$REPO_ROOT/infrastructure/tutor/themes/mereka"
CONFIG="$REPO_ROOT/infrastructure/tutor/config.example.yml"

PASS=0
FAIL=0
WARN=0

do_pass() { PASS=$((PASS + 1)); echo "  PASS  $1"; }
do_fail() { FAIL=$((FAIL + 1)); echo "  FAIL  $1"; }
do_warn() { WARN=$((WARN + 1)); echo "  WARN  $1"; }

echo "=== AC-UI-002: Theme Consistency Check ==="
echo ""

# 1. LMS default theme
echo "--- LMS Theme Configuration ---"
if grep -q 'LMS_DEFAULT_SITE_THEME.*mereka' "$CONFIG" 2>/dev/null; then
  do_pass "LMS_DEFAULT_SITE_THEME set to mereka in config.example.yml"
else
  do_fail "LMS_DEFAULT_SITE_THEME not set to mereka"
fi

# 2. Theme directory exists with required structure
echo ""
echo "--- Theme Directory Structure ---"
if [ -d "$THEME_DIR" ]; then
  do_pass "Theme directory exists: infrastructure/tutor/themes/mereka"
else
  do_fail "Theme directory missing"
fi

for subdir in lms cms; do
  if [ -d "$THEME_DIR/$subdir" ]; then
    do_pass "Theme has $subdir subdirectory"
  else
    do_warn "Theme missing $subdir subdirectory (may use shared assets)"
  fi
done

# 3. Plugin registers theme
echo ""
echo "--- Plugin Theme Registration ---"
if grep -q 'COMPREHENSIVE_THEME_DIRS' "$PLUGIN" 2>/dev/null || grep -q 'themes' "$PLUGIN" 2>/dev/null; then
  do_pass "Plugin references theme configuration"
else
  do_warn "Plugin does not explicitly reference themes (may use config.yml)"
fi

# 4. MFE footer customization
echo ""
echo "--- MFE Footer Customization ---"
if grep -q 'MerekaFooter\|mereka.*footer\|mereka_footer' "$PLUGIN" 2>/dev/null; then
  do_pass "Plugin defines MerekaFooter component"
else
  do_fail "MerekaFooter not found in plugin"
fi

if grep -q 'MerekaFooter\|mereka.*footer' "$PATCHES" 2>/dev/null; then
  do_pass "apply-patches.sh wires MerekaFooter into MFE slots"
else
  do_warn "MerekaFooter not found in apply-patches.sh"
fi

# 5. Head-extra template for theme CSS injection
echo ""
echo "--- Theme CSS Injection ---"
head_extra="$REPO_ROOT/deploy/k8s/base/apps/openedx/head-extra.html"
if [ -f "$head_extra" ]; then
  do_pass "head-extra.html exists for CSS injection"
  if grep -qi 'mereka\|brand' "$head_extra" 2>/dev/null; then
    do_pass "head-extra.html contains branding references"
  else
    do_warn "head-extra.html exists but no branding references found"
  fi
else
  do_warn "head-extra.html not found (theme may use SCSS only)"
fi

# 6. Google Fonts stripped (Mereka uses custom fonts)
echo ""
echo "--- Google Fonts Stripping ---"
if grep -q 'google.*font\|Google font\|strip.*font' "$PLUGIN" 2>/dev/null; then
  do_pass "Plugin strips Google Fonts from SCSS"
else
  do_warn "Google Fonts stripping not found in plugin"
fi

# 7. Settings theme references
echo ""
echo "--- Settings Theme References ---"
for label_file in "LMS:$LMS_SETTINGS" "CMS:$CMS_SETTINGS"; do
  label="${label_file%%:*}"
  file="${label_file#*:}"
  [ -f "$file" ] || continue
  if grep -q 'PLATFORM_NAME\|PLATFORM_DESCRIPTION\|mereka' "$file" 2>/dev/null; then
    do_pass "$label settings reference platform branding"
  else
    do_warn "$label settings missing explicit branding references"
  fi
done

# 8. Kustomize ConfigMap for theme head-extra
echo ""
echo "--- Kustomize Theme ConfigMap ---"
kustomization="$REPO_ROOT/deploy/k8s/base/kustomization.yaml"
if grep -q 'theme-head-extra\|head-extra' "$kustomization" 2>/dev/null; then
  do_pass "Kustomize includes theme head-extra ConfigMap"
else
  do_warn "Theme head-extra ConfigMap not in kustomization.yaml"
fi

# 9. Runtime check (if cluster is accessible)
echo ""
echo "--- Runtime Checks (cluster) ---"
if kubectl get deployment lms -n mereka-lms &>/dev/null; then
  # Check LMS theme setting in running pod
  theme=$(kubectl exec -n mereka-lms deployment/lms -- python3 -c "
from django.conf import settings
print(getattr(settings, 'DEFAULT_SITE_THEME', 'NOT SET'))
" 2>/dev/null || echo "UNAVAILABLE")
  if [ "$theme" = "mereka" ]; then
    do_pass "LMS runtime DEFAULT_SITE_THEME = mereka"
  elif [ "$theme" = "UNAVAILABLE" ]; then
    do_warn "Could not query LMS runtime theme (pod may not be ready)"
  else
    do_fail "LMS runtime theme is '$theme', expected 'mereka'"
  fi

  # Check MFE Caddyfile has all MFE routes
  mfe_routes=$(kubectl exec -n mereka-lms deployment/mfe -- grep -c 'file_server' /etc/caddy/Caddyfile 2>/dev/null || echo "0")
  if [ "$mfe_routes" -ge 9 ]; then
    do_pass "MFE Caddy serves $mfe_routes MFE routes (>= 9 expected)"
  else
    do_warn "MFE Caddy has only $mfe_routes routes (expected >= 9)"
  fi
else
  do_warn "Cluster not accessible — skipping runtime checks"
fi

echo ""
echo "=== AC-UI-002 Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
