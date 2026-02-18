#!/usr/bin/env bash
# @covers AC-OPS-080, AC-OPS-081, AC-OPS-082, AC-OPS-083
# @spec: ops-runbook_spec.md
#
# Canonical single-tree release workflow for Mereka LMS.
# Enforces: canonical path, main branch, no stale worktrees,
# image hash cache check, and delegates to release-openedx-gitops.sh.
#
# Usage:
#   ./scripts/infra/canonical-release.sh --openedx-tag TAG --mfe-tag TAG [options]
#   ./scripts/infra/canonical-release.sh --check-only   # Just validate environment
#   ./scripts/infra/canonical-release.sh --dry-run       # Full dry-run with cache check

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# ── AC-OPS-082: Canonical path and worktree enforcement ──────────────

CANONICAL_PATH="/home/gurpreet/projects/k8s/mereka-lms"
CANONICAL_BRANCH="main"
CACHE_DIR="${REPO_ROOT}/var/build-cache"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

fail_hard() { echo -e "${RED}HARD FAIL${NC}: $1" >&2; exit 1; }
warn()      { echo -e "${YELLOW}WARN${NC}: $1"; }
ok()        { echo -e "${GREEN}OK${NC}: $1"; }
info()      { echo -e "INFO: $1"; }

CHECK_ONLY=0
DRY_RUN=0
PASSTHROUGH_ARGS=()

# Parse our flags, pass the rest through
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --check-only) CHECK_ONLY=1; shift ;;
    --dry-run)    DRY_RUN=1; shift ;;
    *)            ARGS+=("$1"); shift ;;
  esac
done

check_canonical_environment() {
  local errors=0

  # 1. Canonical path
  local real_repo
  real_repo="$(realpath "$REPO_ROOT")"
  local real_canonical
  real_canonical="$(realpath "$CANONICAL_PATH" 2>/dev/null || echo "$CANONICAL_PATH")"

  if [[ "$real_repo" != "$real_canonical" ]]; then
    fail_hard "Non-canonical path: $real_repo (expected $real_canonical)"
  fi
  ok "Canonical path: $real_repo"

  # 2. Branch check
  local current_branch
  current_branch="$(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
  if [[ "$current_branch" != "$CANONICAL_BRANCH" ]]; then
    fail_hard "Non-canonical branch: $current_branch (expected $CANONICAL_BRANCH)"
  fi
  ok "Branch: $current_branch"

  # 3. Stale worktree check
  local worktree_count
  worktree_count="$(git -C "$REPO_ROOT" worktree list | wc -l)"
  if [[ "$worktree_count" -gt 1 ]]; then
    warn "Multiple worktrees detected ($worktree_count):"
    git -C "$REPO_ROOT" worktree list | while read -r line; do
      echo "  $line"
    done
    # Check for stale worktrees (missing paths)
    local stale=0
    while IFS= read -r wt_path; do
      if [[ ! -d "$wt_path" ]]; then
        warn "Stale worktree: $wt_path (path does not exist)"
        stale=1
      fi
    done < <(git -C "$REPO_ROOT" worktree list --porcelain | grep "^worktree " | sed 's/^worktree //')
    if [[ "$stale" -eq 1 ]]; then
      fail_hard "Stale worktrees detected. Run: git worktree prune"
    fi
  else
    ok "Single worktree (no drift risk)"
  fi

  # 4. Clean working tree
  if [[ -n "$(git -C "$REPO_ROOT" status --porcelain --ignore-submodules 2>/dev/null)" ]]; then
    warn "Working tree has uncommitted changes"
  else
    ok "Working tree clean"
  fi

  # 5. Up-to-date with remote
  git -C "$REPO_ROOT" fetch origin "$CANONICAL_BRANCH" --quiet 2>/dev/null || true
  local local_sha remote_sha
  local_sha="$(git -C "$REPO_ROOT" rev-parse HEAD)"
  remote_sha="$(git -C "$REPO_ROOT" rev-parse "origin/$CANONICAL_BRANCH" 2>/dev/null || echo "unknown")"
  if [[ "$local_sha" != "$remote_sha" && "$remote_sha" != "unknown" ]]; then
    warn "Local HEAD ($local_sha) differs from origin/$CANONICAL_BRANCH ($remote_sha)"
  else
    ok "HEAD matches origin/$CANONICAL_BRANCH"
  fi

  return $errors
}

# ── AC-OPS-081: Image hash cache check ──────────────────────────────

ensure_cache_dir() {
  mkdir -p "$CACHE_DIR"
}

get_cached_digest() {
  local image_name="$1"
  local cache_file="$CACHE_DIR/${image_name//\//_}.digest"
  if [[ -f "$cache_file" ]]; then
    cat "$cache_file"
  else
    echo ""
  fi
}

