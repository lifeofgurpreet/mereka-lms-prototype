#!/usr/bin/env bash
# @covers AC-CI-012
# @spec: ci-cd-pipeline_spec.md
#
# verify-image-freshness.sh - Detect silently failing image builds
#
# Invariant: The mereka-brand mutable tag on GHCR must be refreshed at least
# once every MAX_AGE_DAYS days. If it's stale, image builds are broken and
# nobody noticed — the exact failure mode that caused academyv2.mereka.dev
# to run stock Open edX branding for days (March 2026 incident).
#
# Usage:
#   ./scripts/qa/verify-image-freshness.sh           # check all images
#   MAX_AGE_DAYS=3 ./scripts/qa/verify-image-freshness.sh  # stricter threshold

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0
WARNED=0

do_pass() { echo -e "${GREEN}PASS${NC} $1"; PASSED=$((PASSED + 1)); }
do_fail() { echo -e "${RED}FAIL${NC} $1"; FAILED=$((FAILED + 1)); }
do_warn() { echo -e "${YELLOW}WARN${NC} $1"; WARNED=$((WARNED + 1)); }

MAX_AGE_HOURS="${MAX_AGE_HOURS:-24}"
REGISTRY="ghcr.io/biji-biji-initiative/mereka-lms"

echo "=== Image Freshness Verification ==="
echo "Max age: ${MAX_AGE_HOURS} hours"
echo

# Images and their mutable tags that must stay fresh
declare -A IMAGES=(
  ["openedx"]="mereka-brand"
  ["mfe"]="mereka-brand"
)

check_image_freshness() {
  local image="$1"
  local tag="$2"
  local full_ref="${REGISTRY}/${image}:${tag}"

  echo "Checking ${full_ref} ..."

  # Method 1: Use gh api to check GHCR package versions
  local updated_at=""
  updated_at=$(gh api \
    "orgs/biji-biji-initiative/packages/container/mereka-lms%2F${image}/versions" \
    --jq "[.[] | select(.metadata.container.tags[] == \"${tag}\")] | .[0].updated_at // empty" \
    2>/dev/null || echo "")

  if [[ -z "$updated_at" ]]; then
    # Method 2: Try crane if available
    if command -v crane &>/dev/null; then
      updated_at=$(crane config "${full_ref}" 2>/dev/null | \
        python3 -c "import sys,json; print(json.load(sys.stdin).get('created',''))" 2>/dev/null || echo "")
    fi
  fi

  if [[ -z "$updated_at" ]]; then
    # Method 3: Check recent workflow runs as proxy
    local last_success=""
    last_success=$(gh run list \
      --workflow=build-tutor-images.yml \
      --status=completed \
      --json conclusion,updatedAt \
      --jq '[.[] | select(.conclusion=="success")] | .[0].updatedAt // empty' \
      2>/dev/null || echo "")

    if [[ -n "$last_success" ]]; then
      updated_at="$last_success"
      echo "  (using last successful build run as proxy for image age)"
    fi
  fi

  if [[ -z "$updated_at" ]]; then
    do_fail "${image}:${tag} — cannot determine image age (tag may not exist on GHCR)"
    return
  fi

  # Calculate age in days
  local updated_epoch=""
  local now_epoch=""
  updated_epoch=$(date -d "$updated_at" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$updated_at" +%s 2>/dev/null || echo "")
  now_epoch=$(date +%s)

  if [[ -z "$updated_epoch" ]]; then
    do_warn "${image}:${tag} — could not parse timestamp: ${updated_at}"
    return
  fi

  local age_seconds=$((now_epoch - updated_epoch))
  local age_hours=$((age_seconds / 3600))

  if [[ "$age_hours" -le "$MAX_AGE_HOURS" ]]; then
    do_pass "${image}:${tag} — ${age_hours}h old (threshold: ${MAX_AGE_HOURS}h)"
  else
    do_fail "${image}:${tag} — ${age_hours}h old (threshold: ${MAX_AGE_HOURS}h) — image builds are likely broken!"
    echo "       Last updated: ${updated_at}"
    echo "       Action: Check build-tutor-images.yml workflow for recent failures"
    echo "       Quick fix: gh workflow run build-tutor-images.yml"
  fi
}

# --- Section 1: Image freshness ---
echo "=== Section 1: GHCR Image Freshness ==="
echo

for image in "${!IMAGES[@]}"; do
  check_image_freshness "$image" "${IMAGES[$image]}"
done

echo

# --- Section 2: Recent build health ---
echo "=== Section 2: Recent Build Health ==="
echo

# Check if the last N builds succeeded
RECENT_BUILDS=$(gh run list \
  --workflow=build-tutor-images.yml \
  --limit 5 \
  --json conclusion,displayTitle,updatedAt \
  --jq '.[] | "\(.conclusion)\t\(.updatedAt)\t\(.displayTitle)"' \
  2>/dev/null || echo "")

if [[ -z "$RECENT_BUILDS" ]]; then
  do_warn "Could not fetch recent build runs (gh auth may be missing)"
else
  CONSECUTIVE_FAILURES=0
  while IFS=$'\t' read -r conclusion updated_at title; do
    case "$conclusion" in
      success) break ;;
      failure|startup_failure)
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        ;;
      cancelled) ;; # skip
    esac
  done <<< "$RECENT_BUILDS"

  if [[ "$CONSECUTIVE_FAILURES" -eq 0 ]]; then
    do_pass "Last build succeeded"
  elif [[ "$CONSECUTIVE_FAILURES" -lt 3 ]]; then
    do_warn "${CONSECUTIVE_FAILURES} consecutive build failure(s) — investigate soon"
  else
    do_fail "${CONSECUTIVE_FAILURES} consecutive build failures — image pipeline is broken!"
    echo "       Action: gh run list --workflow=build-tutor-images.yml --limit 5"
  fi
