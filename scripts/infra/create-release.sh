#!/usr/bin/env bash
# Create a semver release tag, generate a changelog, and push to origin.
#
# Usage:
#   ./scripts/infra/create-release.sh v1.2.0
#
# The script will:
#   1. Validate the semver tag format
#   2. Confirm main is up-to-date and clean
#   3. Generate a changelog from conventional commits since the previous tag
#   4. Create an annotated git tag
#   5. Push the tag to origin (triggers release.yml workflow)
#   6. Print the rollback command for reference
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

err() { echo "ERROR: $*" >&2; exit 1; }
info() { echo "  $*"; }

usage() {
  echo "Usage: $0 <version>"
  echo ""
  echo "  version   Semver tag, e.g. v1.2.0"
  echo ""
  echo "Examples:"
  echo "  $0 v1.2.0     # minor release"
  echo "  $0 v1.2.1     # patch / hotfix"
  echo "  $0 v2.0.0     # major (breaking)"
  exit 1
}

# ---------------------------------------------------------------------------
# Argument validation
# ---------------------------------------------------------------------------

if [[ $# -ne 1 ]]; then
  usage
fi

VERSION="$1"

if ! echo "${VERSION}" | grep -qE '^v[0-9]+\.[0-9]+\.[0-9]+$'; then
  err "Invalid version '${VERSION}'. Expected format: vMAJOR.MINOR.PATCH (e.g. v1.2.0)"
fi

echo ""
echo "=== Mereka LMS Release: ${VERSION} ==="
echo ""

# ---------------------------------------------------------------------------
# Repo state checks
# ---------------------------------------------------------------------------

cd "${REPO_ROOT}"

info "Checking repo state..."

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [[ "${CURRENT_BRANCH}" != "main" ]]; then
  err "Must be on 'main' branch to create a release. Current branch: ${CURRENT_BRANCH}"
fi

if ! git diff --quiet || ! git diff --cached --quiet; then
  err "Working tree has uncommitted changes. Commit or stash before releasing."
fi

info "Fetching latest from origin..."
git fetch --tags --quiet

LOCAL_SHA="$(git rev-parse HEAD)"
REMOTE_SHA="$(git rev-parse origin/main 2>/dev/null || true)"
if [[ -n "${REMOTE_SHA}" && "${LOCAL_SHA}" != "${REMOTE_SHA}" ]]; then
  err "Local main is not in sync with origin/main. Run: git pull --ff-only"
fi

# Check tag does not already exist
if git tag --list | grep -qxF "${VERSION}"; then
  err "Tag '${VERSION}' already exists. Use a different version."
fi

# ---------------------------------------------------------------------------
# Find previous tag
# ---------------------------------------------------------------------------

PREV_TAG="$(git tag --sort=-version:refname \
  | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' \
  | head -1 \
  || true)"

if [[ -z "${PREV_TAG}" ]]; then
  info "No previous semver tag found. Changelog will cover all commits."
  PREV_REF="$(git rev-list --max-parents=0 HEAD)"
else
  info "Previous release: ${PREV_TAG}"
  PREV_REF="${PREV_TAG}"
fi

# ---------------------------------------------------------------------------
# Generate changelog
# ---------------------------------------------------------------------------

info "Generating changelog from ${PREV_REF} to HEAD..."
echo ""

COMMITS="$(git log "${PREV_REF}..HEAD" \
  --pretty=format:'%s' \
  --no-merges \
  | grep -E '^(feat|fix|docs|refactor|chore|test|perf|ci)(\(.+\))?!?:' \
  || true)"

FEATURES="$(echo "${COMMITS}" | grep -E '^feat(\(.+\))?!?:' || true)"
FIXES="$(echo "${COMMITS}" | grep -E '^fix(\(.+\))?!?:' || true)"
BREAKING="$(echo "${COMMITS}" | grep -E '^(feat|fix|refactor)(\(.+\))?!:' || true)"
DOCS="$(echo "${COMMITS}" | grep -E '^docs(\(.+\))?!?:' || true)"
REFACTORS="$(echo "${COMMITS}" | grep -E '^refactor(\(.+\))?!?:' || true)"
CHORES="$(echo "${COMMITS}" | grep -E '^(chore|ci|test|perf)(\(.+\))?!?:' || true)"
OTHER="$(git log "${PREV_REF}..HEAD" \
  --pretty=format:'%s' \
  --no-merges \
  | grep -vE '^(feat|fix|docs|refactor|chore|test|perf|ci)(\(.+\))?!?:' \
  || true)"

CHANGELOG=""

if [[ -n "${BREAKING}" ]]; then
  CHANGELOG+=$'## Breaking Changes\n\n'
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    CHANGELOG+="- ${line}"$'\n'
  done <<< "${BREAKING}"
  CHANGELOG+=$'\n'
fi

if [[ -n "${FEATURES}" ]]; then
  CHANGELOG+=$'## Features\n\n'
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    CHANGELOG+="- ${line}"$'\n'
  done <<< "${FEATURES}"
  CHANGELOG+=$'\n'
fi

if [[ -n "${FIXES}" ]]; then
  CHANGELOG+=$'## Bug Fixes\n\n'
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    CHANGELOG+="- ${line}"$'\n'
  done <<< "${FIXES}"
  CHANGELOG+=$'\n'
fi

if [[ -n "${DOCS}" ]]; then
  CHANGELOG+=$'## Documentation\n\n'
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    CHANGELOG+="- ${line}"$'\n'
  done <<< "${DOCS}"
  CHANGELOG+=$'\n'
fi

if [[ -n "${REFACTORS}" ]]; then
  CHANGELOG+=$'## Refactoring\n\n'
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    CHANGELOG+="- ${line}"$'\n'
  done <<< "${REFACTORS}"
  CHANGELOG+=$'\n'
fi

if [[ -n "${CHORES}" ]]; then
  CHANGELOG+=$'## Chores / CI\n\n'
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    CHANGELOG+="- ${line}"$'\n'
  done <<< "${CHORES}"
  CHANGELOG+=$'\n'
fi

if [[ -n "${OTHER}" ]]; then
  CHANGELOG+=$'## Other\n\n'
  while IFS= read -r line; do
    [[ -z "${line}" ]] && continue
    CHANGELOG+="- ${line}"$'\n'
  done <<< "${OTHER}"
  CHANGELOG+=$'\n'
fi

if [[ -z "${CHANGELOG}" ]]; then
  CHANGELOG="No conventional commits found since ${PREV_REF}."
fi

echo "--- Changelog preview ---"
echo ""
echo "${CHANGELOG}"
echo "-------------------------"
echo ""

# ---------------------------------------------------------------------------
# Confirm before tagging
# ---------------------------------------------------------------------------

if [[ -t 0 ]]; then
  read -r -p "Create annotated tag '${VERSION}' and push to origin? [y/N] " CONFIRM
  if [[ "${CONFIRM}" != "y" && "${CONFIRM}" != "Y" ]]; then
    echo "Aborted."
    exit 0
  fi
fi

# ---------------------------------------------------------------------------
# Create annotated tag
# ---------------------------------------------------------------------------

TAG_MESSAGE="Release ${VERSION}"$'\n\n'"${CHANGELOG}"

info "Creating annotated tag ${VERSION}..."
git tag -a "${VERSION}" -m "${TAG_MESSAGE}"

# ---------------------------------------------------------------------------
# Push tag
# ---------------------------------------------------------------------------

info "Pushing tag to origin..."
git push origin "${VERSION}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------

echo ""
echo "=== Release ${VERSION} tagged and pushed ==="
echo ""
echo "The release.yml workflow will now create a GitHub Release automatically."
echo "Monitor at: https://github.com/$(git remote get-url origin | sed 's|.*github.com[:/]||;s|\.git$||')/actions"
echo ""
echo "--- Rollback command (if needed) ---"
echo ""
echo "  # Remove the tag (then re-deploy previous image tag via GitOps):"
echo "  git tag -d ${VERSION}"
echo "  git push origin :refs/tags/${VERSION}"
if [[ -n "${PREV_TAG}" ]]; then
  echo ""
  echo "  # Re-deploy previous release via GitOps orchestrator:"
  echo "  ./scripts/infra/release-openedx-gitops.sh \\"
  echo "    --target-env production \\"
  echo "    --openedx-tag ${PREV_TAG} \\"
  echo "    --mfe-tag ${PREV_TAG} \\"
  echo "    --apply --commit --push --verify-runtime"
fi
echo ""
echo "See docs/operations/RELEASE_PROCESS.md for full rollback instructions."
