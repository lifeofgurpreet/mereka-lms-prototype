#!/usr/bin/env bash
set -euo pipefail

# Prepare/update the bbi-infrastructure pinned ref for mereka-lms base manifests.
#
# Default mode is dry-run (prints before/after and next commands).
# Use --apply to write changes in the target repo.
#
# Usage:
#   ./scripts/infra/prepare-bbi-infra-ref-bump.sh
#   ./scripts/infra/prepare-bbi-infra-ref-bump.sh --apply
#   ./scripts/infra/prepare-bbi-infra-ref-bump.sh --repo /path/to/bbi-infrastructure --sha <commit>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

TARGET_REPO="${TARGET_REPO:-/home/gurpreet/projects/k8s/bbi-infrastructure}"
TARGET_FILE_REL="apps/mereka-lms/base/kustomization.yaml"
APPLY=0
SOURCE_SHA=""

usage() {
  cat <<'EOF'
Usage: ./scripts/infra/prepare-bbi-infra-ref-bump.sh [--apply] [--repo PATH] [--sha COMMIT]

Options:
  --apply       Write changes to target file (default is dry-run)
  --repo PATH   Path to bbi-infrastructure repo
  --sha COMMIT  Explicit commit SHA to pin (default: current repo HEAD)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply)
      APPLY=1
      shift
      ;;
    --repo)
      TARGET_REPO="${2:-}"
      shift 2
      ;;
    --sha)
      SOURCE_SHA="${2:-}"
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

if [[ -z "$SOURCE_SHA" ]]; then
  SOURCE_SHA="$(git -C "$REPO_ROOT" rev-parse HEAD)"
fi

TARGET_FILE="$TARGET_REPO/$TARGET_FILE_REL"
if [[ ! -f "$TARGET_FILE" ]]; then
  echo "Target file not found: $TARGET_FILE" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 is required" >&2
  exit 1
fi

python3 - "$TARGET_FILE" "$SOURCE_SHA" "$APPLY" <<'PY'
import pathlib
import re
import sys

path = pathlib.Path(sys.argv[1])
new_sha = sys.argv[2].strip()
apply = sys.argv[3] == "1"
content = path.read_text(encoding="utf-8")

pat = re.compile(
    r"(https://github\.com/Biji-Biji-Initiative/mereka-lms\.git//deploy/k8s/base\?ref=)([0-9a-fA-F]{7,40})"
)
match = pat.search(content)
if not match:
    raise SystemExit("Could not find mereka-lms base ref URL in target kustomization")

old_sha = match.group(2)
updated = pat.sub(rf"\1{new_sha}", content, count=1)

print(f"Target file: {path}")
print(f"Old ref: {old_sha}")
print(f"New ref: {new_sha}")

if apply:
    path.write_text(updated, encoding="utf-8")
    print("Applied update.")
else:
    print("Dry-run only. Re-run with --apply to write.")
PY

echo ""
echo "Next steps:"
echo "  1) cd \"$TARGET_REPO\""
echo "  2) git diff -- \"$TARGET_FILE_REL\""
echo "  3) git commit -am \"chore: bump mereka-lms base ref to $SOURCE_SHA\""
echo "  4) git push"
echo "  5) verify Argo sync + runtime:"
echo "     kubectl --context gke_bbi-k8_asia-southeast1-c_bbi-k8-cluster -n mereka-lms get svc mongodb"
