#!/usr/bin/env bash
# Migration Verification Pipeline Orchestrator
#
# Runs all migration verification scripts in workflow order and produces
# a summary report. Continues even if individual scripts fail.
#
# Usage: ./scripts/migrations/run-verification-pipeline.sh
#
# Output: scripts/migrations/output/verification/summary.txt

set -euo pipefail

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
QA_DIR="$PROJECT_ROOT/scripts/qa"
OUTPUT_DIR="$SCRIPT_DIR/output/verification"

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Summary file
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"

# Results tracking
declare -a RESULTS
declare -a DURATIONS
TOTAL_PASSED=0
TOTAL_FAILED=0

echo -e "${BLUE}=== Migration Verification Pipeline ===${NC}"
echo -e "Started: $(date '+%Y-%m-%d %H:%M:%S')\n"

# Verification scripts in workflow order
VERIFICATION_SCRIPTS=(
  # Export phase
  "verify-kajabi-export.sh"
  "verify-mct-export.sh"
  "verify-kajabi-completions-export.sh"
  "verify-mct-video-urls.sh"

  # Transform phase
  "verify-kajabi-transform.sh"
  "verify-mct-transform.sh"
  "verify-kajabi-olx-packages.sh"
  "verify-mct-olx-packages.sh"

  # User import phase
  "verify-user-import-counts.sh"
  "verify-cross-system-identity.sh"

  # Course import phase
  "verify-course-import-counts.sh"
  "verify-course-structure-sample.sh"

  # Enrollment phase
  "verify-enrollment-import-counts.sh"
  "verify-enrollment-skip-handling.sh"

  # Certificate phase
  "verify-certificate-issuance.sh"

  # Video phase
  "verify-mux-video-upload.sh"
  "verify-kajabi-thumbnails.sh"

  # Rollback and idempotency phase
  "verify-rollback-dry-run.sh"
  "verify-idempotency.sh"
  "verify-incremental-sync.sh"
)

# Function to run a verification script
run_verification() {
  local script_name="$1"
  local script_path="$QA_DIR/$script_name"

  # Check if script exists
  if [[ ! -f "$script_path" ]]; then
    echo -e "${YELLOW}⚠ SKIP${NC}  $script_name (not found)"
    RESULTS+=("SKIP")
    DURATIONS+=("0")
    return
  fi

  echo -e "${BLUE}▶ RUN${NC}   $script_name"

  # Run script and capture exit code
  local start_time
  start_time=$(date +%s)

  set +e
  "$script_path" > "$OUTPUT_DIR/${script_name}.log" 2>&1
  local exit_code=$?
  set -e

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  # Record result
  if [[ $exit_code -eq 0 ]]; then
    echo -e "${GREEN}✓ PASS${NC}  $script_name (${duration}s)"
    RESULTS+=("PASS")
    TOTAL_PASSED=$((TOTAL_PASSED + 1))
  else
    echo -e "${RED}✗ FAIL${NC}  $script_name (exit code: $exit_code, ${duration}s)"
    RESULTS+=("FAIL")
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
  fi

  DURATIONS+=("$duration")
  echo ""
}

# Run all verification scripts
for script in "${VERIFICATION_SCRIPTS[@]}"; do
  run_verification "$script"
done

# Calculate total duration
TOTAL_DURATION=0
for duration in "${DURATIONS[@]}"; do
  TOTAL_DURATION=$((TOTAL_DURATION + duration))
done

# Write summary file
{
  echo "=== Migration Verification Pipeline Summary ==="
  echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
  echo ""
  echo "Total Scripts: ${#VERIFICATION_SCRIPTS[@]}"
  echo "Passed: $TOTAL_PASSED"
  echo "Failed: $TOTAL_FAILED"
  echo "Total Duration: ${TOTAL_DURATION}s"
  echo ""
  echo "=== Individual Results ==="
  echo ""
  printf "%-50s %-10s %-10s\n" "Script" "Result" "Duration"
  printf "%-50s %-10s %-10s\n" "------" "------" "--------"

  for i in "${!VERIFICATION_SCRIPTS[@]}"; do
    printf "%-50s %-10s %-10s\n" \
      "${VERIFICATION_SCRIPTS[$i]}" \
      "${RESULTS[$i]}" \
      "${DURATIONS[$i]}s"
  done

  echo ""
  echo "=== Logs ==="
  echo "Individual logs: $OUTPUT_DIR/*.log"
} > "$SUMMARY_FILE"

# Print summary table
echo -e "${BLUE}=== Summary ===${NC}"
echo ""
printf "%-50s %-10s %-10s\n" "Script" "Result" "Duration"
printf "%-50s %-10s %-10s\n" "------" "------" "--------"

for i in "${!VERIFICATION_SCRIPTS[@]}"; do
  result="${RESULTS[$i]}"
  color="$NC"

  case "$result" in
    PASS) color="$GREEN" ;;
    FAIL) color="$RED" ;;
    SKIP) color="$YELLOW" ;;
  esac

  printf "%-50s ${color}%-10s${NC} %-10s\n" \
    "${VERIFICATION_SCRIPTS[$i]}" \
    "$result" \
    "${DURATIONS[$i]}s"
done

echo ""
echo -e "${BLUE}Total:${NC} ${#VERIFICATION_SCRIPTS[@]} scripts"
echo -e "${GREEN}Passed:${NC} $TOTAL_PASSED"
echo -e "${RED}Failed:${NC} $TOTAL_FAILED"
echo -e "${BLUE}Duration:${NC} ${TOTAL_DURATION}s"
echo ""
echo -e "${BLUE}Summary written to:${NC} $SUMMARY_FILE"

# Exit with failure if any script failed
if [[ $TOTAL_FAILED -gt 0 ]]; then
  echo -e "${RED}Pipeline failed: $TOTAL_FAILED script(s) failed${NC}"
  exit 1
else
  echo -e "${GREEN}Pipeline passed: All scripts succeeded${NC}"
  exit 0
fi




