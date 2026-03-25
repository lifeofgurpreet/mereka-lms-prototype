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

materialize_overlay_source() {
  local infra_root="$1"
  local relative_path="$2"
  local overlay_path="${infra_root}/${relative_path}"
  local overlay_source="${overlay_path}"
  local overlay_cleanup=""

  if [[ ! -f "$overlay_path" ]]; then
    return 1
  fi

  # When the caller explicitly points at a checkout, honor that checkout so PR
  # branches can be validated before merge.
  if [[ -z "$BBI_INFRA_ROOT" ]] && git -C "$infra_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git -C "$infra_root" fetch --quiet origin main >/dev/null 2>&1 || true
    if git -C "$infra_root" rev-parse --verify origin/main >/dev/null 2>&1; then
      overlay_source="$(mktemp)"
      overlay_cleanup="$overlay_source"
      if ! git -C "$infra_root" show "origin/main:${relative_path}" >"$overlay_source" 2>/dev/null; then
        rm -f "$overlay_source"
        overlay_source="$overlay_path"
        overlay_cleanup=""
      fi
    fi
  fi

  printf '%s\n%s\n' "$overlay_source" "$overlay_cleanup"
}

extract_kustomize_image_field() {
  local kustomization="$1"
  local image_name="$2"
  local field_name="$3"
  python3 - "$kustomization" "$image_name" "$field_name" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
image_name = sys.argv[2]
field_name = sys.argv[3]

current_name = None
found = False
value = ""

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
        field_match = re.match(rf"^\s*{re.escape(field_name)}:\s*(\S+)\s*$", line)
        if field_match:
            value = field_match.group(1).strip("\"'")
            break

if not found:
    sys.exit(1)

print(value)
PY
}

extract_kustomize_new_tag() {
  extract_kustomize_image_field "$1" "$2" "newTag"
}

extract_kustomize_digest() {
  extract_kustomize_image_field "$1" "$2" "digest"
}

ghcr_package_has_tag() {
  local package_name="$1"
  local tag="$2"
  local encoded_package="${package_name//\//%2F}"

  gh api "orgs/Biji-Biji-Initiative/packages/container/${encoded_package}/versions?per_page=100" 2>/dev/null \
    | jq -e --arg tag "$tag" 'map(select(any(.metadata.container.tags[]?; . == $tag))) | length > 0' >/dev/null
}

