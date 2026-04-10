#!/usr/bin/env bash
# sync-vendored-openedx-settings.sh — sync canonical Open edX settings into infra vendored base.
#
# Default behavior is dry-run (report drift only). Use --apply to copy canonical
# settings from the app repo into the infra checkout.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(cd "$REPO_ROOT/.." && pwd)}"
INFRA_REPO=""
APPLY=0

TRACKED_FILES=(
  "apps/openedx/settings/lms/development.py"
  "apps/openedx/settings/lms/production.py"
  "apps/openedx/settings/lms/mereka_xblock_iframe.py"
  "apps/openedx/settings/cms/production.py"
  "apps/openedx/settings/lms/mereka_multisite.py"
  "apps/openedx/settings/cms/mereka_multisite.py"
  "apps/openedx/settings/lms/mereka_forwarded_headers.py"
  "apps/openedx/settings/cms/mereka_forwarded_headers.py"
  "apps/openedx/settings/lms/mereka_enterprise_channels.py"
  "apps/openedx/settings/lms/mereka_platform_admin.py"
  "apps/openedx/settings/cms/mereka_platform_admin.py"
)

usage() {
  cat <<EOF
Usage: scripts/infra/sync-vendored-openedx-settings.sh [--infra-repo PATH] [--apply]

Options:
  --infra-repo PATH  Path to infra checkout (auto-detect when omitted)
  --apply            Copy canonical settings into infra vendored base
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
    "${WORKSPACE_ROOT}/infrastructure" \
    "${WORKSPACE_ROOT}/bbi-infrastructure"; do
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

SRC_BASE="$REPO_ROOT/deploy/k8s/base"
DST_BASE="$INFRA_REPO/apps/mereka-lms/base/deploy/k8s/base"

if [[ ! -d "$SRC_BASE" ]]; then
  echo "ERROR: Missing canonical source base: $SRC_BASE" >&2
  exit 1
fi
if [[ ! -d "$DST_BASE" ]]; then
  echo "ERROR: Missing vendored destination base: $DST_BASE" >&2
  exit 1
fi

PASS=0
FAIL=0

echo "=== Vendored Open edX Settings Sync ==="
echo "Source base: $SRC_BASE"
echo "Dest base:   $DST_BASE"
echo ""

for rel_path in "${TRACKED_FILES[@]}"; do
  src="$SRC_BASE/$rel_path"
  dst="$DST_BASE/$rel_path"

  if [[ ! -f "$src" ]]; then
    echo "ERROR: Missing canonical source file: $src" >&2
    exit 1
  fi
  if [[ ! -f "$dst" ]]; then
    echo "ERROR: Missing vendored destination file: $dst" >&2
    exit 1
  fi

  # Normalize CRLF before comparing — infra repo may have different line endings
  if diff -q <(tr -d '\r' < "$src") <(tr -d '\r' < "$dst") >/dev/null 2>&1; then
    echo "OK   $(basename "$rel_path"): in sync"
    PASS=$((PASS + 1))
    continue
  fi

  echo "DRIFT $(basename "$rel_path"): differs"
  FAIL=$((FAIL + 1))

  if [[ "$APPLY" -eq 1 ]]; then
    cp "$src" "$dst"
    echo "APPLY $(basename "$rel_path"): copied canonical source"
  fi
done

echo ""
echo "=== Summary: PASS=$PASS DRIFT=$FAIL APPLY=$APPLY ==="

if [[ "$FAIL" -eq 0 ]]; then
  echo "OK: vendored Open edX settings already synchronized."
  exit 0
fi

if [[ "$APPLY" -eq 0 ]]; then
  echo ""
  echo "Dry-run mode: no changes applied."
  echo "Apply with:"
  echo "  scripts/infra/sync-vendored-openedx-settings.sh --infra-repo \"$INFRA_REPO\" --apply"
  exit 1
fi

echo ""
echo "APPLIED: copied canonical Open edX settings into infra vendored base."
echo "Next steps:"
echo "1. cd \"$INFRA_REPO\""
echo "2. git add apps/mereka-lms/base/deploy/k8s/base/apps/openedx/settings"
echo "3. git commit -m \"chore(gitops): sync vendored openedx settings\""