fi

echo

# --- Section 3: Build workflow file sanity ---
echo "=== Section 3: Build Workflow Sanity ==="
echo

BUILD_WF="$REPO_ROOT/.github/workflows/build-tutor-images.yml"

if [[ -f "$BUILD_WF" ]]; then
  # Ensure BuildKit is enabled (never DOCKER_BUILDKIT=0)
  if grep -q 'DOCKER_BUILDKIT:\s*0' "$BUILD_WF" || grep -q "DOCKER_BUILDKIT=0" "$BUILD_WF"; then
    do_fail "build-tutor-images.yml disables BuildKit (DOCKER_BUILDKIT=0) — cache won't work"
  else
    do_pass "BuildKit is not disabled in build workflow"
  fi

  # Ensure cache-from is used
  if grep -q '\-\-cache-from' "$BUILD_WF"; then
    do_pass "Build workflow uses --cache-from for layer caching"
  else
    do_fail "Build workflow missing --cache-from — every build starts from scratch"
  fi

  # Ensure mereka-brand tag is pushed
  if grep -q 'mereka-brand' "$BUILD_WF"; then
    do_pass "Build workflow pushes mereka-brand mutable tag"
  else
    do_fail "Build workflow does not push mereka-brand tag"
  fi

  # Ensure heavy builders are used for image builds
  if grep -q 'mereka-k8s-heavy-builders' "$BUILD_WF"; then
    do_pass "Image builds use heavy-builder runners"
  else
    do_warn "Image builds may not use heavy-builder runners"
  fi
else
  do_fail "Build workflow not found at $BUILD_WF"
fi

echo

# --- Summary ---
echo "=== Summary ==="
echo -e "${GREEN}PASS:${NC} $PASSED | ${RED}FAIL:${NC} $FAILED | ${YELLOW}WARN:${NC} $WARNED"
echo

if [[ $FAILED -gt 0 ]]; then
  echo "Image freshness issues detected."
  echo "Stale images mean academyv2.mereka.dev runs unbranded Open edX."
  echo "Fix: investigate build-tutor-images.yml failures and re-trigger."
  exit 1
fi

if [[ $WARNED -gt 0 ]]; then
  echo "Image freshness verified with warnings."
  exit 0
fi

echo "All image freshness checks passed!"
exit 0
