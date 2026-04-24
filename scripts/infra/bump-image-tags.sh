#!/usr/bin/env bash
# @covers AC-020
# @spec: ci-cd-pipeline_spec.md
#
# Query GCR Artifact Registry for the latest available tag for each image in
# the production Kustomize overlay and show current vs latest.
#
# Usage:
#   scripts/infra/bump-image-tags.sh [--apply] [--overlay PATH]
#
# Options:
#   --apply           Write updated tags into the overlay file (default: dry-run)
#   --overlay PATH    Path to kustomization.yaml (default: production overlay)
#   -h, --help        Show this help
#
# DEPRECATED — do not use (Wave 9 prep, bead mereka-lms-2xwo item 2)
# ----------------------------------------------------------------------
# This script is a GKE/GCR relic:
#   - Queries `gcloud artifacts docker tags list` (Google Artifact Registry),
#     which is no longer our image registry (now ghcr.io).
#   - Writes to the app-repo DEPRECATED `deploy/k8s/overlays/production/`
#     overlay, which is not runtime-authoritative per ADR-025 (authoritative
#     source is bbi-infrastructure/apps/mereka-lms/overlays/prod/).
# Use `scripts/infra/release-openedx-gitops.sh` for the canonical release
# workflow. canonical-entrypoints.yaml already flags this script as
# non-canonical.

set -euo pipefail

# Hard-fail unless explicit opt-in — prevent accidental use.
if [[ "${ALLOW_DEPRECATED_BUMP_IMAGE_TAGS:-}" != "1" ]]; then
  cat >&2 <<'EOF'
❌ scripts/infra/bump-image-tags.sh is DEPRECATED (Wave 9 / bead mereka-lms-2xwo item 2).

Why:
  - Targets GCR Artifact Registry (we now use ghcr.io)
  - Writes to DEPRECATED app-repo overlay (bbi-infrastructure is authoritative)
  - Flagged as non-canonical in scripts/governance/canonical-entrypoints.yaml

Use instead:
  scripts/infra/release-openedx-gitops.sh

Override only for explicit historical inspection:
  ALLOW_DEPRECATED_BUMP_IMAGE_TAGS=1 scripts/infra/bump-image-tags.sh ...
EOF
  exit 2
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

APPLY=0
OVERLAY_FILE="${REPO_ROOT}/deploy/k8s/overlays/production/kustomization.yaml"

usage() {
  cat <<'EOF'
Usage:
  scripts/infra/bump-image-tags.sh [--apply] [--overlay PATH]

Options:
  --apply           Write updated tags into the overlay file (default: dry-run)
  --overlay PATH    Path to kustomization.yaml (default: production overlay)
  -h, --help        Show this help

Description:
  For each image in the production Kustomize overlay:
    - Parses current tag or digest reference
    - Queries 'gcloud artifacts docker tags list' for the latest available tag
    - Shows a diff of current vs latest
  By default runs in dry-run mode. Pass --apply to write changes.

Examples:
  # Preview available tag updates
  scripts/infra/bump-image-tags.sh

  # Apply tag updates to production overlay
  scripts/infra/bump-image-tags.sh --apply
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --overlay)
      OVERLAY_FILE="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ ! -f "$OVERLAY_FILE" ]]; then
  echo "ERROR: Overlay file not found: $OVERLAY_FILE" >&2
  exit 1
fi

if ! command -v gcloud &>/dev/null; then
  echo "ERROR: gcloud is not installed or not in PATH." >&2
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo "ERROR: python3 is not installed or not in PATH." >&2
  exit 1
fi

echo "Overlay: ${OVERLAY_FILE#"$REPO_ROOT"/}"
echo "Mode:    $([[ "$APPLY" -eq 1 ]] && echo apply || echo dry-run)"
echo ""

# ---------------------------------------------------------------------------
# Parse image entries from the kustomization file.
# Each entry may use:
#   newTag: <tag>               (tag-based reference)
#   digest: sha256:<hex>        (digest-based reference, may accompany newTag)
# We emit: newName|currentTag|currentDigest  (digest may be empty)
# ---------------------------------------------------------------------------
parse_images() {
  python3 - "$OVERLAY_FILE" <<'PY'
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
raw = path.read_text(encoding="utf-8")
lines = raw.splitlines()

# Collect image blocks: list of dicts with name/newName/newTag/digest
in_images = False
current = {}
images = []

for line in lines:
  stripped = line.lstrip()
  indent = len(line) - len(stripped)

  if re.match(r'^images\s*:', line):
    in_images = True
    continue

  if in_images:
    # A top-level key (no leading spaces) or a new section ends the images block
    if indent == 0 and stripped and not stripped.startswith('-') and not stripped.startswith('#'):
      in_images = False
      if current:
        images.append(current)
        current = {}
      continue

    # New image entry
    m = re.match(r'^\s*-\s*name:\s*(\S+)', line)
    if m:
      if current:
        images.append(current)
      current = {'name': m.group(1), 'newName': '', 'newTag': '', 'digest': ''}
      continue

    m = re.match(r'^\s*newName:\s*(\S+)', line)
    if m and current:
      current['newName'] = m.group(1)
      continue

    m = re.match(r'^\s*newTag:\s*(\S+)', line)
    if m and current:
      current['newTag'] = m.group(1)
      continue

    m = re.match(r'^\s*digest:\s*(\S+)', line)
    if m and current:
      current['digest'] = m.group(1)
      continue

if current:
  images.append(current)

for img in images:
  resolved_name = img['newName'] if img['newName'] else img['name']
  print(f"{resolved_name}|{img['newTag']}|{img['digest']}")
PY
}

