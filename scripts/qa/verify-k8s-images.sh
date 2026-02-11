#!/usr/bin/env bash
# @covers AC-025, AC-026
# @spec: k8s-deployment_spec.md
set -euo pipefail

# verify-k8s-images.sh - Verifies production image tags in K8s manifests
#
# Usage:
#   scripts/qa/verify-k8s-images.sh                      # Run all checks
#   scripts/qa/verify-k8s-images.sh --check no-latest    # Check for :latest tags
#   scripts/qa/verify-k8s-images.sh --check registry-path # Check registry paths

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROD_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"
BASE_KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/base/kustomization.yaml"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Counters
PASS=0
FAIL=0

# Helper functions
pass() {
  echo -e "${GREEN}✓${NC} $1"
  PASS=$((PASS + 1))
}

fail() {
  echo -e "${RED}✗${NC} $1"
  FAIL=$((FAIL + 1))
}

warn() {
  echo -e "${YELLOW}⚠${NC} $1"
}

# Check 1: No :latest tags in production
check_no_latest() {
  echo "Checking for :latest tags in production images..."

  if [[ ! -f "$PROD_KUSTOMIZATION" ]]; then
    fail "File not found: $PROD_KUSTOMIZATION"
    return
  fi

  # Extract image tags from production kustomization
  local in_images=false
  local latest_found=false
  local latest_images=()

  while IFS= read -r line; do
    # Detect images section
    if [[ "$line" =~ ^images: ]]; then
      in_images=true
      continue
    fi

    # Exit images section if we hit another top-level key
    if [[ "$in_images" == true && "$line" =~ ^[a-zA-Z] ]]; then
      in_images=false
    fi

    # Check for :latest tag
    if [[ "$in_images" == true && "$line" =~ newTag:[[:space:]]*(.+) ]]; then
      local tag="${BASH_REMATCH[1]}"
      if [[ "$tag" == "latest" ]]; then
        latest_found=true
        # Try to find the image name from previous lines
        local context
        context=$(grep -B 3 "newTag: $tag" "$PROD_KUSTOMIZATION" | grep "newName:" | tail -1 | sed -E 's/.*newName:\s+//' || echo "unknown")
        latest_images+=("$context")
      fi
    fi
  done < "$PROD_KUSTOMIZATION"

  if [[ "$latest_found" == true ]]; then
    fail "Found :latest tags in production images:"
    for img in "${latest_images[@]}"; do
      echo "    - $img"
    done
  else
    pass "No :latest tags found in production kustomization"
  fi
}

# Check 2: OpenEdX images use correct registry path and date-SHA format
check_registry_path() {
  echo "Checking OpenEdX image registry paths and tag format..."

  local files=("$PROD_KUSTOMIZATION" "$BASE_KUSTOMIZATION")
  local expected_registry="asia-southeast1-docker.pkg.dev/mereka-lms/openedx/"
  local tag_pattern='^[0-9]{8}-.*-[a-f0-9]+$'

  local all_valid=true
  local checked=0

  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      warn "File not found: $file (skipping)"
      continue
    fi

    local in_images=false
    local current_image=""
    local current_tag=""

    while IFS= read -r line; do
      # Detect images section
      if [[ "$line" =~ ^images: ]]; then
        in_images=true
        continue
      fi

      # Exit images section
      if [[ "$in_images" == true && "$line" =~ ^[a-zA-Z] ]]; then
        in_images=false
      fi

      # Extract newName (registry path)
      if [[ "$in_images" == true && "$line" =~ newName:[[:space:]]*(.+) ]]; then
        current_image="${BASH_REMATCH[1]}"
      fi

      # Extract newTag and validate
      if [[ "$in_images" == true && "$line" =~ newTag:[[:space:]]*(.+) ]]; then
        current_tag="${BASH_REMATCH[1]}"

        # Only check OpenEdX images from our registry
        if [[ "$current_image" == ${expected_registry}* ]]; then
          checked=$((checked + 1))

          # Check if it follows date-SHA pattern (YYYYMMDD-*-HASH)
          if [[ "$current_tag" =~ $tag_pattern ]]; then
            pass "$current_image:$current_tag (valid format)"
          else
            fail "$current_image:$current_tag (invalid format, expected: YYYYMMDD-*-HASH)"
            all_valid=false
          fi
        fi

        current_image=""
        current_tag=""
      fi
    done < "$file"
  done

  if [[ $checked -eq 0 ]]; then
    warn "No OpenEdX images found in kustomization files"
  elif [[ "$all_valid" == true ]]; then
    pass "All $checked OpenEdX images use correct registry and tag format"
  fi
}

# Main execution
main() {
  local check_type="all"

  # Parse arguments
  if [[ $# -gt 0 ]]; then
    if [[ "$1" == "--check" && $# -eq 2 ]]; then
      check_type="$2"
    else
      echo "Usage: $0 [--check no-latest|registry-path]"
      exit 1
    fi
  fi

  echo "=== K8s Image Tag Verification ==="
  echo "Production: $PROD_KUSTOMIZATION"
  echo "Base: $BASE_KUSTOMIZATION"
  echo

  # Run checks
  case "$check_type" in
    no-latest)
      check_no_latest
      ;;
    registry-path)
      check_registry_path
      ;;
    all)
      check_no_latest
      echo
      check_registry_path
      ;;
    *)
      echo "Unknown check type: $check_type"
      exit 1
      ;;
  esac

  # Summary
  echo
  echo "=== Summary ==="
  echo -e "${GREEN}PASS:${NC} $PASS"
  echo -e "${RED}FAIL:${NC} $FAIL"

  if [[ $FAIL -gt 0 ]]; then
    exit 1
  fi

  exit 0
}

main "$@"
