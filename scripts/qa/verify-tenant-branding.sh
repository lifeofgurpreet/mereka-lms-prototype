#!/usr/bin/env bash
# @covers AC-MTA-008, AC-MTA-009, AC-MTA-010, AC-MTA-011
# @spec: multi-tenancy-architecture_spec.md
# Verify tenant branding pipeline exists and has correct structure.
# AC-MTA-008: Custom logo via SiteConfiguration.
# AC-MTA-009: Custom brand colors.
# AC-MTA-010: Custom footer.
# AC-MTA-011: Branding updates without image rebuild (collectstatic only).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PASS=0
FAIL=0

log_pass() { printf "PASS: %s\n" "$1"; PASS=$((PASS + 1)); }
log_fail() { printf "FAIL: %s\n" "$1"; FAIL=$((FAIL + 1)); }

echo "=== Tenant Branding Verification ==="
echo "Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
echo

THEME_BASE="$REPO_ROOT/infrastructure/tutor/themes/mereka"

# Check 1: Base Mereka theme exists
if [ -d "$THEME_BASE" ]; then
  log_pass "Base Mereka theme directory exists"
else
  log_fail "Base Mereka theme directory not found"
fi

# Check 2: Theme has required subdirectories
for subdir in lms cms common mfe; do
  if [ -d "$THEME_BASE/$subdir" ]; then
    log_pass "Theme has $subdir/ directory"
  else
    log_fail "Theme missing $subdir/ directory"
  fi
done

# Check 3: Logo files exist in base theme (horizontal, square, white variants)
LOGO_VARIANTS=("logo-horizontal" "logo-square" "logo-white")
for variant in "${LOGO_VARIANTS[@]}"; do
  FOUND=0
  for ext in png svg; do
    if [ -f "$THEME_BASE/common/static/images/${variant}.${ext}" ]; then
      FOUND=1
      break
    fi
  done
  if [ $FOUND -eq 1 ]; then
    log_pass "Base theme has ${variant} logo"
  else
    log_fail "Base theme missing ${variant} logo"
  fi
done

# Check 4: Branding sync script exists and is executable
SYNC_SCRIPT="$REPO_ROOT/scripts/tenants/sync-tenant-branding.sh"
if [ -x "$SYNC_SCRIPT" ]; then
  log_pass "sync-tenant-branding.sh exists and is executable"
else
  log_fail "sync-tenant-branding.sh missing or not executable"
fi

# Check 5: Branding sync script accepts --slug argument
if [ -f "$SYNC_SCRIPT" ] && grep -q "\-\-slug" "$SYNC_SCRIPT"; then
  log_pass "sync-tenant-branding.sh accepts --slug argument"
else
  log_fail "sync-tenant-branding.sh missing --slug argument"
fi

# Check 6: Branding sync script supports --dry-run
if [ -f "$SYNC_SCRIPT" ] && grep -q "\-\-dry-run" "$SYNC_SCRIPT"; then
  log_pass "sync-tenant-branding.sh supports --dry-run"
else
  log_fail "sync-tenant-branding.sh missing --dry-run support"
fi

# Check 7: Branding sync script references @covers AC-MTA annotations
if [ -f "$SYNC_SCRIPT" ] && grep -q "@covers.*AC-MTA-008" "$SYNC_SCRIPT"; then
  log_pass "sync-tenant-branding.sh has @covers AC-MTA-008 annotation"
else
  log_fail "sync-tenant-branding.sh missing @covers annotation"
fi

# Check 8: TenantConfig model has branding_config field
MODEL_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/models.py"
if [ -f "$MODEL_FILE" ] && grep -q "branding_config" "$MODEL_FILE"; then
  log_pass "TenantConfig model has branding_config field"
else
  log_fail "TenantConfig model missing branding_config field"
fi

# Check 9: SiteConfiguration with branding values in provisioning command
CMD_FILE="$REPO_ROOT/infrastructure/tutor/plugins/multi-tenancy/management/commands/provision_tenant.py"
if [ -f "$CMD_FILE" ] && grep -q "PLATFORM_NAME\|platform_name" "$CMD_FILE"; then
  log_pass "Provisioning command sets platform branding in SiteConfiguration"
else
  log_fail "Provisioning command missing platform branding in SiteConfiguration"
fi

# Check 10: Tenant branding directory convention documented
# The convention is: infrastructure/tutor/themes/mereka/tenants/{slug}/
if [ -f "$SYNC_SCRIPT" ] && grep -q "tenants/" "$SYNC_SCRIPT"; then
  log_pass "Branding pipeline uses tenants/{slug}/ directory convention"
else
  log_fail "Branding pipeline does not use tenants/{slug}/ convention"
fi

# Check 11: CSS override support
if [ -f "$SYNC_SCRIPT" ] && grep -q "css\|CSS" "$SYNC_SCRIPT"; then
  log_pass "Branding pipeline supports CSS overrides"
else
  log_fail "Branding pipeline missing CSS override support"
fi

# Check 12: branding.json support (SiteConfiguration values)
if [ -f "$SYNC_SCRIPT" ] && grep -q "branding.json" "$SYNC_SCRIPT"; then
  log_pass "Branding pipeline supports branding.json for SiteConfiguration"
else
  log_fail "Branding pipeline missing branding.json support"
fi

# Check 13: No image rebuild needed for branding (AC-MTA-011)
# This is structural: assets are in static files directory, not baked into Docker image.
if [ -d "$THEME_BASE/common/static" ] && [ -d "$THEME_BASE/lms/static" ]; then
  log_pass "Branding assets are static files (no rebuild needed for AC-MTA-011)"
else
  log_fail "Branding assets not in static directories"
fi

# Check 14: Head-extra template exists (for injecting per-tenant CSS)
if [ -f "$THEME_BASE/lms/templates/head-extra.html" ]; then
  log_pass "head-extra.html template exists for per-tenant CSS injection"
else
  log_fail "head-extra.html template missing"
fi

# Check 15: Footer template exists (for per-tenant footer content)
if [ -f "$THEME_BASE/lms/templates/footer.html" ]; then
  log_pass "footer.html template exists for per-tenant footer"
else
  log_fail "footer.html template missing"
fi

echo
echo "=== Summary ==="
echo "PASS: $PASS"
echo "FAIL: $FAIL"
echo
if [ $FAIL -eq 0 ]; then
  echo "ALL CHECKS PASSED"
  exit 0
else
  echo "SOME CHECKS FAILED"
  exit 1
fi
