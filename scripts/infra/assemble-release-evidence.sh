#!/usr/bin/env bash
# assemble-release-evidence.sh — Assemble a release evidence bundle for a given SHA or tag.
#
# Usage:
#   ./scripts/infra/assemble-release-evidence.sh [<sha-or-tag>]
#
# Defaults to HEAD when no argument is provided.
# Output: var/release-evidence/<sha>/
#
# See docs/reference/operations/RELEASE_EVIDENCE.md for full bundle spec.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

# ── Helpers ───────────────────────────────────────────────────────────

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${CYAN}INFO${NC}  $*"; }
ok()    { echo -e "${GREEN}OK${NC}    $*"; }
warn()  { echo -e "${YELLOW}WARN${NC}  $*"; }

# ── Resolve target SHA ────────────────────────────────────────────────

TARGET="${1:-HEAD}"
SHA="$(git -C "${REPO_ROOT}" rev-parse --verify "${TARGET}" 2>/dev/null)" || {
  echo "ERROR: cannot resolve '${TARGET}' to a git SHA" >&2
  exit 1
}
SHORT_SHA="${SHA:0:12}"

# Resolve a tag name if the target is a tag, for display purposes
TAG="$(git -C "${REPO_ROOT}" tag --points-at "${SHA}" 2>/dev/null | head -1 || true)"

BUNDLE_DIR="${REPO_ROOT}/var/release-evidence/${SHORT_SHA}"
mkdir -p "${BUNDLE_DIR}"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Release Evidence Assembly"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
info "Target: ${TARGET} → ${SHORT_SHA}${TAG:+ (tag: ${TAG})}"
info "Bundle: ${BUNDLE_DIR}"
echo ""

# ── 1. Changelog ──────────────────────────────────────────────────────

info "Generating changelog.txt..."
PREV_TAG="$(git -C "${REPO_ROOT}" describe --tags --abbrev=0 "${SHA}^" 2>/dev/null || true)"
if [[ -n "${PREV_TAG}" ]]; then
  git -C "${REPO_ROOT}" log --oneline "${PREV_TAG}...${SHA}" \
    > "${BUNDLE_DIR}/changelog.txt"
  ok "changelog.txt (${PREV_TAG}...${SHORT_SHA}: $(wc -l < "${BUNDLE_DIR}/changelog.txt") commits)"
else
  git -C "${REPO_ROOT}" log --oneline "${SHA}" \
    > "${BUNDLE_DIR}/changelog.txt"
  warn "No previous tag found — changelog.txt contains full history to ${SHORT_SHA}"
fi

# ── 2. Image tags from production kustomization ───────────────────────

info "Recording image tags..."
KUSTOMIZATION="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"
if [[ -f "${KUSTOMIZATION}" ]]; then
  {
    echo "# Image tags from deploy/k8s/overlays/production/kustomization.yaml"
    echo "# SHA: ${SHORT_SHA}  Tag: ${TAG:-n/a}  Date: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    # Extract images block (name + newName + newTag lines)
    python3 - "${KUSTOMIZATION}" <<'PY'
import sys, pathlib, re

path = pathlib.Path(sys.argv[1])
content = path.read_text()

in_images = False
for line in content.splitlines():
    stripped = line.strip()
    if stripped == "images:":
        in_images = True
        continue
    if in_images:
        # Stop at a new top-level key (non-indented, non-comment, non-list-item)
        if stripped and not stripped.startswith("#") and not stripped.startswith("-") \
                and not line.startswith(" ") and not line.startswith("\t"):
            break
        print(line)
PY
  } > "${BUNDLE_DIR}/image-tags.txt"
  ok "image-tags.txt"
else
  warn "kustomization.yaml not found — skipping image-tags.txt"
fi

# ── 3. SBOM (CycloneDX JSON) ──────────────────────────────────────────

info "Looking for SBOM..."
SBOM_FOUND=0
for candidate in \
    "${REPO_ROOT}/var/sbom.cdx.json" \
    "${REPO_ROOT}/var/openedx-sbom.cdx.json" \
    "${REPO_ROOT}/var/mfe-sbom.cdx.json"; do
  if [[ -f "${candidate}" ]]; then
    cp "${candidate}" "${BUNDLE_DIR}/sbom.cdx.json"
    ok "sbom.cdx.json (copied from ${candidate})"
    SBOM_FOUND=1
    break
  fi
