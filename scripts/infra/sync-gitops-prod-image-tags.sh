#!/usr/bin/env bash
# sync-gitops-prod-image-tags.sh — sync prod Open edX/MFE tags into infra overlay.
#
# Default behavior is dry-run (report drift + diff only). Use --apply to write.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_OVERLAY="$REPO_ROOT/deploy/k8s/overlays/production/kustomization.yaml"
INFRA_REPO=""
DEST_OVERLAY=""
APPLY=0

usage() {
  cat <<EOF
Usage: scripts/infra/sync-gitops-prod-image-tags.sh [options]

Options:
  --infra-repo PATH      Path to infra checkout (auto-detect when omitted)
  --source-overlay PATH  Source overlay (default: deploy/k8s/overlays/production/kustomization.yaml)
  --dest-overlay PATH    Destination overlay (default: <infra>/apps/mereka-lms/overlays/prod/kustomization.yaml)
  --apply                Apply changes to destination overlay
  -h, --help             Show help

Default mode is dry-run and exits non-zero when drift exists.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --infra-repo)
      [[ $# -lt 2 ]] && { echo "ERROR: --infra-repo requires a value" >&2; exit 2; }
      INFRA_REPO="$2"
      shift 2
      ;;
    --source-overlay)
      [[ $# -lt 2 ]] && { echo "ERROR: --source-overlay requires a value" >&2; exit 2; }
      SOURCE_OVERLAY="$2"
      shift 2
      ;;
    --dest-overlay)
      [[ $# -lt 2 ]] && { echo "ERROR: --dest-overlay requires a value" >&2; exit 2; }
      DEST_OVERLAY="$2"
      shift 2
      ;;
    --apply)
      APPLY=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$INFRA_REPO" ]]; then
  for candidate in \
    /home/gurpreet/projects/k8s/infrastructure \
    /home/gurpreet/projects/k8s/bbi-infrastructure; do
    if [[ -d "$candidate/.git" ]]; then
      INFRA_REPO="$candidate"
      break
    fi
  done
fi

if [[ -z "$INFRA_REPO" ]]; then
  echo "ERROR: Could not auto-detect infra repo. Use --infra-repo PATH." >&2
  exit 2
fi

if [[ -z "$DEST_OVERLAY" ]]; then
  DEST_OVERLAY="$INFRA_REPO/apps/mereka-lms/overlays/prod/kustomization.yaml"
fi

if [[ ! -f "$SOURCE_OVERLAY" ]]; then
  echo "ERROR: Missing source overlay: $SOURCE_OVERLAY" >&2
  exit 1
fi
if [[ ! -f "$DEST_OVERLAY" ]]; then
  echo "ERROR: Missing destination overlay: $DEST_OVERLAY" >&2
  exit 1
fi

tmp_out="$(mktemp -t gitops-tags-sync.XXXXXX)"
trap 'rm -f "$tmp_out"' EXIT

python3 - "$SOURCE_OVERLAY" "$DEST_OVERLAY" "$tmp_out" <<'PY'
import pathlib
import re
import sys

src_path = pathlib.Path(sys.argv[1])
dst_path = pathlib.Path(sys.argv[2])
out_path = pathlib.Path(sys.argv[3])

src_lines = src_path.read_text(encoding="utf-8").splitlines(keepends=True)
dst_lines = dst_path.read_text(encoding="utf-8").splitlines(keepends=True)

def extract_tag(lines, image_name):
    cur = None
    for line in lines:
        m_name = re.match(r'^\s*-\s+name:\s*(\S+)\s*$', line)
        if m_name:
            cur = m_name.group(1)
            continue
        m_tag = re.match(r'^(\s*)newTag:\s*(\S+)\s*$', line)
        if m_tag and cur == image_name:
            return m_tag.group(2)
    return None

openedx_tag = extract_tag(src_lines, "docker.io/overhangio/openedx")
mfe_tag = extract_tag(src_lines, "docker.io/overhangio/openedx-mfe")

if not openedx_tag:
    raise SystemExit("ERROR: source overlay missing docker.io/overhangio/openedx newTag")
if not mfe_tag:
    raise SystemExit("ERROR: source overlay missing docker.io/overhangio/openedx-mfe newTag")

target_map = {
    "docker.io/overhangio/openedx": openedx_tag,
    "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx": openedx_tag,
    "docker.io/overhangio/openedx-mfe": mfe_tag,
    "asia-southeast1-docker.pkg.dev/mereka-lms/openedx/openedx-mfe": mfe_tag,
}

result = []
cur = None
for line in dst_lines:
    m_name = re.match(r'^(\s*-\s+name:\s*)(\S+)(\s*)$', line)
    if m_name:
        cur = m_name.group(2)
        result.append(line)
        continue
    m_tag = re.match(r'^(\s*)newTag:\s*(\S+)(\s*)$', line)
    if m_tag and cur in target_map:
        indent = m_tag.group(1)
        result.append(f"{indent}newTag: {target_map[cur]}\n")
    else:
        result.append(line)

out_path.write_text("".join(result), encoding="utf-8")
PY

read -r openedx_tag mfe_tag <<<"$(python3 - "$SOURCE_OVERLAY" <<'PY'
import re
import sys
from pathlib import Path

lines = Path(sys.argv[1]).read_text(encoding="utf-8").splitlines()

def extract_tag(lines, image_name):
    cur = None
    for line in lines:
        m_name = re.match(r'^\s*-\s+name:\s*(\S+)\s*$', line)
        if m_name:
            cur = m_name.group(1)
            continue
        m_tag = re.match(r'^\s*newTag:\s*(\S+)\s*$', line)
        if m_tag and cur == image_name:
            return m_tag.group(1)
    return ""

openedx = extract_tag(lines, "docker.io/overhangio/openedx")
mfe = extract_tag(lines, "docker.io/overhangio/openedx-mfe")
print(openedx, mfe)
PY
)"

status_line="$(python3 - "$SOURCE_OVERLAY" "$DEST_OVERLAY" "$tmp_out" <<'PY'
import pathlib
import sys

dst = pathlib.Path(sys.argv[2]).read_text(encoding="utf-8")
out = pathlib.Path(sys.argv[3]).read_text(encoding="utf-8")
print("clean" if dst == out else "drift")
PY
)"

if [[ "$status_line" == "clean" ]]; then
  echo "PASS: Infra prod overlay image tags already synchronized."
  echo "Source: $SOURCE_OVERLAY"
  echo "Dest:   $DEST_OVERLAY"
  exit 0
fi

echo "DRIFT: Infra prod overlay image tags differ from app source overlay."
echo "Source: $SOURCE_OVERLAY"
echo "Dest:   $DEST_OVERLAY"
echo "Desired tags: openedx=$openedx_tag, mfe=$mfe_tag"
echo ""
python3 - "$DEST_OVERLAY" "$tmp_out" <<'PY'
import difflib
import pathlib
import sys

dst_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
dst_lines = dst_path.read_text(encoding="utf-8").splitlines(keepends=True)
out_lines = out_path.read_text(encoding="utf-8").splitlines(keepends=True)

for line in difflib.unified_diff(
    dst_lines,
    out_lines,
    fromfile=str(dst_path),
    tofile=str(dst_path) + " (synced)",
):
    sys.stdout.write(line)
PY

if [[ "$APPLY" -eq 0 ]]; then
  echo ""
  echo "Dry-run mode: no changes applied."
  echo "Apply with:"
  echo "  scripts/infra/sync-gitops-prod-image-tags.sh --infra-repo \"$INFRA_REPO\" --apply"
  exit 1
fi

cp "$tmp_out" "$DEST_OVERLAY"
echo ""
echo "APPLIED: synced image tags into infra prod overlay."
echo "Next steps:"
echo "1. cd \"$INFRA_REPO\""
echo "2. git add apps/mereka-lms/overlays/prod/kustomization.yaml"
echo "3. git commit -m \"chore(gitops): sync prod image tags from mereka-lms\""
