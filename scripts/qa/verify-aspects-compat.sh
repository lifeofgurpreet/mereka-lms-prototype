#!/usr/bin/env bash
# Aspects Version Compatibility Check
#
# Validates that the installed tutor-contrib-aspects version is compatible
# with the Ulmo release track (Tutor 21.x).
#
# Known compatible range for Ulmo: >= 1.0.0 and < 2.0.0
# (Redwood/Tutor 18.x used >= 0.70.0, < 1.0.0 — now superseded by Ulmo)
#
# Usage:
#   ./scripts/qa/verify-aspects-compat.sh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

# --- Constants ---
# Updated from 18 (Redwood) to 21 (Ulmo) — 2026-03-06
TUTOR_VERSION_MAJOR=21
ASPECTS_MIN_MAJOR=1
ASPECTS_MIN_MINOR=0
ASPECTS_MAX_MAJOR=2   # exclusive upper bound (must be < 2.0)

# --- Colors ---
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0

do_pass() { echo -e "  ${GREEN}PASS${NC}  $1"; PASSED=$((PASSED + 1)); }
do_fail() { echo -e "  ${RED}FAIL${NC}  $1"; FAILED=$((FAILED + 1)); }
do_warn() { echo -e "  ${YELLOW}WARN${NC}  $1"; WARNED=$((WARNED + 1)); }
do_info() { echo -e "  ${CYAN}INFO${NC}  $1"; }

echo "══════════════════════════════════════════════════════════════"
echo "  Aspects Version Compatibility Check (Ulmo / Tutor 21.x)"
echo "══════════════════════════════════════════════════════════════"
echo ""

# ============================================================================
# Step 1: Detect if Aspects is configured at all
# ============================================================================
echo "──────────────────────────────────────────────────────────────"
echo "  Detect Aspects configuration"
echo "──────────────────────────────────────────────────────────────"

ASPECTS_VERSION=""

# Source 1: requirements.lock or requirements*.txt
REQUIREMENTS_FILES=(requirements.lock requirements.txt requirements-dev.txt)
for req_file in "${REQUIREMENTS_FILES[@]}"; do
  if [[ -f "$req_file" ]]; then
    version_line=$(grep -i "tutor-contrib-aspects" "$req_file" 2>/dev/null | head -1 || true)
    if [[ -n "$version_line" ]]; then
      ASPECTS_VERSION=$(echo "$version_line" | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1 || true)
      if [[ -n "$ASPECTS_VERSION" ]]; then
        do_info "Found tutor-contrib-aspects in $req_file: $ASPECTS_VERSION"
        break
      fi
    fi
  fi
done

# Source 2: infrastructure/tutor/config.example.yml (plugin list)
if [[ -z "$ASPECTS_VERSION" ]]; then
  CONFIG_EXAMPLE="infrastructure/tutor/config.example.yml"
  if [[ -f "$CONFIG_EXAMPLE" ]] && grep -qi "aspects" "$CONFIG_EXAMPLE" 2>/dev/null; then
    do_info "Aspects referenced in $CONFIG_EXAMPLE (no explicit version pinned)"
    # Mark as configured but unpinned
    ASPECTS_VERSION="unpinned"
  fi
fi

# Source 3: Any pip freeze / pip-tools output in the repo
if [[ -z "$ASPECTS_VERSION" ]]; then
  while IFS= read -r -d '' req_file; do
    version_line=$(grep -i "tutor-contrib-aspects" "$req_file" 2>/dev/null | head -1 || true)
    if [[ -n "$version_line" ]]; then
      ASPECTS_VERSION=$(echo "$version_line" | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1 || true)
      if [[ -n "$ASPECTS_VERSION" ]]; then
        do_info "Found tutor-contrib-aspects in $req_file: $ASPECTS_VERSION"
        break
      fi
    fi
  done < <(find "$REPO_ROOT" -maxdepth 3 -name "requirements*.txt" -o -name "requirements*.lock" 2>/dev/null | tr '\n' '\0')
fi

echo ""

# ============================================================================
# Step 2: If not configured, skip gracefully
# ============================================================================
if [[ -z "$ASPECTS_VERSION" ]]; then
  echo "  Aspects (tutor-contrib-aspects) is not configured in this repo."
  echo "  Skipping compatibility check."
  echo ""
  echo "══════════════════════════════════════════════════════════════"
  echo "  Summary"
  echo "══════════════════════════════════════════════════════════════"
  echo ""
  echo "  Aspects not configured — skipping (exit 0)"
  exit 0
fi

# ============================================================================
# Step 3: Version compatibility validation
# ============================================================================
echo "──────────────────────────────────────────────────────────────"
echo "  Version compatibility (Ulmo = Tutor ${TUTOR_VERSION_MAJOR}.x)"
echo "──────────────────────────────────────────────────────────────"

if [[ "$ASPECTS_VERSION" == "unpinned" ]]; then
  do_warn "Aspects is referenced in config but no explicit version is pinned"
  do_warn "Pin tutor-contrib-aspects>=1.0,<2.0 in requirements for Ulmo compatibility"
  echo ""
