#!/usr/bin/env bash
# Prune over-retention GCP Compute snapshots to restore snapshot quota headroom.
#
# Safe defaults:
# - Dry-run by default (no deletions)
# - Filters to snapshots whose names start with pvc-
# - Deletes only snapshots older than RETENTION_DAYS (default 30)
#
# Usage:
#   ./scripts/infra/prune-gcp-snapshots.sh
#   CONFIRM_PRUNE_GCP_SNAPSHOTS=PRUNE_GCP_SNAPSHOTS ALLOW_PROD_APPLY=1 \
#     ./scripts/infra/prune-gcp-snapshots.sh --apply --max-delete 300
#   PROJECT_ID=bbi-k8 RETENTION_DAYS=30 CONFIRM_PRUNE_GCP_SNAPSHOTS=PRUNE_GCP_SNAPSHOTS \
#     ALLOW_PROD_APPLY=1 ./scripts/infra/prune-gcp-snapshots.sh --apply --max-delete 300
set -euo pipefail

# Safety guard: require explicit confirmation for production-mutating operations
if [[ "${CONFIRM:-}" != "yes-i-am-sure" ]]; then
  echo "ERROR: This script mutates production. To proceed, run:"
  echo "  CONFIRM=yes-i-am-sure $0 $*"
  exit 1
fi

PROJECT_ID="${PROJECT_ID:-bbi-k8}"
RETENTION_DAYS="${RETENTION_DAYS:-30}"
NAME_PREFIX="${NAME_PREFIX:-pvc-}"
MAX_DELETE="${MAX_DELETE:-0}"   # 0 means no cap
APPLY=0
ALLOW_PROD_APPLY="${ALLOW_PROD_APPLY:-0}"
REQUIRE_MAX_DELETE="${REQUIRE_MAX_DELETE:-1}"
CONFIRM_PRUNE_GCP_SNAPSHOTS="${CONFIRM_PRUNE_GCP_SNAPSHOTS:-}"
CONFIRM_TOKEN="PRUNE_GCP_SNAPSHOTS"

usage() {
  cat <<USAGE
Usage: $0 [--apply] [--project PROJECT] [--retention-days N] [--name-prefix PREFIX] [--max-delete N]

Options:
  --apply                Delete matched snapshots (default: dry-run)
  --project PROJECT      GCP project id (default: $PROJECT_ID)
  --retention-days N     Delete snapshots older than N days (default: $RETENTION_DAYS)
  --name-prefix PREFIX   Snapshot name prefix filter (default: $NAME_PREFIX)
  --max-delete N         Max snapshots to delete in apply mode (default: $MAX_DELETE; 0 = no cap)
  -h, --help             Show help

Safety controls for --apply:
  CONFIRM_PRUNE_GCP_SNAPSHOTS=PRUNE_GCP_SNAPSHOTS
  ALLOW_PROD_APPLY=1     Required for prod-like projects (e.g., bbi-k8)
  REQUIRE_MAX_DELETE=1   Default: require explicit --max-delete > 0 in apply mode
USAGE
}

die() {
  echo "$*" >&2
  exit 1
}

require_bool_01() {
  local var_name="$1"
  local value="$2"
  case "$value" in
    0|1) ;;
    *) die "Invalid ${var_name}='${value}' (expected 0 or 1)" ;;
  esac
}

require_non_negative_int() {
  local var_name="$1"
  local value="$2"
  [[ "$value" =~ ^[0-9]+$ ]] || die "Invalid ${var_name}='${value}' (expected non-negative integer)"
}

is_prod_like_project() {
  local project="$1"
  local normalized
  normalized="$(tr '[:upper:]' '[:lower:]' <<<"$project")"
  if [[ "$normalized" == *"nonprod"* ]] || [[ "$normalized" == *"staging"* ]] || [[ "$normalized" == *"dev"* ]]; then
    return 1
  fi
  [[ "$normalized" == "bbi-k8" ]] || [[ "$normalized" == *"production"* ]] || [[ "$normalized" == *"prod"* ]]
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --apply) APPLY=1; shift ;;
    --project) PROJECT_ID="${2:-}"; shift 2 ;;
    --retention-days) RETENTION_DAYS="${2:-}"; shift 2 ;;
    --name-prefix) NAME_PREFIX="${2:-}"; shift 2 ;;
    --max-delete) MAX_DELETE="${2:-}"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage; exit 1 ;;
  esac
done

require_bool_01 "ALLOW_PROD_APPLY" "$ALLOW_PROD_APPLY"
require_bool_01 "REQUIRE_MAX_DELETE" "$REQUIRE_MAX_DELETE"
require_non_negative_int "RETENTION_DAYS" "$RETENTION_DAYS"
require_non_negative_int "MAX_DELETE" "$MAX_DELETE"

command -v gcloud >/dev/null 2>&1 || { echo "Missing gcloud" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "Missing python3" >&2; exit 2; }

