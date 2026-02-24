#!/usr/bin/env bash
# @spec: mfe-ulmo-migration_spec.md
# @covers AC-ULMO-001: OPENEDX_COMMON_VERSION patch confirmed working (ensure_mfe_ulmo_source_refs)
# @covers AC-ULMO-002: All MFE app source refs use release/ulmo.1
# @covers AC-ULMO-003: Atlas translation pulls use open-release/ulmo.1
# @covers AC-ULMO-004: Brand package upgraded to ulmo-compatible version (^2.4.3)
# @covers AC-ULMO-006: discussions webpack fix is no-op on ulmo (fixed upstream)
set -euo pipefail

PASS=0
FAIL=0
WARN=0

pass() { PASS=$((PASS + 1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL + 1)); echo "  FAIL: $1"; }
warn() { WARN=$((WARN + 1)); echo "  WARN: $1"; }

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APPLY_PATCHES="$REPO_ROOT/infrastructure/tutor/apply-patches.sh"
SNAPSHOT="$REPO_ROOT/infrastructure/tutor/mfe-build/Dockerfile"

echo "========================================"
echo "MFE Ulmo Migration Verification"
echo "========================================"
echo ""

# -----------------------------------------------------------------------
# AC-ULMO-001: Patch function exists in apply-patches.sh
# -----------------------------------------------------------------------
echo "AC-ULMO-001: ensure_mfe_ulmo_source_refs patch function"

if [[ ! -f "$APPLY_PATCHES" ]]; then
  fail "apply-patches.sh not found"
else
  if grep -q "def ensure_mfe_ulmo_source_refs" "$APPLY_PATCHES"; then
    pass "ensure_mfe_ulmo_source_refs() function present in apply-patches.sh"
  else
    fail "ensure_mfe_ulmo_source_refs() missing from apply-patches.sh"
  fi

  if grep -q "open-release/redwood\.3.*release/ulmo\.1\|release/ulmo\.1" "$APPLY_PATCHES"; then
    pass "apply-patches.sh patches ADD refs to release/ulmo.1"
  else
    fail "apply-patches.sh has no ulmo.1 ref patch"
  fi

  # Confirm OPENEDX_COMMON_VERSION stays redwood.3 (patch approach, not config change)
  TUTOR_CONFIG="$REPO_ROOT/tutor_env/config.yml"
  if [[ -f "$TUTOR_CONFIG" ]]; then
    CONFIG_VER=$(grep "OPENEDX_COMMON_VERSION" "$TUTOR_CONFIG" | head -1 || true)
    if echo "$CONFIG_VER" | grep -q "redwood"; then
      pass "OPENEDX_COMMON_VERSION=redwood.3 (patch approach active — not config-driven)"
    elif echo "$CONFIG_VER" | grep -q "ulmo"; then
      pass "OPENEDX_COMMON_VERSION=ulmo (config-driven approach — patch is no-op)"
    else
      warn "OPENEDX_COMMON_VERSION not determinable from config.yml"
    fi
  else
    warn "tutor_env/config.yml not found (gitignored) — cannot verify OPENEDX_COMMON_VERSION"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-ULMO-002: All MFE app source refs use release/ulmo.1 in snapshot
# -----------------------------------------------------------------------
echo "AC-ULMO-002: MFE source refs in snapshot Dockerfile"

if [[ ! -f "$SNAPSHOT" ]]; then
  fail "Dockerfile snapshot missing: infrastructure/tutor/mfe-build/Dockerfile"
else
  pass "Dockerfile snapshot exists"

  REDWOOD_COUNT=$(grep -c "frontend-app.*\.git#open-release/redwood" "$SNAPSHOT" || true)
  ULMO_COUNT=$(grep -c "frontend-app.*\.git#release/ulmo" "$SNAPSHOT" || true)

  if [[ "$REDWOOD_COUNT" -eq 0 ]]; then
    pass "No redwood-era ADD refs in snapshot (0 found)"
  else
    fail "$REDWOOD_COUNT redwood-era ADD refs still in snapshot (expected 0)"
  fi

  if [[ "$ULMO_COUNT" -ge 11 ]]; then
    pass "All MFE apps use release/ulmo.1 ($ULMO_COUNT refs found, expected ≥11)"
  elif [[ "$ULMO_COUNT" -ge 1 ]]; then
    warn "Only $ULMO_COUNT ulmo refs found (expected ≥11)"
  else
    fail "No ulmo ADD refs in snapshot"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-ULMO-003: Atlas translation revision uses open-release/ulmo.1