latest_successful_workflow_run() {
  local workflow="$1"
  gh run list \
    --repo Biji-Biji-Initiative/mereka-lms \
    --workflow "$workflow" \
    --branch main \
    --status completed \
    --limit 10 \
    --json conclusion,headSha,url \
    2>/dev/null \
    | jq -r 'map(select(.conclusion=="success")) | .[0] | (.headSha // ""), (.url // "")'
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

  local overlay_info=()
  mapfile -t overlay_info < <(materialize_overlay_source "$infra_root" "apps/mereka-lms/overlays/profiles/dev/kustomization.yaml")
  local overlay_source="${overlay_info[0]:-}"
  local overlay_cleanup="${overlay_info[1]:-}"
  if [[ -z "$overlay_source" ]]; then
    do_warn "enterprise portal dev pin freshness — missing dev overlay: apps/mereka-lms/overlays/profiles/dev/kustomization.yaml"
    echo
    return
  fi

  local latest_info=()
  mapfile -t latest_info < <(latest_successful_workflow_run build-enterprise-mfe.yml)
  local latest_sha="${latest_info[0]:-}"
  local latest_url="${latest_info[1]:-}"

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

check_purchase_gateway_promotion_truth() {
  echo "=== Section 3: Purchase Gateway Promotion Truth ==="
  echo

  if ! command -v gh &>/dev/null; then
    do_warn "purchase-gateway promotion truth — gh CLI unavailable"
    echo
    return
  fi

  if ! command -v jq &>/dev/null; then
    do_warn "purchase-gateway promotion truth — jq unavailable"
    echo
    return
  fi

  local infra_root=""
  if ! infra_root="$(resolve_bbi_infra_root)"; then
    do_warn "purchase-gateway promotion truth — bbi-infrastructure checkout not found (set BBI_INFRA_ROOT)"
    echo
    return
  fi

  local latest_info=()
  mapfile -t latest_info < <(latest_successful_workflow_run build-purchase-gateway.yml)
  local latest_sha="${latest_info[0]:-}"
  local latest_url="${latest_info[1]:-}"
  if [[ -z "$latest_sha" ]]; then
    do_warn "purchase-gateway promotion truth — could not determine latest successful main purchase-gateway build"
    echo
    return
  fi

  local image_name="ghcr.io/biji-biji-initiative/purchase-gateway"

  local dev_info=()
  mapfile -t dev_info < <(materialize_overlay_source "$infra_root" "apps/mereka-lms/overlays/profiles/dev/kustomization.yaml")
  local dev_overlay="${dev_info[0]:-}"
  local dev_cleanup="${dev_info[1]:-}"
  if [[ -z "$dev_overlay" ]]; then
    do_fail "purchase-gateway dev overlay missing from bbi-infrastructure"
  else
    local dev_tag=""
    if ! dev_tag="$(extract_kustomize_new_tag "$dev_overlay" "$image_name" 2>/dev/null)"; then
      do_fail "purchase-gateway dev overlay pin missing from ${dev_overlay}"
    elif [[ "$dev_tag" == "${latest_sha}-"* ]]; then
      do_pass "purchase-gateway dev tag tracks latest successful main build (${latest_sha})"
    else
      do_fail "purchase-gateway dev tag is stale (${dev_tag}); expected prefix ${latest_sha}-"
      [[ -n "$latest_url" ]] && echo "       Latest successful build: ${latest_url}"
      echo "       Overlay: ${dev_overlay}"
    fi
  fi
  [[ -n "$dev_cleanup" ]] && rm -f "$dev_cleanup"

  local staging_info=()
  mapfile -t staging_info < <(materialize_overlay_source "$infra_root" "apps/mereka-lms/overlays/staging/kustomization.yaml")
  local staging_overlay="${staging_info[0]:-}"
  local staging_cleanup="${staging_info[1]:-}"
  if [[ -z "$staging_overlay" ]]; then
    do_fail "purchase-gateway staging overlay missing from bbi-infrastructure"
  else
    local staging_tag=""
    local staging_digest=""
    if ! staging_tag="$(extract_kustomize_new_tag "$staging_overlay" "$image_name" 2>/dev/null)"; then
      do_fail "purchase-gateway staging pin missing from ${staging_overlay}"
    else
      do_pass "purchase-gateway staging overlay declares an explicit image tag (${staging_tag})"
      staging_digest="$(extract_kustomize_digest "$staging_overlay" "$image_name" 2>/dev/null || true)"
      if [[ -z "$staging_digest" ]]; then
        do_fail "purchase-gateway staging pin missing digest in ${staging_overlay}"
      else
        do_pass "purchase-gateway staging overlay is digest-pinned (${staging_digest})"
      fi

      if ghcr_package_has_tag "purchase-gateway" "$staging_tag"; then
        do_pass "purchase-gateway staging tag exists on GHCR (${staging_tag})"
      else
        do_fail "purchase-gateway staging tag does not exist on GHCR (${staging_tag})"
      fi
    fi
  fi
  [[ -n "$staging_cleanup" ]] && rm -f "$staging_cleanup"

  local prod_info=()
  mapfile -t prod_info < <(materialize_overlay_source "$infra_root" "apps/mereka-lms/overlays/prod/kustomization.yaml")
  local prod_overlay="${prod_info[0]:-}"
  local prod_cleanup="${prod_info[1]:-}"
  if [[ -z "$prod_overlay" ]]; then
    do_warn "purchase-gateway prod overlay missing from bbi-infrastructure"
  else
    local prod_tag=""
    if ! prod_tag="$(extract_kustomize_new_tag "$prod_overlay" "$image_name" 2>/dev/null)"; then
      do_warn "purchase-gateway prod overlay pin missing — prod currently inherits the app base image contract"
    elif ghcr_package_has_tag "purchase-gateway" "$prod_tag"; then
      do_pass "purchase-gateway prod overlay tag exists on GHCR (${prod_tag})"
    else
      do_fail "purchase-gateway prod overlay tag does not exist on GHCR (${prod_tag})"
    fi
  fi
  [[ -n "$prod_cleanup" ]] && rm -f "$prod_cleanup"

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

# --- Section 3: Purchase gateway promotion truth ---
check_purchase_gateway_promotion_truth

# --- Section 4: Recent build health ---
echo "=== Section 4: Recent Build Health ==="
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

# --- Section 5: Build workflow file sanity ---
echo "=== Section 5: Build Workflow Sanity ==="
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
  echo "Broken build or promotion paths can leave environments on stale or nonexistent images."
  echo "Fix: investigate broken build lanes, missing GitOps pins, or stale promotion paths and re-trigger."
  exit 1
fi

if [[ $WARNED -gt 0 ]]; then
  echo "Image freshness verified with warnings."
  exit 0
fi

echo "All image freshness checks passed!"
exit 0