workdir="$(mktemp -d -t prune-gcp-snapshots.XXXXXX)"
trap 'rm -rf "$workdir"' EXIT

snap_json="$workdir/snapshots.json"
quota_json="$workdir/quota.json"
candidates_file="$workdir/candidates.txt"

printf '[%s] Fetching snapshot inventory for project=%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$PROJECT_ID"
gcloud compute snapshots list --project "$PROJECT_ID" --format=json > "$snap_json"
gcloud compute project-info describe --project "$PROJECT_ID" --format=json > "$quota_json"

python3 - "$snap_json" "$quota_json" "$RETENTION_DAYS" "$NAME_PREFIX" "$candidates_file" <<'PY'
import json
import sys
from datetime import datetime, timedelta, timezone

snap_path, quota_path, retention_days, prefix, out_path = sys.argv[1:6]
retention_days = int(retention_days)

with open(snap_path, 'r', encoding='utf-8') as f:
    snaps = json.load(f)
with open(quota_path, 'r', encoding='utf-8') as f:
    quota = json.load(f)

snap_metric = next((q for q in quota.get('quotas', []) if q.get('metric') == 'SNAPSHOTS'), {})
limit = int(float(snap_metric.get('limit', 0) or 0))
usage = int(float(snap_metric.get('usage', 0) or 0))

cutoff = datetime.now(timezone.utc) - timedelta(days=retention_days)
candidates = []
for s in snaps:
    name = s.get('name', '')
    if prefix and not name.startswith(prefix):
        continue
    ts = s.get('creationTimestamp')
    if not ts:
        continue
    created = datetime.fromisoformat(ts.replace('Z', '+00:00'))
    if created < cutoff:
        candidates.append((name, created.isoformat(), int(s.get('diskSizeGb', 0) or 0)))

candidates.sort(key=lambda x: x[1])
with open(out_path, 'w', encoding='utf-8') as f:
    for name, created, size in candidates:
        f.write(f"{name}\t{created}\t{size}\n")

print(f"quota_limit={limit}")
print(f"quota_usage={usage}")
print(f"quota_free={max(limit-usage,0)}")
print(f"total_snapshots={len(snaps)}")
print(f"candidates_older_than_{retention_days}d={len(candidates)}")
PY

if [[ ! -s "$candidates_file" ]]; then
  echo "No over-retention snapshots found for prefix '$NAME_PREFIX'."
  exit 0
fi

echo ""
echo "Candidate snapshots (first 20):"
head -n 20 "$candidates_file" | awk -F '\t' '{printf "  - %s  (%s)  %sGiB\n", $1, $2, $3}'
echo ""

candidate_count="$(wc -l < "$candidates_file" | tr -d ' ')"
echo "Total candidates: $candidate_count"

if [[ "$APPLY" -ne 1 ]]; then
  echo "Dry-run only. Re-run with --apply to delete candidates."
  exit 0
fi

if [[ "$CONFIRM_PRUNE_GCP_SNAPSHOTS" != "$CONFIRM_TOKEN" ]]; then
  die "Refusing --apply without explicit confirmation token. Set CONFIRM_PRUNE_GCP_SNAPSHOTS=${CONFIRM_TOKEN}"
fi

if is_prod_like_project "$PROJECT_ID" && [[ "$ALLOW_PROD_APPLY" != "1" ]]; then
  die "Refusing --apply on prod-like project '$PROJECT_ID' without ALLOW_PROD_APPLY=1"
fi

if [[ "$REQUIRE_MAX_DELETE" == "1" && "$MAX_DELETE" -le 0 ]]; then
  die "Refusing --apply with REQUIRE_MAX_DELETE=1 unless --max-delete is set to a positive integer"
fi

echo "Applying deletions..."

deleted=0
while IFS=$'\t' read -r name _created _size; do
  if [[ "$MAX_DELETE" -gt 0 && "$deleted" -ge "$MAX_DELETE" ]]; then
    break
  fi
  printf '  deleting %s\n' "$name"
  gcloud compute snapshots delete "$name" --project "$PROJECT_ID" --quiet
  deleted=$((deleted + 1))
done < "$candidates_file"

echo "Deleted snapshots: $deleted"

echo "Post-delete quota snapshot:"
post_quota_json="$workdir/post-quota.json"
gcloud compute project-info describe --project "$PROJECT_ID" --format=json > "$post_quota_json"
python3 - "$post_quota_json" <<'PY'
import json
import sys
with open(sys.argv[1], "r", encoding="utf-8") as f:
    q = json.load(f).get('quotas', [])
s=next((x for x in q if x.get('metric')=='SNAPSHOTS'),{})
limit=int(float(s.get('limit',0) or 0))
usage=int(float(s.get('usage',0) or 0))
print(f"  SNAPSHOTS limit={limit} usage={usage} free={max(limit-usage,0)}")
PY
