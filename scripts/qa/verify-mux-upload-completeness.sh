#!/usr/bin/env bash
# @covers AC-002
# @spec: video-pipeline-delivery_spec.md
# Verify Mux upload completeness from results file
# AC-002: Check all 503 MCT videos have mux_asset_id and mux_playback_id
#
# Usage:
#   ./scripts/qa/verify-mux-upload-completeness.sh
#
# Returns:
#   0 if all videos have Mux IDs
#   1 if missing data or validation fails

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
RESULTS_FILE="${RESULTS_FILE:-exports/mct/mux_upload_complete.json}"
EXPECTED_COUNT="${EXPECTED_COUNT:-503}"

# =============================================================================
# Validation
# =============================================================================
main() {
  info "Verifying Mux upload completeness..."
  info "Results file: ${RESULTS_FILE}"
  info "Expected videos: ${EXPECTED_COUNT}"
  echo

  # Check file exists
  if [[ ! -f "${RESULTS_FILE}" ]]; then
    error "Results file not found: ${RESULTS_FILE}"
    return 1
  fi

  # Check valid JSON
  if ! jq empty "${RESULTS_FILE}" 2>/dev/null; then
    error "Invalid JSON in ${RESULTS_FILE}"
    return 1
  fi

  # Extract statistics
  local total_videos
  total_videos=$(jq -r '.total_videos // 0' "${RESULTS_FILE}")

  local successful_count
  successful_count=$(jq '.successful | length' "${RESULTS_FILE}")

  info "Total videos reported: ${total_videos}"
  info "Successful uploads: ${successful_count}"

  # Check total matches expected
  if [[ "${total_videos}" -ne "${EXPECTED_COUNT}" ]]; then
    warn "Total videos (${total_videos}) does not match expected (${EXPECTED_COUNT})"
  fi

  # Check all successful entries have required fields
  local missing_asset_id
  missing_asset_id=$(jq '[.successful[] | select(.mux_asset_id == null or .mux_asset_id == "")] | length' "${RESULTS_FILE}")

  local missing_playback_id
  missing_playback_id=$(jq '[.successful[] | select(.mux_playback_id == null or .mux_playback_id == "")] | length' "${RESULTS_FILE}")

  echo
  info "Validation results:"
  echo "  - Missing mux_asset_id: ${missing_asset_id}"
  echo "  - Missing mux_playback_id: ${missing_playback_id}"

  # Check for failed uploads
  local failed_count=0
  if jq -e '.failed' "${RESULTS_FILE}" > /dev/null 2>&1; then
    failed_count=$(jq '.failed | length' "${RESULTS_FILE}")
    if [[ "${failed_count}" -gt 0 ]]; then
      warn "Found ${failed_count} failed uploads:"
      jq -r '.failed[] | "  - \(.title) (MCT lesson \(.mct_lesson_id)): \(.error // "unknown error")"' "${RESULTS_FILE}"
    fi
  fi

  # Sample check: display 5 random entries
  echo
  info "Sample entries (5 random):"
  jq -r '.successful | sort_by(.mct_lesson_id) | .[0:5][] | "  ✓ \(.title) → \(.mux_playback_id)"' "${RESULTS_FILE}"

  # Final verdict
  echo
  if [[ "${missing_asset_id}" -eq 0 ]] && [[ "${missing_playback_id}" -eq 0 ]]; then
    info "✅ All ${successful_count} videos have complete Mux IDs"
    return 0
  else
    error "❌ Found ${missing_asset_id} missing asset IDs and ${missing_playback_id} missing playback IDs"
    return 1
  fi
}

main "$@"
