#!/usr/bin/env bash
# @covers AC-020
# @spec: ci-cd-pipeline_spec.md
#
# Scan deploy/k8s/overlays/production/ for image tag policy violations:
#   1. Any newTag: latest  (mutable tag forbidden in production)
#   2. Any newTag: present without an accompanying digest: (tag-only, no immutability guarantee)
#
# Exit 0 = policy clean.
# Exit 1 = violations found.
#
# Usage:
#   scripts/qa/verify-no-latest-tags.sh [--warn-no-digest]
#
# Options:
#   --warn-no-digest   Also warn (but do not fail) for tag-only refs without digest
#   --strict           Fail on tag-only refs without digest (implies --warn-no-digest)
#   -h, --help         Show this help

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

WARN_NO_DIGEST=0
STRICT_NO_DIGEST=0

usage() {
  cat <<'EOF'
Usage:
  scripts/qa/verify-no-latest-tags.sh [--warn-no-digest] [--strict]

Options:
  --warn-no-digest   Warn (stdout) for tag-only refs missing a digest (no exit 1)
  --strict           Fail (exit 1) for tag-only refs missing a digest
  -h, --help         Show this help

Checks:
  1. No newTag: latest in any production overlay kustomization.yaml
  2. (optional) No tag-only image refs without an accompanying digest: field

Examples:
  # Basic latest-tag check only
  scripts/qa/verify-no-latest-tags.sh

  # Warn about missing digests, but do not fail
  scripts/qa/verify-no-latest-tags.sh --warn-no-digest

  # Fail on any tag-only ref without digest (strictest mode)
  scripts/qa/verify-no-latest-tags.sh --strict
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --warn-no-digest)
      WARN_NO_DIGEST=1
      shift
      ;;
    --strict)
      STRICT_NO_DIGEST=1
      WARN_NO_DIGEST=1
      shift
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

PROD_OVERLAY_DIR="${REPO_ROOT}/deploy/k8s/overlays/production"

if [[ ! -d "$PROD_OVERLAY_DIR" ]]; then
  echo "ERROR: Production overlay directory not found: $PROD_OVERLAY_DIR" >&2
  exit 1
fi

violations=0
warnings=0

# ---------------------------------------------------------------------------
# Check 1: No newTag: latest
# ---------------------------------------------------------------------------
echo "Checking for mutable ':latest' tags in production overlays..."

while IFS= read -r kustomization_file; do
  rel="${kustomization_file#"$REPO_ROOT"/}"
  if grep -nE '^\s*newTag:\s*["\x27]?latest["\x27]?(\s*#.*)?$' "$kustomization_file" \
      >/tmp/mereka-no-latest-hits.txt 2>/dev/null; then
    echo "FAIL: ':latest' newTag found in ${rel}:"
    sed 's/^/  /' /tmp/mereka-no-latest-hits.txt
    violations=1
  fi
done < <(find "$PROD_OVERLAY_DIR" -type f -name 'kustomization.yaml' | sort)

rm -f /tmp/mereka-no-latest-hits.txt

# ---------------------------------------------------------------------------
# Check 2: Tag-only refs without an accompanying digest (optional)
# ---------------------------------------------------------------------------
if [[ "$WARN_NO_DIGEST" -eq 1 ]]; then
  echo ""
  echo "Checking for tag-only image refs without a digest (immutability)..."

  while IFS= read -r kustomization_file; do
    rel="${kustomization_file#"$REPO_ROOT"/}"

    rc=0
    python3 - "$kustomization_file" "$rel" <<'PY' || rc=$?
import re
import sys
from pathlib import Path

path = Path(sys.argv[1])
rel  = sys.argv[2]
raw  = path.read_text(encoding="utf-8")
lines = raw.splitlines()

in_images = False
current = {}
blocks = []

for i, line in enumerate(lines):
  stripped = line.lstrip()
  indent = len(line) - len(stripped)

  if re.match(r'^images\s*:', line):
    in_images = True
    continue

  if in_images:
    if indent == 0 and stripped and not stripped.startswith('-') and not stripped.startswith('#'):
      if current:
        blocks.append(current)
        current = {}
      in_images = False
      continue

    m = re.match(r'^\s*-\s*name:\s*(\S+)', line)
    if m:
      if current:
        blocks.append(current)
      current = {'name': m.group(1), 'newTag': '', 'digest': '', 'lineno': i + 1}
      continue

    m = re.match(r'^\s*newTag:\s*(\S+)', line)
    if m and current:
      current['newTag'] = m.group(1)
      current['tag_line'] = i + 1
      continue

    m = re.match(r'^\s*digest:\s*(\S+)', line)
    if m and current:
      current['digest'] = m.group(1)
      continue

if current:
  blocks.append(current)

tag_only = [
  b for b in blocks
  if b.get('newTag') and b['newTag'] != 'latest' and not b.get('digest')
]

if tag_only:
  print(f"WARN: tag-only refs (no digest) in {rel}:")
  for b in tag_only:
    lineno = b.get('tag_line', b['lineno'])
    print(f"  L{lineno} {b['name']}: tag={b['newTag']} (no digest)")
  sys.exit(2)

sys.exit(0)
PY
    if [[ $rc -eq 2 ]]; then
      warnings=1
    elif [[ $rc -ne 0 ]]; then
      echo "ERROR: digest-check script failed (rc=$rc) for $kustomization_file" >&2
      violations=1
    fi
  done < <(find "$PROD_OVERLAY_DIR" -type f -name 'kustomization.yaml' | sort)
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""

if [[ "$violations" -ne 0 ]]; then
  echo "FAIL: Production tag policy failed — ':latest' tags found."
  exit 1
fi

if [[ "$warnings" -ne 0 && "$STRICT_NO_DIGEST" -eq 1 ]]; then
  echo "FAIL: Strict mode — tag-only refs without digest found."
  exit 1
fi

if [[ "$warnings" -ne 0 ]]; then
  echo "PASS: No ':latest' tags found. (warnings: tag-only refs without digest — run with --strict to fail on these)"
else
  echo "PASS: Production tag policy clean — no ':latest' tags, all refs pinned."
fi
