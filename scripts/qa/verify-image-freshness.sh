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
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"

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
BBI_INFRA_ROOT="${BBI_INFRA_ROOT:-${GITOPS_REPO_ROOT:-${INFRA_REPO:-}}}"

echo "=== Image Freshness Verification ==="
echo "Max age: ${MAX_AGE_HOURS} hours"
echo

# Images and their mutable tags that must stay fresh
declare -A IMAGES=(
  ["openedx"]="mereka-brand"
  ["mfe"]="mereka-brand"
)

resolve_bbi_infra_root() {
  if [[ -n "$BBI_INFRA_ROOT" && -d "$BBI_INFRA_ROOT" ]]; then
    printf '%s\n' "$BBI_INFRA_ROOT"
    return 0
  fi

  local candidate=""
  for candidate in \
    "${WORKSPACE_ROOT}/bbi-infrastructure" \
    "${WORKSPACE_ROOT}/infrastructure/bbi-infrastructure" \
    "${HOME}/projects/k8s/bbi-infrastructure" \
    "${HOME}/projects/infrastructure/bbi-infrastructure" \
    "${HOME}/bbi-infrastructure"; do
    if [[ -d "$candidate/apps/mereka-lms" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  return 1
}

extract_kustomize_new_tag() {
  local kustomization="$1"
  local image_name="$2"
  python3 - "$kustomization" "$image_name" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
image_name = sys.argv[2]

current_name = None
found = False
new_tag = ""

for raw in path.read_text(encoding="utf-8").splitlines():
    line = raw.rstrip()
    name_match = re.match(r"^\s*-\s*name:\s*(\S+)\s*$", line)
    if name_match:
        if found:
            break
        current_name = name_match.group(1)
        found = current_name == image_name
        continue
    if found:
        tag_match = re.match(r"^\s*newTag:\s*(\S+)\s*$", line)
        if tag_match:
            new_tag = tag_match.group(1)
            break

if not found:
    sys.exit(1)

print(new_tag)
PY
}

check_enterprise_dev_promotion_freshness() {
  echo "=== Section 2: Enterprise Dev Promotion Freshness ==="
  echo

  if ! command -v gh &>/dev/null; then
    do_warn "enterprise portal dev pin freshness — gh CLI unavailable"
    echo
    return
  fi

  local infra_root=""
  if ! infra_root="$(resolve_bbi_infra_root)"; then
    do_warn "enterprise portal dev pin freshness — bbi-infrastructure checkout not found (set BBI_INFRA_ROOT)"
    echo
    return
  fi

  local dev_overlay="${infra_root}/apps/mereka-lms/overlays/profiles/dev/kustomization.yaml"
  local overlay_source="${dev_overlay}"
  local overlay_cleanup=""
  if [[ ! -f "$dev_overlay" ]]; then
    do_warn "enterprise portal dev pin freshness — missing dev overlay: ${dev_overlay}"
    echo
    return
  fi

  if git -C "$infra_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$infra_root" fetch --quiet origin main >/dev/null 2>&1 || true
    if git -C "$infra_root" rev-parse --verify origin/main >/dev/null 2>&1; then
      overlay_source="$(mktemp)"
      overlay_cleanup="$overlay_source"
      if ! git -C "$infra_root" show origin/main:apps/mereka-lms/overlays/profiles/dev/kustomization.yaml >"$overlay_source" 2>/dev/null; then
        rm -f "$overlay_source"
        overlay_source="$dev_overlay"
        overlay_cleanup=""
        do_warn "enterprise portal dev pin freshness — failed to read origin/main overlay, falling back to local checkout"
      fi
    fi
  fi

  local latest_sha=""
  local latest_url=""
  latest_sha="$(gh run list \
    --repo Biji-Biji-Initiative/mereka-lms \
    --workflow build-enterprise-mfe.yml \
    --branch main \
    --status completed \
    --limit 10 \
    --json conclusion,headSha \
    --jq '[.[] | select(.conclusion=="success")][0].headSha // empty' \
    2>/dev/null || true)"
  latest_url="$(gh run list \
    --repo Biji-Biji-Initiative/mereka-lms \
    --workflow build-enterprise-mfe.yml \
    --branch main \
    --status completed \
    --limit 10 \
    --json conclusion,url \
    --jq '[.[] | select(.conclusion=="success")][0].url // empty' \
    2>/dev/null || true)"

  if [[ -z "$latest_sha" ]]; then
    do_warn "enterprise portal dev pin freshness — could not determine latest successful main enterprise build"
    echo
    return
  fi

  local admin_tag=""
  local learner_tag=""
  if ! admin_tag="$(extract_kustomize_new_tag "$overlay_source" "ghcr.io/biji-biji-initiative/mereka-lms/enterprise-admin-portal" 2>/dev/null)"; then
    do_fail "enterprise admin dev tag missing from ${overlay_source}"
    [[ -n "$overlay_cleanup" ]] && rm -f "$overlay_cleanup"
    echo
    return
  fi
  if ! learner_tag="$(extract_kustomize_new_tag "$overlay_source" "ghcr.io/biji-biji-initiative/mereka-lms/enterprise-learner-portal" 2>/dev/null)"; then
    do_fail "enterprise learner dev tag missing from ${overlay_source}"
    [[ -n "$overlay_cleanup" ]] && rm -f "$overlay_cleanup"
    echo
    return
  fi

  if [[ "$admin_tag" == "${latest_sha}-"* ]]; then
    do_pass "enterprise-admin-portal dev tag tracks latest successful main enterprise build (${latest_sha})"
  else
    do_fail "enterprise-admin-portal dev tag is stale (${admin_tag}); expected prefix ${latest_sha}-"
    [[ -n "$latest_url" ]] && echo "       Latest successful build: ${latest_url}"
    echo "       Overlay: ${overlay_source}"
  fi

  if [[ "$learner_tag" == "${latest_sha}-"* ]]; then
    do_pass "enterprise-learner-portal dev tag tracks latest successful main enterprise build (${latest_sha})"
  else
    do_fail "enterprise-learner-portal dev tag is stale (${learner_tag}); expected prefix ${latest_sha}-"
    [[ -n "$latest_url" ]] && echo "       Latest successful build: ${latest_url}"
    echo "       Overlay: ${overlay_source}"
  fi

  [[ -n "$overlay_cleanup" ]] && rm -f "$overlay_cleanup"
  echo
}

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

# --- Section 2: Enterprise dev promotion freshness ---
check_enterprise_dev_promotion_freshness

# --- Section 3: Recent build health ---
echo "=== Section 3: Recent Build Health ==="
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

# --- Section 4: Build workflow file sanity ---
echo "=== Section 4: Build Workflow Sanity ==="
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
  echo "Fix: investigate broken build lanes or stale GitOps promotion paths and re-trigger."
  exit 1
fi

if [[ $WARNED -gt 0 ]]; then
  echo "Image freshness verified with warnings."
  exit 0
fi

echo "All image freshness checks passed!"
exit 0