# ---------------------------------------------------------------------------
# Query the latest tag for a given Artifact Registry image path.
# Returns the tag with the most recent CREATE_TIME from the tag list.
# We sort lexicographically on the timestamp portion of the tag name when
# tags follow the "<sha>-<yyyymmddHHMMSS>" pattern, and fall back to the
# last tag returned by the API otherwise.
# ---------------------------------------------------------------------------
latest_tag_for_image() {
  local full_image="$1"
  # Strip the registry host to get the repository path for gcloud
  # e.g. ghcr.io/biji-biji-initiative/mereka-lms/openedx
  #   -> projects/mereka-lms/locations/asia-southeast1/repositories/openedx/packages/openedx
  # gcloud artifacts docker tags list accepts the full image reference directly.

  local raw_output
  if ! raw_output="$(gcloud artifacts docker tags list "$full_image" \
      --format='value(tag)' --sort-by='~createTime' --limit=1 2>/dev/null)"; then
    echo ""
    return
  fi
  # Strip any registry prefix that gcloud may prepend to the tag value
  echo "$raw_output" | tail -1 | sed 's|.*:||'
}

# ---------------------------------------------------------------------------
# Apply updated tags to the overlay file using Python for safe YAML editing.
# ---------------------------------------------------------------------------
apply_tag_update() {
  local file="$1"
  # args: "image1|newTag1" "image2|newTag2" ...
  shift
  local updates_json="$1"

  python3 - "$file" "$updates_json" <<'PY'
import json
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
updates = json.loads(sys.argv[2])  # {resolved_name: new_tag}

if not updates:
  print("= no updates to apply")
  sys.exit(0)

raw = path.read_text(encoding="utf-8")
lines = raw.splitlines(keepends=True)

current_name = None
current_new_name = None
applied = []

for idx, line in enumerate(lines):
  line_s = line.rstrip("\r\n")
  eol = line[len(line_s):]

  m_name = re.match(r'^(\s*-\s*name:\s*)(\S+)', line_s)
  if m_name:
    current_name = m_name.group(2)
    current_new_name = None
    continue

  m_newname = re.match(r'^(\s*newName:\s*)(\S+)', line_s)
  if m_newname:
    current_new_name = m_newname.group(2)
    continue

  m_tag = re.match(r'^(\s*newTag:\s*)(\S+)(\s*)$', line_s)
  if m_tag:
    resolved = current_new_name if current_new_name else current_name
    if resolved and resolved in updates:
      old_tag = m_tag.group(2)
      new_tag = updates[resolved]
      if old_tag != new_tag:
        lines[idx] = f"{m_tag.group(1)}{new_tag}{m_tag.group(3)}{eol}"
        applied.append((idx + 1, resolved, old_tag, new_tag))

if not applied:
  print("= all tags already up-to-date")
  sys.exit(0)

path.write_text("".join(lines), encoding="utf-8")
print(f"  applied {len(applied)} tag update(s) to {path}")
for line_no, name, before, after in applied:
  print(f"    L{line_no} {name}: {name.split('/')[-1]}:{before} -> {after}")
PY
}

# ---------------------------------------------------------------------------
# Main: iterate images, compare tags, collect updates
# ---------------------------------------------------------------------------
declare -A updates_map  # resolved_name -> new_tag
any_updates=0
any_errors=0

echo "Querying Artifact Registry for latest tags..."
echo ""

while IFS='|' read -r resolved_name current_tag current_digest; do
  # Skip docker.io images — they are remapped via newName to GCR, so the
  # docker.io name never gets a tag queried directly. The GCR name entry
  # will cover it.
  if [[ "$resolved_name" == docker.io/* ]]; then
    continue
  fi

  printf "  %-65s  current: %s\n" "${resolved_name##*/}" "${current_tag:-<digest-only>}"

  if [[ -z "$current_tag" && -n "$current_digest" ]]; then
    printf "    %-61s  (digest-pinned, skipping tag query)\n" ""
    continue
  fi

  latest_tag="$(latest_tag_for_image "$resolved_name")"

  if [[ -z "$latest_tag" ]]; then
    printf "    WARNING: could not retrieve latest tag from Artifact Registry\n"
    any_errors=1
    continue
  fi

  if [[ "$current_tag" == "$latest_tag" ]]; then
    printf "    %-61s  latest: %s  (up-to-date)\n" "" "$latest_tag"
  else
    printf "    %-61s  latest: %s  <<< UPDATE AVAILABLE\n" "" "$latest_tag"
    updates_map["$resolved_name"]="$latest_tag"
    any_updates=1
  fi
done < <(parse_images)

echo ""

if [[ "$any_updates" -eq 0 ]]; then
  echo "All image tags are up-to-date."
  exit 0
fi

# Build JSON for the Python apply function
updates_json="{"
first=1
for key in "${!updates_map[@]}"; do
  val="${updates_map[$key]}"
  if [[ "$first" -eq 1 ]]; then
    first=0
  else
    updates_json+=","
  fi
  updates_json+="\"$key\":\"$val\""
done
updates_json+="}"

echo "Proposed changes:"
for key in "${!updates_map[@]}"; do
  echo "  ${key##*/}: ${updates_map[$key]}"
done
echo ""

if [[ "$APPLY" -eq 1 ]]; then
  apply_tag_update "$OVERLAY_FILE" "$updates_json"
  echo ""
  echo "Done. Review the diff, then commit:"
  echo "  git diff ${OVERLAY_FILE#"$REPO_ROOT"/}"
  echo "  git add ${OVERLAY_FILE#"$REPO_ROOT"/} && git commit -m 'chore: bump production image tags'"
else
  echo "Dry-run: no changes written. Pass --apply to apply."
fi

if [[ "$any_errors" -ne 0 ]]; then
  echo ""
  echo "WARNING: Some images could not be queried. Check gcloud authentication and image paths." >&2
fi
