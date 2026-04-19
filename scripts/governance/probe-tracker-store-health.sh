#!/usr/bin/env bash
set -euo pipefail

store_dir="${1:-}"

if [[ -z "$store_dir" ]]; then
  echo "usage: $0 /path/to/.beads" >&2
  exit 2
fi

if [[ ! -d "$store_dir" ]]; then
  echo "error: missing store dir: $store_dir" >&2
  exit 2
fi

db_path="$store_dir/beads.db"
jsonl_path="$store_dir/issues.jsonl"

if [[ ! -f "$jsonl_path" ]]; then
  echo "error: missing issues.jsonl: $jsonl_path" >&2
  exit 2
fi

echo "=== Tracker Store Probe ==="
echo "store_dir: $store_dir"
echo "db_exists: $([[ -f "$db_path" ]] && echo yes || echo no)"
echo "wal_exists: $([[ -f "$db_path-wal" ]] && echo yes || echo no)"
[[ -f "$db_path" ]] && ls -lh "$db_path" "$db_path-wal" 2>/dev/null || true

echo "--- br doctor ---"
set +e
BR_DATA_DIR="$store_dir" br doctor
doctor_rc=$?
set -e
echo "doctor_rc=$doctor_rc"

if [[ -f "$db_path" ]]; then
  echo "--- sqlite3 count(*) ---"
  set +e
  sqlite_out="$(sqlite3 "$db_path" 'select count(*) from issues;' 2>&1)"
  sqlite_rc=$?
  set -e
  echo "$sqlite_out"
  echo "sqlite_rc=$sqlite_rc"
else
  echo "--- sqlite3 count(*) ---"
  echo "skipped (no db)"
  sqlite_rc=9
fi

echo "--- br list timeout 10 ---"
set +e
list_out="$(timeout 10 env BR_DATA_DIR="$store_dir" br list --limit 5 2>&1)"
list_rc=$?
set -e
echo "$list_out"
echo "list_rc=$list_rc"

echo "--- summary ---"
if [[ $doctor_rc -eq 0 && $sqlite_rc -eq 0 && $list_rc -eq 0 ]]; then
  echo "healthy"
  exit 0
fi

echo "degraded"
exit 1