save_cached_digest() {
  local image_name="$1"
  local digest="$2"
  local cache_file="$CACHE_DIR/${image_name//\//_}.digest"
  echo "$digest" > "$cache_file"
}

check_image_cache() {
  local registry="asia-southeast1-docker.pkg.dev/mereka-lms/openedx"

  ensure_cache_dir
  info "Checking image cache for rebuild skip..."

  local openedx_tag mfe_tag
  # Extract tags from args
  for ((i=0; i<${#ARGS[@]}; i++)); do
    case "${ARGS[$i]}" in
      --openedx-tag) openedx_tag="${ARGS[$((i+1))]:-}" ;;
      --mfe-tag)     mfe_tag="${ARGS[$((i+1))]:-}" ;;
    esac
  done

  if [[ -z "${openedx_tag:-}" || -z "${mfe_tag:-}" ]]; then
    info "Tags not provided — skipping cache check"
    return 1
  fi

  local skipped=0

  # Check openedx image
  local openedx_remote_digest
  openedx_remote_digest="$(gcloud artifacts docker images describe \
    "${registry}/openedx:${openedx_tag}" \
    --format='value(image_summary.digest)' 2>/dev/null || echo "")"

  if [[ -n "$openedx_remote_digest" ]]; then
    local cached_openedx
    cached_openedx="$(get_cached_digest "openedx_${openedx_tag}")"
    if [[ "$openedx_remote_digest" == "$cached_openedx" ]]; then
      ok "openedx:${openedx_tag} — cache hit (digest unchanged: ${openedx_remote_digest:0:20}...)"
      skipped=$((skipped + 1))
    else
      info "openedx:${openedx_tag} — cache miss or digest changed"
      save_cached_digest "openedx_${openedx_tag}" "$openedx_remote_digest"
    fi
  else
    info "openedx:${openedx_tag} — not in registry (new build needed)"
  fi

  # Check mfe image
  local mfe_remote_digest
  mfe_remote_digest="$(gcloud artifacts docker images describe \
    "${registry}/openedx-mfe:${mfe_tag}" \
    --format='value(image_summary.digest)' 2>/dev/null || echo "")"

  if [[ -n "$mfe_remote_digest" ]]; then
    local cached_mfe
    cached_mfe="$(get_cached_digest "mfe_${mfe_tag}")"
    if [[ "$mfe_remote_digest" == "$cached_mfe" ]]; then
      ok "openedx-mfe:${mfe_tag} — cache hit (digest unchanged: ${mfe_remote_digest:0:20}...)"
      skipped=$((skipped + 1))
    else
      info "openedx-mfe:${mfe_tag} — cache miss or digest changed"
      save_cached_digest "mfe_${mfe_tag}" "$mfe_remote_digest"
    fi
  else
    info "openedx-mfe:${mfe_tag} — not in registry (new build needed)"
  fi

  if [[ "$skipped" -eq 2 ]]; then
    ok "Both images unchanged — no rebuild needed (cache reuse)"
    return 0
  fi
  return 1
}

# ── AC-OPS-083: Dry-run output ──────────────────────────────────────

print_dry_run_summary() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "CANONICAL RELEASE DRY-RUN SUMMARY"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "Repo:     $REPO_ROOT"
  echo "Branch:   $(git -C "$REPO_ROOT" rev-parse --abbrev-ref HEAD)"
  echo "HEAD:     $(git -C "$REPO_ROOT" rev-parse --short HEAD)"
  echo "Worktrees: $(git -C "$REPO_ROOT" worktree list | wc -l)"
  echo ""
  echo "Release script: scripts/infra/release-openedx-gitops.sh"
  echo "Args: ${ARGS[*]:-<none>}"
  echo ""

  if check_image_cache 2>/dev/null; then
    echo "Cache result: SKIP (both images unchanged)"
  else
    echo "Cache result: BUILD NEEDED (one or more images changed/missing)"
  fi
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# ── Main ─────────────────────────────────────────────────────────────

echo "Canonical Release Workflow"
echo "========================="
echo ""

check_canonical_environment

if [[ "$CHECK_ONLY" -eq 1 ]]; then
  echo ""
  ok "Environment checks passed. Ready for release."
  exit 0
fi

if [[ "$DRY_RUN" -eq 1 ]]; then
  print_dry_run_summary
  echo ""
  info "Delegating to release-openedx-gitops.sh (dry-run mode)..."
  "$REPO_ROOT/scripts/infra/release-openedx-gitops.sh" "${ARGS[@]}" || true
  exit 0
fi

# Full release: check cache, then delegate
echo ""
info "Checking image cache..."
if check_image_cache; then
  info "Skipping build phase (cache hit). Proceeding to tag update only."
fi

echo ""
info "Delegating to release-openedx-gitops.sh..."
exec "$REPO_ROOT/scripts/infra/release-openedx-gitops.sh" "${ARGS[@]}"
