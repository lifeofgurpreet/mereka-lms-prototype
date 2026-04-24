#!/usr/bin/env bash
set -euo pipefail

repo_root="${1:-}"
work_root="${2:-/tmp/tracker-rebuild-repro}"
sync_timeout="${SYNC_TIMEOUT:-30}"
list_timeout="${LIST_TIMEOUT:-15}"

if [[ -z "$repo_root" ]]; then
  echo "usage: $0 /path/to/repo [work_root]" >&2
  exit 2
fi

repo_root="$(cd "$repo_root" && pwd)"

if [[ ! -d "$repo_root/.git" ]]; then
  echo "error: repo_root must be a git checkout: $repo_root" >&2
  exit 2
fi

map_json="$repo_root/docs/status/active/TRACKER-LEGACY-ID-NORMALIZATION-MAP.json"
preview_py="$repo_root/scripts/governance/preview-tracker-legacy-normalization.py"

if [[ ! -f "$map_json" ]]; then
  echo "error: missing normalization map: $map_json" >&2
  exit 2
fi

if [[ ! -f "$preview_py" ]]; then
  echo "error: missing preview script: $preview_py" >&2
  exit 2
fi

rm -rf "$work_root"
cp -a "$repo_root" "$work_root"

preview_dir="$work_root/.tracker-normalization-preview"
python3 "$preview_py" "$repo_root" --write-dir "$preview_dir" >/tmp/tracker-preview.out

cp "$preview_dir/normalized-issues.jsonl" "$work_root/.beads/issues.jsonl"
rm -f "$work_root/.beads/beads.db" "$work_root/.beads/beads.db-wal"

echo "=== Tracker Rebuild Repro ==="
echo "repo_root: $repo_root"
echo "work_root: $work_root"
echo "sync_timeout: $sync_timeout"
echo "list_timeout: $list_timeout"
echo "--- preview summary ---"
cat "$preview_dir/summary.json"

echo "--- sync attempt ---"
set +e
(
  cd "$work_root"
  timeout "$sync_timeout" br sync --import-only --rebuild \
    >/tmp/tracker-repro-sync.out 2>/tmp/tracker-repro-sync.err
)
sync_rc=$?
set -e
echo "sync_rc=$sync_rc"
cat /tmp/tracker-repro-sync.err 2>/dev/null || true

echo "--- files after sync ---"
ls -lh "$work_root/.beads" | sed -n '1,20p'

echo "--- list attempt ---"
set +e
(
  cd "$work_root"
  timeout "$list_timeout" br list --limit 10 \
    >/tmp/tracker-repro-list.out 2>/tmp/tracker-repro-list.err
)
list_rc=$?
set -e
echo "list_rc=$list_rc"
cat /tmp/tracker-repro-list.err 2>/dev/null || true
cat /tmp/tracker-repro-list.out 2>/dev/null || true

echo "--- sqlite count probe ---"
set +e
sqlite_out="$(sqlite3 "$work_root/.beads/beads.db" 'select count(*) from issues;' 2>&1)"
sqlite_rc=$?
set -e
echo "$sqlite_out"
echo "sqlite_rc=$sqlite_rc"

echo "--- verdict ---"
if [[ $sync_rc -ne 0 || $list_rc -ne 0 || $sqlite_rc -ne 0 ]]; then
  echo "reproduced"
  exit 1
fi
echo "not_reproduced"
