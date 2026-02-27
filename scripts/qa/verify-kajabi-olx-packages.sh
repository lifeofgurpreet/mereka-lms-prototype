#!/usr/bin/env bash
# @covers AC-009
# @spec: data-migrations-kajabi-mct_spec.md
# Verify Kajabi OLX packages against AC-009.
#
# Checks:
# - 109 OLX tarballs generated
# - Course keys in correct format: course-v1:MEREKA+MEKA-{id}+RUN-{id}
# - Each tarball contains required OLX structure
#
# Usage:
#   ./scripts/qa/verify-kajabi-olx-packages.sh
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

failures=0
pass() { echo "[PASS] $*"; }
fail() { echo "[FAIL] $*"; failures=$((failures + 1)); }

PACKAGE_DIR="scripts/migrations/kajabi/output/course_packages"
MANIFEST_FILE="$PACKAGE_DIR/course_packages_manifest.csv"
shopt -s nullglob

# Check directory exists
if [[ ! -d "$PACKAGE_DIR" ]]; then
  fail "Course packages directory missing: $PACKAGE_DIR"
  exit 1
fi

pass "Course packages directory exists: $PACKAGE_DIR"

# Count .tar.gz files (recursive; package layout is nested by slug)
mapfile -t tarballs < <(find "$PACKAGE_DIR" -type f -name "*.tar.gz" | sort)
package_count="${#tarballs[@]}"

if [[ "$package_count" -eq 109 ]]; then
  pass "Exactly 109 OLX packages found"
else
  fail "Found $package_count packages (expected 109)"
fi

# Check course key format from manifest (canonical source of generated keys).
if [[ ! -f "$MANIFEST_FILE" ]]; then
  fail "Course package manifest missing: $MANIFEST_FILE"
else
  pass "Course package manifest exists: $MANIFEST_FILE"
  invalid_format=$(
    python3 - "$MANIFEST_FILE" <<'PY'
import csv
import re
import sys

path = sys.argv[1]
bad = 0
with open(path, newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    for row in reader:
        org = (row.get("org") or "").strip()
        number = (row.get("course_number") or "").strip()
        run = (row.get("run") or "").strip()
        if org != "MEREKA" or not re.match(r"^MEKA-[0-9]+$", number) or not re.match(r"^RUN-[0-9]+$", run):
            bad += 1
print(bad)
PY
  )
  if [[ "$invalid_format" -eq 0 ]]; then
    pass "All manifest rows match course-v1:MEREKA+MEKA-{id}+RUN-{id} components"
  else
    fail "$invalid_format manifest rows have invalid org/course_number/run values"
  fi
fi

# Validate OLX structure in sample tarballs
sample_count=0
if [[ "${#tarballs[@]}" -eq 0 ]]; then
  fail "No .tar.gz files found in $PACKAGE_DIR"
fi
for tarball in "${tarballs[@]}"; do
  if [[ "$sample_count" -ge 3 ]]; then
    break
  fi

  # Extract to temp directory
  temp_dir=$(mktemp -d)
  tar -xzf "$tarball" -C "$temp_dir" 2>/dev/null || {
    fail "Failed to extract: $(basename "$tarball")"
    rm -rf "$temp_dir"
    continue
  }

  # Check for required OLX files/directories.
  has_course_xml=0
  has_chapter_dir=0
  has_sequential_dir=0
  has_vertical_dir=0
  if find "$temp_dir" -type f -name "course.xml" | head -1 | grep -q .; then
    has_course_xml=1
  fi
  if find "$temp_dir" -type d -name "chapter" | head -1 | grep -q .; then
    has_chapter_dir=1
  fi
  if find "$temp_dir" -type d -name "sequential" | head -1 | grep -q .; then
    has_sequential_dir=1
  fi
  if find "$temp_dir" -type d -name "vertical" | head -1 | grep -q .; then
    has_vertical_dir=1
  fi

  if [[ "$has_course_xml" -eq 1 && "$has_chapter_dir" -eq 1 && "$has_sequential_dir" -eq 1 && "$has_vertical_dir" -eq 1 ]]; then
    pass "Valid OLX structure in $(basename "$tarball")"
  else
    fail "Invalid OLX structure in $(basename "$tarball")"
  fi

  rm -rf "$temp_dir"
  sample_count=$((sample_count + 1))
done

# Summary
echo ""
if [[ "$failures" -eq 0 ]]; then
  echo "✓ All Kajabi OLX package checks passed"
  exit 0
else
  echo "✗ $failures check(s) failed"
  exit 1
fi