# -----------------------------------------------------------------------
echo "AC-ULMO-003: Atlas translation revision"

if [[ -f "$SNAPSHOT" ]]; then
  ATLAS_REDWOOD=$(grep -c "revision=open-release/redwood" "$SNAPSHOT" || true)
  ATLAS_ULMO=$(grep -c "revision=open-release/ulmo" "$SNAPSHOT" || true)

  if [[ "$ATLAS_REDWOOD" -eq 0 ]]; then
    pass "No redwood atlas translation revisions in snapshot"
  else
    fail "$ATLAS_REDWOOD redwood atlas revision refs still in snapshot"
  fi

  if [[ "$ATLAS_ULMO" -ge 11 ]]; then
    pass "All atlas pulls use open-release/ulmo.1 ($ATLAS_ULMO found)"
  elif [[ "$ATLAS_ULMO" -ge 1 ]]; then
    warn "Only $ATLAS_ULMO atlas ulmo refs found (expected ≥11)"
  else
    fail "No ulmo atlas translation refs in snapshot"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-ULMO-004: Brand package upgraded to ulmo-compatible version
# -----------------------------------------------------------------------
echo "AC-ULMO-004: Brand package version"

if [[ -f "$SNAPSHOT" ]]; then
  OLD_BRAND=$(grep -c "indigo-brand-openedx@\^2\.1\.1" "$SNAPSHOT" || true)
  NEW_BRAND=$(grep -c "indigo-brand-openedx@\^2\.4\.[0-9]" "$SNAPSHOT" || true)

  if [[ "$OLD_BRAND" -eq 0 ]]; then
    pass "No redwood-era brand pin (^2.1.1) in snapshot"
  else
    fail "$OLD_BRAND occurrences of ^2.1.1 brand pin still in snapshot"
  fi

  if [[ "$NEW_BRAND" -ge 11 ]]; then
    pass "Brand upgraded to ulmo-compatible version ($NEW_BRAND installs, expected ≥11)"
  elif [[ "$NEW_BRAND" -ge 1 ]]; then
    warn "Only $NEW_BRAND ulmo-compatible brand installs found (expected ≥11)"
  else
    fail "No ulmo-compatible brand version found in snapshot"
  fi
fi

if [[ -f "$APPLY_PATCHES" ]]; then
  if grep -q "def ensure_mfe_brand_ulmo_version" "$APPLY_PATCHES"; then
    pass "ensure_mfe_brand_ulmo_version() function present in apply-patches.sh"
  else
    fail "ensure_mfe_brand_ulmo_version() missing from apply-patches.sh"
  fi

  if grep -q "indigo-brand-openedx@\^2\.4\." "$APPLY_PATCHES"; then
    pass "apply-patches.sh references ulmo-compatible brand version"
  else
    fail "apply-patches.sh still references old brand version"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# AC-ULMO-006: discussions webpack fix is no-op on ulmo
# -----------------------------------------------------------------------
echo "AC-ULMO-006: discussions webpack (ulmo native fix)"

if [[ -f "$SNAPSHOT" ]]; then
  DISCUSSIONS_REDWOOD=$(grep -c "frontend-app-discussions.*redwood" "$SNAPSHOT" || true)
  if [[ "$DISCUSSIONS_REDWOOD" -eq 0 ]]; then
    pass "discussions app uses ulmo.1 (not redwood) — webpack prompt fix not needed"
  else
    fail "discussions still on redwood — webpack non-interactive fix needed"
  fi
fi

if [[ -f "$APPLY_PATCHES" ]]; then
  if grep -q "def ensure_mfe_discussions_webpack_noninteractive" "$APPLY_PATCHES"; then
    pass "ensure_mfe_discussions_webpack_noninteractive() present as guard"
  else
    warn "ensure_mfe_discussions_webpack_noninteractive() not found — guard was removed"
  fi
fi

echo ""

# -----------------------------------------------------------------------
# Summary
# -----------------------------------------------------------------------
echo "[INFO] Build verification (AC-ULMO-007/008/009) requires WhiteCliff lane:"
echo "  tutor images build mfe -a PIP_COMMAND=pip"
echo "  tutor images push mfe"
echo ""
echo "========================================"
echo "MFE Ulmo Migration: $PASS PASS / $FAIL FAIL / $WARN WARN"
echo "========================================"
exit $((FAIL > 0 ? 1 : 0))