done
if [[ "${SBOM_FOUND}" -eq 0 ]]; then
  warn "SBOM not found in var/ — download from CI build-tutor-images artifact and place at var/sbom.cdx.json"
fi

# ── 4. Trivy suppression record ───────────────────────────────────────

info "Recording Trivy suppression (.trivyignore)..."
TRIVYIGNORE="${REPO_ROOT}/.trivyignore"
if [[ -f "${TRIVYIGNORE}" ]]; then
  cp "${TRIVYIGNORE}" "${BUNDLE_DIR}/trivy-suppression.txt"
  ok "trivy-suppression.txt"
else
  warn ".trivyignore not found — skipping trivy-suppression.txt"
fi

# ── 5. Security scan placeholders ────────────────────────────────────

for scan_file in security-scan.log codeql.log trufflehog.log argocd-sync.log smoke-test.log; do
  if [[ ! -f "${BUNDLE_DIR}/${scan_file}" ]]; then
    warn "${scan_file} not present — add manually from CI artifacts (see RELEASE_EVIDENCE.md)"
  else
    ok "${scan_file} (already present)"
  fi
done

# ── 6. Bundle metadata ────────────────────────────────────────────────

info "Writing bundle metadata..."
BRANCH="$(git -C "${REPO_ROOT}" rev-parse --abbrev-ref "${SHA}" 2>/dev/null || echo "unknown")"
COMMITTER="$(git -C "${REPO_ROOT}" log -1 --format="%ae" "${SHA}" 2>/dev/null || echo "unknown")"
COMMIT_DATE="$(git -C "${REPO_ROOT}" log -1 --format="%cI" "${SHA}" 2>/dev/null || echo "unknown")"
ASSEMBLED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

python3 -c "
import json, sys
data = {
    'schema_version': '1',
    'assembled_at_utc': sys.argv[1],
    'git_sha': sys.argv[2],
    'git_sha_short': sys.argv[3],
    'git_tag': sys.argv[4],
    'git_branch': sys.argv[5],
    'git_committer': sys.argv[6],
    'git_commit_date': sys.argv[7],
    'assembled_by': sys.argv[8],
    'script': 'scripts/infra/assemble-release-evidence.sh',
}
print(json.dumps(data, indent=2))
" "${ASSEMBLED_AT}" "${SHA}" "${SHORT_SHA}" "${TAG:-}" "${BRANCH}" "${COMMITTER}" "${COMMIT_DATE}" "$(whoami)@$(hostname -s 2>/dev/null || echo unknown)" \
  > "${BUNDLE_DIR}/bundle-metadata.json"
ok "bundle-metadata.json"

# ── 7. manifest.json with checksums ───────────────────────────────────

info "Computing manifest.json (SHA-256 checksums)..."
python3 - "${BUNDLE_DIR}" "${SHA}" "${ASSEMBLED_AT}" <<'PY'
import json, hashlib, sys, pathlib
from datetime import datetime, timezone

bundle_dir = pathlib.Path(sys.argv[1])
sha = sys.argv[2]
assembled_at = sys.argv[3]

files = []
for p in sorted(bundle_dir.iterdir()):
  if p.name == "manifest.json":
    continue
  if p.is_file():
    digest = hashlib.sha256(p.read_bytes()).hexdigest()
    files.append({"path": p.name, "sha256": digest, "size_bytes": p.stat().st_size})

manifest = {
  "schema_version": "1",
  "assembled_at_utc": assembled_at,
  "git_sha": sha,
  "file_count": len(files),
  "files": files,
}
(bundle_dir / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"  {len(files)} files indexed")
PY
ok "manifest.json"

# ── Summary ───────────────────────────────────────────────────────────

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Bundle assembled: ${BUNDLE_DIR}"
echo ""
echo "  Files:"
for f in "${BUNDLE_DIR}"/*; do
  printf "    %-40s %s\n" "$(basename "${f}")" "$(du -sh "${f}" | cut -f1)"
done
echo ""
echo "  Next steps:"
echo "    1. Add missing scan logs from CI artifacts (see RELEASE_EVIDENCE.md)"
echo "    2. For tagged releases, archive to GCS:"
echo "       gsutil -m cp -r ${BUNDLE_DIR}/ gs://mereka-lms-release-evidence/releases/${TAG:-${SHORT_SHA}}/"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
