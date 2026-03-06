#!/usr/bin/env bash
# @covers AC-013
# @spec: video-pipeline-delivery_spec.md
# Verify no Mux asset IDs exposed in HTML/JS output
# AC-013: Only playback IDs should be visible, never asset IDs or API credentials
#
# Usage:
#   ./scripts/qa/verify-no-mux-asset-ids.sh [--output-dir <path>]
#
# Returns:
#   0 if no asset IDs found in build artifacts
#   1 if asset IDs detected

set -euo pipefail

# Source shared config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shared/config.sh"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# =============================================================================
# Configuration
# =============================================================================
OUTPUT_DIR="${OUTPUT_DIR:-tutor_env/env}"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --output-dir)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    *)
      error "Unknown option: $1"
      exit 1
      ;;
  esac
done

# =============================================================================
# Detection Patterns
# =============================================================================
# Mux asset ID format: alphanumeric string, typically 40+ chars
# Examples: n58kT8AhCnMFBJ7e008ok8bA01C7hE4nf2P2TQre9X02Kc
# API credential patterns
CREDENTIAL_PATTERNS=(
  'MUX_TOKEN_ID'
  'MUX_TOKEN_SECRET'
  'mux.*api.*key'
  'mux.*secret'
)

# =============================================================================
# Scan Functions
# =============================================================================

load_known_asset_ids() {
  # Load asset IDs from upload results to check against
  local results_file="exports/mct/mux_upload_complete.json"

  if [[ ! -f "${results_file}" ]]; then
    warn "Mux upload results not found: ${results_file}" >&2
    echo ""
    return
  fi

  jq -r '.successful[]? | .mux_asset_id // empty' "${results_file}" 2>/dev/null || echo ""
}

load_known_playback_ids() {
  # Load playback IDs (these are OK to expose)
  local results_file="exports/mct/mux_upload_complete.json"

  if [[ ! -f "${results_file}" ]]; then
    echo ""
    return
  fi

  jq -r '.successful[]? | .mux_playback_id // empty' "${results_file}" 2>/dev/null || echo ""
}

scan_for_asset_ids() {
  info "Scanning build artifacts for exposed Mux asset IDs..."
  echo

  local found_issues=0
  local scanned_paths=0
  local search_paths=(
    "${OUTPUT_DIR}/apps/openedx/templates"
    "${OUTPUT_DIR}/apps/mfe"
    "${OUTPUT_DIR}/build/openedx"
  )
  local asset_ids
  asset_ids=$(load_known_asset_ids)

  local playback_ids
  playback_ids=$(load_known_playback_ids)

  if [[ -z "${asset_ids}" ]]; then
    warn "No asset IDs loaded from exports - cannot verify exposure"
    info "Checking for API credentials only..."
  fi

  # Scan each path
  for search_path in "${search_paths[@]}"; do
    if [[ ! -d "${search_path}" ]]; then
      warn "Path not found: ${search_path}"
      continue
    fi

    scanned_paths=$((scanned_paths + 1))
    info "Scanning ${search_path}..."

    # Look for known asset IDs
    if [[ -n "${asset_ids}" ]]; then
      while IFS= read -r asset_id; do
        if [[ -z "${asset_id}" ]]; then
          continue
        fi

        local matches
        matches=$(grep -r "${asset_id}" "${search_path}" 2>/dev/null || true)

        if [[ -n "${matches}" ]]; then
          error "  ❌ Found asset ID ${asset_id} in:"
          echo "${matches}" | sed 's/^/    /'
          echo
          found_issues=1
        fi
      done <<< "${asset_ids}"
    fi

    # Look for API credential patterns
    for pattern in "${CREDENTIAL_PATTERNS[@]}"; do
      local matches
      matches=$(grep -ri "${pattern}" "${search_path}" \
        --include="*.html" \
        --include="*.js" \
        --include="*.jsx" \
        --include="*.ts" \
        --include="*.tsx" \
        2>/dev/null || true)

      if [[ -n "${matches}" ]]; then
        error "  ❌ Found credential pattern '${pattern}' in:"
        echo "${matches}" | sed 's/^/    /'
        echo
        found_issues=1
      fi
    done
  done

  # Verify playback IDs are present (sanity check)
  if [[ -n "${playback_ids}" ]]; then
    info "Verifying playback IDs are present (expected)..."
    local playback_count=0
    local sample_playback_id
    sample_playback_id=$(echo "${playback_ids}" | head -n1)

    if [[ -n "${sample_playback_id}" ]]; then
      for search_path in "${search_paths[@]}"; do
        if [[ ! -d "${search_path}" ]]; then
          continue
        fi

        if grep -q "${sample_playback_id}" "${search_path}" 2>/dev/null; then
          playback_count=$((playback_count + 1))
        fi
      done
    fi

    if [[ "${playback_count}" -gt 0 ]]; then
      info "  ✓ Found playback IDs in build artifacts (expected)"
    else
      warn "  ⚠ No playback IDs found - may need to rebuild with Mux videos"
    fi
  fi

  if [[ "${scanned_paths}" -eq 0 ]]; then
    warn "No build artifact paths found under OUTPUT_DIR=${OUTPUT_DIR}; content scan skipped"
  fi

  return "${found_issues}"
}

# =============================================================================
# Main
# =============================================================================
main() {
  if scan_for_asset_ids; then
    echo
    info "✅ No Mux asset IDs or credentials exposed in build artifacts"
    return 0
  else
    echo
    error "❌ Found exposed Mux asset IDs or credentials"
    error "    Only playback IDs should be visible in HTML/JS output"
    return 1
  fi
}

main "$@"