else
  # Parse semver components
  ASPECTS_MAJOR=$(echo "$ASPECTS_VERSION" | cut -d. -f1)
  ASPECTS_MINOR=$(echo "$ASPECTS_VERSION" | cut -d. -f2)
  ASPECTS_PATCH=$(echo "$ASPECTS_VERSION" | cut -d. -f3)

  do_info "Detected version: tutor-contrib-aspects==${ASPECTS_VERSION}"
  do_info "Compatible range for Ulmo (Tutor 21.x): >=1.0.0,<2.0.0"
  echo ""

  # Check lower bound: >= 1.0.0
  ABOVE_MIN=false
  if [[ "$ASPECTS_MAJOR" -gt "$ASPECTS_MIN_MAJOR" ]]; then
    ABOVE_MIN=true
  elif [[ "$ASPECTS_MAJOR" -eq "$ASPECTS_MIN_MAJOR" && "$ASPECTS_MINOR" -ge "$ASPECTS_MIN_MINOR" ]]; then
    ABOVE_MIN=true
  fi

  # Check upper bound: < 2.0.0
  BELOW_MAX=false
  if [[ "$ASPECTS_MAJOR" -lt "$ASPECTS_MAX_MAJOR" ]]; then
    BELOW_MAX=true
  fi

  if $ABOVE_MIN; then
    do_pass "tutor-contrib-aspects ${ASPECTS_VERSION} >= 1.0.0 (minimum Ulmo-compatible)"
  else
    do_fail "tutor-contrib-aspects ${ASPECTS_VERSION} is below 1.0.0 — not compatible with Ulmo"
    do_fail "Upgrade to tutor-contrib-aspects>=1.0,<2.0 for Tutor 21.x / Ulmo"
  fi

  if $BELOW_MAX; then
    do_pass "tutor-contrib-aspects ${ASPECTS_VERSION} < 2.0.0 (within Ulmo release track)"
  else
    do_fail "tutor-contrib-aspects ${ASPECTS_VERSION} >= 2.0.0 — may target a future release beyond Ulmo"
    do_fail "Pin tutor-contrib-aspects<2.0 for Ulmo / Tutor 21.x compatibility"
  fi

  echo ""
fi

# ============================================================================
# Step 4: dbt project version alignment (informational)
# ============================================================================
echo "──────────────────────────────────────────────────────────────"
echo "  dbt project version alignment (informational)"
echo "──────────────────────────────────────────────────────────────"

DBT_PROJECT_FILE=""
# Look for aspects dbt project file in common locations
for candidate in \
  "deploy/k8s/base/plugins/aspects/dbt_project.yml" \
  "infrastructure/aspects/dbt_project.yml" \
  "aspects/dbt_project.yml"; do
  if [[ -f "$candidate" ]]; then
    DBT_PROJECT_FILE="$candidate"
    break
  fi
done

if [[ -n "$DBT_PROJECT_FILE" ]]; then
  DBT_VERSION=$(grep "^version:" "$DBT_PROJECT_FILE" | head -1 | grep -oP '[\d]+\.[\d]+\.[\d]+' | head -1 || true)
  if [[ -n "$DBT_VERSION" ]]; then
    do_info "Found dbt project version: ${DBT_VERSION} in ${DBT_PROJECT_FILE}"
    # For Redwood, expect dbt project version to align with aspects plugin minor
    if [[ "$ASPECTS_VERSION" != "unpinned" ]]; then
      DBT_MINOR=$(echo "$DBT_VERSION" | cut -d. -f2)
      ASPECTS_MINOR_CMP=$(echo "$ASPECTS_VERSION" | cut -d. -f2)
      if [[ "$DBT_MINOR" -eq "$ASPECTS_MINOR_CMP" ]]; then
        do_pass "dbt project minor version (${DBT_MINOR}) aligns with aspects plugin minor (${ASPECTS_MINOR_CMP})"
      else
        do_warn "dbt project minor version (${DBT_MINOR}) differs from aspects plugin minor (${ASPECTS_MINOR_CMP})"
        do_warn "Verify dbt project is compatible with tutor-contrib-aspects ${ASPECTS_VERSION}"
      fi
    fi
  else
    do_info "dbt project file found but could not parse version — review manually"
  fi
else
  do_info "No Aspects dbt project file found in repo (may be bundled inside plugin image)"
fi

echo ""

# ============================================================================
# Summary
# ============================================================================
echo "══════════════════════════════════════════════════════════════"
echo "  Summary"
echo "══════════════════════════════════════════════════════════════"
echo ""
echo -e "  ${GREEN}PASS${NC}: ${PASSED}"
echo -e "  ${RED}FAIL${NC}: ${FAILED}"
echo -e "  ${YELLOW}WARN${NC}: ${WARNED}"
echo ""

if [[ $FAILED -eq 0 && $WARNED -eq 0 ]]; then
  echo "✓ Aspects version is compatible with Ulmo (Tutor 21.x)"
  exit 0
elif [[ $FAILED -eq 0 ]]; then
  echo "✓ Aspects compatibility check passed with warnings — review above"
  exit 0
else
  echo "✗ Aspects version compatibility check failed"
  echo "  Compatible range for Ulmo: tutor-contrib-aspects>=1.0,<2.0"
  echo "  See: https://github.com/openedx/tutor-contrib-aspects"
  exit 1
fi
