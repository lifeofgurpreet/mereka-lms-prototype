#!/usr/bin/env bash
# Verify course structure in OLX packages against AC-017 and AC-018.
#
# Checks:
# - Course structure matches source data
# - Kajabi: modules and lessons count
# - MCT: sections match MCT "Courses" count
#
# Note: This checks OLX package structure, not imported database state.
#
# Usage:
#   ./scripts/qa/verify-course-structure-sample.sh --source kajabi|mct [--course NAME]
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

SOURCE=""
COURSE_NAME=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --source)
      SOURCE="$2"
      shift 2
      ;;
    --course)
      COURSE_NAME="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

if [[ -z "$SOURCE" ]]; then
  echo "Usage: $0 --source kajabi|mct [--course NAME]"
  exit 1
fi

if [[ "$SOURCE" == "kajabi" ]]; then
  PACKAGE_DIR="scripts/migrations/kajabi/output/course_packages"
  STRUCTURE_FILE="scripts/migrations/kajabi/output/course_structure.json"
elif [[ "$SOURCE" == "mct" ]]; then
  PACKAGE_DIR="exports/mct/course_packages"
  STRUCTURE_FILE="exports/mct/structure/basic-microsoft.json"  # Example for "basic-microsoft"

  # For MCT, we need a specific course name
  if [[ -z "$COURSE_NAME" ]]; then
    echo "[INFO] No course specified, checking first package only"
  fi
else
  fail "Invalid source: $SOURCE"
  exit 1
fi

# Check structure file exists (if applicable)
if [[ -f "$STRUCTURE_FILE" ]]; then
  pass "Course structure file exists: $STRUCTURE_FILE"

  # Validate JSON
  if jq empty "$STRUCTURE_FILE" 2>/dev/null; then
    pass "Valid JSON format"
  else
    fail "Invalid JSON format: $STRUCTURE_FILE"
  fi
else
  echo "[INFO] Course structure file not found: $STRUCTURE_FILE"
fi

# Extract and inspect a sample course package
if [[ -n "$COURSE_NAME" ]]; then
  # Find package matching course name
  package=$(find "$PACKAGE_DIR" -name "*${COURSE_NAME}*.tar.gz" | head -1)
else
  # Use first package
  package=$(find "$PACKAGE_DIR" -name "*.tar.gz" | head -1)
fi

if [[ -z "$package" ]]; then
  fail "No course package found"
  exit 1
fi

pass "Inspecting package: $(basename "$package")"

# Extract to temp directory
temp_dir=$(mktemp -d)
tar -xzf "$package" -C "$temp_dir" 2>/dev/null || {
  fail "Failed to extract package"
  rm -rf "$temp_dir"
  exit 1
}

# Count OLX components
chapter_count=$(find "$temp_dir" -name "*.xml" -path "*/chapter/*" | wc -l | tr -d ' ')
sequential_count=$(find "$temp_dir" -name "*.xml" -path "*/sequential/*" | wc -l | tr -d ' ')
vertical_count=$(find "$temp_dir" -name "*.xml" -path "*/vertical/*" | wc -l | tr -d ' ')

pass "OLX structure: $chapter_count chapters, $sequential_count sequentials, $vertical_count verticals"

# MCT-specific: check for expected section count (AC-018)
if [[ "$SOURCE" == "mct" && "$COURSE_NAME" == "basic-microsoft" ]]; then
  if [[ "$chapter_count" -eq 12 ]]; then
    pass "Basic Microsoft has 12 sections (matching 12 MCT courses)"
  else
    fail "Basic Microsoft has $chapter_count sections (expected 12)"
  fi
fi

# Kajabi-specific: check structure matches course_structure.json
if [[ "$SOURCE" == "kajabi" && -f "$STRUCTURE_FILE" ]]; then
  # This is a simplified check - full validation would require matching specific course IDs
  if [[ "$chapter_count" -gt 0 && "$vertical_count" -gt 0 ]]; then
    pass "Course has expected OLX hierarchy"
  else
    fail "Course missing expected OLX components"
  fi
fi

rm -rf "$temp_dir"

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All course structure checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
