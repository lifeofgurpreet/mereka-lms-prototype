#!/usr/bin/env bash
# sync-vendored-mfe-caddyfile.sh — sync vendored MFE Caddyfile into infra checkout.
#
# Default behavior is dry-run (report diff only). Use --apply to copy.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INFRA_REPO=""
APPLY=0

usage() {
  cat <<EOF
Usage: scripts/infra/sync-vendored-mfe-caddyfile.sh [--infra-repo PATH] [--apply]

Options:
  --infra-repo PATH  Path to infra checkout (auto-detect when omitted)
  --apply            Apply sync (copy source file into infra vendored base)
  -h, --help         Show this help

Default mode is dry-run and will exit non-zero when drift exists.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --infra-repo)
      [[ $# -lt 2 ]] && { echo "ERROR: --infra-repo requires a value" >&2; exit 2; }
      INFRA_REPO="$2"
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
  echo "ERROR: Could not auto-detect infra checkout. Use --infra-repo PATH." >&2
  exit 2
fi

SRC="$REPO_ROOT/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
DST="$INFRA_REPO/apps/mereka-lms/base/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"

if [[ ! -f "$SRC" ]]; then
  echo "ERROR: Missing source Caddyfile: $SRC" >&2
  exit 1
fi
if [[ ! -f "$DST" ]]; then
  echo "ERROR: Missing destination Caddyfile: $DST" >&2
  exit 1
fi

if cmp -s "$SRC" "$DST"; then
  echo "PASS: Vendored MFE Caddyfile already synchronized."
  echo "Source: $SRC"
  echo "Dest:   $DST"
  exit 0
fi

echo "DRIFT: Vendored MFE Caddyfile differs."
echo "Source: $SRC"
echo "Dest:   $DST"
echo ""
echo "Unified diff (source -> dest):"
diff -u "$DST" "$SRC" || true

if [[ "$APPLY" -eq 0 ]]; then
  echo ""
  echo "Dry-run mode: no changes applied."
  echo "Apply with:"
  echo "  scripts/infra/sync-vendored-mfe-caddyfile.sh --infra-repo \"$INFRA_REPO\" --apply"
  exit 1
fi

cp "$SRC" "$DST"
echo ""
echo "APPLIED: copied source Caddyfile into infra vendored base."
echo "Next steps:"
echo "1. cd \"$INFRA_REPO\""
echo "2. git add apps/mereka-lms/base/deploy/k8s/base/plugins/mfe/apps/mfe/Caddyfile"
echo "3. git commit -m \"chore(gitops): sync vendored MFE Caddyfile from mereka-lms\""
