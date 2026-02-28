#!/usr/bin/env bash
# verify-theme-consistency.sh — AC-UI-002: Theme consistency across LMS, Studio, MFEs
#
# Checks that the Mereka theme is correctly wired in all surfaces:
# - LMS: mereka theme set as default
# - Studio (CMS): same theme references
# - MFEs: custom footer, branding assets, no default Open edX branding
#
# Usage: ./scripts/qa/verify-theme-consistency.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
LMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/lms/production.py"
CMS_SETTINGS="$REPO_ROOT/deploy/k8s/base/apps/openedx/settings/cms/production.py"
PLUGIN="$REPO_ROOT/infrastructure/tutor/plugins/mereka_lms.py"
PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
FOOTER_COMPONENT_PATCH="$REPO_ROOT/infrastructure/tutor/patches/footer-component.sh"
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

if grep -q 'org.openedx.frontend.layout.footer.v1\|PLUGIN_SLOTS' "$PLUGIN" 2>/dev/null; then
  do_pass "Plugin wires footer branding through FPF slots"
else
  do_fail "Footer FPF slot wiring not found in plugin"
fi

if [ -f "$FOOTER_COMPONENT_PATCH" ] && grep -q 'source "\$PATCHES_DIR/footer-component.sh"' "$PATCHES" 2>/dev/null; then
  do_pass "apply-patches.sh sources footer-component patch module"
else
  do_warn "footer-component patch module wiring not found in apply-patches.sh"
fi

# 5. Head-extra template for theme CSS injection
echo ""
echo "--- Theme CSS Injection ---"
head_extra_found=0
head_extra_branding=0
for head_extra in \
  "$REPO_ROOT/deploy/k8s/base/apps/openedx/theme/head-extra.html" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/common/templates/head-extra.html" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/lms/templates/head-extra.html" \
  "$REPO_ROOT/infrastructure/tutor/themes/mereka/cms/templates/head-extra.html"; do
  if [ -f "$head_extra" ]; then
    head_extra_found=$((head_extra_found + 1))
    if grep -Eqi 'mereka|brand|font|preload' "$head_extra" 2>/dev/null; then
      head_extra_branding=$((head_extra_branding + 1))
    fi
  fi
done
if [ "$head_extra_found" -gt 0 ]; then
  do_pass "Found $head_extra_found head-extra template(s) in current theme paths"
  if [ "$head_extra_branding" -gt 0 ]; then
    do_pass "head-extra templates include branding/font wiring markers"
  else
    do_warn "head-extra templates found but no branding/font markers detected"
  fi
else
  do_warn "No head-extra templates found in expected current paths"
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

  # Check MFE Caddyfile has critical route markers.
  # Counting `file_server` entries is brittle across Caddy template revisions.
  caddyfile_content="$(kubectl exec -n mereka-lms deployment/mfe -- cat /etc/caddy/Caddyfile 2>/dev/null || true)"
  if [ -n "$caddyfile_content" ]; then
    missing_markers=0
    for marker in '/authn/*' '/profile/*' '/learning/*' '/theme/*'; do
      if grep -Fq "$marker" <<<"$caddyfile_content"; then
        :
      else
        missing_markers=$((missing_markers + 1))
      fi
    done

    if [ "$missing_markers" -eq 0 ]; then
      do_pass "MFE Caddyfile contains critical MFE/theme route markers"
    else
      do_warn "MFE Caddyfile missing $missing_markers critical route marker(s)"
    fi
  else
    do_warn "Could not read MFE Caddyfile from runtime pod"
  fi
else
  do_warn "Cluster not accessible — skipping runtime checks"
fi

echo ""
echo "=== AC-UI-002 Results: $PASS PASS / $FAIL FAIL / $WARN WARN ==="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
